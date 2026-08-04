# Sprint 1.2 — Baseline Atualizada da Infraestrutura

## Data da atualização

```text
2026-08-03
```

## Objetivo

Registrar o estado real da infraestrutura do CompanyOS após a integração do
provedor de IA e a configuração operacional do RabbitMQ, Redis e MinIO.

Este documento substitui o baseline inicial da Sprint 1.2.

## Git

Estado confirmado:

```text
branch: main
origin: origin/main
working tree: clean
sincronização: atualizada
```

Commits mais recentes:

```text
a0ad365 feat: provision private MinIO buckets with versioning
d67719a feat: configure Redis persistence and coordination
786b4c8 feat: add RabbitMQ event topology with retry and dead-letter
9c8ea29 docs: record Sprint 1.2 infrastructure baseline
9d4b2ae fix: configure RabbitMQ development virtual host
0809f80 feat: integrate external Ollama with AMD GPU
8cc0058 fix: include Mission Control in integrated backups
```

## Arquitetura atual

```text
Windows host — 192.168.3.18
├── AMD Radeon RX 7600
├── Ollama 0.32.5
└── qwen2.5-coder:3b

Ubuntu VM — 192.168.3.19
├── Mission Control
├── PostgreSQL
├── RabbitMQ
├── Redis
└── MinIO
```

O Ollama é executado no Windows para usar diretamente a GPU. Os demais
componentes são executados em containers Docker na VM Ubuntu.

## Sistema operacional

```text
Hostname: stieve-software-company
Kernel:   Linux 7.0.0-28-generic x86_64
IP:       192.168.3.19
```

## Recursos da VM

Memória:

```text
Total:      14 GiB
Disponível: aproximadamente 13 GiB na auditoria inicial
Swap:       0 B
```

Disco raiz:

```text
Total:      49 GiB
Disponível: aproximadamente 38–39 GiB
Uso:        aproximadamente 18–19%
```

## Docker

```text
Docker Engine:  29.7.1
Docker Compose: v5.3.1
```

## Serviços ativos

```text
mission-control   healthy
postgres          healthy
rabbitmq          healthy
redis             healthy
minio             healthy
```

## Mission Control

```text
Versão:      0.2.0
Endereço:    http://192.168.3.19:8080
Bind:        0.0.0.0:8080
Banco:       conectado
Autenticação: ativa
RBAC:        ativo
Auditoria:   ativa
```

Health check confirmado:

```json
{
  "status": "healthy",
  "service": "ssc-mission-control",
  "version": "0.2.0",
  "database": "connected"
}
```

## Ollama externo

### Estado

```text
Host:            Windows
IP:              192.168.3.18
Porta:           11434
Versão da API:   0.32.5
Modelo:          qwen2.5-coder:3b
Contexto:        4096
GPU:             AMD Radeon RX 7600
VRAM:            modelo integralmente carregado
```

### Segurança de rede

A porta `11434` está liberada no firewall do Windows somente para a VM:

```text
origem permitida: 192.168.3.19
destino:          192.168.3.18:11434
```

Não existe redirecionamento da porta no roteador.

### Validações

```text
API respondendo
modelo disponível
inferência concluída
modelo carregado na GPU
Mission Control conectado
latência exibida no painel
```

## RabbitMQ

### Versão e virtual host

```text
RabbitMQ: 4.3.4
Vhost operacional: development
```

O vhost legado abaixo ainda existe, mas não é utilizado:

```text
/development
```

### Exchanges

```text
companyos.commands
companyos.events
companyos.retry.5s
companyos.retry.30s
companyos.retry.5m
companyos.dead-letter
```

### Filas

```text
companyos.workflow.commands
companyos.agent.commands
companyos.audit.events
companyos.notifications.events
companyos.retry.5s
companyos.retry.30s
companyos.retry.5m
companyos.dead-letter
```

### Topologia

```text
Exchanges: 6
Filas:     8
Políticas: 5
Bindings:  19
```

### Validações

```text
commands
events
retry de 5 segundos
dead-letter
permissões
health check
```

### Hardening pendente

O usuário atual:

```text
companyos [administrator]
```

Em uma etapa futura deverão ser separados:

```text
usuário administrativo
usuário de aplicação
usuário de observabilidade
```

## Redis

### Estado

```text
Redis:            8.8.1
Banco lógico:     0
Volume:           ssc_redis_data
Memória máxima:   256 MB
Política:         noeviction
Autenticação:     obrigatória
Usuário:          default
Protected mode:   yes
```

### Persistência

```text
AOF:                  ativo
appendfsync:           everysec
aof-use-rdb-preamble:  yes
RDB:                  ativo
```

### Namespaces

```text
ssc:session:
ssc:cache:
ssc:lock:
ssc:idempotency:
ssc:rate:
ssc:workflow:
ssc:agent:
ssc:system:
ssc:test:
```

### Validações

```text
PING autenticado
acesso sem senha rejeitado
persistência após recriação
SET e GET
TTL
expiração real
lock NX
liberação por token
idempotência
incremento atômico
nenhuma eviction
limpeza das chaves de teste
Mission Control conectado
```

### Evolução planejada

Quando a carga justificar, separar:

```text
redis-coordination   noeviction
redis-cache          allkeys-lru ou allkeys-lfu
```

## MinIO

### Estado

```text
MinIO Server:   RELEASE.2025-09-07T16-13-09Z
MinIO Client:   RELEASE.2025-08-13T08-35-41Z
Volume:         ssc_minio_data
Health live:    OK
Health ready:   OK
```

### Buckets

```text
companyos-references
companyos-artifacts
companyos-exports
companyos-backups
```

### Versionamento

Habilitado:

```text
companyos-references
companyos-artifacts
companyos-backups
```

Não habilitado:

```text
companyos-exports
```

### Privacidade

```text
anonymous access: none
```

Todos os buckets são privados.

### Validações

```text
criação idempotente
persistência após recriação
upload com SHA-256
metadados customizados
stat do objeto
listagem por prefixo
download autenticado
comparação SHA-256
acesso anônimo rejeitado
URL assinada
download por URL assinada
duas versões do mesmo objeto
remoção de todas as versões de teste
Mission Control conectado
nenhum objeto temporário restante
```

### Hardening pendente

Atualmente o provisionamento utiliza as credenciais root do MinIO.

Etapa futura:

```text
usuário administrativo
usuário de aplicação com privilégio mínimo
políticas por bucket e operação
rotação de credenciais
```

## PostgreSQL

### Estado atual

```text
Container: healthy
Volume:    ssc_postgres_data
Banco:     conectado ao Mission Control
```

### Pendente

A configuração operacional detalhada ainda precisa validar:

```text
usuários e privilégios
usuário exclusivo da aplicação
extensões
parâmetros de memória
conexões
backups lógicos
restauração lógica
migrations com Alembic
observabilidade
```

As tabelas do Mission Control ainda são criadas pelo SQLAlchemy. A migração
para Alembic continua planejada.

## Volumes persistentes

```text
ssc_postgres_data
ssc_rabbitmq_data
ssc_redis_data
ssc_minio_data
```

Todos são incluídos no backup integrado.

## Backup

O script integrado protege:

```text
PostgreSQL
RabbitMQ
Redis
MinIO
```

A composição utilizada no backup inclui:

```text
compose.yaml
compose.access.yaml
```

O último backup completo conhecido foi validado com:

```text
checksums
cópia dos quatro volumes
reinício dos serviços
health checks
```

Regra permanente:

```text
não executar docker compose down -v
```

## Redes Docker

Definidas:

```text
ssc_public
ssc_application
ssc_data
ssc_execution
ssc_observability
```

Atualmente utilizadas pelos serviços principais:

```text
ssc_public
ssc_application
ssc_data
```

As redes de execução e observabilidade serão utilizadas conforme os respectivos
perfis forem ativados.

## Segurança atual

Implementado:

```text
.env privado e ignorado pelo Git
serviços de dados em rede interna
senhas não incluídas nos arquivos versionados
Mission Control com autenticação e RBAC
CSRF
sessões
auditoria
MinIO privado
Redis autenticado
RabbitMQ autenticado
Ollama restrito pelo firewall
Docker sem socket montado no Mission Control
no-new-privileges nos containers
```

## Riscos e hardening pendentes

### Ausência de swap

A VM não possui swap. Isso deverá ser reavaliado antes de:

```text
múltiplos agentes simultâneos
builds pesados
observabilidade completa
serviços adicionais
```

### TLS

O acesso atual usa HTTP na rede local.

TLS será necessário antes de qualquer exposição além do ambiente controlado.

### Privilégios amplos

Ainda precisam ser reduzidos:

```text
RabbitMQ: usuário companyos administrador
MinIO: credenciais root
Redis: usuário default
PostgreSQL: usuário da aplicação a revisar
```

### Rate limiting

O Mission Control ainda precisa de rate limiting, especialmente no login.

### Migrações

O banco ainda precisa de Alembic para controle formal do schema.

## Estado da Sprint 1.2

```text
Baseline da infraestrutura:          concluído
Backup integrado:                    concluído
Mission Control v0.2:                concluído
Ollama externo com GPU:              concluído
RabbitMQ vhost e topologia:          concluído
Redis operacional:                   concluído
MinIO operacional:                   concluído
PostgreSQL operacional:              pendente
Observabilidade:                     pendente
Hardening de credenciais de serviço: pendente
```

## Próxima atividade

Executar a auditoria e a configuração operacional do PostgreSQL:

```text
usuários
privilégios
parâmetros
backup lógico
restauração
migrations
testes pelo Mission Control
```
