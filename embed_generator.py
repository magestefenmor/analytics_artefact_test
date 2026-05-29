"""
embed_generator.py
==================
Génère les embeddings Cohere pour les textes non-structurés
(complaints + reviews) et les stocke dans DuckDB.

Usage:
    python embed_generator.py --api-key <COHERE_API_KEY>
    python embed_generator.py --api-key <COHERE_API_KEY> --dry-run

Modèle : embed-multilingual-v3.0
  → Supporte FR + EN (nos deux langues)
  → Dimension : 1024
  → Input type : search_document (pour le stockage)
                 search_query   (pour la recherche)
"""

import argparse
import duckdb
import cohere
import json
import time
import sys
from datetime import datetime

# ── Configuration ────────────────────────────────────────────────────────────

DB_PATH         = "dev.duckdb"
EMBED_MODEL     = "embed-multilingual-v3.0"
EMBED_DIM       = 1024
BATCH_SIZE      = 96        # limite Cohere API par batch


# ── Helpers ──────────────────────────────────────────────────────────────────

def build_complaint_text(row: dict) -> str:
    """
    Construit le texte à embedder pour une plainte.
    On concatène type + texte + action corrective pour donner
    un contexte complet au modèle d'embedding.
    """
    parts = []
    if row.get("complaint_type"):
        parts.append(f"Type: {row['complaint_type']}")
    if row.get("complaint_text"):
        parts.append(row["complaint_text"])
    if row.get("corrective_action_taken"):
        parts.append(f"Action: {row['corrective_action_taken']}")
    return " | ".join(parts)


def build_review_text(row: dict) -> str:
    """
    Construit le texte à embedder pour un avis client.
    On inclut le sentiment et la catégorie pour enrichir le contexte.
    """
    parts = []
    if row.get("complaint_category"):
        parts.append(f"Thème: {row['complaint_category']}")
    if row.get("review_text"):
        parts.append(row["review_text"])
    if row.get("nlp_sentiment"):
        parts.append(f"Sentiment: {row['nlp_sentiment']}")
    return " | ".join(parts)


def batch_embed(client: cohere.Client, texts: list[str]) -> list[list[float]]:
    """
    Appelle l'API Cohere en batches de BATCH_SIZE.
    Retourne la liste de vecteurs dans le même ordre que les textes.
    """
    all_vectors = []

    for i in range(0, len(texts), BATCH_SIZE):
        batch      = texts[i:i + BATCH_SIZE]
        batch_num  = i // BATCH_SIZE + 1
        total_batches = (len(texts) + BATCH_SIZE - 1) // BATCH_SIZE
        print(f"  Batch {batch_num}/{total_batches} ({len(batch)} textes)...")

        response = client.embed(
            texts      = batch,
            model      = EMBED_MODEL,
            input_type = "search_document",  # stockage
        )

        all_vectors.extend(response.embeddings)

        # Pause entre batches pour respecter les rate limits
        if i + BATCH_SIZE < len(texts):
            time.sleep(0.5)

    return all_vectors


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Génère les embeddings Cohere")
    parser.add_argument("--api-key",  required=True, help="Clé API Cohere")
    parser.add_argument("--dry-run",  action="store_true",
                        help="Simule sans appeler l'API (test structure)")
    parser.add_argument("--reset",    action="store_true",
                        help="Supprime et recrée la table embeddings")
    args = parser.parse_args()

    # ── Connexion DuckDB ──────────────────────────────────────────────────────
    con = duckdb.connect(DB_PATH)
    print(f" Connecté à {DB_PATH}")

    # ── Création de la table complaint_embeddings ─────────────────────────────
    if args.reset:
        con.execute("DROP TABLE IF EXISTS complaint_embeddings")
        print("  Table complaint_embeddings supprimée")

    con.execute(f"""
        CREATE TABLE IF NOT EXISTS complaint_embeddings (
            doc_id          VARCHAR PRIMARY KEY,
            doc_type        VARCHAR,          -- 'complaint' | 'review'
            source_id       VARCHAR,          -- complaint_id ou review_id
            customer_id     VARCHAR,
            flight_id       VARCHAR,
            route_id        VARCHAR,
            doc_date        DATE,
            raw_text        VARCHAR,
            embed_text      VARCHAR,          -- texte effectivement embedé
            vector          FLOAT[{EMBED_DIM}],
            model           VARCHAR,
            embedded_at     TIMESTAMP,
            source_table    VARCHAR
        )
    """)
    print("Table complaint_embeddings prête")

    # ── Charger les complaints ────────────────────────────────────────────────
    print("\n Chargement des complaints...")
    complaints = con.execute("""
        SELECT
            'CMP-' || complaint_id          AS doc_id,
            'complaint'                     AS doc_type,
            complaint_id                    AS source_id,
            customer_id,
            flight_id,
            NULL                            AS route_id,
            TRY_CAST(complaint_date AS DATE) AS doc_date,
            complaint_text                  AS raw_text,
            complaint_type,
            corrective_action_taken
        FROM main_staging.stg_complaint_logs
        WHERE complaint_text IS NOT NULL
          AND complaint_id NOT IN (
              SELECT source_id FROM complaint_embeddings
              WHERE doc_type = 'complaint'
          )
    """).fetchdf()

    print(f"  {len(complaints)} complaints à embedder")

    # ── Charger les reviews ───────────────────────────────────────────────────
    print(" Chargement des reviews...")
    reviews = con.execute("""
        SELECT
            'REV-' || review_id             AS doc_id,
            'review'                        AS doc_type,
            review_id                       AS source_id,
            customer_id,
            flight_id,
            route_id,
            TRY_CAST(review_date AS DATE)   AS doc_date,
            review_text                     AS raw_text,
            complaint_category,
            nlp_sentiment
        FROM main_staging.stg_reviews
        WHERE review_text IS NOT NULL
          AND review_id NOT IN (
              SELECT source_id FROM complaint_embeddings
              WHERE doc_type = 'review'
          )
    """).fetchdf()

    # Support tickets — 3ème source non-structurée
    print("Chargement des support tickets...")
    tickets = con.execute("""
        SELECT
            'TKT-' || ticket_id             AS doc_id,
            'ticket'                        AS doc_type,
            ticket_id                       AS source_id,
            customer_id,
            NULL                            AS flight_id,
            NULL                            AS route_id,
            TRY_CAST(created_date AS DATE)  AS doc_date,
            ticket_text                     AS raw_text,
            category                        AS complaint_category,
            NULL                            AS nlp_sentiment
        FROM main_staging.stg_support_tickets
        WHERE ticket_text IS NOT NULL
          AND ticket_id NOT IN (
              SELECT source_id FROM complaint_embeddings
              WHERE doc_type = 'ticket'
          )
    """).fetchdf()
    print(f"  {len(tickets)} tickets à embedder")

    print(f"  {len(reviews)} reviews à embedder")

    total = len(complaints) + len(reviews) + len(tickets)
    if total == 0:
        print("\n Tous les documents sont déjà embedés.")
        con.close()
        return

    # ── Construire les textes à embedder ──────────────────────────────────────
    complaint_texts = [
        build_complaint_text({
            "complaint_type":          row["complaint_type"],
            "complaint_text":          row["raw_text"],
            "corrective_action_taken": row["corrective_action_taken"],
        })
        for _, row in complaints.iterrows()
    ]

    review_texts = [
        build_review_text({
            "complaint_category": row["complaint_category"],
            "review_text":        row["raw_text"],
            "nlp_sentiment":      row["nlp_sentiment"],
        })
        for _, row in reviews.iterrows()
    ]

    ticket_texts = [
        f"Ticket {row['complaint_category']}: {row['raw_text']}"
        for _, row in tickets.iterrows()
    ]

    all_texts   = complaint_texts + review_texts + ticket_texts
    all_sources = (
        [("complaint", row) for _, row in complaints.iterrows()] +
        [("review",    row) for _, row in reviews.iterrows()]   +
        [("ticket",    row) for _, row in tickets.iterrows()]
    )

    total = len(all_texts)
    print(f"\n Total : {total} documents à embedder")

    # ── Mode dry-run ──────────────────────────────────────────────────────────
    if args.dry_run:
        print("\n DRY RUN — aperçu des textes qui seraient embedés :")
        for i, (doc_type, row) in enumerate(all_sources[:3]):
            print(f"\n  [{doc_type}] {row['doc_id']}")
            print(f"  Texte: {all_texts[i][:150]}...")
        print(f"\n  ... et {total - 3} autres documents.")
        print("\n Dry run terminé. Lance sans --dry-run pour embedder.")
        con.close()
        return

    # ── Appel Cohere API ──────────────────────────────────────────────────────
    print(f"\n Génération des embeddings via Cohere ({EMBED_MODEL})...")
    client  = cohere.Client(api_key=args.api_key)
    vectors = batch_embed(client, all_texts)
    print(f" {len(vectors)} vecteurs générés (dim={EMBED_DIM})")

    # ── Insertion dans DuckDB ─────────────────────────────────────────────────
    print("\n Insertion dans DuckDB...")
    embedded_at = datetime.now()
    inserted    = 0

    for i, ((doc_type, row), vector) in enumerate(zip(all_sources, vectors)):
        # Convertir le vecteur en liste Python
        vec_list = vector if isinstance(vector, list) else list(vector)

        con.execute("""
            INSERT OR REPLACE INTO complaint_embeddings (
                doc_id, doc_type, source_id, customer_id, flight_id, route_id,
                doc_date, raw_text, embed_text, vector,
                model, embedded_at, source_table
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, [
            row["doc_id"],
            doc_type,
            row["source_id"],
            row.get("customer_id"),
            row.get("flight_id"),
            row.get("route_id"),
            row.get("doc_date"),
            row["raw_text"],
            all_texts[i],
            vec_list,
            EMBED_MODEL,
            embedded_at,
            {'complaint': 'main_staging.stg_complaint_logs', 'review': 'main_staging.stg_reviews', 'ticket': 'main_staging.stg_support_tickets'}.get(doc_type, 'unknown'),
        ])
        inserted += 1

        if inserted % 50 == 0:
            print(f"  {inserted}/{total} insérés...")

    con.commit()

    # ── Validation finale ─────────────────────────────────────────────────────
    count    = con.execute("SELECT COUNT(*) FROM complaint_embeddings").fetchone()[0]
    by_type  = con.execute("""
        SELECT doc_type, COUNT(*) AS n
        FROM complaint_embeddings
        GROUP BY doc_type
    """).fetchall()

    print(f"\n Embedding terminé !")
    print(f" Total dans DuckDB : {count} documents")
    for doc_type, n in by_type:
        print(f"   - {doc_type}: {n}")

    # Test cosine similarity
    print("\n Test cosine similarity (sanity check)...")
    test = con.execute(f"""
        SELECT doc_id, doc_type,
               array_cosine_similarity(
                   vector::FLOAT[{EMBED_DIM}],
                   (SELECT vector::FLOAT[{EMBED_DIM}]
                    FROM complaint_embeddings LIMIT 1)
               ) AS similarity
        FROM complaint_embeddings
        ORDER BY similarity DESC
        LIMIT 3
    """).fetchall()

    for doc_id, doc_type, sim in test:
        print(f"   {doc_id} ({doc_type}): similarity = {sim:.4f}")

    con.close()
    print("\n Script terminé avec succès.")


if __name__ == "__main__":
    main()
