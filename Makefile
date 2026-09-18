.PHONY: install data train evaluate test mlflow-ui serve docker-build docker-run docker-compose-up clean lint

PYTHON := python3

install:
	$(PYTHON) -m pip install -r requirements.txt

data:
	$(PYTHON) -m src.data

train:
	$(PYTHON) -m src.train

evaluate:
	$(PYTHON) -m src.evaluate

test:
	$(PYTHON) -m pytest tests/ -v

lint:
	$(PYTHON) -m pyflakes src api tests || true

mlflow-ui:
	mlflow ui --backend-store-uri file:./mlruns --port 5000

serve:
	uvicorn api.main:app --host 0.0.0.0 --port 8000 --reload

docker-build:
	docker build -t mlops-final-project:latest .

docker-run:
	docker run -p 8000:8000 -v $$(pwd)/mlruns:/app/mlruns mlops-final-project:latest

docker-compose-up:
	docker compose up --build

clean:
	rm -rf mlruns mlartifacts data/raw data/processed .pytest_cache __pycache__
	find . -name "*.pyc" -delete

# Pipeline complet en une commande : installe, entraîne, teste
all: install data train test
