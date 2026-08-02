# Arquitetura da Stieve Software Company

## Objetivo

Definir a arquitetura geral da Stieve Software Company, incluindo o SSC Mission Control, CompanyOS, Agent Runtime, projetos, eventos, workflows, armazenamento, segurança e infraestrutura.

A plataforma deverá administrar múltiplos projetos simultaneamente, mantendo isolamento, rastreabilidade e controle humano sobre ações críticas.

## Visão geral

```text
Usuário
   |
   v
### SSC Mission Control
   |
   v
### API Gateway
   |
   v
### CompanyOS
   |
   +-------------------------------+
   |                               |
   v                               v
Project Management           Executive Layer
   |                               |
   |                         Solution Architect
   |                         Product Manager
   |                         Change Manager
   |                         Tech Lead
   |                         Release Manager
   |                         Deployment Manager
   |
   +-------------------------------+
   |
   v
## Workflow Engine
   |
   v
## Event Bus
   |
   +-------------------------------+
   |         |         |           |
   v         v         v           v
Backend   Frontend     QA       Security
Agent      Agent      Agent       Agent
   |
   v
Workspace isolado
   |
   v
Git + Testes + Build + Artefatos
```
## Componentes principais
### SSC Mission Control

Portal Web utilizado para administrar a empresa.

Responsabilidades:

criar projetos;
enviar referências;
responder entrevistas;
acompanhar agentes;
visualizar tarefas;
consultar eventos;
aprovar decisões;
criar releases;
autorizar deployments;
monitorar infraestrutura.

O Mission Control não deverá executar comandos diretamente na máquina.

Todas as ações deverão passar pela API do CompanyOS.

### API Gateway

Ponto de entrada das requisições externas.

Responsabilidades:

encaminhar requisições;
validar autenticação;
aplicar limites;
registrar correlação;
centralizar acesso à API;
encaminhar conexões em tempo real.

A API pública será versionada inicialmente em:

/api/v1
### CompanyOS

Núcleo operacional da Stieve Software Company.

Responsabilidades:

administrar usuários;
administrar projetos;
registrar agentes;
controlar permissões;
criar tarefas;
iniciar workflows;
publicar eventos;
solicitar aprovações;
registrar auditoria;
controlar releases;
controlar deployments.

Nenhum agente deverá controlar diretamente outro agente.

Toda coordenação deverá passar pelo CompanyOS, pelo Workflow Engine ou pelo Event Bus.

### Project Management

Responsável pelo ciclo de vida dos projetos.

Cada projeto deverá possuir:

identidade;
estado;
responsáveis;
configurações;
documentação;
referências;
requisitos;
backlog;
arquitetura;
repositório;
ambientes;
releases;
deployments;
histórico;
auditoria.
## Isolamento dos projetos

Os projetos deverão ser isolados logicamente desde o início.

Cada projeto possuirá:

Project
├── metadata
├── discovery
├── references
├── requirements
├── architecture
├── backlog
├── workspace
├── knowledge-vault
├── releases
├── deployments
└── audit

Um agente deverá receber explicitamente o identificador do projeto no qual poderá trabalhar.

O acesso a arquivos, dados e ferramentas deverá ser limitado ao projeto autorizado.

## Project Knowledge Vault

Cada projeto possuirá uma base própria de conhecimento.

Ela armazenará:

ideia original;
arquivos enviados;
informações extraídas;
entrevistas;
requisitos;
regras de negócio;
decisões;
ADRs;
RFCs;
arquitetura;
conhecimento do código;
testes;
incidentes;
releases;
lições aprendidas.

Os agentes deverão ser preferencialmente stateless.

A memória persistente deverá permanecer no Knowledge Vault, e não dentro do processo do agente.

## Executive Layer

A camada executiva será responsável por análise, planejamento e aprovação técnica.

Agentes principais:

Solution Architect
Product Manager
Change Manager
Tech Lead
Release Manager
Deployment Manager
Infrastructure Manager
Knowledge Manager

Esses agentes não deverão alterar código sem uma tarefa e permissão específicas.

## Engineering Layer

A camada de engenharia executará tarefas técnicas.

Agentes iniciais:

Backend Engineer
Frontend Engineer
QA Engineer
Security Engineer
DevOps Engineer
Documentation Engineer
Database Engineer
UX/UI Engineer

Cada agente possuirá:

identidade;
função;
capacidades;
ferramentas;
permissões;
limites;
fila;
estado;
histórico de execução.
## Agent Runtime

O Agent Runtime será responsável por executar os agentes.

Responsabilidades:

registrar agentes;
carregar configurações;
selecionar modelo de IA;
disponibilizar ferramentas;
aplicar permissões;
carregar contexto;
iniciar execução;
limitar recursos;
registrar logs;
devolver resultados;
publicar eventos.

Fluxo básico:

Tarefa criada
   ↓
Workflow seleciona capacidade
   ↓
Agent Runtime reserva um agente
   ↓
Contexto do projeto é carregado
   ↓
Ferramentas autorizadas são disponibilizadas
   ↓
Agente executa
   ↓
Resultado é validado
   ↓
Commit, artefato ou relatório é registrado
   ↓
Evento de conclusão é publicado
## Ferramentas dos agentes

As ferramentas deverão ser disponibilizadas por interfaces controladas.

Exemplos:

leitura de arquivo;
escrita de arquivo;
busca no código;
criação de branch;
Git diff;
commit;
execução de testes;
build;
Docker;
navegador automatizado;
consulta ao banco;
criação de tarefa;
registro de decisão.

O agente não deverá receber acesso irrestrito ao shell da máquina principal.

## Workflow Engine

O Workflow Engine será responsável pelos processos de longa duração.

Exemplos:

Project Discovery;
planejamento técnico;
desenvolvimento de funcionalidade;
revisão de código;
testes;
revisão de segurança;
criação de release;
deployment;
rollback;
processamento de mudança.

O Workflow Engine deverá suportar:

estado persistente;
etapas;
dependências;
timeout;
retry;
pausa;
continuação;
cancelamento;
aprovação humana;
compensação;
histórico.
## Event Bus

A plataforma será orientada por eventos.

A implementação inicial poderá utilizar RabbitMQ, mas os serviços deverão depender de uma abstração de Event Bus.

Serviço
   ↓
Interface Event Bus
   ↓
RabbitMQ

Isso permitirá substituir o mecanismo de eventos futuramente sem reescrever os serviços principais.

## Regras dos eventos

Todos os eventos deverão possuir:

identificador;
tipo;
versão;
projeto;
origem;
timestamp;
correlation_id;
causation_id;
payload;
metadados.

Os consumidores deverão ser idempotentes.

Falhas permanentes deverão ser encaminhadas para uma dead-letter queue.

## API

A API será inicialmente desenvolvida com FastAPI.

Características:

REST;
OpenAPI;
Swagger;
autenticação;
autorização;
paginação;
filtros;
versionamento;
logs estruturados;
tratamento padronizado de erros;
auditoria.

Endpoints iniciais previstos:

/api/v1/auth
/api/v1/users
/api/v1/projects
/api/v1/references
/api/v1/discovery
/api/v1/requirements
/api/v1/agents
/api/v1/tasks
/api/v1/workflows
/api/v1/events
/api/v1/approvals
/api/v1/releases
/api/v1/deployments
/api/v1/audit
## Atualizações em tempo real

O Mission Control deverá receber atualizações em tempo real.

Tecnologias previstas:

WebSocket; ou
Server-Sent Events.

Eventos em tempo real incluirão:

alteração do estado dos agentes;
início e conclusão de tarefas;
falhas;
aprovações pendentes;
progresso de workflows;
deployments;
alertas de infraestrutura.
## Persistência
### PostgreSQL

Armazenará dados estruturados:

usuários;
projetos;
requisitos;
tarefas;
workflows;
agentes;
aprovações;
releases;
deployments;
auditoria;
metadados.
### Armazenamento de objetos

Armazenará:

uploads;
documentos;
imagens;
vídeos;
logs extensos;
artefatos;
backups;
relatórios.

Poderá ser utilizado MinIO ou armazenamento compatível.

### Redis

Poderá ser utilizado para:

cache;
locks distribuídos;
estado temporário;
limitação de requisições;
sessões temporárias.

Redis não deverá ser a fonte definitiva de dados importantes.

## Git e workspaces

Cada projeto deverá possuir um repositório Git próprio.

Os agentes deverão trabalhar em branches específicas.

Exemplo:

main
develop
feature/TASK-001-backend
feature/TASK-002-frontend
test/TASK-001
security/TASK-001

Regras:

nenhuma alteração direta na branch principal;
commits deverão indicar tarefa e agente;
merges deverão passar pelos controles definidos;
releases deverão possuir tags;
push forçado na branch principal será proibido.
## Execução isolada

As tarefas técnicas deverão ser executadas preferencialmente em containers.

Cada execução deverá possuir:

workspace isolado;
limite de CPU;
limite de memória;
timeout;
diretórios autorizados;
variáveis controladas;
rede limitada;
logs;
identificação do projeto;
identificação da tarefa.
## Provedor de IA

A plataforma deverá utilizar uma interface abstrata para provedores de IA.

Implementação inicial:

AI Provider Interface
         |
         v
       Ollama
         |
   +-----+-----+
   |           |
 Llama      Modelos de código

Isso permitirá adicionar futuramente:

outros modelos locais;
servidores de inferência;
APIs externas opcionais;
fallback entre modelos.
## Segurança

A arquitetura deverá aplicar:

autenticação;
RBAC;
menor privilégio;
isolamento entre projetos;
execução em container;
segredos fora do Git;
aprovação humana para produção;
auditoria obrigatória;
validação de uploads;
revisão de dependências;
bloqueio de comandos perigosos.
## Observabilidade

Todos os serviços deverão expor:

/health
/ready
/metrics
/version

A plataforma deverá registrar:

logs estruturados;
métricas;
traces futuramente;
eventos;
consumo de recursos;
tempo de execução;
falhas;
retries;
filas;
estado dos agentes.

Tecnologias previstas:

Prometheus
Grafana
Loki
## Infraestrutura inicial

A primeira versão será executada em uma única VM Ubuntu Server utilizando Docker Compose.

Ubuntu Server
   |
   v
Docker Compose
   |
   +-- Mission Control
   +-- CompanyOS API
   +-- PostgreSQL
   +-- RabbitMQ
   +-- Redis
   +-- Ollama
   +-- MinIO
   +-- Prometheus
   +-- Grafana
   +-- Loki

A arquitetura deverá permitir evolução futura para múltiplas máquinas ou Kubernetes, sem que isso seja necessário na primeira versão.

## Ambientes

Cada projeto poderá possuir:

development;
testing;
staging;
production.

Produção deverá permanecer separada do ambiente onde os agentes desenvolvem.

## Releases e deployments

Fluxo esperado:

Código concluído
   ↓
Testes
   ↓
Revisão de segurança
   ↓
Documentação
   ↓
Release Manager
   ↓
Release aprovada
   ↓
Homologação
   ↓
Aprovação humana
   ↓
Produção
   ↓
Health checks
   ↓
Sucesso ou rollback
## Decisões arquiteturais

Decisões importantes deverão ser registradas em ADRs.

Mudanças significativas em projetos deverão ser registradas em RFCs.

Nenhum agente poderá alterar uma decisão aprovada sem criar uma nova proposta rastreável.

## Stack inicial
Ubuntu Server
Docker
Docker Compose
Python 3.12
FastAPI
### PostgreSQL
SQLAlchemy
Alembic
RabbitMQ
### Redis
Ollama
MinIO
Git
Pytest
Prometheus
Grafana
Loki
MkDocs
## Restrições iniciais
Priorizar tecnologias gratuitas e open source.
Não depender obrigatoriamente de APIs pagas.
Não utilizar Kubernetes na primeira versão.
Não permitir deploy autônomo em produção.
Não disponibilizar shell irrestrito aos agentes.
Não compartilhar memória entre projetos.
Não armazenar segredos no repositório.
## Critérios de aceite

A arquitetura será considerada definida quando:

os componentes principais estiverem documentados;
as responsabilidades estiverem separadas;
projetos forem isolados;
o Agent Runtime estiver definido;
eventos e workflows estiverem definidos;
a API estiver prevista;
segurança estiver incorporada;
observabilidade estiver prevista;
o fluxo de release e deployment estiver definido;
a evolução futura puder ocorrer sem reescrever toda a plataforma.
