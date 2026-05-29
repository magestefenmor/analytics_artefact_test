# Air Cote d'Ivoire Analytics AI

Projet analytics engineer construit autour d'un pipeline dbt/DuckDB et d'une interface IA pour analyser les donnees operationnelles, commerciales et clients d'Air Cote d'Ivoire.

L'objectif est de transformer des fichiers sources en couches analytiques documentees, puis d'exposer ces donnees a un agent IA capable de repondre a des questions metier comme :

- Quelles routes meritent plus de budget au prochain trimestre ?
- Quels clients sont a risque de churn ?
- Pourquoi une route affiche une faible satisfaction ?
- Quelles routes doivent etre optimisees en priorite ?

## Architecture

Le projet suit une architecture en couches.

```text
seeds CSV
   |
   v
staging
   |
   v
data vault /business vault
   |
   v
marts
   |
   v
semantic + ontology
   |
   v
ai_ready
   |
   v
MCP tools + LLM agent + React UI
```

## Couches dbt

### Seeds

Les donnees sources sont chargees depuis `seeds/` :

- aeroports
- routes
- vols
- reservations
- clients
- couts de vol
- activite de fidelite
- avis clients
- plaintes
- tickets support

### Staging

Le dossier `models/staging/` nettoie et standardise les sources :

- typage des colonnes
- normalisation des noms
- conversion des montants et indicateurs numeriques
- premiers tests de qualite

### Vault

Le dossier `models/vault/` organise les donnees selon une logique Data Vault :

- `hubs` : entites principales comme client, vol, route, booking, aeroport
- `links` : relations entre les entites
- `satellites` : attributs descriptifs et historisables
- `business_vault` : tables PIT et bridges pour faciliter les analyses metier

### Marts

Le dossier `models/marts/` produit les tables analytiques :

- dimensions : clients, routes, aeroports, avions, dates
- faits : vols, bookings, couts, fidelite

### Semantic

Le dossier `models/semantic/` expose les KPIs metier :

- `sem_kpis_operations` : ponctualite, retards, annulations, load factor
- `sem_kpis_revenue` : yield, RASK, CASK, marge, revenus annexes
- `sem_kpis_customer` : LTV, repeat rate, risque client, fidelite
- `sem_kpis_route` : performance agregee par route

### Ontology

Le dossier `models/ontology/` ajoute des labels decisionnels :

- classification des routes : Cash Cow, Loss Maker, Emerging, Strategic Underperformer
- classification des clients : High-Value Active, At-Risk, Dormant, Standard
- classification des vols : High-Yield, Chronically Delayed, Loss-Making
- opportunites d'upsell

### AI Ready

Le dossier `models/ai_ready/` fournit les tables finales pour l'IA :

- `obt_route_summary` : vue 360 par route
- `obt_customer_360` : vue 360 par client
- `obt_flight_full` : vue complete par vol

Ces tables sont les principales sources de contexte pour l'agent IA.

## Partie IA

La partie IA est composee de trois elements.

### MCP tools

`mcp_server.py` contient les fonctions analytiques appelees par l'agent :

- performance d'une route
- comparaison de routes
- recommandation budgetaire
- clients a risque
- analyse de sentiment et plaintes
- recherche dans les plaintes vectorisees

Dans l'interface actuelle, ce fichier est importe directement par l'agent Python. Il n'est donc pas necessaire de lancer `mcp_server.py` separement pour utiliser l'application.

### LLM agent

`llm_agent.py` orchestre les appels a Cohere et aux outils MCP. Il selectionne les bons outils selon la question de l'utilisateur, puis construit une reponse synthetique.

Le modele peut etre configure avec la variable d'environnement :

```powershell
.env:COHERE_CHAT_MODEL="command-a-03-2025"
```
Obtenir l'API cohere en s'inscrivant sur https://cohere.com/ 
### Interface

`airci_interface.py` lance une application web locale qui sert l'interface React contenue dans `ui/`.

Flux d'une question utilisateur :

```text
Interface React
   -> POST /api/ask
   -> airci_interface.py
   -> llm_agent.py
   -> outils de mcp_server.py
   -> DuckDB / Cohere
   -> reponse formatee dans l'interface
```

## Installation

Depuis le dossier parent du projet :

```powershell
cd analytics_engineer_artefact_test\airci_project
```

Activer l'environnement virtuel :

Installer les dependances Python si besoin :


pip install -r requirement.txt


Installer les packages dbt :


dbt deps

Le fichier `.env` doit contenir la cle Cohere :

```text
COHERE_API_KEY=...
```

Ne pas versionner cette cle.

## Lancer le pipeline dbt

Charger les seeds :

```powershell
dbt seed
```

Construire les modeles :

```powershell
dbt run
```

Executer les tests :

```powershell
dbt test
```

Ou tout executer en une commande :

```powershell
dbt build
```

La base DuckDB produite est `dev.duckdb`.

## Generer la documentation dbt

Generer la documentation :

```powershell
dbt docs generate
```

Servir la documentation localement :

```powershell
dbt docs serve
```

Les fichiers generes sont disponibles dans `target/`, notamment :

- `target/index.html`
- `target/manifest.json`
- `target/catalog.json`

## Generer les embeddings

Si les embeddings doivent etre regeneres :

```powershell
python embed_generator.py
```

Les embeddings de plaintes sont stockes dans DuckDB, dans la table :

```text
main.complaint_embeddings
```

## Tester l'agent en ligne de commande

Exemple :

```powershell
python llm_agent.py --question "Which routes deserve more budget next quarter?"
```

Autre exemple :

```powershell
python llm_agent.py --question "What complaints are driving low satisfaction on route R001?"
```

## Lancer l'interface web

Lancer le serveur local :

```powershell
python airci_interface.py
```

Puis ouvrir :

```text
http://127.0.0.1:8051
```

Si le port est deja utilise, lancer sur un autre port :

```powershell
$env:AIRCI_UI_PORT="8052"
python airci_interface.py
```

## Livrables

### Livrables data

- `dev.duckdb` : base analytique locale
- `models/staging/` : modeles de nettoyage
- `models/vault/` : modelisation Data Vault
- `models/marts/` : dimensions et faits
- `models/semantic/` : KPIs metier
- `models/ontology/` : labels decisionnels
- `models/ai_ready/` : tables finales pour IA

### Livrables qualite

- tests dbt dans les fichiers `schema.yml`
- tests de cle unique et non-null
- tests de valeurs acceptees
- tests de relations entre tables
- documentation dbt generee dans `target/`
- dictionnaire de donnees dans `DATA_DICTIONARY.md`

### Livrables IA

- `mcp_server.py` : outils analytiques
- `llm_agent.py` : agent IA connecte a Cohere
- `embed_generator.py` : generation des embeddings
- table `main.complaint_embeddings` : recherche semantique sur les plaintes

### Livrables interface

- `airci_interface.py` : serveur HTTP local
- `ui/index.html` : entree de l'interface
- `ui/app.jsx` : application React
- `ui/styles.css` : design Air Cote d'Ivoire
- `static/image/` et `ui/` : assets visuels

### Livrables Power BI

Dashboard.pbix

## Commandes utiles

Verifier dbt :

```powershell
dbt debug
```

Nettoyer les artefacts dbt :

```powershell
dbt clean
```

Relancer uniquement la couche IA-ready :

```powershell
dbt run --select ai_ready
```

Relancer les tests de la couche IA-ready :

```powershell
dbt test --select ai_ready
```

## Notes d'exploitation

- L'application web actuelle n'a pas besoin d'un serveur MCP lance a part.
- Le serveur `mcp_server.py` peut etre lance separement uniquement pour un usage MCP externe.
- La cle Cohere est lue depuis `.env`.
- Les reponses IA dependent de la disponibilite de l'API Cohere.
- Les donnees finales exploitees par l'agent sont principalement dans les schemas `main_ai_ready`, `main_semantic`, `main_ontology` et `main`.
