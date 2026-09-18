# Projet final — Pipeline MLOps de bout en bout

Projet réalisé dans le cadre du cours MLOps (M2 Campus Cyber, Ali Mokh).

Pipeline complet de machine learning, du chargement de la donnée jusqu'au
service du modèle via une API, entièrement **exécutable en local**, sans
aucun service cloud payant.

## Dataset

`breast_cancer` (scikit-learn) — classification binaire tabulaire, 30
features numériques, 569 observations. Choisi pour que le projet tourne
immédiatement sans dépendance réseau (aucun téléchargement externe
requis). Changer de dataset ne nécessite de modifier que `src/data.py`.

## Ce que ce projet couvre (bonnes pratiques MLOps)

| Thème | Implémentation |
|---|---|
| **Reproductibilité** | `config/config.yaml` centralise tous les hyperparamètres, seeds, chemins. Aucune valeur en dur dans le code. |
| **Pipeline structuré** | Étapes séparées : ingestion (`src/data.py`) → preprocessing+modèle (`src/preprocessing.py`) → entraînement (`src/train.py`) → évaluation (`src/evaluate.py`) → service (`api/main.py`). |
| **Pas de fuite de données** | `ColumnTransformer` + modèle assemblés dans un unique `sklearn.Pipeline`, fitté uniquement sur le train. |
| **Tracking d'expériences** | MLflow autologging : chaque run (par modèle × combinaison d'hyperparamètres via `GridSearchCV`) logue params, métriques (train/val/test) et artefacts. |
| **Model Registry** | Le meilleur modèle est enregistré dans le MLflow Model Registry et promu au stage `Production`. L'API et le script d'évaluation chargent toujours la version actuellement promue — pas un fichier `.pkl` figé. |
| **Tests automatisés** | `pytest` : tests unitaires sur les données (splits, stratification, absence de fuite d'index), sur le pipeline (fit/predict, erreurs), et tests d'intégration sur l'API (`TestClient`). |
| **CI** | `.github/workflows/ci.yml` : tests exécutés automatiquement à chaque push/PR. |
| **Service du modèle** | API FastAPI (`/predict`, `/predict/batch`, `/health`) chargeant le modèle depuis le Model Registry au démarrage. |
| **Conteneurisation** | `Dockerfile` pour l'API + `docker-compose.yml` pour lancer API et serveur MLflow ensemble. |
| **Orchestration locale** | `Makefile` : une commande par étape (`make train`, `make test`, `make serve`...). |

## Arborescence

```
mlops-final-project/
├── README.md
├── Makefile
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── .gitignore
├── .github/workflows/ci.yml
├── config/
│   └── config.yaml
├── src/
│   ├── utils.py
│   ├── data.py
│   ├── preprocessing.py
│   ├── train.py
│   └── evaluate.py
├── api/
│   └── main.py
└── tests/
    ├── conftest.py
    ├── test_data.py
    ├── test_pipeline.py
    └── test_api.py
```

## Installation

```bash
python3 -m venv .venv
source .venv/bin/activate       # Windows: .venv\Scripts\activate
make install
```

## Utilisation — pas à pas

### 1. Générer les données (chargement + split train/val/test)
```bash
make data
```

### 2. Entraîner (GridSearchCV + tracking MLflow + registry)
```bash
make train
```
Cela va :
- Tester `LogisticRegression` et `RandomForestClassifier` via `GridSearchCV` ;
- Logger chaque run dans MLflow (`./mlruns`) ;
- Enregistrer le meilleur modèle sous le nom `breast_cancer_clf` dans le
  Model Registry, et le promouvoir au stage `Production`.

### 3. Visualiser les expériences dans l'UI MLflow
```bash
make mlflow-ui
```
Ouvrir http://localhost:5000 — onglet **Experiments** pour les runs,
onglet **Models** pour le registry et les versions promues.

### 4. Évaluer le modèle actuellement en Production
```bash
make evaluate
```

### 5. Lancer l'API de service
```bash
make serve
```
Puis tester :
```bash
curl http://localhost:8000/health

curl -X POST http://localhost:8000/predict \
  -H "Content-Type: application/json" \
  -d '{"features": {"mean radius": 14.0, "mean texture": 20.0, ...}}'
```
Documentation interactive : http://localhost:8000/docs

### 6. Lancer les tests
```bash
make test
```

### 7. Tout en une commande (install + data + train + test)
```bash
make all
```

## Exécution avec Docker

```bash
# Après avoir entraîné en local au moins une fois (pour peupler ./mlruns)
make docker-build
make docker-run
```

Ou pour lancer serveur MLflow + API ensemble :
```bash
make docker-compose-up
```

## Pourquoi ce dataset et ces choix techniques ?

- **Aucun service externe** : `mlflow.set_tracking_uri("file:./mlruns")`
  utilise un backend fichier local — pas de base Postgres ni de bucket S3
  à configurer pour faire tourner la démo.
- **`GridSearchCV`** plutôt qu'un seul modèle codé en dur : illustre le
  tuning d'hyperparamètres tracé par MLflow, avec comparaison entre
  familles de modèles.
- **Model Registry avec stages** (`None` → `Staging`/`Production`) : sépare
  le suivi des expériences (tracking) du cycle de vie du modèle déployé
  (registry), ce qui est le cœur de la proposition de valeur de MLflow en
  MLOps.
- **API séparée du code d'entraînement** : le service ne réentraîne
  jamais, il charge une version versionnée depuis le registry — ce qui
  permet de changer de modèle en production sans redéployer de code.

## Prochaines étapes possibles (non implémentées, pistes d'amélioration)

- Détection de dérive des données (data drift) avec `evidently` ou
  `whylogs`.
- Déploiement automatique du modèle promu `Production` via un webhook
  MLflow déclenchant un redéploiement de l'API.
- Ajout d'un job de ré-entraînement planifié (cron / Airflow) si de
  nouvelles données arrivent.
