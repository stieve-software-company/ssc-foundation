# Contratos da API da Stieve Software Company

## Objetivo

Definir os contratos iniciais da API do CompanyOS.

Este documento estabelece:

- convenções de URL;
- versionamento;
- autenticação;
- autorização;
- cabeçalhos;
- formato de requisições;
- formato de respostas;
- paginação;
- filtros;
- ordenação;
- idempotência;
- concorrência;
- operações de domínio;
- endpoints iniciais;
- eventos em tempo real;
- critérios de teste.

A API será usada por:

- SSC Mission Control;
- serviços internos;
- agentes autorizados;
- integrações futuras;
- ferramentas administrativas;
- automações controladas.

---

# Princípios

## API-first

Os contratos deverão ser definidos antes da implementação.

Toda funcionalidade exposta deverá possuir:

- endpoint;
- método HTTP;
- autenticação;
- autorização;
- schema de entrada;
- schema de saída;
- erros possíveis;
- idempotência;
- exemplos;
- testes.

## Versionamento

A versão inicial será:

```text
/api/v1
```

Mudanças incompatíveis deverão criar uma nova versão.

Exemplo:

```text
/api/v2
```

Mudanças compatíveis poderão ser adicionadas à versão atual.

## Recursos no plural

Exemplos:

```text
/projects
/tasks
/agents
/releases
/deployments
```

## Identificadores na URL

Exemplo:

```text
GET /api/v1/projects/{project_id}
```

## Operações de domínio explícitas

Mudanças de estado importantes não deverão ser representadas apenas por atualização genérica.

Exemplo correto:

```text
POST /api/v1/projects/{project_id}/transitions
```

Exemplo evitado:

```text
PATCH /api/v1/projects/{project_id}
{
  "status": "PRODUCTION"
}
```

## HTTPS

Ambientes públicos deverão utilizar HTTPS.

## JSON

O formato padrão será:

```text
application/json
```

Uploads poderão utilizar:

```text
multipart/form-data
```

---

# URL base

Exemplo local:

```text
http://localhost:8000/api/v1
```

Exemplo de homologação:

```text
https://api.staging.example.com/api/v1
```

Exemplo de produção:

```text
https://api.example.com/api/v1
```

Os domínios finais serão definidos na infraestrutura.

---

# Cabeçalhos

## Cabeçalhos de requisição

### Authorization

```http
Authorization: Bearer <access_token>
```

### Content-Type

```http
Content-Type: application/json
```

### Accept

```http
Accept: application/json
```

### X-Correlation-ID

Permite rastrear a solicitação.

```http
X-Correlation-ID: cor_01JABC123
```

Se não for informado, o CompanyOS deverá gerar um.

### Idempotency-Key

Obrigatório em operações que não podem ser duplicadas.

```http
Idempotency-Key: 01JABC123XYZ
```

### If-Match

Usado para controle otimista de concorrência.

```http
If-Match: "8"
```

O valor representa a versão atual do recurso.

---

# Cabeçalhos de resposta

## X-Correlation-ID

```http
X-Correlation-ID: cor_01JABC123
```

## ETag

```http
ETag: "9"
```

## Location

Usado após criação.

```http
Location: /api/v1/projects/prj_01JABC123
```

## Retry-After

Usado quando o cliente deve aguardar.

```http
Retry-After: 30
```

---

# Autenticação

## Login

```http
POST /api/v1/auth/login
```

### Requisição

```json
{
  "email": "usuario@example.com",
  "password": "senha"
}
```

### Resposta

```json
{
  "data": {
    "access_token": "token",
    "refresh_token": "token",
    "token_type": "bearer",
    "expires_in": 900
  },
  "meta": {
    "correlation_id": "cor_01"
  }
}
```

## Renovação

```http
POST /api/v1/auth/refresh
```

### Requisição

```json
{
  "refresh_token": "token"
}
```

## Logout

```http
POST /api/v1/auth/logout
```

## Usuário atual

```http
GET /api/v1/auth/me
```

## Revogar sessão

```http
DELETE /api/v1/auth/sessions/{session_id}
```

---

# Autorização

Cada endpoint deverá declarar:

```text
permission
scope
risk_level
approval_required
```

Exemplo:

```yaml
permission: project.read
scope: PROJECT
risk_level: LOW
approval_required: false
```

Exemplo crítico:

```yaml
permission: deployment.production
scope: ENVIRONMENT
risk_level: CRITICAL
approval_required: true
```

---

# Estrutura padrão de resposta

## Recurso único

```json
{
  "data": {
    "id": "prj_01",
    "name": "Projeto Genesis",
    "status": "DISCOVERY",
    "version": 3,
    "created_at": "2026-08-02T20:00:00Z",
    "updated_at": "2026-08-02T20:30:00Z"
  },
  "meta": {
    "correlation_id": "cor_01"
  }
}
```

## Coleção

```json
{
  "data": [
    {
      "id": "prj_01",
      "name": "Projeto Genesis",
      "status": "DISCOVERY"
    }
  ],
  "meta": {
    "correlation_id": "cor_01",
    "pagination": {
      "page": 1,
      "page_size": 20,
      "total_items": 1,
      "total_pages": 1
    }
  }
}
```

## Operação assíncrona

```json
{
  "data": {
    "operation_id": "op_01",
    "status": "QUEUED",
    "resource_type": "reference",
    "resource_id": "ref_01"
  },
  "meta": {
    "correlation_id": "cor_01"
  }
}
```

---

# Códigos HTTP

## Sucesso

```text
200 OK
201 Created
202 Accepted
204 No Content
```

## Cliente

```text
400 Bad Request
401 Unauthorized
403 Forbidden
404 Not Found
409 Conflict
412 Precondition Failed
415 Unsupported Media Type
422 Unprocessable Entity
429 Too Many Requests
```

## Servidor

```text
500 Internal Server Error
502 Bad Gateway
503 Service Unavailable
504 Gateway Timeout
```

---

# Paginação

A paginação inicial será baseada em página.

Parâmetros:

```text
page
page_size
```

Exemplo:

```http
GET /api/v1/projects?page=1&page_size=20
```

Regras:

- `page` inicia em 1;
- `page_size` padrão será 20;
- `page_size` máximo inicial será 100;
- valores inválidos deverão retornar erro de validação.

Para eventos e auditoria, poderá ser usado cursor futuramente.

Exemplo futuro:

```text
cursor
limit
```

---

# Filtros

Filtros deverão utilizar parâmetros de consulta.

Exemplo:

```http
GET /api/v1/tasks?project_id=prj_01&status=RUNNING
```

Filtros múltiplos:

```http
GET /api/v1/tasks?status=RUNNING&status=BLOCKED
```

Filtros de data:

```http
GET /api/v1/audit?created_from=2026-08-01T00:00:00Z&created_to=2026-08-02T23:59:59Z
```

Filtros de busca:

```http
GET /api/v1/projects?q=genesis
```

---

# Ordenação

Parâmetro:

```text
sort
```

Exemplo crescente:

```http
GET /api/v1/projects?sort=name
```

Exemplo decrescente:

```http
GET /api/v1/projects?sort=-created_at
```

Mais de um campo:

```http
GET /api/v1/tasks?sort=priority,-created_at
```

Campos permitidos deverão ser declarados por endpoint.

---

# Seleção de campos

Poderá ser utilizada para respostas menores.

Exemplo:

```http
GET /api/v1/projects?fields=id,name,status
```

Campos sensíveis nunca deverão ser retornados por seleção arbitrária.

---

# Expansão de relacionamentos

Parâmetro:

```text
include
```

Exemplo:

```http
GET /api/v1/projects/prj_01?include=owner,members
```

A API deverá limitar expansões para evitar consultas excessivas.

---

# Idempotência

## Operações obrigatórias

`Idempotency-Key` deverá ser obrigatório para:

- criação de projeto;
- upload de referência;
- criação de release;
- solicitação de deployment;
- aprovação crítica;
- rollback;
- operações financeiras futuras;
- chamadas externas com efeito.

## Comportamento

Primeira requisição:

```text
processa
+
armazena resultado
```

Repetição com mesma chave e mesmo corpo:

```text
retorna o resultado anterior
```

Repetição com mesma chave e corpo diferente:

```http
409 Conflict
```

## Retenção

A retenção inicial das chaves será configurável.

---

# Concorrência otimista

Recursos alteráveis deverão possuir:

```text
version
```

O cliente deverá enviar:

```http
If-Match: "8"
```

Se a versão atual for diferente:

```http
412 Precondition Failed
```

Exemplo de erro:

```json
{
  "error": {
    "code": "RESOURCE_VERSION_MISMATCH",
    "message": "O recurso foi alterado por outra operação.",
    "details": {
      "expected_version": 8,
      "current_version": 9
    }
  }
}
```

---

# Campos comuns

## Entidades mutáveis

```text
id
created_at
created_by
updated_at
updated_by
version
```

## Entidades arquiváveis

```text
archived_at
archived_by
```

## Entidades com exclusão lógica

```text
is_deleted
deleted_at
deleted_by
```

---

# Projetos

## Criar projeto

```http
POST /api/v1/projects
```

Permissão:

```text
project.create
```

### Requisição

```json
{
  "name": "Projeto Genesis",
  "short_name": "Genesis",
  "description": "Projeto inicial de validação da SSC.",
  "problem_statement": "Processo atual depende de tarefas manuais.",
  "objective": "Automatizar e rastrear o processo.",
  "business_area": "Tecnologia",
  "solution_type": "WEB_SYSTEM",
  "confidentiality_level": "INTERNAL",
  "priority": "HIGH",
  "owner_id": "usr_01"
}
```

### Resposta

```http
201 Created
```

## Listar projetos

```http
GET /api/v1/projects
```

Permissão:

```text
project.read
```

Filtros:

```text
status
priority
owner_id
business_area
q
```

## Consultar projeto

```http
GET /api/v1/projects/{project_id}
```

## Atualizar projeto

```http
PATCH /api/v1/projects/{project_id}
```

Campos de estado não poderão ser alterados diretamente.

## Transição do projeto

```http
POST /api/v1/projects/{project_id}/transitions
```

### Requisição

```json
{
  "transition": "start_discovery",
  "reason": "Contexto inicial preenchido."
}
```

## Membros

```http
GET    /api/v1/projects/{project_id}/members
POST   /api/v1/projects/{project_id}/members
PATCH  /api/v1/projects/{project_id}/members/{member_id}
DELETE /api/v1/projects/{project_id}/members/{member_id}
```

## Agentes do projeto

```http
GET    /api/v1/projects/{project_id}/agents
POST   /api/v1/projects/{project_id}/agents
PATCH  /api/v1/projects/{project_id}/agents/{project_agent_id}
DELETE /api/v1/projects/{project_id}/agents/{project_agent_id}
```

---

# Discovery

## Criar sessão

```http
POST /api/v1/projects/{project_id}/discovery-sessions
```

## Consultar sessão atual

```http
GET /api/v1/projects/{project_id}/discovery-sessions/current
```

## Listar versões

```http
GET /api/v1/projects/{project_id}/discovery-sessions
```

## Transição

```http
POST /api/v1/discovery-sessions/{discovery_id}/transitions
```

## Perguntas

```http
GET  /api/v1/discovery-sessions/{discovery_id}/questions
POST /api/v1/discovery-sessions/{discovery_id}/questions
```

## Responder pergunta

```http
POST /api/v1/interview-questions/{question_id}/answers
```

### Requisição

```json
{
  "answer": "O gerente da área deverá aprovar.",
  "answer_type": "TEXT"
}
```

## Discovery Report

```http
GET  /api/v1/discovery-sessions/{discovery_id}/report
POST /api/v1/discovery-sessions/{discovery_id}/report/generate
```

A geração poderá retornar:

```http
202 Accepted
```

---

# Referências

## Upload

```http
POST /api/v1/projects/{project_id}/references
```

Tipo:

```text
multipart/form-data
```

Campos:

```text
file
name
description
purpose
category
importance
permission_of_use
```

## Adicionar link

```http
POST /api/v1/projects/{project_id}/references/links
```

### Requisição

```json
{
  "name": "Documentação da API",
  "external_url": "https://example.com/docs",
  "description": "Referência técnica",
  "category": "TECHNICAL",
  "importance": "HIGH"
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/references
```

## Consultar

```http
GET /api/v1/references/{reference_id}
```

## Iniciar processamento

```http
POST /api/v1/references/{reference_id}/process
```

## Tentar novamente

```http
POST /api/v1/references/{reference_id}/retry
```

## Arquivar

```http
POST /api/v1/references/{reference_id}/transitions
```

---

# Requisitos

## Criar

```http
POST /api/v1/projects/{project_id}/requirements
```

### Requisição

```json
{
  "title": "Autenticação de usuários",
  "description": "O sistema deverá permitir login seguro.",
  "requirement_type": "SECURITY",
  "priority": "HIGH",
  "source_type": "INTERVIEW_ANSWER",
  "source_id": "ans_01",
  "acceptance_criteria": [
    "Usuário válido consegue autenticar.",
    "Senha inválida é rejeitada.",
    "Tentativas excessivas são bloqueadas."
  ]
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/requirements
```

## Consultar

```http
GET /api/v1/requirements/{requirement_id}
```

## Atualizar

```http
PATCH /api/v1/requirements/{requirement_id}
```

## Transição

```http
POST /api/v1/requirements/{requirement_id}/transitions
```

## Relacionar referência

```http
POST /api/v1/requirements/{requirement_id}/references
```

---

# Decisões

## Criar ADR ou RFC

```http
POST /api/v1/projects/{project_id}/decisions
```

### Requisição

```json
{
  "decision_type": "ADR",
  "title": "Utilizar PostgreSQL",
  "context": "A plataforma precisa de persistência relacional.",
  "decision": "Utilizar PostgreSQL como banco principal.",
  "alternatives": [
    "MySQL",
    "SQLite"
  ],
  "positive_consequences": [
    "Boa integridade relacional",
    "Suporte a JSONB"
  ],
  "negative_consequences": [
    "Maior operação que SQLite"
  ]
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/decisions
```

## Transição

```http
POST /api/v1/decisions/{decision_id}/transitions
```

---

# Backlog

## Épicos

```http
GET  /api/v1/projects/{project_id}/epics
POST /api/v1/projects/{project_id}/epics
GET  /api/v1/epics/{epic_id}
PATCH /api/v1/epics/{epic_id}
```

## Histórias

```http
GET  /api/v1/projects/{project_id}/stories
POST /api/v1/projects/{project_id}/stories
GET  /api/v1/stories/{story_id}
PATCH /api/v1/stories/{story_id}
```

---

# Tarefas

## Criar

```http
POST /api/v1/projects/{project_id}/tasks
```

### Requisição

```json
{
  "title": "Criar endpoint de projetos",
  "description": "Implementar criação e consulta de projetos.",
  "task_type": "BACKEND",
  "priority": "HIGH",
  "user_story_id": "sto_01",
  "max_attempts": 3,
  "timeout_seconds": 1800
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/tasks
```

Filtros:

```text
status
task_type
priority
assigned_agent_id
assigned_user_id
workflow_id
```

## Consultar

```http
GET /api/v1/tasks/{task_id}
```

## Atualizar metadados

```http
PATCH /api/v1/tasks/{task_id}
```

## Transição

```http
POST /api/v1/tasks/{task_id}/transitions
```

### Exemplo

```json
{
  "transition": "enqueue",
  "reason": "Dependências concluídas."
}
```

## Dependências

```http
GET  /api/v1/tasks/{task_id}/dependencies
POST /api/v1/tasks/{task_id}/dependencies
DELETE /api/v1/tasks/{task_id}/dependencies/{dependency_id}
```

---

# Workflows

## Criar

```http
POST /api/v1/projects/{project_id}/workflows
```

## Listar

```http
GET /api/v1/projects/{project_id}/workflows
```

## Consultar

```http
GET /api/v1/workflows/{workflow_id}
```

## Transição

```http
POST /api/v1/workflows/{workflow_id}/transitions
```

## Etapas

```http
GET /api/v1/workflows/{workflow_id}/steps
```

---

# Agentes

## Listar definições

```http
GET /api/v1/agent-definitions
```

## Criar definição

```http
POST /api/v1/agent-definitions
```

## Listar instâncias

```http
GET /api/v1/agents
```

## Consultar agente

```http
GET /api/v1/agents/{agent_id}
```

## Atualizar agente

```http
PATCH /api/v1/agents/{agent_id}
```

## Transição

```http
POST /api/v1/agents/{agent_id}/transitions
```

## Execuções

```http
GET /api/v1/agents/{agent_id}/executions
GET /api/v1/agent-executions/{execution_id}
```

## Cancelar execução

```http
POST /api/v1/agent-executions/{execution_id}/cancel
```

---

# Aprovações

## Listar

```http
GET /api/v1/approvals
```

Filtros:

```text
project_id
approval_type
status
assigned_to_user_id
risk_level
```

## Consultar

```http
GET /api/v1/approvals/{approval_id}
```

## Aprovar

```http
POST /api/v1/approvals/{approval_id}/approve
```

### Requisição

```json
{
  "reason": "Evidências revisadas e aprovadas."
}
```

## Rejeitar

```http
POST /api/v1/approvals/{approval_id}/reject
```

## Cancelar

```http
POST /api/v1/approvals/{approval_id}/cancel
```

---

# Testes

## Criar execução

```http
POST /api/v1/projects/{project_id}/test-runs
```

## Consultar

```http
GET /api/v1/test-runs/{test_run_id}
```

## Listar

```http
GET /api/v1/projects/{project_id}/test-runs
```

## Cancelar

```http
POST /api/v1/test-runs/{test_run_id}/cancel
```

---

# Segurança

## Listar achados

```http
GET /api/v1/projects/{project_id}/security-findings
```

## Criar achado

```http
POST /api/v1/projects/{project_id}/security-findings
```

## Consultar

```http
GET /api/v1/security-findings/{finding_id}
```

## Transição

```http
POST /api/v1/security-findings/{finding_id}/transitions
```

## Aceitar risco

```http
POST /api/v1/security-findings/{finding_id}/accept-risk
```

Exige aprovação humana.

---

# Releases

## Criar

```http
POST /api/v1/projects/{project_id}/releases
```

### Requisição

```json
{
  "version": "0.1.0",
  "name": "Foundation API",
  "commit_sha": "abc123",
  "changelog": "Primeira versão da API.",
  "rollback_plan": "Restaurar a versão anterior."
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/releases
```

## Consultar

```http
GET /api/v1/releases/{release_id}
```

## Transição

```http
POST /api/v1/releases/{release_id}/transitions
```

## Artefatos

```http
GET /api/v1/releases/{release_id}/artifacts
```

---

# Deployments

## Solicitar

```http
POST /api/v1/projects/{project_id}/deployments
```

### Requisição

```json
{
  "release_id": "rel_01",
  "environment": "STAGING"
}
```

## Listar

```http
GET /api/v1/projects/{project_id}/deployments
```

## Consultar

```http
GET /api/v1/deployments/{deployment_id}
```

## Transição

```http
POST /api/v1/deployments/{deployment_id}/transitions
```

## Logs

```http
GET /api/v1/deployments/{deployment_id}/logs
```

## Rollback

```http
POST /api/v1/deployments/{deployment_id}/rollback
```

---

# Eventos

## Listar

```http
GET /api/v1/events
```

Filtros:

```text
project_id
event_type
source
correlation_id
status
created_from
created_to
```

## Consultar

```http
GET /api/v1/events/{event_id}
```

## Reprocessar

```http
POST /api/v1/events/{event_id}/retry
```

## Dead-letter queue

```http
GET  /api/v1/events/dead-letter
POST /api/v1/events/dead-letter/{event_id}/reprocess
```

---

# Auditoria

## Listar

```http
GET /api/v1/audit
```

Filtros:

```text
organization_id
project_id
actor_type
actor_id
action
resource_type
resource_id
result
risk_level
correlation_id
created_from
created_to
```

## Consultar

```http
GET /api/v1/audit/{audit_id}
```

## Exportar

```http
POST /api/v1/audit/exports
```

Exportações deverão ser assíncronas e auditadas.

---

# Knowledge Vault

## Criar item

```http
POST /api/v1/projects/{project_id}/knowledge-items
```

## Listar

```http
GET /api/v1/projects/{project_id}/knowledge-items
```

## Consultar

```http
GET /api/v1/knowledge-items/{knowledge_id}
```

## Criar nova versão

```http
POST /api/v1/knowledge-items/{knowledge_id}/versions
```

## Arquivar

```http
POST /api/v1/knowledge-items/{knowledge_id}/archive
```

---

# Incidentes

## Criar

```http
POST /api/v1/projects/{project_id}/incidents
```

## Listar

```http
GET /api/v1/projects/{project_id}/incidents
```

## Consultar

```http
GET /api/v1/incidents/{incident_id}
```

## Transição

```http
POST /api/v1/incidents/{incident_id}/transitions
```

---

# Operações

## Consultar operação assíncrona

```http
GET /api/v1/operations/{operation_id}
```

Resposta:

```json
{
  "data": {
    "id": "op_01",
    "status": "RUNNING",
    "progress": 45,
    "resource_type": "reference",
    "resource_id": "ref_01",
    "started_at": "2026-08-02T20:00:00Z"
  }
}
```

Estados:

```text
QUEUED
RUNNING
COMPLETED
FAILED
CANCELLED
```

---

# Saúde e versão

## Health check

```http
GET /health
```

Resposta:

```json
{
  "status": "healthy"
}
```

## Readiness

```http
GET /ready
```

## Métricas

```http
GET /metrics
```

O endpoint deverá ser protegido conforme o ambiente.

## Versão

```http
GET /version
```

Resposta:

```json
{
  "service": "companyos-api",
  "version": "0.1.0",
  "commit_sha": "abc123",
  "build_date": "2026-08-02T20:00:00Z"
}
```

---

# Atualizações em tempo real

## Server-Sent Events

Endpoint inicial recomendado:

```http
GET /api/v1/stream
```

Filtros:

```text
project_id
event_type
```

Exemplo de evento:

```text
event: TaskCompleted
id: evt_01
data: {"project_id":"prj_01","task_id":"tsk_01"}
```

## WebSocket

Alternativa futura:

```text
/ws/v1
```

Autenticação deverá ocorrer antes da assinatura.

O cliente somente poderá assinar projetos autorizados.

---

# Limitação de requisições

A API deverá aplicar rate limiting.

Exemplo de resposta:

```http
429 Too Many Requests
Retry-After: 30
```

As políticas poderão variar por:

- usuário;
- agente;
- IP;
- endpoint;
- risco;
- ambiente.

---

# Uploads

Regras:

- limite de tamanho;
- tipos permitidos;
- validação do MIME real;
- hash;
- verificação de duplicidade;
- quarentena;
- nome físico seguro;
- auditoria.

Upload grande poderá utilizar fluxo assíncrono ou URL pré-assinada futuramente.

---

# Exclusão

## Exclusão lógica

Operação padrão:

```http
DELETE /api/v1/resources/{resource_id}
```

Poderá retornar:

```http
204 No Content
```

A exclusão deverá registrar auditoria.

## Exclusão crítica

Projeto e dados sensíveis deverão usar operação explícita:

```http
POST /api/v1/projects/{project_id}/deletion-requests
```

Exige:

- permissão;
- aprovação;
- motivo;
- avaliação de dependências;
- política de retenção.

---

# Compatibilidade

Mudanças compatíveis:

- adicionar campo opcional;
- adicionar endpoint;
- adicionar valor de enum quando consumidores ignoram desconhecidos;
- adicionar filtro opcional.

Mudanças incompatíveis:

- remover campo;
- alterar tipo;
- renomear campo;
- alterar significado;
- tornar campo opcional obrigatório;
- remover valor aceito;
- alterar URL.

Mudanças incompatíveis exigem nova versão ou período de depreciação.

---

# Depreciação

Cabeçalhos recomendados:

```http
Deprecation: true
Sunset: Wed, 31 Dec 2027 23:59:59 GMT
Link: </api/v2/resource>; rel="successor-version"
```

A documentação deverá indicar:

- motivo;
- alternativa;
- data de encerramento;
- plano de migração.

---

# Segurança das respostas

A API nunca deverá retornar:

- senha;
- hash de senha;
- refresh token armazenado;
- chave privada;
- segredo;
- variável de ambiente sensível;
- stack trace;
- caminho interno desnecessário;
- query completa sensível.

Campos sensíveis deverão ser mascarados.

---

# Testes obrigatórios

Cada endpoint deverá possuir testes para:

- sucesso;
- autenticação ausente;
- permissão ausente;
- recurso inexistente;
- validação;
- conflito de versão;
- estado inválido;
- aprovação ausente;
- idempotência;
- paginação;
- filtros;
- ordenação;
- auditoria;
- correlação;
- evento emitido;
- isolamento entre projetos.

Exemplo:

```text
given user has project.create
when POST /api/v1/projects
then status = 201
and Location is returned
and ProjectCreated is recorded
and audit is recorded
```

---

# Critérios de aceite da Sprint

Este documento será considerado aprovado quando:

- convenções gerais estiverem definidas;
- autenticação estiver documentada;
- autorização estiver relacionada às permissões;
- respostas possuírem formato padronizado;
- paginação, filtros e ordenação estiverem definidos;
- idempotência estiver definida;
- concorrência otimista estiver definida;
- endpoints principais estiverem listados;
- transições de estado utilizarem operações explícitas;
- operações assíncronas estiverem previstas;
- eventos em tempo real estiverem previstos;
- segurança das respostas estiver definida;
- os contratos puderem ser transformados em OpenAPI;
- os cenários puderem ser transformados em testes automatizados.
