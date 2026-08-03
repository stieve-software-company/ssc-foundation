# CompanyOS — Operações do MinIO

## Papel do serviço

O MinIO armazena objetos binários e arquivos. O PostgreSQL continua sendo a
fonte de verdade para metadados, permissões e relacionamentos.

## Buckets

### companyos-references

```text
documentos enviados
imagens
datasets
especificações
referências de projeto
versionamento: habilitado
```

### companyos-artifacts

```text
builds
relatórios
documentação gerada
pacotes produzidos por agentes
versionamento: habilitado
```

### companyos-exports

```text
arquivos preparados para download
pacotes de entrega
exports solicitados por usuários
versionamento: não habilitado
```

### companyos-backups

```text
backups gerenciados pela plataforma
manifests
checksums
metadados de restauração
versionamento: habilitado
```

## Convenção de objetos

```text
projects/<project-id>/<categoria>/<ano>/<mês>/<object-id>/<nome>
```

Exemplos:

```text
projects/uuid/references/2026/08/uuid/requisitos.pdf
projects/uuid/artifacts/2026/08/uuid/backend-build.tar.gz
projects/uuid/exports/2026/08/uuid/release.zip
system/backups/2026/08/uuid/manifest.json
```

## Metadados

Metadados recomendados:

```text
project_id
object_id
content_type
original_name
sha256
created_at
created_by_type
created_by_id
classification
```

O registro canônico deverá existir também no PostgreSQL.

## Privacidade

Todos os buckets são privados.

Não configure:

```text
anonymous download
anonymous upload
anonymous public
```

Entregas externas devem usar URLs assinadas com expiração.

## Versionamento

O versionamento protege contra sobrescritas e exclusões acidentais, mas aumenta
o consumo de armazenamento.

A exclusão normal de um objeto versionado pode criar um marcador de exclusão.
A remoção definitiva de todas as versões exige uma ação explícita e deve ser
restrita a objetos conhecidos.

## Lifecycle

Nenhuma política automática de exclusão está ativa nesta etapa.

Antes de habilitar lifecycle:

1. documentar o prazo;
2. validar o bucket e o prefixo;
3. testar com objetos temporários;
4. registrar o impacto em versões;
5. criar backup;
6. obter aprovação humana.

## Upload

Aplicações devem:

- validar tamanho;
- validar tipo;
- calcular SHA-256;
- usar identificador único;
- gravar metadados no PostgreSQL;
- registrar auditoria;
- evitar confiar apenas no nome original.

## Download

Downloads externos devem usar URL assinada com prazo curto.

O usuário não deve receber as credenciais do MinIO.

## Objetos temporários

Testes e tarefas temporárias devem usar:

```text
ssc-test/
```

ou outro prefixo explicitamente reservado.

## Backup

O volume persistente é:

```text
ssc_minio_data
```

Ele continua protegido pelo backup integrado do CompanyOS.

O bucket `companyos-backups` é uma camada de armazenamento da aplicação e não
substitui o backup do volume Docker.

## Diagnóstico

Estado:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  ps minio
```

Auditoria:

```bash
./scripts/audit-minio.sh
```

Teste:

```bash
./scripts/test-minio-integration.sh
```

Logs:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  logs --tail=100 minio
```

## Segurança

- credenciais somente no `.env`;
- nenhum acesso anônimo;
- portas externas limitadas pelo Compose;
- URLs assinadas com expiração;
- nenhum segredo em metadados;
- nenhum `docker compose down -v`;
- nenhuma regra de lifecycle destrutiva sem aprovação.
