# Configuração MinIO

## Arquivo canônico

```text
buckets.json
```

O arquivo declara:

- nomes dos buckets;
- finalidade;
- versionamento;
- acesso anônimo.

Não contém credenciais.

## Bootstrap

```bash
./scripts/bootstrap-minio.sh
```

O bootstrap:

1. valida o JSON;
2. compara os buckets com `MINIO_DEFAULT_BUCKETS`;
3. aguarda o MinIO;
4. cria buckets ausentes;
5. habilita versionamento;
6. garante acesso privado;
7. valida persistência após recriação;
8. executa os testes funcionais.

## Auditoria

```bash
./scripts/audit-minio.sh
```

## Testes

```bash
./scripts/test-minio-integration.sh
```

## Idempotência

O bootstrap pode ser executado novamente.

Ele não remove buckets, versões ou objetos de negócio.

## Lifecycle

Nenhuma regra de exclusão automática é aplicada nesta versão.
