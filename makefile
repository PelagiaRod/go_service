# Check to see if we can use ash, in Alpine images, or default to BASH.
SHELL_PATH = /bin/ash
SHELL = $(if $(wildcard $(SHELL_PATH)),/bin/ash,/bin/bash)

run:
	go run apis/services/sales/main.go | go run apis/tooling/logfmt/main.go

help:
	go run apis/services/sales/main.go --help

version:
	go run apis/services/sales/main.go --version

curl-test:
	curl -il -X GET http://localhost:3000/test

curl-live:
	curl -il -X GET http://localhost:3000/liveness

curl-ready:
	curl -il -X GET http://localhost:3000/readiness

admin:
	go run apis/tooling/admin/main.go

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
VERSION         := 0.0.2
SALES_IMAGE     := $(BASE_IMAGE_NAME)/$(SALES_APP):$(VERSION)
METRICS_IMAGE   := $(BASE_IMAGE_NAME)/metrics:$(VERSION)
AUTH_IMAGE      := $(BASE_IMAGE_NAME)/$(AUTH_APP):$(VERSION)


# ==============================================================================
# Building containers

build: sales auth

sales:
	docker build \
		-f zarf/docker/dockerfile.sales \
		-t $(SALES_IMAGE) \
		--build-arg BUILD_TAG=$(VERSION) \
		--build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
		.

auth:
	docker build \
		-f zarf/docker/dockerfile.auth \
		-t $(AUTH_IMAGE) \
		--build-arg BUILD_REF=$(VERSION) \
		--build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
		.

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

# ------------------------------------------------------------------------------

dev-load:
	kind load docker-image $(SALES_IMAGE) --name $(KIND_CLUSTER)
	kind load docker-image $(AUTH_IMAGE) --name $(KIND_CLUSTER)

dev-apply:
	kustomize build zarf/k8s/dev/auth | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(AUTH_APP) --timeout=120s --for=condition=Ready

	kustomize build zarf/k8s/dev/sales | kubectl apply -f -
	kubectl wait pods --namespace=$(NAMESPACE) --selector app=$(SALES_APP) --timeout=120s --for=condition=Ready

dev-restart:
	kubectl rollout restart deployment $(SALES_APP) --namespace=$(NAMESPACE)

dev-run: build dev-up dev-load dev-apply

dev-update: build dev-load dev-restart

dev-update-apply: build dev-load dev-apply

dev-logs:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(SALES_APP) --all-containers=true -f --tail=100 --max-log-requests=6 | go run apis/tooling/logfmt/main.go -service=$(SALES_APP)

dev-logs-auth:
	kubectl logs --namespace=$(NAMESPACE) -l app=$(AUTH_APP) --all-containers=true -f --tail=100 | go run apis/tooling/logfmt/main.go

# ==============================================================================

dev-describe-deployment:
	kubectl describe deployment --namespace=$(NAMESPACE) $(SALES_APP)

dev-describe-sales:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(SALES_APP)

dev-describe-auth:
	kubectl describe pod --namespace=$(NAMESPACE) -l app=$(AUTH_APP)

# ==============================================================================
# Metrics and Tracing

metrics:
	expvarmon -ports="localhost:3010" -vars="build,requests,goroutines,errors,panics,mem:memstats.HeapAlloc,mem:memstats.HeapSys,mem:memstats.Sys"

statsviz:
	$(OPEN_CMD) http://localhost:3010/debug/statsviz

# ===============================================================================
# Modules support
tidy:
	go mod tidy
	go mod vendor

# ==============================================================================
# Hitting endpoints

token:
	curl -il \
	--user "admin@example.com:gophers" http://localhost:6000/v1/auth/token/54bb2165-71e1-41a6-af3e-7da4a0e1e2c1

# export TOKEN="COPY TOKEN STRING FROM LAST CALL"

users:
	curl -il \
	-H "Authorization: Bearer ${TOKEN}" "http://localhost:3000/v1/users?page=1&rows=2"

load:
	hey -m GET -c 100 -n 1000 \
	-H "Authorization: Bearer ${TOKEN}" "http://localhost:3000/v1/users?page=1&rows=2"

otel-test:
	curl -il \
	-H "Traceparent: 00-918dd5ecf264712262b68cf2ef8b5239-896d90f23f69f006-01" \
	--user "admin@example.com:gophers" http://localhost:3000/v1/users/token/54bb2165-71e1-41a6-af3e-7da4a0e1e2c1