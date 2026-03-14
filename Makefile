SHELL := /bin/bash

NAMESPACE ?= ksoot
MINIKUBE_PROFILE ?= minikube

SPARK_BASE_IMAGE ?= ksoot/spark:4.0.0
SPARK_JOB_SERVICE_IMAGE ?= spark-job-service:0.0.1
SPARK_BATCH_IMAGE ?= spark-batch-sales-report-job:0.0.1
SPARK_STREAM_IMAGE ?= spark-stream-logs-analysis-job:0.0.1

SALES_MONTH ?= 2024-08

PLATFORM_POSTGRES_PASSWORD ?=
PLATFORM_ARANGO_ROOT_PASSWORD ?=
PLATFORM_CDK_ADMIN_PASSWORD ?=
PLATFORM_CONDUKTOR_ANALYST_PASSWORD ?=

.PHONY: help minikube-start minikube-stop minikube-delete minikube-tunnel docker-env \
	build image-spark-base image-job-service image-batch image-stream images \
	namespace secrets deploy-infra deploy-rbac deploy-app deploy rollout-status \
	pods services kafka-ui-health spark-job-service-port-forward spark-job-service-api-check \
	clean-job-pods submit-sales submit-logs smoke show-recent-pods \
	service-logs events cleanup helm-install

help:
	@echo "Runbook-compatible targets:"
	@echo "  make minikube-start             # Start minikube with runbook defaults"
	@echo "  make build                      # mvn clean package -DskipTests"
	@echo "  make images                     # Build all images into minikube Docker"
	@echo "  make namespace secrets          # Create namespace and platform-secrets"
	@echo "  make deploy                     # Apply infra + rbac + app manifests"
	@echo "  make rollout-status             # Wait for core deployments"
	@echo "  make smoke                      # Clean old pods + submit sales/logs + show pods"
	@echo "  make cleanup                    # Delete app and infra manifests"

minikube-start:
	minikube start --driver=docker --cpus=4 --memory=6144 -p $(MINIKUBE_PROFILE)
	kubectl config use-context $(MINIKUBE_PROFILE)
	kubectl get nodes

minikube-stop:
	minikube stop -p $(MINIKUBE_PROFILE)

minikube-delete:
	minikube delete -p $(MINIKUBE_PROFILE)

minikube-tunnel:
	minikube tunnel -p $(MINIKUBE_PROFILE)

docker-env:
	@echo 'Run this in your shell:'
	@echo 'eval "$$($(MAKE) -s print-docker-env)"'

print-docker-env:
	@minikube -p $(MINIKUBE_PROFILE) docker-env

build:
	mvn clean package -DskipTests

image-spark-base:
	eval "$$(minikube -p $(MINIKUBE_PROFILE) docker-env)" && docker build -t $(SPARK_BASE_IMAGE) -f docker/Dockerfile docker

image-job-service:
	eval "$$(minikube -p $(MINIKUBE_PROFILE) docker-env)" && docker build -t $(SPARK_JOB_SERVICE_IMAGE) ./spark-job-service

image-batch:
	eval "$$(minikube -p $(MINIKUBE_PROFILE) docker-env)" && docker build -t $(SPARK_BATCH_IMAGE) ./spark-batch-sales-report-job

image-stream:
	eval "$$(minikube -p $(MINIKUBE_PROFILE) docker-env)" && docker build -t $(SPARK_STREAM_IMAGE) ./spark-stream-logs-analysis-job

images: image-spark-base image-job-service image-batch image-stream

namespace:
	kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -

secrets:
	@if [[ -z "$(PLATFORM_POSTGRES_PASSWORD)" || -z "$(PLATFORM_ARANGO_ROOT_PASSWORD)" || -z "$(PLATFORM_CDK_ADMIN_PASSWORD)" || -z "$(PLATFORM_CONDUKTOR_ANALYST_PASSWORD)" ]]; then \
		echo "Set PLATFORM_POSTGRES_PASSWORD, PLATFORM_ARANGO_ROOT_PASSWORD, PLATFORM_CDK_ADMIN_PASSWORD, PLATFORM_CONDUKTOR_ANALYST_PASSWORD"; \
		exit 1; \
	fi
	kubectl create secret generic platform-secrets -n $(NAMESPACE) \
	  --from-literal=postgres-password='$(PLATFORM_POSTGRES_PASSWORD)' \
	  --from-literal=arango-root-password='$(PLATFORM_ARANGO_ROOT_PASSWORD)' \
	  --from-literal=cdk-admin-password='$(PLATFORM_CDK_ADMIN_PASSWORD)' \
	  --from-literal=conduktor-analyst-password='$(PLATFORM_CONDUKTOR_ANALYST_PASSWORD)' \
	  --dry-run=client -o yaml | kubectl apply -f -

deploy-infra:
	kubectl apply -f k8s/infra-kubernetes-deploy.yml

deploy-rbac:
	kubectl apply -f k8s/spark-rbac.yml

deploy-app:
	kubectl apply -f k8s/deployment.yml

deploy: deploy-infra deploy-rbac deploy-app

rollout-status:
	kubectl rollout status deployment/postgres -n $(NAMESPACE) --timeout=300s
	kubectl rollout status deployment/kafka-ui -n $(NAMESPACE) --timeout=300s
	kubectl rollout status deployment/spark-job-service -n $(NAMESPACE) --timeout=300s

pods:
	kubectl get pods -n $(NAMESPACE) -o wide

services:
	kubectl get svc -n $(NAMESPACE)

kafka-ui-health:
	kubectl run kafka-ui-check --rm -i --restart=Never -n $(NAMESPACE) --image=busybox:1.36 -- wget -qO- http://kafka-ui:8100/actuator/health

spark-job-service-port-forward:
	kubectl port-forward -n $(NAMESPACE) svc/spark-job-service 8090:8090

spark-job-service-api-check:
	curl -s -o /tmp/spark_job_service_response.json -w '%{http_code}' http://localhost:8090/v3/api-docs && echo
	head -c 220 /tmp/spark_job_service_response.json

clean-job-pods:
	kubectl get pods -n $(NAMESPACE) --no-headers \
	  | awk '/(sales-report-job|logs-analysis-job)/ && ($$3=="Error" || $$3=="Completed" || $$3=="Failed") {print $$1}' \
	  | xargs -r kubectl delete pod -n $(NAMESPACE)

submit-sales:
	kubectl run sales-submit --rm -i --restart=Never -n $(NAMESPACE) --image=curlimages/curl:8.10.1 -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"sales-report-job","jobArguments":{"month":"$(SALES_MONTH)"}}'

submit-logs:
	kubectl run logs-submit --rm -i --restart=Never -n $(NAMESPACE) --image=curlimages/curl:8.10.1 -- \
	  -sS -X POST http://spark-job-service:8090/v1/spark-jobs/start \
	  -H 'Content-Type: application/json' \
	  -d '{"jobName":"logs-analysis-job"}'

show-recent-pods:
	kubectl get pods -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp | tail -n 12

smoke: clean-job-pods submit-sales submit-logs show-recent-pods

service-logs:
	kubectl logs -n $(NAMESPACE) deployment/spark-job-service -f

events:
	kubectl get events -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp

cleanup:
	kubectl delete -f k8s/deployment.yml
	kubectl delete -f k8s/spark-rbac.yml
	kubectl delete -f k8s/infra-kubernetes-deploy.yml

helm-install:
	helm upgrade --install local-release ./helm -f helm/values-dev.yaml --set platformSecrets.existingSecret=platform-secrets
