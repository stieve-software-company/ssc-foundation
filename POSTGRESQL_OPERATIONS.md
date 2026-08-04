# Operações do PostgreSQL

## Instalação

```bash
./scripts/install-postgresql-operational.sh
```

## Backup físico obrigatório

Antes de alterar os papéis:

```bash
./scripts/backup.sh --yes
```

## Configurar acessos

```bash
./scripts/configure-postgresql-access.sh
```

Esse script:

```text
gera ou reutiliza credenciais privadas
cria companyos_app
cria companyos_monitor
aplica privilégios
testa as credenciais
atualiza o .env
recria somente o Mission Control
executa testes
restaura o .env anterior se houver falha
```

## Testar acessos novamente

```bash
./scripts/test-postgresql-access.sh
```

## Backup lógico

```bash
./scripts/backup-postgresql-logical.sh
```

Destino:

```text
infrastructure/backups/logical/postgresql/<data-hora>
```

Conteúdo:

```text
companyos.dump
globals-no-passwords.sql
restore-list.txt
manifest.env
checksums.sha256
```

## Testar a restauração mais recente

```bash
./scripts/test-postgresql-logical-restore.sh
```

Também é possível informar um diretório:

```bash
./scripts/test-postgresql-logical-restore.sh \
  infrastructure/backups/logical/postgresql/AAAA-MM-DD_HH-MM-SS
```

O teste cria um banco temporário, restaura o arquivo, compara schema e dados
e remove o banco temporário.

O banco `companyos` não é sobrescrito.

## Conferir o usuário do Mission Control

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  exec -T mission-control \
  python -c '
from sqlalchemy import text
from app.database import engine

with engine.connect() as connection:
    print(connection.execute(text("select current_user")).scalar_one())
'
```

Resultado esperado:

```text
companyos_app
```

## Diagnóstico

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  ps postgres mission-control
```

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  logs --tail=150 postgres mission-control
```

## Arquivos que não devem ir ao Git

```text
.env
postgresql-audit.txt
infrastructure/backups/
*.dump
```

## Regra permanente

Nunca execute:

```text
docker compose down -v
```
