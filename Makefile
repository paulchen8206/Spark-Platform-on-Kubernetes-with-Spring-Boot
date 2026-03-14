SHELL := /bin/bash
.DEFAULT_GOAL := help

NAMESPACE ?= ksoot
MINIKUBE_PROFILE ?= minikube
MINIKUBE_CPUS ?= 4
MINIKUBE_MEMORY ?= 6144

SPARK_BASE_IMAGE ?= ksoot/spark:4.0.0
SPARK_JOB_SERVICE_IMAGE ?= spark-job-service:0.0.1
SPARK_BATCH_IMAGE ?= spark-batch-sales-report-job:0.0.1
SPARK_STREAM_IMAGE ?= spark-stream-logs-analysis-job:0.0.1
CURL_IMAGE ?= curlimages/curl:8.10.1

SALES_MONTH ?= 2024-08
PLATFORM_SECRETS_FILE ?= k8s/platform-secrets-dev.yaml

KUBECTL ?= kubectl
MINIKUBE ?= minikube
KNS := $(KUBECTL) -n $(NAMESPACE)
MK_DOCKER_ENV = eval "$$($(MINIKUBE) -p $(MINIKUBE_PROFILE) docker-env)"

.PHONY: help minikube-start minikube-stop stop-minikube minikube-delete cleanup-minikube minikube-tunnel docker-env \
	build image-spark-base image-job-service image-batch image-stream images \
	namespace secrets deploy-infra deploy-rbac deploy-app deploy rollout-status \
	pods services kafka-ui-health spark-job-service-port-forward spark-job-service-api-check \
	clean-job-pods submit-sales submit-logs smoke show-recent-pods \
	service-logs events cleanup cleanup-all helm-install

help: ## Show runbook-compatible targets
	@awk 'BEGIN {FS = ":.*##"; printf "Runbook-compatible targets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  make %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

minikube-start: ## Start minikube with runbook defaults
	$(MINIKUBE) start --driver=docker --cpus=$(MINIKUBE_CPUS) --memory=$(MINIKUBE_MEMORY) -p $(MINIKUBE_PROFILE)
	$(KUBECTL) config use-context $(MINIKUBE_PROFILE)
	$(KUBECTL) get nodes

minikube-stop: ## Stop minikube profile
	$(MINIKUBE) stop -p $(MINIKUBE_PROFILE)

stop-minikube: minikube-stop ## Alias to stop minikube profile

minikube-delete: ## Delete minikube profile/container
	$(MINIKUBE) delete -p $(MINIKUBE_PROFILE) || true

cleanup-minikube: minikube-delete ## Cleanup minikube profile/container

minikube-tunnel: ## Start minikube tunnel for LoadBalancer access
	$(MINIKUBE) tunnel -p $(MINIKUBE_PROFILE)

docker-env: ## Print command to switch Docker CLI to minikube daemon
	@echo 'Run this in your shell:'
	@echo 'eval "$$($(MAKE) -s print-docker-env)"'

print-docker-env: ## Output minikube docker-env exports
	@$(MINIKUBE) -p $(MINIKUBE_PROFILE) docker-env

build: ## Build Maven artifacts (skip tests)
	mvn clean package -DskipTests

image-spark-base: ## Build base Spark runtime image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_BASE_IMAGE) -f docker/Dockerfile docker

image-job-service: ## Build spark-job-service image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_JOB_SERVICE_IMAGE) ./spark-job-service

image-batch: ## Build batch sales job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_BATCH_IMAGE) ./spark-batch-sales-report-job

image-stream: ## Build streaming logs analysis job image
	$(MK_DOCKER_ENV) && docker build -t $(SPARK_STREAM_IMAGE) ./spark-stream-logs-analysis-job

images: image-spark-base image-job-service image-batch image-stream ## Build all images in minikube Docker

namespace: ## Create namespace if missing
	$(KUBECTL) create namespace $(NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -

secrets: ## Create/update platform-secrets from $(PLATFORM_SECRETS_FILE)
	@if [[ ! -f "$(PLATFORM_SECRETS_FILE)" ]]; then \
		echo "Secrets file not found: $(PLATFORM_SECRETS_FILE)"; \
		exit 1; \
	fi
	$(KNS) apply -f $(PLATFORM_SECRETS_FILE)

deploy-infra: ## Apply infrastructure manifests
	$(KUBECTL) apply -f k8s/infra-kubernetes-deploy.yml

deploy-rbac: ## Apply Spark RBAC manifests
	$(KUBECTL) apply -f k8s/spark-rbac.yml

deploy-app: ## Apply spark-job-service deployment manifest
	$(KUBECTL) apply -f k8s/deployment.yml

deploy: deploy-infra deploy-rbac deploy-app ## Apply infra + rbac + app manifests

rollout-status: ## Wait for core deployments to be ready
	$(KNS) rollout status deployment/postgres --timeout=300s
	$(KNS) rollout status deployment/kafka-ui --timeout=300s
	$(KNS) rollout status deployment/spark-job-service --timeout=300s

pods: ## List pods in namespace
	$(KNS) get pods -o wide

services: ## List services in namespace
	$(KNS) get svc

kafka-ui-health: ## Check Kafka UI in-cluster health endpoint
	$(KNS) run kafka-ui-check --rm -i --restart=Never --image=busybox:1.36 -- wget -qO- http://kafka-ui:8100/actuator/health

spark-job-service-port-forward: ## Port-forward spark-job-service to localhost:8090
	$(KNS) port-forward svc/spark-job-service 8090:8090

spark-job-service-api-check: ## Check spark-job-service OpenAPI endpoint on localhost:8090
	curl -s -o /tmp/spark_job_service_response.json -w '%{http_code}' http://localhost:8090/v3/api-docs && echo
	head -c 220 /tmp/spark_job_service_response.json

clean-job-pods: ## Delete completed/failed Spark job pods
	$(KNS) get pods --no-headers \
	  | awk '/(sales-report-job|logs-analysis-job)/ && ($$3=="Error" || $$3=="Completed" || $$3=="Failed") {print $$1}' \
	  | xargs -r $(KNS) delete pod

submit-sales: ## Submit sales-report batch job
	$(KNS) run sales-submit --rm -i --restart=Never --image=$(CURL_IMAGE) -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"sales-report-job","jobArguments":{"month":"$(SALES_MONTH)"}}'

submit-logs: ## Submit logs-analysis streaming job
	$(KNS) run logs-submit --rm -i --restart=Never --image=$(CURL_IMAGE) -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"logs-analysis-job"}'

show-recent-pods: ## Show most recent pods in namespace
	$(KNS) get pods --sort-by=.metadata.creationTimestamp | tail -n 12

smoke: clean-job-pods submit-sales submit-logs show-recent-pods ## Clean old pods, submit jobs, and show latest pods

service-logs: ## Tail spark-job-service logs
	$(KNS) logs deployment/spark-job-service -f

events: ## Show namespace events sorted by creation time
	$(KNS) get events --sort-by=.metadata.creationTimestamp

cleanup: ## Delete app and infra manifests (safe when cluster unavailable)
	@if $(KUBECTL) version --request-timeout=8s >/dev/null 2>&1; then \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/deployment.yml || true; \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/spark-rbac.yml || true; \
		$(KUBECTL) delete --ignore-not-found=true -f k8s/infra-kubernetes-deploy.yml || true; \
	else \
		echo "Skipping kubernetes manifest cleanup: cluster unavailable or auth required for current kubectl context."; \
	fi

cleanup-all: cleanup cleanup-minikube ## Cleanup manifests and delete minikube

helm-install: ## Install/upgrade Helm chart with existing platform-secrets
	helm upgrade --install local-release ./helm -f helm/values-dev.yaml --set platformSecrets.existingSecret=platform-secrets
