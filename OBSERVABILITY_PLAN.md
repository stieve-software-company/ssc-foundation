# Sprint 1.2 — Plano de Observabilidade

## Objetivo

Implantar uma base de observabilidade local, reproduzível e segura para o CompanyOS.

A solução deverá permitir:

```text
visualizar saúde da infraestrutura
consultar métricas históricas
consultar logs centralizados
identificar falhas e reinicializações
acompanhar CPU, memória, disco e containers
acompanhar PostgreSQL, RabbitMQ, Redis e MinIO
acompanhar o Mission Control
validar retenção e persistência
```

## Base confirmada

```text
branch principal: main
commit base: a7de941
PostgreSQL operacional: concluído
Mission Control: healthy
RabbitMQ: healthy
Redis: healthy
MinIO: healthy
Ollama externo: integrado
```

## Situação atual

O Compose já contém definições preliminares para:

```text
Prometheus
Loki
Grafana
```

Ainda precisam ser implementados e validados:

```text
prometheus.yml
loki-config.yaml
provisionamento de datasources
provisionamento de dashboards
coletor de logs
coletor de métricas do host e containers
regras de alertas
integração com os serviços
```

## Arquitetura alvo preliminar

```text
Fontes de métricas e logs
        │
        ▼
Grafana Alloy
├── métricas do host
├── métricas dos containers
├── logs Docker
├── métricas dos serviços
└── telemetria do próprio Alloy
        │
        ├────────► Prometheus
        │
        └────────► Loki
                       │
                       ▼
                    Grafana
```

## Coletor

Promtail não será usado. O coletor planejado será:

```text
Grafana Alloy
```

## Segurança do Docker

O acesso direto ao Docker Socket não será habilitado automaticamente.

Estratégias a avaliar após a auditoria:

### A — Arquivos de log Docker

```text
montagem somente leitura de /var/lib/docker/containers
sem Docker Socket
menor privilégio
metadados menos ricos
```

### B — Proxy restrito do Docker Socket

```text
proxy dedicado
somente endpoints de leitura necessários
nenhuma porta publicada
Alloy sem acesso ao socket bruto
```

### C — Docker Socket direto

Não será adotada por padrão.

## Métricas planejadas

### Infraestrutura

```text
CPU
memória
swap
load average
disco
filesystem
rede
containers
reinicializações
```

### PostgreSQL

```text
conexões
transações
rollbacks
locks
deadlocks
tamanho do banco
cache hit
atividade
```

Será usado o papel já preparado:

```text
companyos_monitor
```

### RabbitMQ

```text
filas
mensagens
consumidores
conexões
memória
dead-letter
```

### Redis

```text
memória
conexões
operações
expirações
persistência
evictions
```

### MinIO

```text
saúde
armazenamento
requisições
erros
buckets
objetos
```

### Mission Control

Nesta sprint:

```text
health check
estado do container
logs
disponibilidade HTTP
```

Um endpoint Prometheus nativo da aplicação fica para a Sprint 1.3.

## Logs planejados

```text
mission-control
postgres
rabbitmq
redis
minio
prometheus
loki
grafana
alloy
```

Labels mínimas:

```text
environment
platform
service
container
stream
host
```

## Grafana

Provisionamento versionado:

```text
datasource Prometheus
datasource Loki
dashboard CompanyOS Infrastructure
dashboard Containers
dashboard PostgreSQL
dashboard RabbitMQ
dashboard Redis
dashboard Logs
```

## Retenção inicial

```text
Prometheus: 15 dias ou 5 GB
Loki: retenção limitada e documentada
logs Docker: rotação já configurada
Grafana: volume persistente
```

A retenção final será definida após a auditoria.

## Fases

### 1 — Auditoria

```text
configuração Compose
imagens
volumes
redes
portas
recursos da VM
logging driver
tamanho dos logs
endpoints disponíveis
plugins ativos
configurações existentes
```

### 2 — Arquitetura final

```text
modo de coleta de logs
modo de coleta dos containers
targets Prometheus
configuração Loki
provisionamento Grafana
retenção
hardening
```

### 3 — Implantação

```text
arquivos de configuração
Compose complementar
scripts
health checks
datasources
dashboards
```

### 4 — Validação

```text
Prometheus healthy
targets UP
Loki ready
logs recebidos
Grafana healthy
datasources OK
dashboards carregados
persistência após recriação
backup e restauração
```

## Critérios de conclusão

- [ ] auditoria concluída;
- [ ] Prometheus validado;
- [ ] Loki validado;
- [ ] Alloy validado;
- [ ] Grafana provisionado;
- [ ] métricas chegando;
- [ ] logs chegando;
- [ ] dashboards disponíveis;
- [ ] retenção documentada;
- [ ] serviços healthy;
- [ ] volumes persistentes;
- [ ] backup integrado atualizado;
- [ ] nenhuma credencial versionada;
- [ ] nenhum Docker Socket bruto no Alloy;
- [ ] documentação atualizada;
- [ ] commit enviado ao GitHub.
