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
