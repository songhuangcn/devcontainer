export COMPOSE_PROJECT_NAME = workspace-devcontainer

COMPOSE = docker compose -f docker-compose.yml

.PHONY: setup
setup:
	bash scripts/setup.sh

.PHONY: run
run: start

.PHONY: start
start:
	$(COMPOSE) up -d

.PHONY: start-opencode
start-opencode: restart-opencode

.PHONY: restart-opencode
restart-opencode:
	$(COMPOSE) up -d app
	$(COMPOSE) restart app

.PHONY: logs
logs:
	$(COMPOSE) logs -f app

.PHONY: restart
restart: stop start

.PHONY: stop
stop:
	$(COMPOSE) stop

.PHONY: bash
bash:
	$(COMPOSE) exec app bash

.PHONY: update
update: pull down start

.PHONY: pull
pull:
	$(COMPOSE) pull

.PHONY: build
build:
	$(COMPOSE) build app

.PHONY: down
down:
	$(COMPOSE) down

.PHONY: destroy
destroy:
	$(COMPOSE) down --volumes --rmi all
