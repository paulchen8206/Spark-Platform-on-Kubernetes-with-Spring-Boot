SHELL := /bin/bash
.DEFAULT_GOAL := help

NAMESPACE ?= ksoot
MINIKUBE_PROFILE ?= minikube
MINIKUBE_CPUS ?= 4
MINIKUBE_MEMORY ?= 6144
HELM_RELEASE ?= local-release
HELM_VALUES ?= helm/values-dev.yaml

SPARK_BASE_IMAGE ?= ksoot/spark:4.0.0
SPARK_JOB_SERVICE_IMAGE ?= spark-job-service:0.0.1
SPARK_BATCH_IMAGE ?= spark-batch-sales-report-job:0.0.1
SPARK_STREAM_IMAGE ?= spark-stream-logs-analysis-job:0.0.1
CURL_IMAGE ?= curlimages/curl:8.10.1

SALES_MONTH ?= 2024-08
PLATFORM_SECRETS_FILE ?= k8s/platform-secrets-dev.yaml
ENV_FILE ?= .env
COMPOSE_REQUIRED_VARS ?= CDK_ADMIN_PASSWORD CDK_ANALYST_PASSWORD DATABASE_PASSWORD POSTGRES_PASSWORD ARANGO_ROOT_PASSWORD

KUBECTL ?= kubectl
MINIKUBE ?= minikube
KNS := $(KUBECTL) -n $(NAMESPACE)
MK_DOCKER_ENV = eval "$$($(MINIKUBE) -p $(MINIKUBE_PROFILE) docker-env)"

.PHONY: help \
	dc-env-check dc-up dc-ps dc-down dc-e2e \
	mk-start mk-stop mk-delete mk-tunnel mk-docker-env mk-print-docker-env mk-build mk-image-spark-base mk-image-job-service mk-image-batch mk-image-stream mk-images mk-namespace mk-secrets mk-deploy-infra mk-deploy-rbac mk-deploy-app mk-deploy mk-rollout-status mk-pods mk-services mk-kafka-ui-health mk-port-forward mk-api-check mk-clean-job-pods mk-submit-sales mk-submit-logs mk-show-recent-pods mk-smoke mk-service-logs mk-events mk-cleanup mk-cleanup-all mk-e2e \
	helm-prepare helm-install helm-verify helm-url helm-smoke helm-uninstall helm-e2e

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
	set -a; source $(ENV_FILE); set +a; docker compose -f docker/docker-compose.yml up -d

dc-ps: ## [A] Show Docker Compose services
	docker compose -f docker/docker-compose.yml ps

dc-down: ## [A] Stop Docker Compose infrastructure
	docker compose -f docker/docker-compose.yml down

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

mk-image-job-service: ## [B] Build spark-job-service image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_JOB_SERVICE_IMAGE) ./spark-job-service

mk-image-batch: ## [B] Build batch sales job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_BATCH_IMAGE) ./spark-batch-sales-report-job

mk-image-stream: ## [B] Build streaming logs analysis job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_STREAM_IMAGE) ./spark-stream-logs-analysis-job

mk-images: mk-image-spark-base mk-image-job-service mk-image-batch mk-image-stream ## [B] Build all images in minikube Docker

mk-namespace: ## [B] Create namespace if missing
	$(KUBECTL) create namespace $(NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -

mk-secrets: ## [B] Create/update platform-secrets from $(PLATFORM_SECRETS_FILE)
	@if [[ ! -f "$(PLATFORM_SECRETS_FILE)" ]]; then \
		echo "Secrets file not found: $(PLATFORM_SECRETS_FILE)"; \
		exit 1; \
	fi
	$(KNS) apply -f $(PLATFORM_SECRETS_FILE)

mk-deploy-infra: ## [B] Apply infrastructure manifests
	$(KUBECTL) apply -f k8s/infra-kubernetes-deploy.yml

mk-deploy-rbac: ## [B] Apply Spark RBAC manifests
	$(KUBECTL) apply -f k8s/spark-rbac.yml

mk-deploy-app: ## [B] Apply spark-job-service deployment manifest
	$(KUBECTL) apply -f k8s/deployment.yml

mk-deploy: mk-deploy-infra mk-deploy-rbac mk-deploy-app ## [B] Apply infra + rbac + app manifests

mk-rollout-status: ## [B] Wait for core deployments to be ready
	$(KNS) rollout status deployment/postgres --timeout=300s
	$(KNS) rollout status deployment/kafka-ui --timeout=300s
	$(KNS) rollout status deployment/spark-job-service --timeout=300s

mk-pods: ## [B] List pods in namespace
	$(KNS) get pods -o wide

mk-services: ## [B] List services in namespace
	$(KNS) get svc

mk-kafka-ui-health: ## [B] Check Kafka UI in-cluster health endpoint
	$(KNS) run kafka-ui-check --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- http://kafka-ui:8100/actuator/health

mk-port-forward: ## [B] Port-forward spark-job-service to localhost:8090
	$(KNS) port-forward svc/spark-job-service 8090:8090

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

mk-submit-logs: ## [B] Submit logs-analysis streaming job
	$(KNS) run logs-submit --rm -i --restart=Never --image=$(CURL_IMAGE) -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"logs-analysis-job"}'

mk-show-recent-pods: ## [B] Show most recent pods in namespace
	$(KNS) get pods --sort-by=.metadata.creationTimestamp | tail -n 12

mk-smoke: mk-clean-job-pods mk-submit-sales mk-submit-logs mk-show-recent-pods ## [B] Clean old pods, submit jobs, and show latest pods

mk-service-logs: ## [B] Tail spark-job-service logs
	$(KNS) logs deployment/spark-job-service -f

mk-events: ## [B] Show namespace events sorted by creation time
	$(KNS) get events --sort-by=.metadata.creationTimestamp

mk-cleanup: ## [B] Delete app and infra manifests (safe when cluster unavailable)
	@if $(KUBECTL) version --request-timeout=8s >/dev/null 2>&1; then \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/deployment.yml || true; \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/spark-rbac.yml || true; \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/infra-kubernetes-deploy.yml || true; \
	else \
		echo "Skipping kubernetes manifest cleanup: cluster unavailable or auth required for current kubectl context."; \
	fi

mk-cleanup-all: mk-cleanup mk-delete ## [B] Cleanup manifests and delete minikube

mk-e2e: mk-start mk-build mk-images mk-namespace mk-secrets mk-deploy mk-rollout-status mk-smoke ## [B] Run minikube manifests end-to-end flow

helm-prepare: mk-namespace mk-secrets ## [C] Prepare namespace and platform secrets for Helm flow

helm-install: ## [C] Install/upgrade Helm chart with existing platform-secrets
	helm upgrade --install $(HELM_RELEASE) ./helm -n $(NAMESPACE) -f $(HELM_VALUES) --set platformSecrets.existingSecret=platform-secrets

helm-verify: ## [C] Verify Helm-managed deployments
	$(KNS) rollout status deployment/postgres --timeout=300s
	$(KNS) rollout status deployment/zookeeper --timeout=300s
	$(KNS) rollout status deployment/kafka --timeout=300s
	$(KNS) rollout status deployment/conduktor --timeout=300s
	$(KNS) get pods -o wide

helm-url: ## [C] Print Conduktor URL via minikube service
	$(MINIKUBE) service -n $(NAMESPACE) conduktor --url

helm-smoke: ## [C] Smoke check Kafka and Postgres from temporary pods
	$(KNS) run kafka-check --rm -i --restart=Never --image=busybox:1.36 -- sh -c 'nc -z kafka 9092 && echo "Kafka reachable"'
	$(KNS) run postgres-check --rm -i --restart=Never --image=postgres:15.15 -- sh -c 'PGPASSWORD=admin psql -h postgres -U conduktor -d conduktor -c "select 1"'

helm-uninstall: ## [C] Uninstall Helm release
	helm uninstall $(HELM_RELEASE) -n $(NAMESPACE)

helm-e2e: helm-prepare helm-install helm-verify helm-url ## [C] Run Helm end-to-end infra flow
