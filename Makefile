SHELL := /bin/bash
REGION ?= $(AWS_REGION)
SERVICE := harborsim
TF_DIR := infra/terraform

.PHONY: fmt lint test
fmt:
	black services/$(SERVICE)/lambdas
	ruff check --fix services/$(SERVICE)/lambdas || true

lint:
	ruff check services/$(SERVICE)/lambdas
	npx mjml --version >/dev/null 2>&1 || echo "Install mjml globally: npm i -g mjml"
	echo "Lint OK"

test:
	pytest -q

# Package each lambda into a .zip under dist/
package:
	bash scripts/package_lambda.sh $(SERVICE)

plan:
	cd $(TF_DIR) && terraform init && terraform plan -var="service_name=$(SERVICE)"

apply:
	cd $(TF_DIR) && terraform init && terraform apply -auto-approve -var="service_name=$(SERVICE)"

