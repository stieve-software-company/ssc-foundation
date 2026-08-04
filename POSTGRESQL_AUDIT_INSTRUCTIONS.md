# Instruções da Auditoria PostgreSQL

## Segurança

O script realiza apenas consultas e verificações.

Ele não executa:

```text
CREATE
ALTER
GRANT
REVOKE
DROP
TRUNCATE
UPDATE
DELETE
INSERT
recriação de container
reinício de serviço
```

O arquivo `.env` não é exibido.

A `DATABASE_URL` do Mission Control é analisada somente para mostrar:

```text
protocolo
host
porta
banco
username
presença de senha
```

A senha não é impressa.

## Instalação

Copie:

```text
scripts/audit-postgresql.sh
```

para o repositório e aplique permissão:

```bash
chmod +x scripts/audit-postgresql.sh
```

## Execução

```bash
./scripts/audit-postgresql.sh
```

## Resultado

O relatório será criado em:

```text
postgresql-audit.txt
```

Permissão esperada:

```text
0600
```

## Git

Não adicione o relatório ao Git.

Antes de qualquer commit:

```bash
git status --short
```

O arquivo abaixo deve permanecer fora do stage:

```text
postgresql-audit.txt
```

Depois da análise, ele poderá ser removido:

```bash
rm -f postgresql-audit.txt
```
