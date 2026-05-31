SHELL := /usr/bin/env bash

COMPOSE_ENV := compose/projects/media/.env
COMPOSE_BASE := compose/projects/media/compose.yml
COMPOSE_WIKI := compose/projects/media/compose.wiki.yml
COMPOSE_DEV := compose/projects/media/compose.dev.yml
COMPOSE_WIKI_DEV := compose/projects/media/compose.wiki.dev.yml
COMPOSE_PROD := compose/projects/media/compose.prod.yml
COMPOSE_WIKI_PROD := compose/projects/media/compose.wiki.prod.yml
COMPOSE := docker compose --env-file $(COMPOSE_ENV) -f $(COMPOSE_BASE) -f $(COMPOSE_WIKI) -f $(COMPOSE_DEV) -f $(COMPOSE_WIKI_DEV)
COMPOSE_PROD_CONFIG := docker compose --env-file $(COMPOSE_ENV) -f $(COMPOSE_BASE) -f $(COMPOSE_WIKI) -f $(COMPOSE_PROD) -f $(COMPOSE_WIKI_PROD)
NETWORK := infra_shared_backend

.PHONY: help init validate config config-prod up down restart ps logs pull health clean-local ansible-syntax ansible-check

help:
	@printf '%s\n' \
		'Targets:' \
		'  make init            Create local dirs and shared Docker network' \
		'  make validate        Run local Compose and NGINX validation' \
		'  make config          Render local Compose config' \
		'  make config-prod     Render production Compose config with local env' \
		'  make up              Start local media stack' \
		'  make down            Stop local media stack' \
		'  make restart         Restart local media stack' \
		'  make ps              Show local stack containers' \
		'  make logs            Follow local stack logs' \
		'  make pull            Pull stack images' \
		'  make health          Check local NGINX and CouchDB endpoints' \
		'  make ansible-check   Run Ansible integrity checks' \
		'  make ansible-syntax  Run deploy playbook syntax check' \
		'  make clean-local     Remove local temp data after stack is down'

init:
	mkdir -p compose/.tmp/media/immich/app
	mkdir -p compose/.tmp/media/immich/postgres
	mkdir -p compose/.tmp/media/couchdb/data
	mkdir -p compose/.tmp/media/wiki/postgres
	chown 999:999 compose/.tmp/media/immich/postgres 2>/dev/null || chmod 0777 compose/.tmp/media/immich/postgres 2>/dev/null || true
	chown 5984:5984 compose/.tmp/media/couchdb/data 2>/dev/null || chmod 0777 compose/.tmp/media/couchdb/data 2>/dev/null || true
	docker network inspect $(NETWORK) >/dev/null 2>&1 || docker network create $(NETWORK)

validate: init
	./compose/scripts/validate-compose.sh

config: init
	$(COMPOSE) config

config-prod:
	$(COMPOSE_PROD_CONFIG) config

up: init
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart: init
	$(COMPOSE) restart

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f --tail=200

pull:
	$(COMPOSE) pull

health:
	curl -fsS http://127.0.0.1:8080/healthz
	curl -fsS "http://admin:devpassword@127.0.0.1:15984/_up"

ansible-syntax:
	ansible-playbook --syntax-check -i ansible/inventories/production/hosts.yml ansible/playbooks/deploy-media.yml

ansible-check:
	./tests/ansible/check.sh

clean-local:
	@test "$(CONFIRM)" = "1" || { \
		printf '%s\n' 'This removes compose/.tmp local data. Stop stack first, then run:'; \
		printf '%s\n' '  make clean-local CONFIRM=1'; \
		exit 1; \
	}
	rm -rf compose/.tmp
