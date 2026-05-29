"""
llm_agent.py
============
LLM Agent Air CI — Cohere Chat avec Tool Use.

Architecture :
  User question
    ↓
  Cohere LLM (Command A)
    ↓ décide quels tools appeler
  MCP Tools (via import direct du mcp_server)
    ↓ retourne les données DuckDB
  Cohere LLM
    ↓ synthétise une réponse grounded avec citations
  Réponse finale

Usage :
  python llm_agent.py --cohere-key <KEY>
  python llm_agent.py --cohere-key <KEY> --question "Which routes need budget?"
"""

import os
import sys
import json
import argparse
import re
import cohere
from typing import Optional

# Import direct des tools du MCP Server
# (pas de transport stdio pour la démo — appel direct en Python)
from mcp_server import (
    tool_get_route_performance,
    tool_get_at_risk_customers,
    tool_get_budget_recommendation,
    tool_compare_routes,
    tool_search_complaints,
    tool_analyze_route_sentiment,
    DB_PATH,
)
import mcp_server as _srv

# ── Configuration ─────────────────────────────────────────────────────────────

MAX_TOKENS = 2000
LLM_MODEL  = os.getenv("COHERE_CHAT_MODEL", "command-a-03-2025")
MAX_STEPS  = 5                    # Nombre maximum de tours tool use

# ── Définition des tools pour Cohere ─────────────────────────────────────────
# Cohere tool use utilise un format légèrement différent de MCP
# On mappe les 6 tools MCP vers le format Cohere

COHERE_TOOLS = [
    {
        "name": "get_route_performance",
        "description": (
            "Retourne les KPIs de performance d'une route Air CI : "
            "load factor, yield, RASK, CASK, marge, OTP, sentiment client. "
            "Si route_id est omis, retourne le classement de toutes les routes "
            "par marge décroissante."
        ),
        "parameter_definitions": {
            "route_id": {
                "description": "ID de la route (ex: R001, R009). Optionnel — omettre pour toutes les routes.",
                "type": "str",
                "required": False,
            }
        }
    },
    {
        "name": "get_at_risk_customers",
        "description": (
            "Identifie les clients à forte valeur (LTV élevée) "
            "inactifs depuis N jours. "
            "Utile pour cibler les campagnes de rétention."
        ),
        "parameter_definitions": {
            "days_inactive": {
                "description": "Nombre de jours d'inactivité minimum (défaut: 90)",
                "type": "int",
                "required": False,
            },
            "min_ltv_usd": {
                "description": "LTV minimum en USD pour considérer un client haute valeur (défaut: 500)",
                "type": "float",
                "required": False,
            },
            "loyalty_tier": {
                "description": "Filtrer par tier loyalty : Gold, Silver, Explorer, None",
                "type": "str",
                "required": False,
            },
            "limit": {
                "description": "Nombre de clients retournés (défaut: 20)",
                "type": "int",
                "required": False,
            }
        }
    },
    {
        "name": "get_budget_recommendation",
        "description": (
            "Analyse le réseau complet et recommande l'allocation budgétaire "
            "entre 3 axes stratégiques : "
            "route optimization, customer retention, upsell/cross-sell. "
            "Inclut les scores de priorité et le raisonnement chiffré."
        ),
        "parameter_definitions": {}
    },
    {
        "name": "compare_routes",
        "description": (
            "Compare deux routes sur tous les KPIs financiers, opérationnels "
            "et qualitatifs. Retourne un verdict structuré avec un gagnant par dimension."
        ),
        "parameter_definitions": {
            "route_a": {
                "description": "ID de la première route (ex: R001)",
                "type": "str",
                "required": True,
            },
            "route_b": {
                "description": "ID de la deuxième route (ex: R009)",
                "type": "str",
                "required": True,
            }
        }
    },
    {
        "name": "search_complaints",
        "description": (
            "Recherche sémantique dans les plaintes, reviews et tickets "
            "via embeddings vectoriels Cohere. "
            "Trouve les documents les plus pertinents même sans correspondance "
            "exacte de mots-clés. Utiliser pour les questions sur la satisfaction client."
        ),
        "parameter_definitions": {
            "query": {
                "description": "Question ou thème à rechercher en langage naturel",
                "type": "str",
                "required": True,
            },
            "top_k": {
                "description": "Nombre de résultats à retourner (défaut: 5)",
                "type": "int",
                "required": False,
            }
        }
    },
    {
        "name": "analyze_route_sentiment",
        "description": (
            "Analyse qualitative complète d'une route : "
            "combine KPIs structurés (OTP, marge, load factor) + "
            "données non-structurées (plaintes récentes, reviews, catégories de problèmes). "
            "Utiliser pour comprendre POURQUOI une route sous-performe."
        ),
        "parameter_definitions": {
            "route_id": {
                "description": "ID de la route à analyser (ex: R009)",
                "type": "str",
                "required": True,
            }
        }
    },
]

# ── System Prompt ─────────────────────────────────────────────────────────────

SYSTEM_PROMPT = """Tu es un analyste senior en données pour Air Côte d'Ivoire.
Tu as accès à des outils d'analyse couvrant les performances des routes, 
la rétention client, les revenus ancillaires et les données qualitatives 
(plaintes, reviews).

Tes réponses sont :
- Précises et chiffrées (toujours citer les KPIs)
- Actionnables (recommandations concrètes)
- Grounded (basées uniquement sur les données retournées par les outils)
- Structurées (contexte → analyse → recommandation)

Langue : réponds dans la langue de la question (français ou anglais).
"""

# ── Dispatcher Tools ──────────────────────────────────────────────────────────

def log_safe(text: str = ""):
    """Print sans casser les consoles Windows cp1252."""
    encoding = sys.stdout.encoding or "utf-8"
    print(str(text).encode(encoding, errors="replace").decode(encoding))


def execute_tool(tool_name: str, tool_params: dict) -> str:
    """
    Exécute un tool MCP et retourne le résultat JSON.
    C'est ici que le LLM Agent appelle le MCP Server.
    """
    log_safe(f"\n  Tool appele : {tool_name}")
    log_safe(f"     Params      : {json.dumps(tool_params, ensure_ascii=True)}")

    try:
        if tool_name == "get_route_performance":
            result = tool_get_route_performance(**tool_params)

        elif tool_name == "get_at_risk_customers":
            result = tool_get_at_risk_customers(**tool_params)

        elif tool_name == "get_budget_recommendation":
            result = tool_get_budget_recommendation()

        elif tool_name == "compare_routes":
            result = tool_compare_routes(**tool_params)

        elif tool_name == "search_complaints":
            result = tool_search_complaints(**tool_params)

        elif tool_name == "analyze_route_sentiment":
            result = tool_analyze_route_sentiment(**tool_params)

        else:
            result = json.dumps({"error": f"Tool inconnu : {tool_name}"})

    except Exception as e:
        result = json.dumps({"error": str(e), "tool": tool_name})

    # Afficher un aperçu du résultat
    preview = result[:200] + "..." if len(result) > 200 else result
    log_safe(f"     Resultat    : {preview}")

    return result


def select_direct_tools(question: str) -> list[tuple[str, dict]]:
    """
    Route les intentions evidentes vers les tools.
    Cela evite les reponses du type "je vais utiliser l'outil" sans appel reel.
    """
    q = question.lower()
    route_match = re.search(r"\bR\d{3}\b", question, flags=re.IGNORECASE)
    route_id = route_match.group(0).upper() if route_match else "R001"

    if any(term in q for term in (
        "budget", "allocation", "invest", "investment", "next quarter",
        "trimestre", "optimisation budg", "optimisation budget",
        "more budget", "deserve more"
    )):
        return [("get_budget_recommendation", {})]

    if any(term in q for term in (
        "at risk", "risque", "retention", "inactive", "inactif",
        "churn"
    )):
        return [("get_at_risk_customers", {"limit": 10})]

    if any(term in q for term in (
        "complaint", "complaints", "plainte", "plaintes",
        "satisfaction", "low satisfaction", "sentiment",
        "quality", "qualite", "qualité", "driver", "driving",
        "why", "pourquoi"
    )) and ("route" in q or route_match):
        return [("analyze_route_sentiment", {"route_id": route_id})]

    if any(term in q for term in (
        "all routes", "toutes les routes", "route performance",
        "performance des routes", "classement"
    )):
        return [("get_route_performance", {})]

    return []


def synthesize_tool_outputs(
    client: cohere.Client,
    question: str,
    tool_outputs: list[dict],
    verbose: bool = True
) -> str:
    """Demande au LLM de synthetiser les resultats reels des tools."""
    payload = json.dumps(tool_outputs, ensure_ascii=False, indent=2)
    message = (
        "Question utilisateur:\n"
        f"{question}\n\n"
        "Resultats des outils MCP au format JSON:\n"
        f"{payload}\n\n"
        "Redige une reponse concise, chiffree et actionnable. "
        "Base-toi uniquement sur ces resultats."
    )

    response = client.chat(
        model=LLM_MODEL,
        message=message,
        preamble=SYSTEM_PROMPT,
        max_tokens=MAX_TOKENS,
        temperature=0.2,
    )

    if verbose:
        print(f"\n{'='*60}")
        print("Reponse finale :")
        print(f"{'='*60}")
        print(response.text)

    return response.text


# ── Agent Loop ────────────────────────────────────────────────────────────────

def run_agent(
    client:    cohere.Client,
    question:  str,
    verbose:   bool = True
) -> str:
    """
    Boucle agent : 
    1. Envoyer la question au LLM
    2. Si le LLM appelle des tools → exécuter → renvoyer les résultats
    3. Répéter jusqu'à réponse finale (max MAX_STEPS tours)
    """

    if verbose:
        print(f"\n{'='*60}")
        print(f"Question : {question}")
        print(f"{'='*60}")

    direct_tools = select_direct_tools(question)
    if direct_tools:
        tool_outputs = []
        for tool_name, tool_params in direct_tools:
            tool_outputs.append({
                "tool": tool_name,
                "parameters": tool_params,
                "result": execute_tool(tool_name, tool_params),
            })
        return synthesize_tool_outputs(client, question, tool_outputs, verbose)

    chat_history = []
    current_message = question
    tool_results_for_next_turn = None

    for step in range(MAX_STEPS):

        if verbose and step > 0:
            print(f"\n  Tour {step + 1}/{MAX_STEPS}")

        # ── Appel Cohere Chat ─────────────────────────────────────────────────
        kwargs = {
            "message":       current_message if tool_results_for_next_turn is None else "",
            "model":         LLM_MODEL,
            "preamble":      SYSTEM_PROMPT,
            "tools":         COHERE_TOOLS,
            "chat_history":  chat_history,
            "max_tokens":    MAX_TOKENS,
            "temperature":   0.3,           # faible pour des réponses factuelles
        }

        # Si on a des résultats de tools à envoyer
        if tool_results_for_next_turn is not None:
            kwargs["tool_results"] = tool_results_for_next_turn
            kwargs["message"]      = ""

        response = client.chat(**kwargs)

        # ── Réponse finale ────────────────────────────────────────────────────
        if response.finish_reason in ("COMPLETE", "MAX_TOKENS", "STOP_SEQUENCE"):
            if verbose:
                print(f"\n{'='*60}")
                print("Reponse finale :")
                print(f"{'='*60}")
                print(response.text)

                # Afficher les citations si disponibles
                if hasattr(response, "citations") and response.citations:
                    print(f"\nSources citees ({len(response.citations)}) :")
                    for i, c in enumerate(response.citations[:5], 1):
                        print(f"   {i}. {c.text[:100]}...")

            return response.text

        # ── Tool Use ──────────────────────────────────────────────────────────
        if response.finish_reason == "TOOL_CALL" and response.tool_calls:

            # Ajouter le message du LLM à l'historique
            chat_history.append({
                "role":    "CHATBOT",
                "message": response.text or "",
                "tool_calls": [
                    {
                        "name":        tc.name,
                        "parameters":  tc.parameters,
                    }
                    for tc in response.tool_calls
                ]
            })

            # Exécuter tous les tools demandés
            tool_results_for_next_turn = []

            for tc in response.tool_calls:
                tool_output = execute_tool(
                    tool_name=tc.name,
                    tool_params=tc.parameters or {}
                )
                tool_results_for_next_turn.append({
                    "call":    {"name": tc.name, "parameters": tc.parameters},
                    "outputs": [{"result": tool_output}]
                })

            # L'historique reçoit aussi les résultats des tools
            chat_history.append({
                "role":         "USER",
                "message":      "",
                "tool_results": tool_results_for_next_turn
            })

        else:
            # Cas inattendu
            if verbose:
                print(f"finish_reason inattendu : {response.finish_reason}")
            return response.text or "Pas de réponse générée."

    return "Nombre maximum de tours atteint sans reponse finale."


# ── Mode Interactif ───────────────────────────────────────────────────────────

def interactive_mode(client: cohere.Client):
    """
    Mode REPL — pose des questions en boucle.
    Tape 'exit' pour quitter.
    """
    print("\n" + "="*60)
    print("Air CI Analytics Agent - Mode Interactif")
    print("="*60)
    print("Pose tes questions en français ou en anglais.")
    print("Tape 'exit' pour quitter.\n")

    while True:
        try:
            question = input("Ta question : ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nAu revoir.")
            break

        if not question:
            continue
        if question.lower() in ("exit", "quit", "q"):
            print("Au revoir.")
            break

        run_agent(client, question, verbose=True)
        print()


# ── Entrée principale ─────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="LLM Agent Air CI")
    parser.add_argument(
        "--cohere-key",
        default=os.getenv("COHERE_API_KEY", ""),
        help="Clé API Cohere"
    )
    parser.add_argument(
        "--db-path",
        default=DB_PATH,
        help="Chemin vers airci.duckdb"
    )
    parser.add_argument(
        "--question",
        default=None,
        help="Question unique (mode non-interactif)"
    )
    args = parser.parse_args()

    if not args.cohere_key:
        print("Cle API Cohere requise. Passe --cohere-key ou definis COHERE_API_KEY.")
        sys.exit(1)

    # Mettre à jour le chemin DB dans le serveur MCP
    _srv.DB_PATH = args.db_path

    # Créer le client Cohere
    client = cohere.Client(api_key=args.cohere_key)
    _srv._cohere = client  # partager le client avec le MCP server

    if args.question:
        # Mode question unique
        run_agent(client, args.question, verbose=True)
    else:
        # Mode interactif
        interactive_mode(client)


if __name__ == "__main__":
    main()
