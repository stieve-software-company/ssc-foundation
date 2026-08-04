# PostgreSQL — Configuração Operacional

## Papéis atuais

```text
companyos          administrador e proprietário temporário
companyos_app      runtime da aplicação
companyos_monitor  observabilidade
```

## Papel da aplicação

`companyos_app` possui somente:

```text
CONNECT
USAGE no schema public
SELECT
INSERT
UPDATE
DELETE
USAGE e SELECT em sequências
```

O papel não possui:

```text
SUPERUSER
CREATEDB
CREATEROLE
REPLICATION
BYPASSRLS
CREATE
TEMPORARY
TRUNCATE
```

## Papel de observabilidade

`companyos_monitor` recebe `pg_monitor` e inicia sessões em modo somente
leitura.

Ele não recebe acesso às tabelas de negócio.

## Propriedade

Os objetos continuam pertencendo temporariamente a `companyos`.

A propriedade será migrada na Sprint 1.3, junto da introdução do Alembic e
do papel dedicado de migrations.

## Credenciais

Credenciais reais existem somente no `.env` privado:

```text
POSTGRES_APP_USER
POSTGRES_APP_PASSWORD
POSTGRES_MONITOR_USER
POSTGRES_MONITOR_PASSWORD
DATABASE_URL
```

Nenhum valor real deve ser versionado.

## Backup

Existem duas camadas:

```text
backup físico do volume
backup lógico com pg_dump
```

As duas são complementares e devem continuar ativas.
