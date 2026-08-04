# Resultado da Configuração Operacional do PostgreSQL

## Status

```text
Concluído com sucesso
```

## Data

```text
2026-08-04
```

## Escopo

```text
Sprint 1.2 — Serviços de Infraestrutura
Componente: PostgreSQL
Versão: PostgreSQL 18.4
```

## Resultado geral

A configuração operacional do PostgreSQL foi implantada e validada.

```text
backup físico concluído
papéis separados
privilégios mínimos aplicados
Mission Control migrado para usuário de aplicação
usuário de observabilidade validado
backup lógico criado
checksums verificados
restauração temporária concluída
schema e dados comparados
banco temporário removido automaticamente
```

## Backup físico

Backup validado:

```text
infrastructure/backups/archives/2026-08-04_01-40-00
```

Proteções confirmadas:

```text
ssc_minio_data
ssc_postgres_data
ssc_rabbitmq_data
ssc_redis_data
```

Validações:

```text
quatro volumes protegidos
checksums SHA-256 verificados
cinco serviços reiniciados
todos os serviços healthy
.env não incluído
```

## Papéis PostgreSQL

### Administrador e proprietário temporário

```text
companyos
```

Permanece como administrador e proprietário dos objetos durante a Sprint 1.2.

O Mission Control não utiliza mais esse papel.

### Usuário da aplicação

```text
companyos_app
```

Atributos confirmados:

```text
LOGIN:        sim
SUPERUSER:    não
CREATEDB:     não
CREATEROLE:   não
INHERIT:      não
REPLICATION:  não
BYPASSRLS:    não
CONNECTIONS:  20
```

Privilégios permitidos:

```text
CONNECT no banco companyos
USAGE no schema public
SELECT nas tabelas
INSERT nas tabelas
UPDATE nas tabelas
DELETE nas tabelas
USAGE nas sequências
SELECT nas sequências
```

Privilégios bloqueados:

```text
CREATE no schema
TEMPORARY no banco
TRUNCATE
SUPERUSER
CREATEDB
CREATEROLE
REPLICATION
BYPASSRLS
```

Limites de sessão:

```text
statement_timeout:                    30 segundos
lock_timeout:                          5 segundos
idle_in_transaction_session_timeout:  60 segundos
```

### Usuário de observabilidade

```text
companyos_monitor
```

Atributos confirmados:

```text
LOGIN:        sim
SUPERUSER:    não
CREATEDB:     não
CREATEROLE:   não
INHERIT:      sim
REPLICATION:  não
BYPASSRLS:    não
CONNECTIONS:  5
```

Permissões:

```text
membro de pg_monitor
transações somente leitura
acesso a pg_stat_activity
sem acesso às tabelas de negócio
```

Limite de sessão:

```text
statement_timeout: 15 segundos
```

## Mission Control

A configuração privada foi atualizada sem exibir credenciais.

Usuário efetivo:

```text
companyos_app
```

Validações:

```text
container healthy
banco conectado
health check respondendo
Aparência preservada
logo preservada
tema preservado
Assistant preservado
```

O container PostgreSQL não foi recriado.

Somente o Mission Control foi recriado para carregar a nova `DATABASE_URL`.

## Backup lógico

Backup criado em:

```text
infrastructure/backups/logical/postgresql/2026-08-04_01-52-29
```

Arquivos:

```text
companyos.dump
globals-no-passwords.sql
restore-list.txt
manifest.env
checksums.sha256
```

Garantias:

```text
formato custom do pg_dump
sem proprietário no archive
sem privilégios no archive
globals sem hashes de senha
arquivos com permissão restrita
checksums SHA-256
catálogo do pg_restore validado
```

## Restauração lógica

Banco temporário:

```text
ssc_restore_20260804_015233
```

Validações concluídas:

```text
backup restaurado
schema comparado
tabelas comparadas
sequências comparadas
dados estáveis comparados
checksums validados
banco principal preservado
banco temporário removido automaticamente
```

Relatório:

```text
infrastructure/backups/logical/postgresql/2026-08-04_01-52-29/restore-test-20260804_015233.txt
```

## Segurança

Confirmado:

```text
nenhuma senha exibida
.env permanece privado
nenhuma credencial versionada
nenhum volume removido
nenhum docker compose down -v
PostgreSQL não recriado
configuração de papéis transacional
SCRAM-SHA-256 preservado
monitor sem acesso às tabelas de negócio
rollback da DATABASE_URL disponível
```

## Propriedade e migrações

Nesta sprint, os objetos continuam pertencendo temporariamente a:

```text
companyos
```

A próxima evolução do PostgreSQL será realizada na Sprint 1.3:

```text
companyos_owner
companyos_migrator
Alembic
revision inicial
migrações controladas
retirada do Base.metadata.create_all()
transferência formal da propriedade
```

## Estado da Sprint 1.2

```text
Baseline da infraestrutura:          concluído
Backup integrado:                    concluído
Mission Control:                     concluído
Ollama externo com GPU:              concluído
RabbitMQ operacional:                concluído
Redis operacional:                   concluído
MinIO operacional:                   concluído
PostgreSQL operacional:              concluído
Observabilidade:                     pendente
Hardening dos demais serviços:       pendente
```

## Próximo passo

Versionar a configuração operacional do PostgreSQL e iniciar a configuração da
observabilidade com Prometheus, Loki e Grafana.
