# Operações de Observabilidade

## Instalação

```bash
./scripts/install-observability.sh
```

O instalador:

```text
preserva os arquivos alterados
atualiza .env.example
atualiza o .env privado sem imprimir segredos
atualiza o bind do Grafana
integra compose.observability.yaml ao backup e restore
valida os arquivos
```

## Bootstrap completo

```bash
./scripts/bootstrap-observability.sh
```

Ordem:

```text
backup físico
download das imagens
recriação controlada de RabbitMQ e MinIO
inicialização dos componentes
testes de métricas
testes de logs
testes do Grafana
teste de reinicialização
backup final
```

## Endereços

Na VM:

```text
Prometheus: http://127.0.0.1:9090
Loki:       http://127.0.0.1:3100
```

Na rede local:

```text
Grafana: http://192.168.3.19:3000
```

O login do Grafana usa os valores privados:

```text
GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD
```

## Inicializar

```bash
./scripts/start-observability.sh
```

## Testar

```bash
./scripts/test-observability.sh
```

## Parar somente a observabilidade

```bash
./scripts/stop-observability.sh
```

Esse comando não remove volumes.

## Status

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  -f compose.observability.yaml \
  --profile observability \
  ps
```

## Logs operacionais

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  -f compose.observability.yaml \
  --profile observability \
  logs --tail=150 \
  prometheus loki grafana alloy
```

## Validação do Prometheus

```bash
curl -fsS http://127.0.0.1:9090/-/healthy
```

```bash
curl -fsS \
  http://127.0.0.1:9090/api/v1/targets
```

## Validação do Loki

```bash
curl -fsS http://127.0.0.1:3100/ready
```

## Validação do Grafana

```bash
curl -fsS http://127.0.0.1:3000/api/health
```

## Dashboards

```text
CompanyOS Infrastructure
CompanyOS Logs
```

## Backup

O backup integrado passa a incluir:

```text
ssc_prometheus_data
ssc_loki_data
ssc_grafana_data
ssc_alloy_data
```

Além dos volumes existentes.

## Regra permanente

Nunca execute:

```text
docker compose down -v
```

## Arquivos privados

Não adicionar ao Git:

```text
.env
observability-audit.txt
observability-test.txt
infrastructure/backups/
```
