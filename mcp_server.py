"""
mcp_server.py
=============
MCP Server Air Côte d'Ivoire
Expose les données analytiques via 6 tools intelligents.

Tools :
  - get_route_performance      → KPIs d'une route (structuré)
  - get_at_risk_customers      → clients à risque (structuré)
  - get_budget_recommendation  → allocation budget réseau (structuré)
  - compare_routes             → comparaison deux routes (structuré + sentiment)
  - search_complaints          → recherche sémantique plaintes (non-structuré)
  - analyze_route_sentiment    → analyse qualitative d'une route (hybride)

Usage :
  python mcp_server.py --db-path airci.duckdb --cohere-key <KEY>
  
  Ou via variables d'environnement :
  AIRCI_DB_PATH=... COHERE_API_KEY=... python mcp_server.py
"""

import os
import sys
import json
import argparse
import duckdb
import cohere
import asyncio
from pathlib import Path
from dotenv import load_dotenv


ENV_PATH = Path(__file__).resolve().with_name(".env")
load_dotenv(dotenv_path=ENV_PATH)

import mcp.types as types
from mcp.server import Server
from mcp.server.stdio import stdio_server

# ── Configuration ─────────────────────────────────────────────────────────────

DB_PATH       = os.getenv("AIRCI_DB_PATH", "dev.duckdb")
COHERE_KEY    = os.getenv("COHERE_API_KEY")
EMBED_MODEL   = "embed-multilingual-v3.0"
EMBED_DIM     = 1024
TOP_K_DEFAULT = 5

# Tables materialisees par dbt dans DuckDB.
T_OBT_ROUTE_SUMMARY = "main_ai_ready.obt_route_summary"
T_OBT_CUSTOMER_360 = "main_ai_ready.obt_customer_360"
T_COMPLAINT_EMBEDDINGS = "main.complaint_embeddings"
T_STG_COMPLAINT_LOGS = "main_staging.stg_complaint_logs"
T_STG_FLIGHTS = "main_staging.stg_flights"
T_STG_REVIEWS = "main_staging.stg_reviews"




# ── Connexions globales ────────────────────────────────────────────────────────

_con: duckdb.DuckDBPyConnection = None
_cohere: cohere.Client          = None


def get_db() -> duckdb.DuckDBPyConnection:
    global _con
    if _con is None:
        _con = duckdb.connect(DB_PATH, read_only=True)
    return _con


def get_cohere() -> cohere.Client:
    global _cohere
    if _cohere is None:
        if not COHERE_KEY:
            raise RuntimeError(
                "COHERE_API_KEY non défini. "
                "Passe --cohere-key ou définis COHERE_API_KEY."
            )
        _cohere = cohere.Client(api_key=COHERE_KEY)
    return _cohere


# ── Helpers SQL ───────────────────────────────────────────────────────────────

def fmt(val, suffix="", decimals=2) -> str:
    """Formate un nombre avec séparateurs et suffix."""
    if val is None:
        return "N/A"
    if isinstance(val, float):
        return f"{val:,.{decimals}f}{suffix}"
    return f"{val:,}{suffix}"


def row_to_dict(cursor) -> list[dict]:
    """Convertit les résultats DuckDB en liste de dicts."""
    cols = [d[0] for d in cursor.description]
    return [dict(zip(cols, row)) for row in cursor.fetchall()]


def table_exists(con: duckdb.DuckDBPyConnection, qualified_name: str) -> bool:
    """Verifie l'existence d'une table ou vue DuckDB avec nom schema.table."""
    schema, table = qualified_name.split(".", 1)
    return con.execute(
        """
        SELECT COUNT(*)
        FROM information_schema.tables
        WHERE table_schema = ?
          AND table_name = ?
        """,
        [schema, table],
    ).fetchone()[0] > 0


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 1 — get_route_performance
# ═══════════════════════════════════════════════════════════════════════════════

def tool_get_route_performance(route_id: str = None) -> str:
    """
    Retourne les KPIs de performance d'une route spécifique
    ou le classement de toutes les routes si route_id est None.
    """
    con = get_db()

    if route_id:
        # Route spécifique
        rows = con.execute(f"""
            SELECT
                route_id,
                route_label,
                route_type,
                origin_city,
                destination_city,
                distance_km,
                total_flights,
                total_seats_sold,
                total_seats_available,
                ROUND(avg_load_factor * 100, 1)         AS load_factor_pct,
                ROUND(on_time_rate * 100, 1)             AS otp_pct,
                ROUND(avg_delay_min, 0)                  AS avg_delay_min,
                ROUND(avg_yield_usd, 2)                  AS avg_yield_usd,
                ROUND(rask_usd, 2)                       AS rask_usd,
                ROUND(cask_usd, 2)                       AS cask_usd,
                ROUND(total_revenue_usd, 0)              AS total_revenue_usd,
                ROUND(total_cost_usd, 0)                 AS total_cost_usd,
                ROUND(total_margin_usd, 0)               AS total_margin_usd,
                ROUND(margin_pct, 1)                     AS margin_pct,
                ROUND(revenue_share_network * 100, 1)   AS revenue_share_pct,
                ROUND(avg_sentiment_score, 2)            AS avg_sentiment_score,
                ROUND(avg_rating, 2)                     AS avg_rating,
                route_label_ontology
            FROM {T_OBT_ROUTE_SUMMARY}
            WHERE UPPER(route_id) = UPPER(?)
        """, [route_id]).fetchdf()

        if rows.empty:
            return json.dumps({
                "error": f"Route '{route_id}' introuvable.",
                "available_routes": con.execute(
                    f"SELECT route_id, route_label FROM {T_OBT_ROUTE_SUMMARY} ORDER BY route_id"
                ).fetchdf().to_dict("records")
            }, ensure_ascii=False)

        r = rows.iloc[0].to_dict()
        return json.dumps({
            "route": r,
            "interpretation": {
                "profitability":   r["route_label_ontology"],
                "load_factor":     "Optimal (≥75%)" if r["load_factor_pct"] >= 75
                                   else "Acceptable (60-75%)" if r["load_factor_pct"] >= 60
                                   else "Sous-rempli (<60%)",
                "margin_signal":   "Rentable ✅" if r["total_margin_usd"] >= 0
                                   else f"Déficitaire ❌ (perte: ${abs(r['total_margin_usd']):,.0f})",
                "sentiment_signal": "Positif 😊" if r["avg_sentiment_score"] > 0.3
                                   else "Neutre 😐" if r["avg_sentiment_score"] > -0.3
                                   else "Négatif 😟",
            }
        }, ensure_ascii=False, indent=2)

    else:
        # Toutes les routes classées par marge
        rows = con.execute(f"""
            SELECT
                route_id,
                route_label,
                route_type,
                ROUND(avg_load_factor * 100, 1)         AS load_factor_pct,
                ROUND(total_revenue_usd, 0)              AS total_revenue_usd,
                ROUND(total_margin_usd, 0)               AS total_margin_usd,
                ROUND(margin_pct, 1)                     AS margin_pct,
                ROUND(avg_sentiment_score, 2)            AS avg_sentiment,
                route_label_ontology
            FROM {T_OBT_ROUTE_SUMMARY}
            ORDER BY total_margin_usd DESC
        """).fetchdf()

        return json.dumps({
            "routes_ranked_by_margin": rows.to_dict("records"),
            "summary": {
                "total_routes":       len(rows),
                "profitable_routes":  int((rows["total_margin_usd"] >= 0).sum()),
                "loss_making_routes": int((rows["total_margin_usd"] < 0).sum()),
            }
        }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 2 — get_at_risk_customers
# ═══════════════════════════════════════════════════════════════════════════════

def tool_get_at_risk_customers(
    days_inactive: int = 90,
    min_ltv_usd:   float = 500.0,
    loyalty_tier:  str = None,
    limit:         int = 20
) -> str:
    """
    Identifie les clients à forte valeur inactifs depuis N jours.
    Paramètres :
      days_inactive : nombre de jours sans réservation (défaut: 90)
      min_ltv_usd   : LTV minimum pour considérer un client "haute valeur"
      loyalty_tier  : filtrer sur un tier (Gold, Silver, Explorer, None)
      limit         : nombre de clients retournés
    """
    con = get_db()

    tier_filter = ""
    params = [days_inactive, min_ltv_usd, limit]

    if loyalty_tier:
        tier_filter = "AND loyalty_tier = ?"
        params = [days_inactive, min_ltv_usd, loyalty_tier, limit]

    rows = con.execute(f"""
        SELECT
            customer_id,
            full_name,
            customer_segment,
            loyalty_tier,
            country,
            ROUND(total_ltv_usd, 0)                 AS total_ltv_usd,
            total_bookings,
            flown_bookings,
            days_since_last_booking,
            loyalty_balance,
            ROUND(loyalty_redemption_rate * 100, 1) AS redemption_rate_pct,
            tier_downgrades,
            ROUND(avg_ticket_price_usd, 0)          AS avg_ticket_price,
            recency_label,
            value_label,
            frequency_label
        FROM {T_OBT_CUSTOMER_360}
        WHERE days_since_last_booking >= ?
          AND total_ltv_usd >= ?
          {tier_filter}
          AND total_bookings > 0
        ORDER BY total_ltv_usd DESC
        LIMIT ?
    """, params).fetchdf()

    if rows.empty:
        return json.dumps({
            "message": "Aucun client à risque trouvé avec ces critères.",
            "criteria": {
                "days_inactive": days_inactive,
                "min_ltv_usd": min_ltv_usd,
                "loyalty_tier": loyalty_tier
            }
        }, ensure_ascii=False)

    total_ltv_at_risk = float(rows["total_ltv_usd"].sum())

    return json.dumps({
        "at_risk_customers": rows.to_dict("records"),
        "summary": {
            "count":                len(rows),
            "total_ltv_at_risk_usd": round(total_ltv_at_risk, 0),
            "avg_days_inactive":    round(float(rows["days_since_last_booking"].mean()), 0),
            "criteria": {
                "days_inactive": days_inactive,
                "min_ltv_usd":   min_ltv_usd,
                "loyalty_tier":  loyalty_tier or "Tous"
            }
        },
        "recommendation": (
            f"{len(rows)} clients représentant ${total_ltv_at_risk:,.0f} de LTV "
            f"sont inactifs depuis ≥{days_inactive} jours. "
            "Action prioritaire : campagne de réactivation ciblée."
        )
    }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 3 — get_budget_recommendation
# ═══════════════════════════════════════════════════════════════════════════════

def tool_get_budget_recommendation() -> str:
    """
    Analyse le réseau complet et recommande l'allocation budgétaire
    entre 3 axes : route expansion, customer retention, upsell/cross-sell.
    """
    con = get_db()

    # Métriques réseau
    network = con.execute(f"""
        SELECT
            SUM(total_revenue_usd)                          AS total_revenue,
            SUM(total_cost_usd)                             AS total_cost,
            SUM(total_margin_usd)                           AS total_margin,
            AVG(avg_load_factor)                            AS avg_load_factor,
            COUNT(*) FILTER (WHERE total_margin_usd >= 0)   AS profitable_routes,
            COUNT(*) FILTER (WHERE total_margin_usd < 0)    AS loss_routes,
            SUM(total_revenue_usd)
                FILTER (WHERE total_margin_usd < 0)         AS revenue_loss_routes,
            SUM(ABS(total_margin_usd))
                FILTER (WHERE total_margin_usd < 0)         AS total_losses
        FROM {T_OBT_ROUTE_SUMMARY}
    """).fetchone()

    # Métriques clients
    customers = con.execute(f"""
        SELECT
            COUNT(*)                                        AS total_customers,
            COUNT(*) FILTER (WHERE recency_label = 'En risque')  AS at_risk,
            COUNT(*) FILTER (WHERE recency_label = 'Dormant')    AS dormant,
            SUM(total_ltv_usd)
                FILTER (WHERE recency_label = 'En risque')  AS ltv_at_risk,
            AVG(ancillary_attach_rate)                      AS avg_ancillary_rate,
            AVG(total_ltv_usd)                              AS avg_ltv
        FROM {T_OBT_CUSTOMER_360}
        WHERE total_bookings > 0
    """).fetchone()

    # Métriques upsell
    upsell = con.execute(f"""
        SELECT
            SUM(total_ancillary_revenue)                    AS total_ancillary,
            SUM(total_revenue_usd)                          AS total_revenue,
            ROUND(SUM(total_ancillary_revenue)
                / NULLIF(SUM(total_revenue_usd), 0) * 100, 1) AS ancillary_share_pct,
            AVG(avg_load_factor)
                FILTER (WHERE route_type = 'International') AS intl_load_factor,
            AVG(avg_load_factor)
                FILTER (WHERE route_type = 'Domestic')      AS dom_load_factor
        FROM {T_OBT_ROUTE_SUMMARY}
    """).fetchone()

    # Scores par axe (0-100)
    route_score    = min(100, int((network[5] / max(network[4] + network[5], 1)) * 100))
    retention_score = min(100, int((customers[1] / max(customers[0], 1)) * 100))
    upsell_score   = max(0, 100 - int(upsell[2] or 0) * 5)  # plus ancillary est bas, plus prioritaire

    total_score = route_score + retention_score + upsell_score

    return json.dumps({
        "network_health": {
            "total_revenue_usd":  round(network[0] or 0, 0),
            "total_margin_usd":   round(network[2] or 0, 0),
            "avg_load_factor_pct": round((network[3] or 0) * 100, 1),
            "profitable_routes":  network[4],
            "loss_routes":        network[5],
            "total_losses_usd":   round(network[7] or 0, 0),
        },
        "customer_health": {
            "total_customers":    customers[0],
            "at_risk_count":      customers[1],
            "dormant_count":      customers[2],
            "ltv_at_risk_usd":    round(customers[3] or 0, 0),
            "avg_ancillary_rate": round((customers[4] or 0) * 100, 1),
        },
        "upsell_opportunity": {
            "ancillary_share_pct":    upsell[2],
            "industry_benchmark_pct": 20.0,
            "gap_pct":                round(20.0 - (upsell[2] or 0), 1),
            "intl_load_factor_pct":   round((upsell[3] or 0) * 100, 1),
            "dom_load_factor_pct":    round((upsell[4] or 0) * 100, 1),
        },
        "budget_allocation": {
            "route_optimization": {
                "priority_score":  route_score,
                "recommended_pct": round(route_score / total_score * 100, 0),
                "rationale": (
                    f"{network[5]} routes déficitaires générant "
                    f"${(network[7] or 0):,.0f} de pertes. "
                    "Repricing tarifaire ou réduction de fréquence recommandée."
                )
            },
            "customer_retention": {
                "priority_score":  retention_score,
                "recommended_pct": round(retention_score / total_score * 100, 0),
                "rationale": (
                    f"{customers[1]} clients 'En risque' représentant "
                    f"${(customers[3] or 0):,.0f} de LTV. "
                    "Campagne de réactivation ciblée à fort ROI."
                )
            },
            "upsell_cross_sell": {
                "priority_score":  upsell_score,
                "recommended_pct": round(upsell_score / total_score * 100, 0),
                "rationale": (
                    f"Ancillary share à {upsell[2]}% vs benchmark 20%. "
                    f"Gap de {round(20.0 - (upsell[2] or 0), 1)}pp à combler. "
                    "Offres bagages, siège, lounge à cibler sur Business et Gold."
                )
            }
        }
    }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 4 — compare_routes
# ═══════════════════════════════════════════════════════════════════════════════

def tool_compare_routes(route_a: str, route_b: str) -> str:
    """
    Compare deux routes sur tous les KPIs financiers, opérationnels
    et qualitatifs (sentiment). Inclut un verdict structuré.
    """
    con = get_db()

    rows = con.execute(f"""
        SELECT
            route_id,
            route_label,
            route_type,
            distance_km,
            total_flights,
            ROUND(avg_load_factor * 100, 1)         AS load_factor_pct,
            ROUND(on_time_rate * 100, 1)             AS otp_pct,
            ROUND(avg_delay_min, 0)                  AS avg_delay_min,
            ROUND(avg_yield_usd, 2)                  AS avg_yield_usd,
            ROUND(rask_usd, 2)                       AS rask_usd,
            ROUND(cask_usd, 2)                       AS cask_usd,
            ROUND(total_revenue_usd, 0)              AS total_revenue_usd,
            ROUND(total_margin_usd, 0)               AS total_margin_usd,
            ROUND(margin_pct, 1)                     AS margin_pct,
            ROUND(revenue_share_network * 100, 1)   AS revenue_share_pct,
            ROUND(avg_sentiment_score, 2)            AS avg_sentiment_score,
            ROUND(avg_rating, 2)                     AS avg_rating,
            route_label_ontology
        FROM {T_OBT_ROUTE_SUMMARY}
        WHERE UPPER(route_id) IN (UPPER(?), UPPER(?))
        ORDER BY route_id
    """, [route_a, route_b]).fetchdf()

    if len(rows) < 2:
        found = rows["route_id"].tolist() if not rows.empty else []
        missing = [r for r in [route_a, route_b]
                   if r.upper() not in [x.upper() for x in found]]
        return json.dumps({
            "error": f"Route(s) introuvable(s) : {missing}",
            "found": found
        }, ensure_ascii=False)

    a = rows.iloc[0].to_dict()
    b = rows.iloc[1].to_dict()

    def winner(field, higher_is_better=True):
        va, vb = a.get(field), b.get(field)
        if va is None or vb is None:
            return "N/A"
        if higher_is_better:
            return a["route_id"] if va > vb else b["route_id"]
        return a["route_id"] if va < vb else b["route_id"]

    return json.dumps({
        "comparison": {
            a["route_id"]: a,
            b["route_id"]: b,
        },
        "winners": {
            "load_factor":     winner("load_factor_pct"),
            "otp":             winner("otp_pct"),
            "yield":           winner("avg_yield_usd"),
            "rask":            winner("rask_usd"),
            "margin":          winner("total_margin_usd"),
            "sentiment":       winner("avg_sentiment_score"),
            "cost_efficiency": winner("cask_usd", higher_is_better=False),
        },
        "verdict": {
            "financially_stronger": winner("total_margin_usd"),
            "operationally_stronger": winner("otp_pct"),
            "customer_preferred":  winner("avg_sentiment_score"),
            "summary": (
                f"{a['route_label']} ({a['route_label_ontology']}) vs "
                f"{b['route_label']} ({b['route_label_ontology']}). "
                f"Marge : ${a['total_margin_usd']:,.0f} vs ${b['total_margin_usd']:,.0f}. "
                f"Load factor : {a['load_factor_pct']}% vs {b['load_factor_pct']}%."
            )
        }
    }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 5 — search_complaints (sémantique)
# ═══════════════════════════════════════════════════════════════════════════════

def tool_search_complaints(query: str, top_k: int = 5) -> str:
    """
    Recherche sémantique dans les plaintes, reviews et tickets
    via embeddings Cohere + cosine similarity DuckDB.
    Retourne les documents les plus pertinents pour la question posée.
    """
    con = get_db()

    # Vérifier que les embeddings existent
    if not table_exists(con, T_COMPLAINT_EMBEDDINGS):
        return json.dumps({
            "error": "Table d'embeddings introuvable.",
            "action": "Lance d'abord : python embed_generator.py --api-key <KEY>"
        }, ensure_ascii=False)

    count = con.execute(
        f"SELECT COUNT(*) FROM {T_COMPLAINT_EMBEDDINGS}"
    ).fetchone()[0]

    if count == 0:
        return json.dumps({
            "error": "Embeddings non générés.",
            "action": "Lance d'abord : python embed_generator.py --api-key <KEY>"
        }, ensure_ascii=False)

    # Embedder la query
    client      = get_cohere()
    query_embed = client.embed(
        texts      = [query],
        model      = EMBED_MODEL,
        input_type = "search_query",
    ).embeddings[0]

    # Recherche cosine similarity dans DuckDB
    results = con.execute(f"""
        SELECT
            doc_id,
            doc_type,
            source_id,
            flight_id,
            route_id,
            doc_date,
            raw_text,
            array_cosine_similarity(
                vector::FLOAT[{EMBED_DIM}],
                ?::FLOAT[{EMBED_DIM}]
            ) AS similarity
        FROM {T_COMPLAINT_EMBEDDINGS}
        ORDER BY similarity DESC
        LIMIT ?
    """, [query_embed, top_k]).fetchdf()

    if results.empty:
        return json.dumps({"message": "Aucun résultat."}, ensure_ascii=False)

    return json.dumps({
        "query":   query,
        "results": results.to_dict("records"),
        "note": (
            f"Top {len(results)} documents les plus proches sémantiquement. "
            "Similarity > 0.7 = très pertinent, > 0.5 = pertinent."
        )
    }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# TOOL 6 — analyze_route_sentiment (hybride)
# ═══════════════════════════════════════════════════════════════════════════════

def tool_analyze_route_sentiment(route_id: str) -> str:
    """
    Analyse qualitative complète d'une route :
    combine KPIs structurés + plaintes + reviews non-structurées.
    """
    con = get_db()

    # KPIs structurés
    route = con.execute(f"""
        SELECT
            route_id, route_label, route_type,
            ROUND(avg_load_factor * 100, 1)  AS load_factor_pct,
            ROUND(on_time_rate * 100, 1)     AS otp_pct,
            ROUND(avg_delay_min, 0)          AS avg_delay_min,
            ROUND(total_margin_usd, 0)       AS total_margin_usd,
            ROUND(avg_sentiment_score, 2)    AS avg_sentiment_score,
            ROUND(avg_rating, 2)             AS avg_rating,
            route_label_ontology
        FROM {T_OBT_ROUTE_SUMMARY}
        WHERE UPPER(route_id) = UPPER(?)
    """, [route_id]).fetchone()

    if not route:
        return json.dumps({
            "error": f"Route '{route_id}' introuvable."
        }, ensure_ascii=False)

    # Plaintes liées aux vols de cette route
    complaints = con.execute(f"""
        SELECT
            c.complaint_id,
            c.complaint_type,
            c.complaint_text,
            c.resolution_status,
            f.flight_id,
            f.flight_status
        FROM {T_STG_COMPLAINT_LOGS} c
        JOIN {T_STG_FLIGHTS} f ON f.flight_id = c.flight_id
        WHERE UPPER(f.route_id) = UPPER(?)
        ORDER BY c.complaint_date DESC
        LIMIT 10
    """, [route_id]).fetchdf()

    # Reviews liées à cette route
    reviews = con.execute(f"""
        SELECT
            r.review_id,
            r.rating AS rating_1_5,
            r.nlp_sentiment,
            r.complaint_category,
            r.review_text,
            r.language
        FROM {T_STG_REVIEWS} r
        WHERE UPPER(r.route_id) = UPPER(?)
        ORDER BY r.review_date DESC
        LIMIT 10
    """, [route_id]).fetchdf()

    # Catégories de plaintes les plus fréquentes
    top_complaint_types = (
        complaints["complaint_type"].value_counts().head(3).to_dict()
        if not complaints.empty else {}
    )
    top_complaint_cats = (
        reviews["complaint_category"].value_counts().head(3).to_dict()
        if not reviews.empty else {}
    )

    return json.dumps({
        "route": {
            "route_id":            route[0],
            "route_label":         route[1],
            "route_type":          route[2],
            "load_factor_pct":     route[3],
            "otp_pct":             route[4],
            "avg_delay_min":       route[5],
            "total_margin_usd":    route[6],
            "avg_sentiment_score": route[7],
            "avg_rating":          route[8],
            "ontology_label":      route[9],
        },
        "qualitative_signals": {
            "total_complaints":        len(complaints),
            "total_reviews":           len(reviews),
            "top_complaint_types":     top_complaint_types,
            "top_complaint_categories": top_complaint_cats,
            "recent_complaints": (
                complaints[["complaint_type", "complaint_text", "resolution_status"]]
                .head(3).to_dict("records")
                if not complaints.empty else []
            ),
            "recent_reviews": (
                reviews[["rating_1_5", "nlp_sentiment", "complaint_category", "review_text"]]
                .head(3).to_dict("records")
                if not reviews.empty else []
            ),
        },
        "diagnosis": {
            "structured_signal":    (
                "Opérationnel ✅" if route[4] >= 80
                else f"OTP faible ({route[4]}%) — retards fréquents ⚠️"
            ),
            "sentiment_signal":     (
                "Satisfaction bonne 😊" if (route[7] or 0) > 0.3
                else "Insatisfaction client 😟" if (route[7] or 0) < -0.3
                else "Satisfaction mitigée 😐"
            ),
            "main_complaint_driver": (
                list(top_complaint_types.keys())[0]
                if top_complaint_types else "Aucune plainte"
            ),
        }
    }, ensure_ascii=False, indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# MCP SERVER
# ═══════════════════════════════════════════════════════════════════════════════

server = Server("airci-analytics")


@server.list_tools()
async def list_tools() -> list[types.Tool]:
    return [
        types.Tool(
            name="get_route_performance",
            description=(
                "Retourne les KPIs de performance d'une route Air CI "
                "(load factor, yield, RASK, CASK, marge, OTP, sentiment). "
                "Si route_id est omis, retourne le classement de toutes les routes."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "route_id": {
                        "type": "string",
                        "description": "ID de la route (ex: R001, R009). Optionnel."
                    }
                }
            }
        ),
        types.Tool(
            name="get_at_risk_customers",
            description=(
                "Identifie les clients à forte valeur (LTV élevée) "
                "qui sont inactifs depuis N jours. "
                "Utile pour cibler les campagnes de rétention."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "days_inactive": {
                        "type": "integer",
                        "description": "Nombre de jours d'inactivité (défaut: 90)",
                        "default": 90
                    },
                    "min_ltv_usd": {
                        "type": "number",
                        "description": "LTV minimum en USD (défaut: 500)",
                        "default": 500.0
                    },
                    "loyalty_tier": {
                        "type": "string",
                        "description": "Filtrer par tier: Gold, Silver, Explorer, None",
                        "enum": ["Gold", "Silver", "Explorer", "None"]
                    },
                    "limit": {
                        "type": "integer",
                        "description": "Nombre de clients retournés (défaut: 20)",
                        "default": 20
                    }
                }
            }
        ),
        types.Tool(
            name="get_budget_recommendation",
            description=(
                "Analyse le réseau complet et recommande l'allocation budgétaire "
                "entre 3 axes : route optimization, customer retention, upsell/cross-sell. "
                "Inclut les scores de priorité et le raisonnement métier."
            ),
            inputSchema={
                "type": "object",
                "properties": {}
            }
        ),
        types.Tool(
            name="compare_routes",
            description=(
                "Compare deux routes sur tous les KPIs : "
                "financiers (marge, RASK, yield), opérationnels (OTP, retard, load factor) "
                "et qualitatifs (sentiment client). Retourne un verdict structuré."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "route_a": {
                        "type": "string",
                        "description": "ID de la première route (ex: R001)"
                    },
                    "route_b": {
                        "type": "string",
                        "description": "ID de la deuxième route (ex: R009)"
                    }
                },
                "required": ["route_a", "route_b"]
            }
        ),
        types.Tool(
            name="search_complaints",
            description=(
                "Recherche sémantique dans les plaintes, reviews et tickets "
                "via embeddings Cohere. Trouve les documents les plus proches "
                "de la question posée, même sans correspondance exacte de mots-clés."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "Question ou thème à rechercher en langage naturel"
                    },
                    "top_k": {
                        "type": "integer",
                        "description": "Nombre de résultats (défaut: 5)",
                        "default": 5
                    }
                },
                "required": ["query"]
            }
        ),
        types.Tool(
            name="analyze_route_sentiment",
            description=(
                "Analyse qualitative complète d'une route : "
                "combine KPIs structurés (OTP, marge) + données non-structurées "
                "(plaintes récentes, reviews, catégories de problèmes). "
                "Utile pour comprendre POURQUOI une route sous-performe."
            ),
            inputSchema={
                "type": "object",
                "properties": {
                    "route_id": {
                        "type": "string",
                        "description": "ID de la route à analyser (ex: R009)"
                    }
                },
                "required": ["route_id"]
            }
        ),
    ]


@server.call_tool()
async def call_tool(name: str, arguments: dict) -> list[types.TextContent]:
    """Dispatcher — route chaque appel vers le bon tool."""
    try:
        if name == "get_route_performance":
            result = tool_get_route_performance(
                route_id=arguments.get("route_id")
            )

        elif name == "get_at_risk_customers":
            result = tool_get_at_risk_customers(
                days_inactive=arguments.get("days_inactive", 90),
                min_ltv_usd=arguments.get("min_ltv_usd", 500.0),
                loyalty_tier=arguments.get("loyalty_tier"),
                limit=arguments.get("limit", 20),
            )

        elif name == "get_budget_recommendation":
            result = tool_get_budget_recommendation()

        elif name == "compare_routes":
            result = tool_compare_routes(
                route_a=arguments["route_a"],
                route_b=arguments["route_b"],
            )

        elif name == "search_complaints":
            result = tool_search_complaints(
                query=arguments["query"],
                top_k=arguments.get("top_k", 5),
            )

        elif name == "analyze_route_sentiment":
            result = tool_analyze_route_sentiment(
                route_id=arguments["route_id"]
            )

        else:
            result = json.dumps({"error": f"Tool inconnu : {name}"})

    except Exception as e:
        result = json.dumps({
            "error": str(e),
            "tool":  name,
            "args":  arguments
        }, ensure_ascii=False)

    return [types.TextContent(type="text", text=result)]


# ═══════════════════════════════════════════════════════════════════════════════
# ENTRÉE PRINCIPALE
# ═══════════════════════════════════════════════════════════════════════════════

async def main():
    global DB_PATH, COHERE_KEY

    parser = argparse.ArgumentParser(description="MCP Server Air CI")
    parser.add_argument("--db-path",    default=DB_PATH,    help="Chemin DuckDB")
    parser.add_argument("--cohere-key", default=COHERE_KEY, help="Clé API Cohere")
    args = parser.parse_args()

    DB_PATH    = args.db_path
    COHERE_KEY = args.cohere_key

    print(f"🚀 MCP Server Air CI démarré", file=sys.stderr)
    print(f"   DB    : {DB_PATH}",          file=sys.stderr)
    print(f"   Tools : 6 disponibles",       file=sys.stderr)

    async with stdio_server() as (read_stream, write_stream):
        await server.run(
            read_stream,
            write_stream,
            server.create_initialization_options()
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nMCP Server Air CI arrete.", file=sys.stderr)
