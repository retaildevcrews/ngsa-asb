SHELL=/bin/bash
.PHONY: create delete

all: create

delete:
	@k3d cluster delete ngsa-asb

create: delete
	@k3d cluster create ngsa-asb --registry-use k3d-registry.localhost:5000 --config .devcontainer/k3d.yaml --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0"

	@kubectl wait node --for condition=ready --all --timeout=60s
	@sleep 5
	@kubectl wait pod -A --all --for condition=ready --timeout=60s

build-extension:
	@DOCKER_BUILDKIT=1 docker build ./spikes/cluster-api/extension \
		-f ./spikes/cluster-api/extension/Dockerfile \
		--build-arg builder_image=golang:1.17.2 \
		-t k3d-registry.localhost:5000/capi-ext \
		-t localhost:5001/capi-ext

	@docker push k3d-registry.localhost:5000/capi-ext
	@docker push localhost:5001/capi-ext

deploy-extension:
	@kubectl apply -f spikes/cluster-api/extension/deploy

	@kubectl wait pod --for=condition=Ready -l app=test-extension --timeout=60s

	@kubectl apply -f spikes/cluster-api/extension/extension-config.yaml
