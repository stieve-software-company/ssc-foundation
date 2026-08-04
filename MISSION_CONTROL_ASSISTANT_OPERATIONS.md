# Operações do CompanyOS Assistant

## Endereço

```text
http://192.168.3.19:8080/assistant
```

Também existe o item `Assistant` na navegação lateral.

## Implantação

```bash
./scripts/install-mission-control-assistant.sh
./scripts/bootstrap-mission-control-assistant.sh
```

## Teste

```bash
./scripts/test-mission-control-assistant.sh
```

## Perguntas disponíveis

```text
Como estão os serviços?
O PostgreSQL está saudável?
O Redis está saudável?
O RabbitMQ está saudável?
O MinIO está saudável?
O Ollama está saudável?
Liste os usuários ativos.
Liste os usuários inativos.
Quantos usuários existem?
Procure o usuário maria.
Liste os perfis de acesso.
Mostre o perfil Operador.
Mostre os últimos eventos de auditoria.
Quantos eventos existem na auditoria?
O que você consegue fazer?
```

## Limitações

A versão `0.3.0` é somente leitura.

Não executa:

```text
criação de usuários
alteração de usuários
desativação de usuários
reset de senha
alteração de perfil
reinício de serviços
comandos Docker
shell
SQL livre
```

Solicitações desse tipo recebem uma explicação e nenhuma alteração
é realizada.

## Informações sensíveis

Não envie:

```text
senhas
tokens
cookies
chaves privadas
credenciais
conteúdo do .env
```

Padrões explícitos de segredo são rejeitados antes da consulta.

## Diagnóstico

Estado do container:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  ps mission-control
```

Logs:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  logs --tail=150 mission-control
```

Health check:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  exec -T mission-control \
  python -c '
import json
import urllib.request

with urllib.request.urlopen(
    "http://127.0.0.1:8080/health",
    timeout=5,
) as response:
    print(json.dumps(json.load(response), indent=2))
'
```

## Resultado esperado do health check

```json
{
  "status": "healthy",
  "service": "ssc-mission-control",
  "version": "0.3.0",
  "database": "connected"
}
```

## Ollama indisponível

Perguntas comuns continuam funcionando pelas regras locais.

Perguntas que exigirem interpretação mais flexível retornam ajuda
segura quando o provedor estiver indisponível.

## Redis indisponível

O rate limiting utiliza temporariamente memória local.

A consulta do próprio Redis continuará indicando indisponibilidade
por meio do coletor de status.

## Backup

Antes da implantação:

```bash
./scripts/backup.sh --yes
```

O instalador também preserva os arquivos alterados em:

```text
infrastructure/backups/config/mission-control-assistant-<data>
```

Nunca execute:

```text
docker compose down -v
```

## Rollback

Use o diretório de backup criado pela execução correspondente do
instalador.

Restaure:

```text
main.py
bootstrap.py
base.html
```

Depois reconstrua somente o Mission Control.
