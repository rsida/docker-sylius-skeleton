# docker-sylius-skeleton Makefile
#
# First-time setup:
#   cp .env.example .env   # edit APP_NAME, APP_DOMAIN, passwords
#   make install           # build images, start containers, install Sylius
#
# Daily usage:
#   make up    / make down
#   make shell             # PHP container bash
#   make console CMD="..."  # run bin/console
#   make logs

ifneq (,$(wildcard .env))
  include .env
  export
endif

APP_NAME    ?= sylius
APP_DOMAIN  ?= sylius.local
COMPOSE     := docker compose
PHP         := $(COMPOSE) exec php

.PHONY: install setup up down build shell console cc logs ps help

## install: First-time setup on a fresh skeleton (create-project → DB → assets)
install: _env build up _wait-db _sylius-install
	@echo ""
	@echo "Sylius is ready!"
	@echo "  App:    https://$(APP_DOMAIN)"
	@echo "  Admin:  https://$(APP_DOMAIN)/admin"
	@echo "  Mail:   https://mail.$(APP_DOMAIN)"
	@echo ""
	@echo "Make sure /etc/hosts contains: 127.0.0.1 $(APP_DOMAIN) mail.$(APP_DOMAIN)"

## setup: Setup for subsequent developers — use this after cloning an existing project
setup: _env build up _wait-db _sylius-setup
	@echo ""
	@echo "Setup complete!"
	@echo "  App:    https://$(APP_DOMAIN)"
	@echo "  Admin:  https://$(APP_DOMAIN)/admin"
	@echo "  Mail:   https://mail.$(APP_DOMAIN)"
	@echo ""
	@echo "Make sure /etc/hosts contains: 127.0.0.1 $(APP_DOMAIN) mail.$(APP_DOMAIN)"

## up: Start all containers in detached mode
up:
	$(COMPOSE) up -d

## down: Stop and remove containers (volumes are preserved)
down:
	$(COMPOSE) down

## build: Build Docker images
build:
	$(COMPOSE) build

## shell: Open a bash shell in the PHP container
shell:
	$(PHP) bash

## console: Run a Symfony console command — usage: make console CMD="cache:clear"
console:
	$(PHP) php bin/console $(CMD)

## cc: Clear Symfony cache
cc:
	$(PHP) php bin/console cache:clear

## logs: Follow logs for all services (or SERVICES="php nginx" make logs)
logs:
	$(COMPOSE) logs -f $(SERVICES)

## ps: Show running services
ps:
	$(COMPOSE) ps

## help: List available targets
help:
	@grep -E '^## ' Makefile | sed 's/^## //' | column -t -s ':'

# ─── Internal targets ────────────────────────────────────────────────────────

_env:
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo ".env created from .env.example — review it before continuing."; \
	fi

_wait-db:
	@echo ">>> Waiting for MariaDB to be ready..."
	@$(COMPOSE) exec mariadb bash -c \
		'until mariadb-admin ping -u root -p"$$MYSQL_ROOT_PASSWORD" --silent 2>/dev/null; do sleep 1; done'
	@echo ">>> MariaDB is ready."

_sylius-install:
	@echo ">>> Installing Sylius via Composer (this takes several minutes)..."
	$(PHP) composer create-project sylius/sylius-standard /tmp/sylius-install --no-interaction --prefer-dist
	$(PHP) bash -c 'cp -rn /tmp/sylius-install/. /var/www/html/ && rm -rf /tmp/sylius-install'
	$(PHP) bash -c 'rm -f /var/www/html/compose.yml /var/www/html/compose.override.dist.yml /var/www/html/docker-compose.yml /var/www/html/docker-compose.yaml'
	@echo ">>> Running Sylius install (migrations + fixtures + assets)..."
	$(PHP) php bin/console sylius:install --no-interaction
	$(PHP) php bin/console cache:warmup
	$(COMPOSE) exec -u root php chown -R www-data:www-data /var/www/html/var

_sylius-setup:
	@echo ">>> Installing Composer dependencies..."
	$(PHP) composer install --no-interaction
	@echo ">>> Running database migrations..."
	$(PHP) php bin/console doctrine:migrations:migrate --no-interaction
	@echo ">>> Installing assets..."
	$(PHP) php bin/console assets:install
	$(PHP) php bin/console cache:warmup
	$(COMPOSE) exec -u root php chown -R www-data:www-data /var/www/html/var
