# Correção PostgreSQL Operacional v1.2

## Estado confirmado

A configuração SQL foi aplicada e finalizada com `COMMIT`.

Os papéis `companyos_app` e `companyos_monitor` já existem com os atributos
esperados. A falha ocorreu somente durante o teste anterior à troca da
`DATABASE_URL`.

## Causa

O teste do monitor chamava:

```sql
has_table_privilege(
    current_user,
    'public.users',
    'SELECT'
)
```

O papel `companyos_monitor` não possui `USAGE` no schema `public`. Ao tentar
resolver o nome textual `public.users`, o PostgreSQL bloqueou o acesso ao
schema e retornou:

```text
permission denied for schema public
```

Esse bloqueio é o comportamento esperado para o monitor.

## Correção

O teste agora:

```text
confirma associação com pg_monitor
confirma modo somente leitura
confirma INHERIT ativo
tenta consultar public.users
exige InsufficientPrivilege
consulta pg_stat_activity
```

Assim, o isolamento das tabelas de negócio é testado por uma tentativa real de
acesso, sem precisar resolver antecipadamente o nome da tabela por uma função
de privilégios.

## Estado do Mission Control

A falha ocorreu antes da atualização do `.env`. O Mission Control ainda deve
estar conectado como `companyos`.

A retomada reaplica os papéis de forma idempotente, testa as novas credenciais,
atualiza o `.env` e recria somente o Mission Control.

## Retomada

```bash
./scripts/resume-postgresql-operational.sh
```

O backup físico não será repetido.

## Segurança preservada

```text
nenhuma senha exibida
nenhum volume removido
PostgreSQL não recriado
configuração SQL transacional
monitor sem acesso às tabelas de negócio
rollback da DATABASE_URL em caso de falha
restauração somente em banco temporário
```
