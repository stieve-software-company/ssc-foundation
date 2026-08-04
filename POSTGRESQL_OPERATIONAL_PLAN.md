# Sprint 1.2 — Plano Operacional do PostgreSQL

## Objetivo

Configurar o PostgreSQL do CompanyOS para operação segura, recuperação
verificável e futura integração com a API da Sprint 1.3.

## Estado atual conhecido

```text
container PostgreSQL saudável
volume persistente ssc_postgres_data
Mission Control conectado
max_connections configurado pelo Compose
shared_buffers configurado pelo Compose
backup físico integrado do volume
```

Ainda precisam ser validados:

```text
papéis e privilégios
usuário exclusivo da aplicação
propriedade dos objetos
schemas
extensões
parâmetros operacionais
conexões
backup lógico
restauração lógica
estratégia de migrações
métricas
```

## Regra de segurança

A configuração será feita em etapas.

```text
auditar
projetar
fazer backup
aplicar
testar
restaurar em ambiente temporário
documentar
versionar
```

Não será utilizado:

```text
docker compose down -v
DROP do banco principal
exposição de senhas
alteração direta sem backup
mudança simultânea de usuário e schema
```

## Etapa 1 — Auditoria somente leitura

Coletar:

```text
versão do servidor
imagem do container
health check
volume e data directory
papéis existentes
atributos dos papéis
bancos e proprietários
schemas e proprietários
tabelas e sequências
privilégios
default privileges
extensões instaladas e disponíveis
conexões atuais
parâmetros de memória
parâmetros de WAL
autenticação pg_hba
timezone
password_encryption
ferramentas pg_dump e pg_restore
identidade usada pelo Mission Control
```

O relatório não deverá conter:

```text
senhas
hashes de senha
DATABASE_URL completa
conteúdo do .env
tokens
cookies
```

## Etapa 2 — Desenho dos papéis

Estrutura alvo preliminar:

```text
companyos_owner      NOLOGIN — propriedade lógica
companyos_migrator   LOGIN   — migrations e DDL
companyos_app        LOGIN   — acesso da aplicação
companyos_monitor    LOGIN   — observabilidade
```

O nome final e os privilégios serão confirmados após a auditoria.

### Observação sobre o Mission Control

O Mission Control ainda executa:

```text
SQLAlchemy Base.metadata.create_all()
```

Portanto, a retirada completa de DDL do usuário da aplicação deverá ocorrer
junto da adoção do Alembic.

Até lá, existem duas opções seguras:

```text
A. usuário da aplicação com CREATE controlado no schema da aplicação;
B. manter o usuário atual temporariamente e criar os novos papéis sem ativá-los.
```

A decisão será tomada com base na propriedade real dos objetos atuais.

## Etapa 3 — Configuração do banco

Entregas previstas:

```text
diretório infrastructure/config/postgresql
script idempotente de bootstrap
papéis separados
privilégios documentados
configurações versionadas sem segredo
validação de conectividade
validação pelo Mission Control
```

Nenhuma senha real será versionada.

## Etapa 4 — Backup lógico

Será criado um processo complementar ao backup físico dos volumes.

Formato planejado:

```text
pg_dump --format=custom
```

Validações:

```text
arquivo não vazio
pg_restore --list
checksum SHA-256
permissão 0600
metadados de versão
retenção inicial documentada
```

O backup físico integrado continuará existindo.

## Etapa 5 — Restauração lógica

A restauração será testada em banco temporário:

```text
criar banco de validação
restaurar backup
comparar schemas
comparar tabelas
comparar contagens essenciais
remover banco temporário após confirmação
```

O banco principal não será sobrescrito.

## Etapa 6 — Migrações

Nesta sprint será definida a estratégia.

Implementação completa prevista para a Sprint 1.3:

```text
Alembic
revision inicial
upgrade
downgrade controlado
histórico de migrations
execução separada da aplicação
```

Até a adoção do Alembic, o comportamento atual do Mission Control será
preservado.

## Etapa 7 — Observabilidade do PostgreSQL

Preparar:

```text
papel companyos_monitor
pg_monitor
métricas de conexões
tamanho dos bancos
transações
locks
deadlocks
cache hit ratio
atividade
tempo de execução
```

A coleta pelo Prometheus será integrada na etapa de observabilidade da
Sprint 1.2.

## Critérios de conclusão

- [ ] auditoria sanitizada executada;
- [ ] papéis e privilégios documentados;
- [ ] usuário de aplicação separado ou transição formal definida;
- [ ] configuração idempotente;
- [ ] Mission Control conectado;
- [ ] backup lógico criado;
- [ ] checksum validado;
- [ ] restauração em banco temporário concluída;
- [ ] banco principal preservado;
- [ ] estratégia de Alembic aprovada;
- [ ] backup físico continua funcionando;
- [ ] nenhuma credencial versionada;
- [ ] documentação operacional atualizada;
- [ ] commit enviado ao GitHub.

## Próximo passo

Executar:

```bash
./scripts/audit-postgresql.sh
```

Depois revisar o arquivo local:

```text
postgresql-audit.txt
```

Esse arquivo é temporário e não deverá ser adicionado ao Git.
