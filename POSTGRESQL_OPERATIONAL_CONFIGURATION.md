# Sprint 1.2 — Configuração Operacional do PostgreSQL

## Objetivo

Remover o uso do superusuário pelo Mission Control e validar uma estratégia
complementar de backup lógico e restauração.

## Entregas

```text
companyos_app
companyos_monitor
privilégios mínimos
transição automática da DATABASE_URL
rollback automático da aplicação
teste de RBAC do PostgreSQL
backup lógico custom
globals sem senhas
checksums
restauração em banco temporário
documentação operacional
```

## Arquivos

```text
scripts/install-postgresql-operational.sh
scripts/configure-postgresql-access.sh
scripts/test-postgresql-access.sh
scripts/backup-postgresql-logical.sh
scripts/test-postgresql-logical-restore.sh
infrastructure/config/postgresql/README.md
```

## Alterações versionadas

O instalador atualiza:

```text
.env.example
.gitignore
```

O arquivo privado `.env` é atualizado somente durante a configuração real e
nunca deve ser adicionado ao Git.

## Fluxo

```text
1. instalar os arquivos
2. executar backup físico integrado
3. criar os papéis
4. conceder privilégios mínimos
5. testar as novas credenciais
6. atualizar o .env privado
7. recriar somente o Mission Control
8. validar o usuário efetivo
9. criar backup lógico
10. restaurar em banco temporário
11. comparar schema e dados
12. remover o banco temporário
```

## Rollback

Durante a transição, o script preserva uma cópia temporária do `.env`.

Se o Mission Control não ficar saudável:

```text
o .env anterior é restaurado
somente o Mission Control é recriado
os novos papéis permanecem inativos e não causam impacto
```

Nenhum volume é removido.

## Propriedade dos objetos

Nesta sprint, a propriedade continua com:

```text
companyos
```

Isso é temporário.

A transferência para um papel `NOLOGIN` e a criação do migrator serão feitas
na Sprint 1.3, junto do Alembic.

## Extensões

Nenhuma extensão será instalada automaticamente.

A aplicação atual não depende de `pgcrypto`, `citext`, `pg_trgm` ou outras
extensões candidatas.

## Parâmetros

Não serão alterados nesta etapa:

```text
max_connections
shared_buffers
effective_cache_size
work_mem
WAL
checkpoints
autovacuum
pg_hba.conf
```

A auditoria mostrou valores adequados para a carga atual.

## Segurança

- senhas geradas com `secrets.token_urlsafe`;
- senhas não impressas;
- arquivos temporários com permissão `0600`;
- SCRAM-SHA-256 mantido;
- nenhum segredo em documentação;
- nenhum Docker Socket na aplicação;
- nenhum `docker compose down -v`;
- nenhuma alteração destrutiva no banco principal;
- restauração somente em banco temporário.
