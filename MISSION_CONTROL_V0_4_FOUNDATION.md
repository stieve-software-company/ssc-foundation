# Mission Control v0.4 — Foundation e Performance

## Estado validado

```text
Versão: 0.4.0
Alembic: managed
Revisão atual: 20260805_0002
Revisão esperada: 20260805_0002
Banco: connected
Testes: PASS
```

## Arquitetura entregue

O dashboard não consulta mais PostgreSQL, Redis, RabbitMQ, MinIO e Ollama
durante cada requisição.

```text
Health Collector em background
    ↓
checks concorrentes
    ↓
snapshot no Redis
    ↓
dashboard
    ↓
SSE para atualização ao vivo
```

## Banco e migrações

Revisões:

```text
20260805_0001 — baseline do schema legado
20260805_0002 — Service Registry
```

Papéis:

```text
companyos           administrador de emergência
companyos_owner     proprietário, sem login
companyos_migrator  migrações one-shot
companyos_app       runtime sem DDL
companyos_monitor   observabilidade
```

O startup apenas valida a revisão. A migração é executada separadamente por:

```text
scripts/run-mission-control-migration.sh
```

## Service Registry

A tabela `service_definitions` registra inicialmente:

```text
PostgreSQL
Redis
RabbitMQ
MinIO
Ollama
```

Ela será a base do auto-discovery das próximas versões.

## API v1

```text
GET /api/v1/me
GET /api/v1/system/summary
GET /api/v1/system/events
```

As rotas usam sessão existente, RBAC e a permissão `system.view`.

## Cache e atualização ao vivo

```text
Redis como cache principal
memória local como fallback
estado collecting
estado ready
estado empty
estado stale
SSE autenticado
```

Variáveis:

```text
MC_STATUS_COLLECT_INTERVAL_SECONDS=10
MC_STATUS_CACHE_TTL_SECONDS=30
MC_STATUS_SSE_INTERVAL_SECONDS=3
```

## Scripts operacionais

```text
scripts/configure-mission-control-migration-access.sh
scripts/run-mission-control-migration.sh
scripts/harden-mission-control-migration-privileges.sh
scripts/test-mission-control-v0-4-foundation-v1-1.sh
```

## Segurança

```text
runtime sem CREATE no schema public
runtime sem credencial do migrator
migração em container one-shot
transação única
pg_advisory_xact_lock
SET LOCAL ROLE companyos_owner
Mission Control sem Docker Socket
sem shell livre
sem operações destrutivas
```

## Operação

Health:

```bash
curl --silent --show-error --fail   http://127.0.0.1:8080/health
```

Revisão:

```bash
docker compose   --env-file .env   -f compose.yaml   -f compose.access.yaml   -f compose.observability.yaml   --profile observability   exec -T mission-control   python -m app.migration_manager status
```

Testes:

```bash
./scripts/test-mission-control-v0-4-foundation-v1-1.sh
```

## Próxima etapa

```text
Mission Control v0.5 — Interface e Assistant UX
```

Escopo previsto:

```text
novo shell visual
Light/Dark/System
Assistant flutuante
histórico persistente
indicador de processamento
streaming
cancelamento
```
