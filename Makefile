SHELL := /bin/bash
.DEFAULT_GOAL := help

PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
ENV_FILE := $(PROJECT_ROOT)/.env
COMPOSE_FILE := $(PROJECT_ROOT)/compose.yaml
SCRIPTS_DIR := $(PROJECT_ROOT)/scripts

COMPOSE := docker compose --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)"

SERVICE ?=
TAIL ?=100
WAIT_TIMEOUT ?=300

.PHONY: help bootstrap validate check security-check \
        start stop restart status ps logs logs-service \
        update update-yes update-ai update-observability update-all \
        backup backup-yes backup-no-restart \
        restore-list restore-latest restore-latest-yes \
        compose-config compose-services compose-profiles \
        volumes networks git-status

help: ## Exibe os comandos disponíveis
	@printf 'CompanyOS — comandos de operação\n\n'
	@awk 'BEGIN {FS = ":.*## "} \
		/^[a-zA-Z0-9_.-]+:.*## / {printf "  %-26s %s\n", $$1, $$2}' \
		$(MAKEFILE_LIST)
	@printf '\nVariáveis opcionais:\n'
	@printf '  SERVICE=<nome>          Serviço usado por logs-service\n'
	@printf '  TAIL=<linhas>           Quantidade de linhas de log (padrão: 100)\n'
	@printf '  WAIT_TIMEOUT=<segundos> Tempo máximo de espera (padrão: 300)\n'

bootstrap: ## Prepara diretórios e verifica os requisitos iniciais
	@"$(SCRIPTS_DIR)/bootstrap.sh"

validate: ## Valida arquivos, credenciais, Docker, portas e recursos
	@"$(SCRIPTS_DIR)/validate.sh"

security-check: ## Confirma que o arquivo .env está protegido pelo Git
	@cd "$(PROJECT_ROOT)" && \
		git check-ignore -q .env || { \
			echo '[ERRO] .env não está protegido pelo .gitignore.' >&2; \
			exit 1; \
		}
	@cd "$(PROJECT_ROOT)" && \
		if git ls-files --error-unmatch .env >/dev/null 2>&1; then \
			echo '[ERRO] .env está sendo rastreado pelo Git.' >&2; \
			exit 1; \
		else \
			echo '[OK] .env está protegido e não é rastreado pelo Git.'; \
		fi

check: security-check validate ## Executa as verificações de segurança e ambiente

start: ## Inicia PostgreSQL, RabbitMQ, Redis e MinIO
	@"$(SCRIPTS_DIR)/start.sh"

stop: ## Interrompe os serviços básicos sem apagar volumes
	@"$(SCRIPTS_DIR)/stop.sh"

restart: ## Reinicia os serviços básicos de forma controlada
	@"$(SCRIPTS_DIR)/restart.sh"

status: ## Exibe saúde, recursos, volumes, redes e portas
	@"$(SCRIPTS_DIR)/status.sh"

ps: ## Exibe todos os containers do projeto, inclusive os parados
	@$(COMPOSE) --profile "*" ps -a

logs: ## Exibe os logs de todos os containers criados
	@"$(SCRIPTS_DIR)/logs.sh" --all --tail "$(TAIL)"

logs-service: ## Exibe logs de SERVICE=<nome>
	@if [[ -z "$(SERVICE)" ]]; then \
		echo '[ERRO] Informe o serviço. Exemplo: make logs-service SERVICE=postgres' >&2; \
		exit 1; \
	fi
	@"$(SCRIPTS_DIR)/logs.sh" "$(SERVICE)" --tail "$(TAIL)"

update: ## Atualiza os serviços básicos com confirmação
	@"$(SCRIPTS_DIR)/update.sh" --wait-timeout "$(WAIT_TIMEOUT)"

update-yes: ## Atualiza os serviços básicos sem confirmação
	@"$(SCRIPTS_DIR)/update.sh" --yes --wait-timeout "$(WAIT_TIMEOUT)"

update-ai: ## Atualiza o perfil de IA
	@"$(SCRIPTS_DIR)/update.sh" --ai --wait-timeout "$(WAIT_TIMEOUT)"

update-observability: ## Atualiza o perfil de observabilidade
	@"$(SCRIPTS_DIR)/update.sh" --observability --wait-timeout "$(WAIT_TIMEOUT)"

update-all: ## Atualiza todos os serviços e perfis
	@"$(SCRIPTS_DIR)/update.sh" --all --wait-timeout "$(WAIT_TIMEOUT)"

backup: ## Cria um backup consistente com confirmação
	@"$(SCRIPTS_DIR)/backup.sh" --wait-timeout "$(WAIT_TIMEOUT)"

backup-yes: ## Cria um backup sem confirmação
	@"$(SCRIPTS_DIR)/backup.sh" --yes --wait-timeout "$(WAIT_TIMEOUT)"

backup-no-restart: ## Cria backup e mantém os serviços parados
	@"$(SCRIPTS_DIR)/backup.sh" --no-restart --wait-timeout "$(WAIT_TIMEOUT)"

restore-list: ## Lista os backups disponíveis
	@"$(SCRIPTS_DIR)/restore.sh" --list

restore-latest: ## Restaura o backup mais recente com confirmação reforçada
	@"$(SCRIPTS_DIR)/restore.sh" --latest --wait-timeout "$(WAIT_TIMEOUT)"

restore-latest-yes: ## Restaura o backup mais recente sem confirmação
	@printf '[AVISO] Esta operação substituirá os dados atuais dos volumes.\n'
	@"$(SCRIPTS_DIR)/restore.sh" --latest --yes --wait-timeout "$(WAIT_TIMEOUT)"

compose-config: ## Valida o Compose incluindo todos os perfis
	@$(COMPOSE) --profile "*" config --quiet
	@echo '[OK] compose.yaml válido, incluindo todos os perfis.'

compose-services: ## Lista todos os serviços configurados
	@$(COMPOSE) --profile "*" config --services

compose-profiles: ## Lista os perfis opcionais configurados
	@$(COMPOSE) config --profiles

volumes: ## Lista os volumes Docker pertencentes ao projeto
	@project_name="$$(awk -F= '$$1 == "COMPOSE_PROJECT_NAME" {print $$2}' "$(ENV_FILE)" | tail -n 1)"; \
	project_name="$${project_name:-ssc}"; \
	docker volume ls \
		--filter "label=com.docker.compose.project=$${project_name}" \
		--format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}'

networks: ## Lista as redes Docker pertencentes ao projeto
	@project_name="$$(awk -F= '$$1 == "COMPOSE_PROJECT_NAME" {print $$2}' "$(ENV_FILE)" | tail -n 1)"; \
	project_name="$${project_name:-ssc}"; \
	docker network ls \
		--filter "label=com.docker.compose.project=$${project_name}" \
		--format 'table {{.Name}}\t{{.Driver}}\t{{.Scope}}'

git-status: ## Exibe o estado atual do repositório
	@cd "$(PROJECT_ROOT)" && git status
