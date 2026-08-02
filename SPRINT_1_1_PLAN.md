# Plano Técnico — Sprint 1.1: Ambiente Docker

## Identificação

```text
Projeto: Stieve Software Company
Plataforma: CompanyOS
Fase: 1 — Infraestrutura Base
Sprint: 1.1 — Ambiente Docker
Estado: Em andamento
```

---

# Objetivo

Criar a base executável, reproduzível, segura e documentada para os serviços do CompanyOS.

Ao final desta sprint, a máquina Ubuntu Server deverá possuir uma estrutura Docker funcional capaz de:

- iniciar a plataforma com um único comando;
- separar serviços por redes;
- preservar dados em volumes;
- carregar configurações por variáveis de ambiente;
- validar a saúde dos containers;
- iniciar e parar serviços com segurança;
- atualizar imagens e configurações;
- produzir backups básicos;
- fornecer comandos simples para operação;
- preparar a infraestrutura para a Sprint 1.2.

---

# Escopo

Esta sprint criará a estrutura operacional do Docker.

Os serviços completos de infraestrutura serão ativados e validados na Sprint 1.2.

Nesta sprint serão preparados:

- estrutura de diretórios;
- arquivo principal do Docker Compose;
- redes;
- volumes;
- configurações;
- arquivo `.env.example`;
- scripts de operação;
- política de logs;
- health checks;
- validações;
- documentação de uso.

---

# Fora do escopo

Não serão implementados nesta sprint:

- regras de negócio do CompanyOS;
- API FastAPI;
- Mission Control;
- autenticação;
- Agent Runtime funcional;
- workflows funcionais;
- banco com entidades do domínio;
- dashboards definitivos;
- modelos de IA configurados para produção;
- deployment em produção.

Esses itens pertencem às próximas sprints.

---

# Decisões técnicas

## Orquestração inicial

Tecnologia:

```text
Docker Compose
```

O Docker Compose será suficiente para a primeira implantação em uma única VM Ubuntu Server.

## Sistema operacional

```text
Ubuntu Server
```

## Diretório do repositório

```text
$HOME/workspace/ssc-foundation
```

## Nome do projeto Docker

```text
ssc
```

A variável recomendada será:

```text
COMPOSE_PROJECT_NAME=ssc
```

## Arquivo principal

```text
compose.yaml
```

O nome `compose.yaml` será usado por ser o formato atual recomendado pelo Docker Compose.

## Configuração local

```text
.env
```

O arquivo `.env` não será enviado ao Git.

## Modelo público de configuração

```text
.env.example
```

O arquivo `.env.example` será versionado sem senhas reais.

---

# Estrutura planejada

```text
ssc-foundation/
├── compose.yaml
├── .env.example
├── .gitignore
├── Makefile
├── SPRINT_1_1_PLAN.md
├── infrastructure/
│   ├── docker/
│   │   ├── postgres/
│   │   ├── rabbitmq/
│   │   ├── redis/
│   │   ├── minio/
│   │   ├── ollama/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   └── loki/
│   ├── config/
│   └── backups/
├── scripts/
│   ├── bootstrap.sh
│   ├── validate.sh
│   ├── start.sh
│   ├── stop.sh
│   ├── restart.sh
│   ├── status.sh
│   ├── logs.sh
│   ├── update.sh
│   ├── backup.sh
│   └── restore.sh
└── data/
    ├── workspaces/
    ├── artifacts/
    └── temporary/
```

---

# Redes Docker

A arquitetura prevê cinco redes.

## `ssc_public`

Responsável por serviços expostos ao navegador ou ao host.

Serviços futuros:

```text
api-gateway
mission-control
```

## `ssc_application`

Responsável pela comunicação entre aplicações internas.

Serviços futuros:

```text
companyos-api
workflow-engine
worker
scheduler
notification-service
```

## `ssc_data`

Responsável por serviços de dados.

Serviços:

```text
postgres
rabbitmq
redis
minio
```

## `ssc_execution`

Responsável pela execução de agentes e modelos.

Serviços:

```text
agent-runtime
tool-gateway
ollama
sandboxes
```

## `ssc_observability`

Responsável pela coleta e visualização operacional.

Serviços:

```text
prometheus
grafana
loki
```

---

# Regras de rede

- somente serviços públicos poderão publicar portas externas por padrão;
- bancos e mensageria permanecerão em redes internas;
- nenhum container de execução terá acesso irrestrito à rede de dados;
- serviços deverão participar apenas das redes necessárias;
- redes deverão possuir nomes previsíveis;
- produção não deverá publicar portas administrativas sem necessidade.

---

# Volumes Docker

Volumes planejados:

```text
ssc_postgres_data
ssc_rabbitmq_data
ssc_redis_data
ssc_minio_data
ssc_ollama_data
ssc_prometheus_data
ssc_grafana_data
ssc_loki_data
```

Volumes vinculados ao host:

```text
./data/workspaces
./data/artifacts
./data/temporary
./infrastructure/backups
```

---

# Regras de volumes

- dados persistentes não ficarão apenas na camada gravável do container;
- workspaces serão separados dos volumes de infraestrutura;
- segredos não serão armazenados em volumes compartilhados;
- backups serão gravados em diretório explícito;
- diretórios temporários possuirão política de limpeza;
- permissões deverão ser validadas antes da inicialização.

---

# Variáveis de ambiente

## Identidade da plataforma

```text
COMPOSE_PROJECT_NAME
SSC_ENVIRONMENT
SSC_VERSION
SSC_TIMEZONE
```

## PostgreSQL

```text
POSTGRES_DB
POSTGRES_USER
POSTGRES_PASSWORD
POSTGRES_PORT
```

## RabbitMQ

```text
RABBITMQ_DEFAULT_USER
RABBITMQ_DEFAULT_PASS
RABBITMQ_PORT
RABBITMQ_MANAGEMENT_PORT
```

## Redis

```text
REDIS_PASSWORD
REDIS_PORT
```

## MinIO

```text
MINIO_ROOT_USER
MINIO_ROOT_PASSWORD
MINIO_API_PORT
MINIO_CONSOLE_PORT
```

## Ollama

```text
OLLAMA_PORT
OLLAMA_KEEP_ALIVE
```

## Grafana

```text
GRAFANA_ADMIN_USER
GRAFANA_ADMIN_PASSWORD
GRAFANA_PORT
```

## Observabilidade

```text
PROMETHEUS_PORT
LOKI_PORT
```

---

# Regras para o `.env`

- `.env` deverá permanecer fora do Git;
- `.env.example` não conterá credenciais reais;
- senhas padrão deverão ser trocadas;
- valores obrigatórios deverão ser validados pelo script de inicialização;
- espaços e caracteres especiais deverão ser tratados corretamente;
- configuração de produção deverá ser separada da configuração de desenvolvimento.

---

# Política de imagens

As imagens deverão:

- possuir versão explícita;
- evitar a tag `latest`;
- vir de repositórios oficiais ou aprovados;
- ser atualizadas de forma controlada;
- ser verificadas antes do uso;
- ter suas versões registradas no Git.

Exemplo:

```yaml
image: postgres:<versão-aprovada>
```

As versões finais serão definidas durante a criação do `compose.yaml`, com validação na documentação oficial de cada projeto.

---

# Política de containers

Todo serviço deverá definir, quando aplicável:

```text
container_name
restart
healthcheck
networks
volumes
environment
ports
logging
security_opt
```

## Reinicialização

Política inicial:

```text
unless-stopped
```

## Segurança

Aplicar quando suportado:

```text
no-new-privileges
read-only filesystem
usuário não privilegiado
capabilities reduzidas
```

Serviços de terceiros que exigirem escrita deverão ter somente os volumes necessários.

---

# Health checks

Cada serviço deverá possuir um health check adequado.

## PostgreSQL

```text
pg_isready
```

## RabbitMQ

```text
rabbitmq-diagnostics
```

## Redis

```text
redis-cli ping
```

## MinIO

```text
endpoint de saúde HTTP
```

## Ollama

```text
endpoint HTTP de disponibilidade
```

## Prometheus

```text
/-/healthy
```

## Grafana

```text
/api/health
```

## Loki

```text
/ready
```

---

# Parâmetros de health check

Padrão inicial:

```text
interval: 10s
timeout: 5s
retries: 5
start_period: variável por serviço
```

Serviços com inicialização demorada deverão ter `start_period` maior.

---

# Dependências

`depends_on` poderá ser usado com condições de saúde quando suportado.

Entretanto, ele não será tratado como garantia completa de disponibilidade.

Cada aplicação futura deverá possuir:

- retry de conexão;
- timeout;
- backoff;
- readiness.

---

# Política de logs do Docker

Driver inicial:

```text
json-file
```

Limites planejados:

```text
max-size: 10m
max-file: 5
```

Objetivo:

- impedir crescimento ilimitado;
- preservar logs recentes;
- preparar coleta futura pelo Loki.

---

# Scripts operacionais

## `bootstrap.sh`

Responsável por:

- validar Docker;
- validar Docker Compose;
- criar diretórios;
- criar `.env` a partir do exemplo;
- ajustar permissões iniciais;
- validar estrutura.

## `validate.sh`

Responsável por:

- verificar arquivos;
- verificar variáveis;
- executar `docker compose config`;
- verificar diretórios;
- verificar permissões;
- detectar portas em uso.

## `start.sh`

Responsável por:

```text
docker compose up -d
```

Antes de iniciar, deverá executar validação.

## `stop.sh`

Responsável por:

```text
docker compose stop
```

Não deverá remover volumes.

## `restart.sh`

Responsável por reiniciar os serviços de forma controlada.

## `status.sh`

Responsável por exibir:

- containers;
- estado;
- saúde;
- portas;
- uso básico.

## `logs.sh`

Responsável por consultar logs com parâmetros seguros.

## `update.sh`

Responsável por:

- validar repositório;
- baixar imagens;
- recriar containers;
- preservar volumes;
- exibir resultado;
- permitir rollback manual.

## `backup.sh`

Responsável por:

- criar diretório datado;
- registrar manifesto;
- exportar dados suportados;
- calcular hashes;
- registrar falhas.

## `restore.sh`

Será preparado, mas sua execução exigirá confirmação explícita.

---

# Makefile

Comandos planejados:

```text
make bootstrap
make validate
make start
make stop
make restart
make status
make logs
make update
make backup
```

O Makefile será apenas uma interface simples para os scripts.

---

# Backups

## Diretório

```text
infrastructure/backups/
```

## Estrutura

```text
backups/
└── YYYY-MM-DD_HH-MM-SS/
    ├── manifest.txt
    ├── checksums.sha256
    ├── postgres/
    ├── rabbitmq/
    ├── minio/
    └── configuration/
```

## Regras

- backups não serão enviados ao Git;
- cada backup terá data;
- cada backup terá manifesto;
- arquivos terão hash;
- falhas interromperão o processo com código diferente de zero;
- restauração será testada em sprint posterior;
- segredos exigirão proteção específica.

---

# Atualizações

O processo de atualização deverá seguir:

```text
1. validar ambiente
2. verificar espaço em disco
3. criar backup quando necessário
4. baixar imagens
5. validar compose
6. recriar containers
7. aguardar health checks
8. exibir status
9. registrar versão
```

---

# Inicialização da máquina

Nesta sprint não será configurado automaticamente um serviço `systemd` para iniciar toda a plataforma.

Primeiro será validado o funcionamento manual.

A automação de inicialização poderá ser adicionada após:

- compose validado;
- health checks estáveis;
- backups testados;
- comportamento de reinício conhecido.

---

# Segurança

## Regras obrigatórias

- não usar containers privilegiados;
- não montar `/var/run/docker.sock`;
- não incluir segredos no Git;
- não usar senhas vazias;
- não expor PostgreSQL publicamente por padrão;
- não expor Redis publicamente por padrão;
- não expor RabbitMQ publicamente sem necessidade;
- não compartilhar workspace entre projetos sem separação;
- não usar `latest`;
- não executar scripts sem validação.

---

# Portas

Portas serão configuráveis por `.env`.

Na primeira instalação, portas administrativas poderão ser vinculadas apenas ao host local ou à rede interna.

A exposição final dependerá do modo de acesso à VM.

---

# Estrutura de execução da sprint

## Etapa 1 — Plano e estrutura

Entregas:

- `SPRINT_1_1_PLAN.md`;
- diretórios;
- `.gitignore`;
- `.env.example`.

## Etapa 2 — Compose base

Entregas:

- `compose.yaml`;
- redes;
- volumes;
- política de logs;
- definições comuns.

## Etapa 3 — Scripts básicos

Entregas:

- bootstrap;
- validate;
- start;
- stop;
- restart;
- status;
- logs.

## Etapa 4 — Atualização e backup

Entregas:

- update;
- backup;
- restore;
- manifests;
- checksums.

## Etapa 5 — Validação

Entregas:

- validação de sintaxe;
- inicialização;
- health checks;
- parada;
- reinício;
- persistência;
- documentação.

---

# Ordem dos próximos arquivos

Após este plano, os arquivos serão criados nesta ordem:

```text
1. .gitignore
2. .env.example
3. compose.yaml
4. scripts/bootstrap.sh
5. scripts/validate.sh
6. scripts/start.sh
7. scripts/stop.sh
8. scripts/restart.sh
9. scripts/status.sh
10. scripts/logs.sh
11. scripts/update.sh
12. scripts/backup.sh
13. scripts/restore.sh
14. Makefile
15. DOCKER_OPERATIONS.md
```

---

# Validações obrigatórias

## Validação de configuração

```bash
docker compose config
```

## Validação de containers

```bash
docker compose ps
```

## Validação de logs

```bash
docker compose logs --tail=100
```

## Validação de volumes

```bash
docker volume ls
```

## Validação de redes

```bash
docker network ls
```

---

# Testes da sprint

## Estrutura

- diretórios existem;
- scripts são executáveis;
- `.env` é ignorado;
- backups são ignorados;
- dados locais são ignorados quando necessário.

## Compose

- sintaxe válida;
- nomes válidos;
- redes criadas;
- volumes criados;
- nenhum serviço usa `latest`;
- portas configuráveis.

## Inicialização

- serviços iniciam;
- health checks ficam saudáveis;
- reinício preserva dados;
- parada não remove volumes.

## Segurança

- nenhum serviço privilegiado;
- Docker socket não montado;
- segredos não aparecem no Git;
- bancos não ficam expostos sem decisão explícita.

## Backup

- diretório criado;
- manifesto criado;
- hash criado;
- falha gera código de erro;
- backup não entra no Git.

---

# Critérios de aceite

A Sprint 1.1 será considerada concluída quando:

- a estrutura Docker estiver versionada;
- o `compose.yaml` passar em `docker compose config`;
- redes estiverem criadas;
- volumes estiverem criados;
- `.env.example` estiver documentado;
- `.env` estiver ignorado;
- health checks estiverem definidos;
- logs estiverem limitados;
- scripts operacionais funcionarem;
- atualização estiver documentada;
- backup básico funcionar;
- dados persistirem após reinício;
- nenhum segredo estiver no Git;
- a operação estiver documentada;
- a base estiver pronta para a Sprint 1.2.

---

# Resultado esperado

Ao final da sprint, a operação básica deverá ser:

```bash
cp .env.example .env
nano .env
make bootstrap
make validate
make start
make status
```

Para encerrar:

```bash
make stop
```

Para backup:

```bash
make backup
```

---

# Próxima sprint

Após a conclusão desta sprint:

```text
Sprint 1.2 — Serviços de infraestrutura
```

Nela serão ativados e validados:

- PostgreSQL;
- RabbitMQ;
- Redis;
- Ollama;
- MinIO;
- Prometheus;
- Grafana;
- Loki.
