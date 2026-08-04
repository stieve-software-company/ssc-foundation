# Sprint 1.2 — Análise da Auditoria PostgreSQL

## Resultado geral

```text
PostgreSQL 18.4
container running
health healthy
restart_count 0
volume persistente ssc_postgres_data
data checksums ativos
autenticação de rede SCRAM-SHA-256
backup lógico disponível
auditoria concluída sem mutações
```

## Banco e aplicação

```text
banco: companyos
usuário atual do Mission Control: companyos
tabelas da aplicação: 6
sequências: 4
tamanho do banco: aproximadamente 9,8 MB
diretório de dados: aproximadamente 65 MB
```

## Risco principal

O único papel com login é:

```text
companyos
```

Ele também possui:

```text
SUPERUSER
CREATEDB
CREATEROLE
REPLICATION
BYPASSRLS
```

O Mission Control usa esse mesmo papel na `DATABASE_URL`.

Isso significa que uma aplicação web está conectada ao PostgreSQL com
privilégios administrativos de cluster.

## Estrutura dos objetos

Os objetos atuais estão no schema:

```text
public
```

Propriedade:

```text
banco companyos: companyos
tabelas: companyos
sequências: companyos
schema public: pg_database_owner
```

O schema `public` já está em uma configuração adequada:

```text
PUBLIC possui USAGE
PUBLIC não possui CREATE
```

Não é necessário criar outro schema nesta etapa.

## Privilégios atuais

O papel `companyos`, por ser proprietário, possui todos os privilégios sobre
tabelas e sequências.

Não existem:

```text
privilégios padrão personalizados
usuário exclusivo de aplicação
usuário exclusivo de observabilidade
usuário exclusivo de migrations
```

## Extensões

Instalada:

```text
plpgsql
```

Extensões candidatas estão disponíveis, mas nenhuma é necessária para o
Mission Control atual.

Não serão instaladas extensões nesta etapa.

## Autenticação

Conexões de rede utilizam:

```text
scram-sha-256
```

Conexões locais internas ao container utilizam `trust`, padrão operacional
da imagem oficial para o ambiente interno inicializado.

A porta do PostgreSQL permanece protegida pela configuração de bind e pela
rede Docker interna.

## Capacidade

```text
max_connections: 100
conexões observadas: 10
shared_buffers: 256 MB
effective_cache_size: 4 GB
work_mem: 4 MB
maintenance_work_mem: 64 MB
autovacuum: ativo
data_checksums: ativo
espaço livre: aproximadamente 39 GB
```

Não há justificativa atual para alterar os parâmetros de memória.

## Decisão da Sprint 1.2

A separação será incremental:

```text
companyos          administrador e proprietário temporário
companyos_app      runtime do Mission Control
companyos_monitor  observabilidade somente leitura
```

O papel `companyos` deixará de ser usado pela aplicação, mas continuará
como administrador e proprietário nesta sprint.

A criação de:

```text
companyos_owner
companyos_migrator
```

será realizada junto da adoção do Alembic na Sprint 1.3. Isso evita uma
transferência prematura da propriedade enquanto o Mission Control ainda
executa `Base.metadata.create_all()`.

## Privilégios de companyos_app

Permitidos:

```text
CONNECT no banco companyos
USAGE no schema public
SELECT, INSERT, UPDATE e DELETE nas tabelas
USAGE e SELECT nas sequências
```

Negados:

```text
SUPERUSER
CREATEDB
CREATEROLE
REPLICATION
BYPASSRLS
CREATE no schema
TEMPORARY no banco
TRUNCATE
privilégios com GRANT OPTION
```

Limites:

```text
connection limit: 20
statement timeout: 30 segundos
lock timeout: 5 segundos
idle in transaction timeout: 60 segundos
```

## Privilégios de companyos_monitor

Permitidos:

```text
CONNECT no banco companyos
associação a pg_monitor
consultas de métricas e atividade
```

Restrições:

```text
transações somente leitura
connection limit: 5
statement timeout: 15 segundos
sem leitura das tabelas de negócio
```

## Backup

O backup de volume continuará sendo a proteção física integrada.

Será acrescentado:

```text
pg_dump em formato custom
pg_restore --list
globals sem hashes de senha
checksum SHA-256
manifesto
restauração em banco temporário
comparação de schema
comparação de dados
remoção do banco temporário
```

## Critérios de sucesso

- Mission Control conectado como `companyos_app`;
- `companyos_app` sem privilégios administrativos;
- aplicação saudável;
- Assistant funcionando;
- Aparência preservada;
- papel de monitoramento validado;
- backup lógico criado;
- restauração temporária concluída;
- banco principal inalterado;
- backup físico ainda funcional;
- nenhuma credencial versionada.
