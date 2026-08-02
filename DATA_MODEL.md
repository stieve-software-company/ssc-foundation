# Modelo de Dados da Stieve Software Company

## Objetivo

Definir o modelo de dados inicial do CompanyOS e do SSC Mission Control.

Este documento estabelece:

- entidades principais;
- responsabilidades;
- relacionamentos;
- identificadores;
- estados;
- regras de integridade;
- isolamento entre projetos;
- rastreabilidade;
- auditoria;
- requisitos para persistência.

O modelo será usado como base para:

- banco PostgreSQL;
- schemas SQLAlchemy;
- migrações Alembic;
- contratos da API;
- eventos;
- permissões;
- workflows;
- documentação OpenAPI.

---

# Princípios

## Identificadores estáveis

Todas as entidades deverão possuir identificadores próprios e imutáveis.

Formato recomendado:

```text
usr_<ulid>
org_<ulid>
prj_<ulid>
agt_<ulid>
tsk_<ulid>
wfl_<ulid>
evt_<ulid>
req_<ulid>
ref_<ulid>
apr_<ulid>
rel_<ulid>
dep_<ulid>
aud_<ulid>
```

O ULID é recomendado por:

- ser único;
- ser ordenável por tempo;
- funcionar bem em sistemas distribuídos;
- não expor sequência interna do banco.

## Isolamento por projeto

Toda entidade pertencente a um projeto deverá possuir:

```text
project_id
```

Entidades globais não deverão possuir `project_id`.

Exemplos de entidades globais:

- Organization
- User
- Role
- Permission
- AgentDefinition
- SystemConfiguration

Exemplos de entidades vinculadas a projeto:

- Requirement
- Reference
- Task
- Workflow
- Release
- Deployment
- ProjectAuditLog

## Rastreabilidade

Toda informação importante deverá permitir rastrear:

```text
origem
  ↓
requisito
  ↓
tarefa
  ↓
execução
  ↓
alteração de código
  ↓
teste
  ↓
release
  ↓
deployment
```

## Exclusão lógica

Entidades importantes não deverão ser removidas fisicamente durante operações normais.

Campos recomendados:

```text
deleted_at
deleted_by
is_deleted
```

Exclusão física deverá ser reservada a:

- dados temporários;
- políticas de retenção;
- solicitações autorizadas;
- processos administrativos auditados.

## Auditoria

Entidades críticas deverão possuir:

```text
created_at
created_by
updated_at
updated_by
version
```

---

# Organização das entidades

```text
Organization
├── Users
├── Roles
├── Permissions
├── Projects
├── Agents
├── Infrastructure
└── Audit Logs

Project
├── Members
├── References
├── Discoveries
├── Requirements
├── Decisions
├── Backlog
├── Tasks
├── Workflows
├── Agent Executions
├── Tests
├── Security Findings
├── Releases
├── Deployments
├── Incidents
└── Knowledge Vault
```

---

# Entidades globais

## Organization

Representa a Stieve Software Company ou uma futura empresa administrada pela plataforma.

### Campos

```text
id
name
slug
description
status
timezone
locale
settings
created_at
updated_at
```

### Estados

```text
ACTIVE
SUSPENDED
ARCHIVED
```

### Regras

- `slug` deverá ser único.
- Uma organização poderá possuir vários projetos.
- Toda entidade global deverá estar vinculada a uma organização.

---

## User

Representa uma pessoa com acesso ao Mission Control.

### Campos

```text
id
organization_id
name
email
password_hash
status
locale
timezone
last_login_at
created_at
created_by
updated_at
updated_by
```

### Estados

```text
INVITED
ACTIVE
BLOCKED
DISABLED
```

### Regras

- O e-mail deverá ser único dentro da organização.
- Senhas nunca deverão ser armazenadas em texto puro.
- Usuários desativados não poderão iniciar novas sessões.

---

## Role

Representa um perfil de acesso.

### Campos

```text
id
organization_id
name
code
description
scope
is_system
created_at
updated_at
```

### Escopos

```text
ORGANIZATION
PROJECT
ENVIRONMENT
```

### Perfis iniciais

```text
OWNER
ADMIN
PROJECT_MANAGER
HUMAN_DEVELOPER
SECURITY_REVIEWER
RELEASE_APPROVER
DEPLOYMENT_OPERATOR
AUDITOR
VIEWER
AGENT
```

---

## Permission

Representa uma ação autorizável.

### Campos

```text
id
code
resource
action
description
risk_level
created_at
```

### Exemplos

```text
project.create
project.read
project.update
project.archive

requirement.approve
task.cancel
workflow.pause
agent.block

release.approve
deployment.staging
deployment.production
deployment.rollback

security.risk.accept
audit.read
```

### Níveis de risco

```text
LOW
MEDIUM
HIGH
CRITICAL
```

---

## RolePermission

Relaciona papéis e permissões.

### Campos

```text
id
role_id
permission_id
created_at
created_by
```

### Restrições

- O par `role_id + permission_id` deverá ser único.

---

## AgentDefinition

Define um tipo de agente disponível na empresa.

### Campos

```text
id
organization_id
name
code
description
layer
capabilities
default_model
default_tools
default_limits
status
created_at
updated_at
```

### Camadas

```text
EXECUTIVE
ENGINEERING
OPERATIONS
```

### Estados

```text
ACTIVE
DISABLED
DEPRECATED
```

### Exemplos

```text
CEO_AGENT
SOLUTION_ARCHITECT
PRODUCT_MANAGER
CHANGE_MANAGER
TECH_LEAD
BACKEND_ENGINEER
FRONTEND_ENGINEER
QA_ENGINEER
SECURITY_ENGINEER
DEVOPS_ENGINEER
```

---

## AgentInstance

Representa uma instância executável de um agente.

### Campos

```text
id
organization_id
agent_definition_id
name
status
model_provider
model_name
tools
resource_limits
last_heartbeat_at
created_at
updated_at
```

### Estados

```text
OFFLINE
STARTING
IDLE
RESERVED
PLANNING
WORKING
WAITING
REVIEWING
BLOCKED
FAILED
STOPPING
```

---

# Entidades de projeto

## Project

Representa um projeto administrado pela SSC.

### Campos

```text
id
organization_id
code
name
short_name
slug
description
problem_statement
objective
business_area
solution_type
confidentiality_level
priority
status
owner_id
settings
created_at
created_by
updated_at
updated_by
archived_at
archived_by
```

### Tipos de solução

```text
WEB_SYSTEM
MOBILE_APP
API
AUTOMATION
INTEGRATION
SAAS_PLATFORM
INTERNAL_SYSTEM
BACKEND_SERVICE
LIBRARY
DATA_TOOL
OTHER
```

### Prioridades

```text
LOW
MEDIUM
HIGH
CRITICAL
```

### Confidencialidade

```text
PUBLIC
INTERNAL
CONFIDENTIAL
RESTRICTED
```

### Estados principais

```text
IDEA
DISCOVERY
WAITING_APPROVAL
PLANNING
DEVELOPMENT
TESTING
STAGING
PRODUCTION
EVOLUTION
PAUSED
ARCHIVED
CANCELLED
```

### Regras

- `code` deverá ser único dentro da organização.
- `slug` deverá ser único dentro da organização.
- Apenas projetos aprovados poderão entrar em planejamento.
- Projetos arquivados não poderão receber novas tarefas.

---

## ProjectMember

Relaciona usuários a projetos.

### Campos

```text
id
project_id
user_id
role_id
status
joined_at
removed_at
created_by
```

### Estados

```text
ACTIVE
SUSPENDED
REMOVED
```

### Restrições

- Um usuário não poderá possuir o mesmo papel repetido no mesmo projeto.

---

## ProjectAgent

Relaciona agentes a projetos.

### Campos

```text
id
project_id
agent_instance_id
role
permissions_override
tools_override
resource_limits_override
status
assigned_at
removed_at
assigned_by
```

### Estados

```text
ASSIGNED
ACTIVE
PAUSED
REMOVED
```

---

# Discovery

## DiscoverySession

Representa o processo de descoberta do projeto.

### Campos

```text
id
project_id
version
status
started_at
started_by
completed_at
approved_at
approved_by
summary
open_questions_count
created_at
updated_at
```

### Estados

```text
DRAFT
COLLECTING_CONTEXT
PROCESSING_REFERENCES
INTERVIEWING
EXTRACTING_REQUIREMENTS
GENERATING_DISCOVERY
WAITING_APPROVAL
CHANGES_REQUESTED
APPROVED
CANCELLED
```

### Regras

- Somente uma sessão poderá estar ativa por projeto.
- Uma nova versão deverá preservar o histórico da versão anterior.
- Apenas `APPROVED` permitirá avanço para planejamento técnico.

---

## InterviewQuestion

Representa uma pergunta da entrevista inteligente.

### Campos

```text
id
project_id
discovery_session_id
question
question_type
category
required
status
sequence
created_by_agent_id
created_at
answered_at
```

### Tipos

```text
TEXT
SINGLE_CHOICE
MULTIPLE_CHOICE
NUMBER
DATE
MONEY
SCALE
PRIORITY
CONFIRMATION
FILE
USER
PROCESS
```

### Estados

```text
PENDING
ANSWERED
SKIPPED
CANCELLED
```

---

## InterviewAnswer

Representa a resposta a uma pergunta.

### Campos

```text
id
project_id
question_id
answer
answer_type
answered_by
source
confidence
created_at
updated_at
```

### Origem

```text
USER
REFERENCE
AGENT_INFERENCE
SYSTEM
```

### Regras

- Inferências de agentes deverão ser identificadas explicitamente.
- Respostas contraditórias deverão gerar uma pendência de revisão.

---

## DiscoveryReport

Representa o relatório de descoberta.

### Campos

```text
id
project_id
discovery_session_id
version
status
executive_summary
problem
objectives
users
processes
scope
out_of_scope
functional_requirements_summary
non_functional_requirements_summary
business_rules_summary
integrations
constraints
risks
open_questions
initial_architecture
complexity
next_steps
generated_at
generated_by_agent_id
approved_at
approved_by
```

### Estados

```text
DRAFT
GENERATED
WAITING_APPROVAL
CHANGES_REQUESTED
APPROVED
REJECTED
```

---

# Referências

## Reference

Representa um arquivo, link ou outra fonte de informação.

### Campos

```text
id
project_id
name
reference_type
source
description
purpose
category
importance
version
content_type
file_name
storage_key
external_url
file_size
file_hash
status
permission_of_use
uploaded_by
uploaded_at
processed_at
archived_at
metadata
```

### Tipos

```text
FILE
LINK
IMAGE
VIDEO
AUDIO
REPOSITORY
API_DOCUMENTATION
TEXT
OTHER
```

### Categorias

```text
BUSINESS_RULE
FUNCTIONAL
VISUAL
TECHNICAL
PROCESS
OFFICIAL_DOCUMENT
POSITIVE_EXAMPLE
NEGATIVE_EXAMPLE
CURRENT_PROCESS
INTEGRATION
RESTRICTION
REGULATION
```

### Estados

```text
UPLOADED
QUEUED
PROCESSING
PROCESSED
FAILED
NEEDS_REVIEW
ARCHIVED
QUARANTINED
```

### Regras

- Arquivos deverão possuir hash.
- O nome original não deverá definir o caminho físico.
- Referências em quarentena não poderão ser processadas por agentes.

---

## ExtractedInformation

Representa uma informação obtida de uma referência.

### Campos

```text
id
project_id
reference_id
information_type
content
confidence
page_or_location
extracted_by_agent_id
status
created_at
reviewed_at
reviewed_by
```

### Tipos

```text
FACT
REQUIREMENT
BUSINESS_RULE
RISK
CONSTRAINT
ENTITY
PROCESS
INTEGRATION
QUESTION
```

### Estados

```text
EXTRACTED
NEEDS_REVIEW
CONFIRMED
REJECTED
```

---

# Requisitos e decisões

## Requirement

Representa um requisito rastreável.

### Campos

```text
id
project_id
code
title
description
requirement_type
priority
status
source_type
source_id
owner_id
acceptance_criteria
dependencies
risks
created_at
created_by
updated_at
updated_by
approved_at
approved_by
implemented_at
verified_at
```

### Tipos

```text
FUNCTIONAL
NON_FUNCTIONAL
BUSINESS_RULE
INTEGRATION
SECURITY
PERFORMANCE
AVAILABILITY
AUDIT
USABILITY
ACCESSIBILITY
PRIVACY
INFRASTRUCTURE
OPERATIONAL
```

### Estados

```text
DRAFT
PROPOSED
NEEDS_REVIEW
APPROVED
REJECTED
IMPLEMENTED
VERIFIED
DEPRECATED
```

### Regras

- `code` deverá ser único dentro do projeto.
- Todo requisito aprovado deverá possuir critério de aceite.
- Todo requisito deverá registrar sua origem.

---

## RequirementReference

Relaciona requisitos e referências.

### Campos

```text
id
project_id
requirement_id
reference_id
relationship_type
created_at
created_by
```

### Relações

```text
ORIGIN
SUPPORT
CONSTRAINT
EXAMPLE
VALIDATION
```

---

## Decision

Representa uma decisão funcional, técnica ou operacional.

### Campos

```text
id
project_id
code
title
decision_type
context
decision
alternatives
positive_consequences
negative_consequences
status
responsible_id
decided_at
created_at
updated_at
```

### Tipos

```text
ADR
RFC
FUNCTIONAL
SECURITY
OPERATIONS
PRODUCT
```

### Estados

```text
PROPOSED
UNDER_REVIEW
APPROVED
REJECTED
SUPERSEDED
DEPRECATED
```

---

# Backlog e execução

## Epic

### Campos

```text
id
project_id
code
title
description
priority
status
owner_id
created_at
updated_at
```

### Estados

```text
DRAFT
PLANNED
IN_PROGRESS
COMPLETED
CANCELLED
```

---

## UserStory

### Campos

```text
id
project_id
epic_id
code
title
description
persona
goal
benefit
acceptance_criteria
priority
status
estimated_points
created_at
updated_at
```

### Estados

```text
DRAFT
READY
PLANNED
IN_PROGRESS
REVIEW
DONE
BLOCKED
CANCELLED
```

---

## Task

Representa uma unidade executável de trabalho.

### Campos

```text
id
project_id
user_story_id
parent_task_id
code
title
description
task_type
priority
status
assigned_user_id
assigned_agent_id
workflow_id
environment
attempt_count
max_attempts
timeout_seconds
scheduled_at
started_at
completed_at
blocked_reason
result_summary
created_at
created_by
updated_at
updated_by
```

### Tipos

```text
ANALYSIS
DESIGN
BACKEND
FRONTEND
DATABASE
TEST
SECURITY
DEVOPS
DOCUMENTATION
REVIEW
DEPLOYMENT
OTHER
```

### Estados

```text
PENDING
QUEUED
ASSIGNED
RUNNING
WAITING_APPROVAL
BLOCKED
RETRYING
COMPLETED
FAILED
CANCELLED
```

### Regras

- Uma tarefa concluída deverá possuir resultado.
- Tarefas críticas deverão possuir evidências.
- Uma tarefa não poderá ser executada em projeto arquivado.

---

## TaskDependency

### Campos

```text
id
project_id
task_id
depends_on_task_id
dependency_type
created_at
```

### Tipos

```text
BLOCKS
REQUIRES
RELATES_TO
DUPLICATES
```

---

## Workflow

Representa um processo de longa duração.

### Campos

```text
id
project_id
code
name
workflow_type
version
status
current_step
input
output
correlation_id
started_at
completed_at
paused_at
cancelled_at
created_at
created_by
```

### Tipos

```text
DISCOVERY
PLANNING
FEATURE_DEVELOPMENT
CHANGE_REQUEST
QUALITY_REVIEW
SECURITY_REVIEW
RELEASE
DEPLOYMENT
ROLLBACK
INCIDENT_RESPONSE
```

### Estados

```text
CREATED
RUNNING
PAUSED
WAITING_APPROVAL
COMPLETED
FAILED
CANCELLED
```

---

## WorkflowStep

### Campos

```text
id
project_id
workflow_id
name
sequence
status
assigned_agent_id
task_id
input
output
attempt_count
started_at
completed_at
error
```

### Estados

```text
PENDING
READY
RUNNING
WAITING
WAITING_APPROVAL
COMPLETED
FAILED
SKIPPED
CANCELLED
```

---

## AgentExecution

Registra uma execução específica de agente.

### Campos

```text
id
project_id
agent_instance_id
task_id
workflow_id
status
input
context_manifest
tools_used
commands_requested
commands_approved
files_read
files_changed
result
error
model_provider
model_name
token_usage
cpu_usage
memory_usage
gpu_usage
started_at
completed_at
duration_ms
commit_sha
correlation_id
```

### Estados

```text
CREATED
RUNNING
WAITING_TOOL
WAITING_APPROVAL
COMPLETED
FAILED
CANCELLED
TIMEOUT
```

---

# Aprovações

## ApprovalRequest

Representa uma decisão humana pendente.

### Campos

```text
id
project_id
approval_type
resource_type
resource_id
title
description
risk_level
status
requested_by_user_id
requested_by_agent_id
assigned_to_user_id
expires_at
decided_at
decision_reason
created_at
```

### Tipos

```text
DISCOVERY
REQUIREMENT
TASK
RFC
ADR
SECURITY_EXCEPTION
RELEASE
DEPLOYMENT
ROLLBACK
DELETE_PROJECT
DELETE_DATA
PERMISSION_CHANGE
HIGH_RISK_EXECUTION
```

### Estados

```text
PENDING
APPROVED
REJECTED
EXPIRED
CANCELLED
```

### Regras

- Aprovações críticas deverão registrar motivo.
- O solicitante não deverá aprovar a própria solicitação quando houver segregação obrigatória.
- Aprovações expiradas não poderão ser reutilizadas.

---

# Qualidade e segurança

## TestRun

### Campos

```text
id
project_id
task_id
release_id
test_type
status
total_tests
passed_tests
failed_tests
skipped_tests
coverage
report_storage_key
started_at
completed_at
executed_by_agent_id
commit_sha
```

### Tipos

```text
UNIT
INTEGRATION
END_TO_END
REGRESSION
PERFORMANCE
SECURITY
SMOKE
```

### Estados

```text
QUEUED
RUNNING
PASSED
FAILED
CANCELLED
```

---

## SecurityFinding

### Campos

```text
id
project_id
task_id
release_id
finding_type
title
description
severity
status
affected_resource
recommendation
detected_by_agent_id
detected_at
resolved_at
resolved_by
accepted_risk_at
accepted_risk_by
```

### Severidades

```text
LOW
MEDIUM
HIGH
CRITICAL
```

### Estados

```text
OPEN
CONFIRMED
IN_PROGRESS
RESOLVED
FALSE_POSITIVE
RISK_ACCEPTED
```

### Regras

- Vulnerabilidade crítica deverá bloquear release.
- Aceite de risco deverá exigir aprovação autorizada.

---

# Releases e deployments

## Release

### Campos

```text
id
project_id
version
name
status
commit_sha
tag_name
changelog
artifact_storage_key
test_summary
security_summary
documentation_status
rollback_plan
created_at
created_by
approved_at
approved_by
published_at
```

### Estados

```text
DRAFT
VALIDATING
WAITING_APPROVAL
APPROVED
REJECTED
PUBLISHED
DEPRECATED
```

### Regras

- `version` deverá ser única por projeto.
- Release aprovada deverá possuir testes e revisão de segurança.
- Release publicada não deverá ser alterada.

---

## Deployment

### Campos

```text
id
project_id
release_id
environment
status
requested_at
requested_by
approved_at
approved_by
started_at
completed_at
deployed_version
previous_version
logs_storage_key
health_check_status
rollback_deployment_id
correlation_id
```

### Ambientes

```text
DEVELOPMENT
TESTING
STAGING
PRODUCTION
```

### Estados

```text
REQUESTED
WAITING_APPROVAL
APPROVED
RUNNING
SUCCEEDED
FAILED
ROLLING_BACK
ROLLED_BACK
CANCELLED
```

### Regras

- Produção deverá exigir aprovação humana.
- Todo deployment em produção deverá possuir versão anterior identificada.
- Falha crítica deverá permitir rollback rastreável.

---

# Eventos e auditoria

## EventRecord

Representa um evento publicado ou recebido.

### Campos

```text
id
organization_id
project_id
event_type
event_version
source
actor_id
correlation_id
causation_id
payload
metadata
status
published_at
processed_at
retry_count
error
created_at
```

### Estados

```text
CREATED
PUBLISHED
PROCESSING
PROCESSED
FAILED
DEAD_LETTERED
```

### Regras

- Eventos publicados não deverão ser alterados.
- O payload não deverá conter segredos.
- Consumidores deverão ser idempotentes.

---

## AuditLog

Representa uma ação auditável.

### Campos

```text
id
organization_id
project_id
actor_type
actor_id
action
resource_type
resource_id
result
risk_level
source_ip
user_agent
correlation_id
before_data
after_data
reason
created_at
```

### Tipos de ator

```text
USER
AGENT
SERVICE
SYSTEM
```

### Resultados

```text
SUCCESS
DENIED
FAILED
```

### Regras

- Registros de auditoria não poderão ser alterados por usuários ou agentes comuns.
- Segredos deverão ser mascarados.
- A retenção deverá ser configurável.

---

# Conhecimento

## KnowledgeItem

Representa um item persistente no Project Knowledge Vault.

### Campos

```text
id
project_id
knowledge_type
title
content
source_type
source_id
version
status
tags
embedding_reference
created_at
created_by
updated_at
updated_by
```

### Tipos

```text
ORIGINAL_IDEA
REFERENCE_SUMMARY
INTERVIEW
REQUIREMENT
BUSINESS_RULE
DECISION
ARCHITECTURE
BACKLOG
CODE_KNOWLEDGE
TEST_RESULT
RELEASE_NOTE
INCIDENT
LESSON_LEARNED
```

### Estados

```text
ACTIVE
SUPERSEDED
ARCHIVED
```

---

# Incidentes

## Incident

### Campos

```text
id
project_id
code
title
description
severity
status
impact
evidence
containment
resolution
root_cause
responsible_id
detected_at
contained_at
resolved_at
postmortem_storage_key
created_at
updated_at
```

### Severidades

```text
LOW
MEDIUM
HIGH
CRITICAL
```

### Estados

```text
OPEN
INVESTIGATING
CONTAINED
RESOLVING
RESOLVED
CLOSED
```

---

# Relacionamentos principais

```text
Organization 1 ─── N User
Organization 1 ─── N Project
Organization 1 ─── N AgentDefinition
Organization 1 ─── N AgentInstance

Project 1 ─── N ProjectMember
Project 1 ─── N ProjectAgent
Project 1 ─── N DiscoverySession
Project 1 ─── N Reference
Project 1 ─── N Requirement
Project 1 ─── N Decision
Project 1 ─── N Epic
Project 1 ─── N UserStory
Project 1 ─── N Task
Project 1 ─── N Workflow
Project 1 ─── N ApprovalRequest
Project 1 ─── N TestRun
Project 1 ─── N SecurityFinding
Project 1 ─── N Release
Project 1 ─── N Deployment
Project 1 ─── N KnowledgeItem
Project 1 ─── N Incident
Project 1 ─── N AuditLog

DiscoverySession 1 ─── N InterviewQuestion
InterviewQuestion 1 ─── N InterviewAnswer
DiscoverySession 1 ─── N DiscoveryReport

Reference 1 ─── N ExtractedInformation
Requirement N ─── N Reference

Epic 1 ─── N UserStory
UserStory 1 ─── N Task
Workflow 1 ─── N WorkflowStep
Task 1 ─── N AgentExecution

Release 1 ─── N Deployment
Release 1 ─── N TestRun
Release 1 ─── N SecurityFinding
```

---

# Regras de integridade

## Obrigatórias

- Toda entidade de projeto deverá possuir `project_id`.
- Toda entidade deverá possuir identificador único.
- Toda alteração crítica deverá gerar auditoria.
- Toda aprovação deverá registrar solicitante e decisor.
- Toda release deverá estar associada a um commit.
- Todo deployment deverá estar associado a uma release.
- Toda execução de agente deverá estar associada a uma tarefa ou workflow.
- Todo requisito deverá possuir origem.
- Todo projeto deverá pertencer a uma organização.

## Restrições de unicidade

```text
Organization.slug

User.organization_id + User.email

Project.organization_id + Project.code
Project.organization_id + Project.slug

Requirement.project_id + Requirement.code
Epic.project_id + Epic.code
UserStory.project_id + UserStory.code
Task.project_id + Task.code

Release.project_id + Release.version
Decision.project_id + Decision.code
Incident.project_id + Incident.code
```

## Concorrência

Entidades alteráveis deverão utilizar controle otimista por versão:

```text
version
```

Uma atualização deverá falhar quando tentar salvar uma versão desatualizada.

---

# Índices recomendados

```text
project_id
organization_id
status
created_at
updated_at
correlation_id
actor_id
assigned_agent_id
assigned_user_id
event_type
resource_type + resource_id
```

Índices compostos recomendados:

```text
(project_id, status)
(project_id, created_at)
(project_id, code)
(organization_id, status)
(correlation_id, created_at)
(resource_type, resource_id)
```

---

# Dados JSON

Campos flexíveis poderão utilizar `JSONB`, principalmente:

```text
settings
metadata
capabilities
tools
resource_limits
input
output
payload
before_data
after_data
```

Regras:

- JSONB não deverá substituir entidades relacionais importantes.
- Campos usados em filtros frequentes deverão possuir colunas próprias.
- Estruturas JSON deverão possuir schema e versão.

---

# Datas e horários

Todas as datas deverão ser armazenadas em UTC.

O Mission Control será responsável pela conversão para o fuso do usuário.

Formato recomendado:

```text
ISO 8601
```

Exemplo:

```text
2026-08-02T20:30:00Z
```

---

# Retenção e privacidade

Cada tipo de dado deverá possuir política de retenção.

Exemplos:

- sessões expiradas;
- arquivos temporários;
- logs operacionais;
- auditoria;
- dados pessoais;
- backups;
- execuções de agentes;
- eventos;
- relatórios.

A exclusão deverá considerar:

- autorização;
- impacto;
- auditoria;
- backup;
- obrigações legais;
- rastreabilidade;
- dados relacionados.

---

# Migrações

Toda alteração no modelo deverá:

1. gerar uma migração Alembic;
2. registrar o motivo;
3. avaliar impacto;
4. possuir estratégia de rollback quando possível;
5. ser testada em ambiente não produtivo;
6. preservar dados existentes;
7. atualizar a documentação.

---

# Critérios de aceite da Sprint

O modelo de dados será considerado aprovado quando:

- entidades principais estiverem definidas;
- relacionamentos estiverem documentados;
- estados estiverem padronizados;
- regras de integridade estiverem definidas;
- isolamento por projeto estiver garantido;
- auditoria estiver incorporada;
- aprovações estiverem modeladas;
- releases e deployments estiverem relacionados;
- eventos e execuções forem rastreáveis;
- o modelo puder ser transformado em schemas SQLAlchemy;
- o modelo puder servir de base aos contratos da API.
