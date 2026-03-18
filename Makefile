SHELL := /bin/bash
.DEFAULT_GOAL := help

NAMESPACE ?= aiks
MINIKUBE_PROFILE ?= minikube
MINIKUBE_CPUS ?= 4
MINIKUBE_MEMORY ?= 6144
HELM_RELEASE ?= local-release
HELM_VALUES ?= helm/values-dev.yaml

SPARK_BASE_IMAGE ?= aiks/spark:4.0.0
SPARK_JOB_SERVICE_IMAGE ?= spark-job-service:0.0.1
SPARK_BATCH_IMAGE ?= spark-batch-sales-report-job:0.0.1
SPARK_STREAM_IMAGE ?= spark-stream-logs-analysis-job:0.0.1
CURL_IMAGE ?= curlimages/curl:8.10.1
SPARK_UI_LOCAL_PORT ?= 4040
KAFKA_UI_LOCAL_PORT ?= 8100
ARANGO_LOCAL_PORT ?= 8529
POSTGRES_CONDUKTOR_LOCAL_PORT ?= 5432
POSTGRES_SPARK_LOCAL_PORT ?= 5433

SALES_MONTH ?= $(shell date +%Y-%m)
PLATFORM_SECRETS_FILE ?= k8s/platform-secrets-dev.yaml
ENV_FILE ?= .env
COMPOSE_REQUIRED_VARS ?= CDK_ADMIN_PASSWORD CDK_ANALYST_PASSWORD DATABASE_PASSWORD POSTGRES_PASSWORD ARANGO_ROOT_PASSWORD
DOCKER_COMPOSE_FILE ?= docker/docker-compose.yml
COMPOSE_CMD = docker compose --env-file $(ENV_FILE) -f $(DOCKER_COMPOSE_FILE)
COMPOSE_APP_CMD = docker compose --env-file $(ENV_FILE) -f $(DOCKER_COMPOSE_FILE) --profile app
K8S_DIR ?= k8s
INFRA_MANIFEST ?= $(K8S_DIR)/infra-kubernetes-deploy.yml
RBAC_MANIFEST ?= $(K8S_DIR)/spark-rbac.yml
APP_MANIFEST ?= $(K8S_DIR)/deployment.yml

KUBECTL ?= kubectl
MINIKUBE ?= minikube
KUBECTL_APPLY_FLAGS ?= --validate=false
KNS := $(KUBECTL) -n $(NAMESPACE)
MK_DOCKER_ENV = eval "$$($(MINIKUBE) -p $(MINIKUBE_PROFILE) docker-env)"

.PHONY: help \
	dc-env-check dc-up dc-ps dc-down dc-build-app dc-up-app dc-logs-app dc-stop-app dc-e2e \
	mk-start mk-stop mk-delete mk-tunnel mk-docker-env mk-print-docker-env mk-build mk-image-spark-base mk-image-job-service mk-image-batch mk-image-stream mk-images mk-k8s-preflight mk-namespace mk-secrets mk-deploy-infra mk-deploy-rbac mk-deploy-app mk-deploy mk-rollout-status mk-verify mk-pods mk-services mk-kafka-ui-health mk-port-forward mk-port-forward-postgres mk-port-forward-kafka-ui mk-port-forward-arango mk-port-forward-spark-ui mk-api-check mk-clean-job-pods mk-submit-sales mk-verify-sales-arango mk-submit-logs mk-show-recent-pods mk-smoke mk-service-logs mk-events mk-cleanup mk-cleanup-all mk-e2e \
	helm-prepare helm-install helm-verify helm-url helm-smoke helm-uninstall helm-shutdown helm-e2e

help: ## Show runbook-compatible targets
	@awk 'BEGIN {FS = ":.*##"; printf "Runbook-compatible targets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  make %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

dc-env-check: ## [A] Validate required env vars for Docker Compose
	@if [[ ! -f "$(ENV_FILE)" ]]; then \
		echo "Missing $(ENV_FILE). Create it or set ENV_FILE=<path>."; \
		exit 1; \
	fi
	@set -a; source $(ENV_FILE); set +a; \
	missing=0; \
	for var in $(COMPOSE_REQUIRED_VARS); do \
		if [[ -z "$${!var}" ]]; then \
			echo "Missing required env var: $$var (set it in $(ENV_FILE) or shell)"; \
			missing=1; \
		fi; \
	done; \
	if [[ $$missing -ne 0 ]]; then exit 1; fi

dc-up: dc-env-check ## [A] Start Docker Compose infrastructure
	$(COMPOSE_CMD) up -d

dc-ps: dc-env-check ## [A] Show Docker Compose services
	$(COMPOSE_CMD) ps

dc-down: dc-env-check ## [A] Stop Docker Compose infrastructure
	$(COMPOSE_CMD) down

dc-build-app: dc-env-check ## [A] Build job artifacts and spark-job-service Docker image for Compose app profile
	mvn -pl spark-job-service,spark-batch-sales-report-job,spark-stream-logs-analysis-job -am package -DskipTests
	docker build -t $(SPARK_BASE_IMAGE) -f docker/Dockerfile docker
	$(COMPOSE_APP_CMD) build spark-job-service

dc-up-app: dc-build-app ## [A] Start spark-job-service container on the Docker Compose network
	$(COMPOSE_APP_CMD) up -d spark-job-service

dc-logs-app: dc-env-check ## [A] Tail spark-job-service container logs
	$(COMPOSE_APP_CMD) logs -f spark-job-service

dc-stop-app: dc-env-check ## [A] Stop spark-job-service container
	$(COMPOSE_APP_CMD) stop spark-job-service

dc-e2e: dc-up dc-ps ## [A] Run Docker Compose end-to-end startup

mk-start: ## [B] Start minikube with runbook defaults
	$(MINIKUBE) start --driver=docker --cpus=$(MINIKUBE_CPUS) --memory=$(MINIKUBE_MEMORY) -p $(MINIKUBE_PROFILE)
	$(KUBECTL) config use-context $(MINIKUBE_PROFILE)
	$(KUBECTL) get nodes

mk-stop: ## [B] Stop minikube profile
	$(MINIKUBE) stop -p $(MINIKUBE_PROFILE)

mk-delete: ## [B] Delete minikube profile/container
	$(MINIKUBE) delete -p $(MINIKUBE_PROFILE) || true

mk-tunnel: ## [B] Start minikube tunnel for LoadBalancer access
	$(MINIKUBE) tunnel -p $(MINIKUBE_PROFILE)

mk-docker-env: ## [B] Print command to switch Docker CLI to minikube daemon
	@echo 'Run this in your shell:'
	@echo 'eval "$$($(MAKE) -s mk-print-docker-env)"'

mk-print-docker-env: ## [B] Output minikube docker-env exports
	@$(MINIKUBE) -p $(MINIKUBE_PROFILE) docker-env

mk-build: ## [B] Build Maven artifacts (skip tests)
	mvn clean package -DskipTests

mk-image-spark-base: ## [B] Build base Spark runtime image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_BASE_IMAGE) -f docker/Dockerfile docker

mk-image-job-service: mk-image-spark-base ## [B] Build spark-job-service image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_JOB_SERVICE_IMAGE) ./spark-job-service

mk-image-batch: mk-image-spark-base ## [B] Build batch sales job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_BATCH_IMAGE) ./spark-batch-sales-report-job

mk-image-stream: mk-image-spark-base ## [B] Build streaming logs analysis job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_STREAM_IMAGE) ./spark-stream-logs-analysis-job

mk-images: mk-image-spark-base mk-image-job-service mk-image-batch mk-image-stream ## [B] Build all images in minikube Docker

mk-k8s-preflight: ## [B] Ensure minikube profile/context/auth are ready for kubectl
	@if ! $(MINIKUBE) -p $(MINIKUBE_PROFILE) status >/dev/null 2>&1; then \
		echo "Minikube profile '$(MINIKUBE_PROFILE)' not found. Run: make mk-start"; \
		exit 1; \
	fi
	@$(KUBECTL) config use-context $(MINIKUBE_PROFILE) >/dev/null 2>&1 || true
	@if ! $(KUBECTL) version --request-timeout=8s >/dev/null 2>&1; then \
		echo "Kubernetes cluster unavailable or authentication required for context '$(MINIKUBE_PROFILE)'."; \
		echo "Run: make mk-start"; \
		exit 1; \
	fi

mk-namespace: mk-k8s-preflight ## [B] Create namespace if missing
	$(KUBECTL) create namespace $(NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply $(KUBECTL_APPLY_FLAGS) -f -

mk-secrets: mk-k8s-preflight ## [B] Create/update platform-secrets from $(PLATFORM_SECRETS_FILE)
	@if [[ ! -f "$(PLATFORM_SECRETS_FILE)" ]]; then \
		echo "Secrets file not found: $(PLATFORM_SECRETS_FILE)"; \
		exit 1; \
	fi
	$(KNS) apply $(KUBECTL_APPLY_FLAGS) -f $(PLATFORM_SECRETS_FILE)

mk-deploy-infra: mk-k8s-preflight ## [B] Apply infrastructure manifests
	$(KUBECTL) apply $(KUBECTL_APPLY_FLAGS) -f $(INFRA_MANIFEST)

mk-deploy-rbac: mk-k8s-preflight ## [B] Apply Spark RBAC manifests
	$(KUBECTL) apply $(KUBECTL_APPLY_FLAGS) -f $(RBAC_MANIFEST)

mk-deploy-app: mk-k8s-preflight mk-image-job-service ## [B] Build image and apply spark-job-service deployment manifest
	$(KUBECTL) apply $(KUBECTL_APPLY_FLAGS) -f $(APP_MANIFEST)

mk-deploy: mk-namespace mk-secrets mk-deploy-infra mk-deploy-rbac mk-deploy-app ## [B] Apply namespace + secrets + infra + rbac + app

mk-rollout-status: mk-k8s-preflight ## [B] Wait for core deployments to be ready
	$(KNS) rollout status deployment/postgres-conduktor --timeout=300s
	$(KNS) rollout status deployment/postgres-spark --timeout=300s
	$(KNS) rollout status deployment/kafka-ui --timeout=300s
	$(KNS) rollout status deployment/spark-job-service --timeout=300s

mk-verify: mk-k8s-preflight mk-rollout-status mk-pods mk-services ## [B] Verify core rollouts, pods and services

mk-pods: ## [B] List pods in namespace
	$(KNS) get pods -o wide

mk-services: ## [B] List services in namespace
	$(KNS) get svc

mk-kafka-ui-health: ## [B] Check Kafka UI in-cluster health endpoint
	$(KNS) run kafka-ui-check --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- http://kafka-ui:8100/actuator/health

mk-port-forward: ## [B] Port-forward spark-job-service to localhost:8090
	$(KNS) port-forward svc/spark-job-service 8090:8090

mk-port-forward-postgres: ## [B] Port-forward postgres-conduktor and postgres-spark to localhost configurable ports
	$(KNS) port-forward svc/postgres-conduktor $(POSTGRES_CONDUKTOR_LOCAL_PORT):5432 &
	$(KNS) port-forward svc/postgres-spark $(POSTGRES_SPARK_LOCAL_PORT):5432

mk-port-forward-kafka-ui: ## [B] Port-forward kafka-ui to localhost:$(KAFKA_UI_LOCAL_PORT)
	$(KNS) port-forward svc/kafka-ui $(KAFKA_UI_LOCAL_PORT):8100

mk-port-forward-arango: ## [B] Port-forward arango to localhost:$(ARANGO_LOCAL_PORT)
	$(KNS) port-forward svc/arango $(ARANGO_LOCAL_PORT):8529

mk-port-forward-spark-ui: ## [B] Port-forward current running Spark driver UI to localhost:4040
	@DRIVER_POD=$$($(KNS) get pods -l spark-role=driver --field-selector=status.phase=Running -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | head -n 1); \
	if [[ -z "$$DRIVER_POD" ]]; then \
		echo "No running Spark driver pod found in namespace $(NAMESPACE)."; \
		echo "Current Spark driver pods:"; \
		$(KNS) get pods -l spark-role=driver -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,REASON:.status.reason,AGE:.metadata.creationTimestamp' || true; \
		echo "Submit a job first or inspect failures with: make mk-pods"; \
		exit 1; \
	fi; \
	echo "Forwarding Spark UI for $$DRIVER_POD to http://localhost:$(SPARK_UI_LOCAL_PORT)"; \
	$(KNS) port-forward pod/$$DRIVER_POD $(SPARK_UI_LOCAL_PORT):4040

mk-api-check: ## [B] Check spark-job-service OpenAPI endpoint on localhost:8090
	curl -s -o /tmp/spark_job_service_response.json -w '%{http_code}' http://localhost:8090/v3/api-docs && echo
	head -c 220 /tmp/spark_job_service_response.json

mk-clean-job-pods: ## [B] Delete completed/failed Spark job pods
	$(KNS) get pods --no-headers \
	  | awk '/(sales-report-job|logs-analysis-job)/ && ($$3=="Error" || $$3=="Completed" || $$3=="Failed") {print $$1}' \
	  | xargs -r $(KNS) delete pod

mk-submit-sales: ## [B] Submit sales-report batch job
	$(KNS) run sales-submit --rm -i --restart=Never --image=$(CURL_IMAGE) -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"sales-report-job","jobArguments":{"month":"$(SALES_MONTH)"}}'

mk-verify-sales-arango: mk-k8s-preflight ## [B] Verify sales smoke data in ArangoDB for SALES_MONTH
	@report_collection=$$(printf 'sales_report_%s' "$(SALES_MONTH)" | tr '-' '_'); \
	products_json=''; \
	products_count=''; \
	for attempt in $$(seq 1 30); do \
		products_json=$$($(KNS) exec deployment/arango -- sh -lc 'wget --user=root --password="$$ARANGO_ROOT_PASSWORD" -qO- http://127.0.0.1:8529/_db/products_db/_api/collection/products/count 2>/dev/null || true'); \
		products_count=$$(printf '%s' "$$products_json" | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p'); \
		if [[ -n "$$products_count" && "$$products_count" -ge 10 ]]; then \
			break; \
		fi; \
		sleep 2; \
	done; \
	if [[ -z "$$products_count" || "$$products_count" -lt 10 ]]; then \
		echo "Unexpected Arango products collection state after retries: $$products_json"; \
		exit 1; \
	fi; \
	report_json=''; \
	report_count=''; \
	for attempt in $$(seq 1 30); do \
		report_json=$$($(KNS) exec deployment/arango -- sh -lc "wget --user=root --password=\"\$$ARANGO_ROOT_PASSWORD\" -qO- http://127.0.0.1:8529/_db/products_db/_api/collection/$$report_collection/count 2>/dev/null || true"); \
		report_count=$$(printf '%s' "$$report_json" | sed -n 's/.*"count":\([0-9][0-9]*\).*/\1/p'); \
		if [[ -n "$$report_count" && "$$report_count" -gt 0 ]]; then \
			echo "Verified Arango report collection $$report_collection with $$report_count documents"; \
			break; \
		fi; \
		sleep 2; \
	done; \
	if [[ -z "$$report_count" || "$$report_count" -le 0 ]]; then \
		echo "Arango report verification failed for $$report_collection"; \
		echo "Last response: $$report_json"; \
		exit 1; \
	fi; \
	echo "Verified Arango products collection with $$products_count documents"

mk-submit-logs: ## [B] Submit logs-analysis streaming job
	$(KNS) run logs-submit --rm -i --restart=Never --image=$(CURL_IMAGE) -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"logs-analysis-job"}'

mk-show-recent-pods: ## [B] Show most recent pods in namespace
	$(KNS) get pods --sort-by=.metadata.creationTimestamp | tail -n 12

mk-smoke: mk-clean-job-pods mk-submit-sales mk-verify-sales-arango mk-submit-logs mk-show-recent-pods ## [B] Clean old pods, submit jobs, verify Arango batch output, and show latest pods

mk-service-logs: ## [B] Tail spark-job-service logs
	$(KNS) logs deployment/spark-job-service -f

mk-events: ## [B] Show namespace events sorted by creation time
	$(KNS) get events --sort-by=.metadata.creationTimestamp

mk-cleanup: ## [B] Delete app and infra manifests (safe when cluster unavailable)
	@if $(KUBECTL) version --request-timeout=8s >/dev/null 2>&1; then \
		$(KUBECTL) delete --ignore-not-found=true -f $(APP_MANIFEST) || true; \
		$(KUBECTL) delete --ignore-not-found=true -f $(RBAC_MANIFEST) || true; \
		$(KUBECTL) delete --ignore-not-found=true -f $(INFRA_MANIFEST) || true; \
	else \
		echo "Skipping kubernetes manifest cleanup: cluster unavailable or auth required for current kubectl context."; \
	fi

mk-cleanup-all: mk-cleanup mk-delete ## [B] Cleanup manifests and delete minikube

mk-e2e: mk-start mk-build mk-images mk-namespace mk-secrets mk-deploy mk-rollout-status mk-smoke ## [B] Run minikube manifests end-to-end flow

helm-prepare: mk-namespace mk-secrets ## [C] Prepare namespace and platform secrets for Helm flow

helm-install: ## [C] Install/upgrade Helm chart with existing platform-secrets
	helm upgrade --install $(HELM_RELEASE) ./helm -n $(NAMESPACE) -f $(HELM_VALUES) --set platformSecrets.existingSecret=platform-secrets

helm-verify: ## [C] Verify Helm-managed deployments
	$(KNS) rollout status deployment/postgres-conduktor --timeout=300s
	$(KNS) rollout status deployment/postgres-spark --timeout=300s
	$(KNS) rollout status deployment/zookeeper --timeout=300s
	$(KNS) rollout status deployment/kafka --timeout=300s
	$(KNS) rollout status deployment/conduktor --timeout=300s
	$(KNS) get pods -o wide

helm-url: ## [C] Print Conduktor URL via minikube service
	$(MINIKUBE) service -n $(NAMESPACE) conduktor --url

helm-smoke: ## [C] Smoke check Kafka and Postgres from temporary pods
	$(KNS) run kafka-check --rm -i --restart=Never --image=busybox:1.36 -- sh -c 'nc -z kafka 9092 && echo "Kafka reachable"'
	$(KNS) run postgres-conduktor-check --rm -i --restart=Never --image=postgres:15.15 -- sh -c 'PGPASSWORD=$$PGPASSWORD psql -h postgres-conduktor -U postgres -d conduktor -c "select 1"'
	$(KNS) run postgres-spark-check --rm -i --restart=Never --image=postgres:15.15 -- sh -c 'PGPASSWORD=$$PGPASSWORD psql -h postgres-spark -U postgres -d spark_jobs_db -c "select 1"'

helm-uninstall: ## [C] Uninstall Helm release
	helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)

helm-shutdown: ## [C] Uninstall Helm release and delete minikube profile
	-helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)
	$(MINIKUBE) -p $(MINIKUBE_PROFILE) delete

helm-e2e: mk-start helm-prepare helm-install helm-verify helm-url ## [C] Run Helm end-to-end infra flow
