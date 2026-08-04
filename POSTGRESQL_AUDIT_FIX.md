# Correção da Auditoria PostgreSQL v2

## Motivo

A primeira execução foi interrompida na seção de privilégios com:

```text
ERROR: column "schema_name" does not exist
```

A consulta utilizava a view:

```text
information_schema.role_usage_grants
```

Essa view não é apropriada para listar os privilégios `USAGE` e `CREATE` de
schemas do PostgreSQL.

## Correção

A versão 2 consulta diretamente os catálogos de controle de acesso:

```text
pg_database.datacl
pg_namespace.nspacl
```

E transforma as ACLs em linhas usando:

```text
acldefault()
aclexplode()
```

A nova auditoria lista:

```text
privilégios de banco
privilégios de schema
privilégios explícitos de tabela
default privileges
```

## Segurança

A correção continua somente leitura.

Não executa:

```text
CREATE
ALTER
GRANT
REVOKE
DROP
INSERT
UPDATE
DELETE
reinício de container
remoção de volume
```

Não imprime:

```text
senhas
hashes de senha
DATABASE_URL completa
conteúdo do .env
tokens
```

## Resultado parcial já confirmado

A primeira execução confirmou:

```text
PostgreSQL 18.4
container running e healthy
volume ssc_postgres_data
data checksums ativos
SCRAM-SHA-256
autovacuum ativo
Mission Control conectado
backup lógico disponível
```

Também identificou um ponto crítico para a próxima etapa:

```text
o usuário companyos é superuser
o Mission Control conecta usando companyos
```

Nenhuma alteração de privilégios deve ser feita antes da auditoria completa e
de um backup validado.

## Execução

Substitua o script anterior e execute:

```bash
./scripts/audit-postgresql.sh
```

O arquivo será sobrescrito:

```text
postgresql-audit.txt
```

O cabeçalho esperado contém:

```text
SSC PostgreSQL Audit v2
audit_version=2
```

## Git

Não adicione ao Git:

```text
postgresql-audit.txt
```

Depois da análise final, o relatório temporário poderá ser removido.
