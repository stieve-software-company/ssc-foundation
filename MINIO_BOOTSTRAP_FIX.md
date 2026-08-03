# Correção do Bootstrap MinIO

## Erro observado

```text
[OK] Bucket já existe: companyos-references
[OK] Acesso anônimo removido: companyos-references
[OK] Versionamento habilitado: companyos-references
mc: <ERROR> Failed to copy ...
Bucket `companyos-exports` does not exist.
```

## Causa

O bootstrap percorria a lista de buckets por meio da entrada padrão de um
`while read`.

Dentro desse laço, `docker compose exec` e o cliente `mc` também tinham acesso à
mesma entrada padrão. A primeira execução consumiu as linhas restantes, então o
laço processou apenas o primeiro bucket.

## Correção

- o cliente `mc` passa a receber entrada de `/dev/null`;
- a lista de buckets é carregada com `mapfile`;
- o provisionamento usa um laço sobre um array;
- todos os buckets são confirmados antes do teste de persistência;
- o teste estrutural usa a mesma abordagem;
- a detecção de versionamento desabilitado foi tornada mais precisa.

## Estado parcial

O bucket `companyos-references` criado na primeira execução está correto.

Não é necessário removê-lo. O bootstrap é idempotente e continuará a partir do
estado atual.

## Arquivos corrigidos

```text
scripts/bootstrap-minio.sh
scripts/test-minio-integration.sh
```

## Aplicação

Substitua os dois scripts e execute:

```bash
chmod +x   scripts/bootstrap-minio.sh   scripts/test-minio-integration.sh

bash -n scripts/bootstrap-minio.sh
bash -n scripts/test-minio-integration.sh

./scripts/bootstrap-minio.sh
```

## Resultado esperado durante o provisionamento

```text
[OK] Bucket já existe: companyos-references
[OK] Bucket criado: companyos-artifacts
[OK] Bucket criado: companyos-exports
[OK] Bucket criado: companyos-backups
[OK] Bucket confirmado: companyos-references
[OK] Bucket confirmado: companyos-artifacts
[OK] Bucket confirmado: companyos-exports
[OK] Bucket confirmado: companyos-backups
```

Nenhum volume será removido.
