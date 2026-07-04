# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

run:
	go run apis/services/sales/main.go | go run apis/tooling/logfmt/main.go

	# ==============================================================================
# Define dependencies

GOLANG          := golang:1.26
ALPINE          := alpine:3.23
KIND            := kindest/node:v1.36.1
POSTGRES        := postgres:18.4
GRAFANA         := grafana/grafana:12.4.0
PROMETHEUS      := prom/prometheus:v3.12.0
TEMPO           := grafana/tempo:2.10.0
LOKI            := grafana/loki:3.7.0
PROMTAIL        := grafana/promtail:3.6.0

KIND_CLUSTER    := ardan-starter-cluster
NAMESPACE       := sales-system
SALES_APP       := sales
AUTH_APP        := auth
BASE_IMAGE_NAME := localhost/ardanlabs
VERSION         := 0.0.1
SALES_IMAGE     := $(BASE_IMAGE_NAME)/$(SALES_APP):$(VERSION)
METRICS_IMAGE   := $(BASE_IMAGE_NAME)/metrics:$(VERSION)
AUTH_IMAGE      := $(BASE_IMAGE_NAME)/$(AUTH_APP):$(VERSION)

# VERSION       := "0.0.1-$(shell git rev-parse --short HEAD)"
# ==============================================================================
# Running from within k8s/kind
# Docker Desktop 28.3.2 changed how it stores image layers, causing KIND's kind
# load docker-image command to fail with "content digest not found" errors. The
# workaround uses docker save | docker exec to bypass this incompatibility for
# the critical images allowing this to work without a network.

dev-up:
	kind create cluster \
		--image $(KIND) \
		--name $(KIND_CLUSTER) \
		--config zarf/k8s/dev/kind-config.yaml

	kubectl wait --timeout=120s --namespace=local-path-storage --for=condition=Available deployment/local-path-provisioner

# 	docker save $(POSTGRES) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	docker save $(GRAFANA) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	docker save $(PROMETHEUS) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	docker save $(TEMPO) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	docker save $(LOKI) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	docker save $(PROMTAIL) | docker exec -i $(KIND_CLUSTER)-control-plane ctr --namespace=k8s.io images import - & \
# 	wait;

dev-down:
	kind delete cluster --name $(KIND_CLUSTER)

dev-up-registry:
	KIND_CLUSTER_NAME=$(KIND_CLUSTER) ./zarf/k8s/dev/kind-with-registry.sh

dev-down-registry:
	kind delete cluster --name $(KIND_CLUSTER)
	docker stop kind-registry 2>/dev/null || true
	docker rm kind-registry 2>/dev/null || true

dev-status-all:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

dev-status:
	watch -n 2 kubectl get pods -o wide --all-namespaces

# Modules support
tidy:
	go mod tidy
	go mod vendor