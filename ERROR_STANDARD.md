# Padrão de Erros da Stieve Software Company

## Objetivo

Definir o padrão oficial de erros da API do CompanyOS.

Este documento estabelece:

- estrutura das respostas de erro;
- códigos HTTP;
- códigos internos;
- mensagens;
- detalhes de validação;
- correlação;
- rastreabilidade;
- tratamento de falhas;
- segurança;
- idempotência;
- concorrência;
- erros de autorização;
- erros de domínio;
- erros de infraestrutura;
- critérios de teste.

O padrão será usado por:

- SSC Mission Control;
- CompanyOS API;
- serviços internos;
- agentes;
- integrações;
- workflows;
- eventos;
- logs;
- auditoria;
- documentação OpenAPI.

---

# Princípios

## Estrutura única

Todas as respostas de erro deverão seguir a mesma estrutura.

## Mensagens seguras

Erros públicos não deverão expor:

- stack trace;
- senha;
- token;
- segredo;
- chave privada;
- query completa;
- variável de ambiente;
- caminho interno sensível;
- detalhes desnecessários de infraestrutura.

## Códigos estáveis

O campo `code` deverá ser estável e utilizável por clientes.

A mensagem poderá evoluir, mas o código não deverá mudar sem motivo de compatibilidade.

## Correlação obrigatória

Todo erro deverá possuir um identificador de correlação.

```text
correlation_id
```

Esse identificador deverá aparecer em:

- resposta da API;
- logs;
- auditoria;
- eventos;
- traces futuros.

## Separação entre erro público e erro interno

A resposta pública deverá ser segura e compreensível.

Os logs internos poderão conter detalhes técnicos adicionais, respeitando proteção de dados e segredos.

---

# Estrutura padrão

```json
{
  "error": {
    "code": "RESOURCE_NOT_FOUND",
    "message": "O recurso solicitado não foi encontrado.",
    "details": {
      "resource_type": "project",
      "resource_id": "prj_01"
    },
    "correlation_id": "cor_01JABC123",
    "timestamp": "2026-08-02T20:50:00Z"
  }
}
```

## Campos

### `code`

Código interno estável.

Exemplo:

```text
RESOURCE_NOT_FOUND
```

### `message`

Mensagem segura e legível.

### `details`

Informações adicionais úteis ao cliente.

Deverá ser opcional.

### `correlation_id`

Identificador de rastreabilidade.

### `timestamp`

Data e hora em UTC no formato ISO 8601.

---

# Estrutura de validação

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Um ou mais campos são inválidos.",
    "details": {
      "fields": [
        {
          "field": "name",
          "code": "REQUIRED",
          "message": "O campo nome é obrigatório."
        },
        {
          "field": "priority",
          "code": "INVALID_ENUM",
          "message": "O valor informado não é permitido.",
          "allowed_values": [
            "LOW",
            "MEDIUM",
            "HIGH",
            "CRITICAL"
          ]
        }
      ]
    },
    "correlation_id": "cor_01",
    "timestamp": "2026-08-02T20:50:00Z"
  }
}
```

## Campos de validação

```text
field
code
message
allowed_values
received_value
constraint
```

`received_value` deverá ser omitido ou mascarado quando contiver informação sensível.

---

# Convenção dos códigos internos

Os códigos deverão:

- utilizar letras maiúsculas;
- utilizar `_` como separador;
- descrever a causa;
- evitar termos genéricos;
- permanecer estáveis.

Exemplos:

```text
AUTHENTICATION_REQUIRED
PERMISSION_DENIED
RESOURCE_NOT_FOUND
INVALID_STATE_TRANSITION
APPROVAL_REQUIRED
RESOURCE_VERSION_MISMATCH
RATE_LIMIT_EXCEEDED
```

---

# Códigos HTTP

## 400 Bad Request

Usado quando a requisição é estruturalmente inválida.

Exemplos:

- JSON inválido;
- parâmetro malformado;
- cabeçalho obrigatório ausente;
- chave de idempotência inválida.

Códigos internos:

```text
INVALID_REQUEST
INVALID_JSON
MISSING_REQUIRED_HEADER
INVALID_QUERY_PARAMETER
INVALID_IDEMPOTENCY_KEY
```

## 401 Unauthorized

Usado quando a autenticação é inexistente ou inválida.

Códigos internos:

```text
AUTHENTICATION_REQUIRED
INVALID_ACCESS_TOKEN
EXPIRED_ACCESS_TOKEN
INVALID_REFRESH_TOKEN
EXPIRED_REFRESH_TOKEN
SESSION_REVOKED
```

## 403 Forbidden

Usado quando o ator está autenticado, mas não possui autorização.

Códigos internos:

```text
PERMISSION_DENIED
SCOPE_ACCESS_DENIED
ENVIRONMENT_ACCESS_DENIED
EXPLICIT_DENY
AGENT_TOOL_NOT_ALLOWED
AGENT_PROJECT_ACCESS_DENIED
```

## 404 Not Found

Usado quando o recurso não existe ou não pode ser revelado ao ator.

Códigos internos:

```text
RESOURCE_NOT_FOUND
PROJECT_NOT_FOUND
TASK_NOT_FOUND
AGENT_NOT_FOUND
RELEASE_NOT_FOUND
DEPLOYMENT_NOT_FOUND
```

## 409 Conflict

Usado em conflitos de domínio.

Códigos internos:

```text
RESOURCE_ALREADY_EXISTS
INVALID_STATE_TRANSITION
APPROVAL_REQUIRED
IDEMPOTENCY_CONFLICT
DEPENDENCY_CONFLICT
ACTIVE_RESOURCE_CONFLICT
DUPLICATE_REFERENCE
```

## 412 Precondition Failed

Usado em controle de concorrência.

Códigos internos:

```text
RESOURCE_VERSION_MISMATCH
PRECONDITION_FAILED
```

## 413 Payload Too Large

Códigos internos:

```text
FILE_TOO_LARGE
REQUEST_TOO_LARGE
```

## 415 Unsupported Media Type

Códigos internos:

```text
UNSUPPORTED_MEDIA_TYPE
UNSUPPORTED_FILE_TYPE
```

## 422 Unprocessable Entity

Usado quando a estrutura é válida, mas os dados não atendem às regras.

Códigos internos:

```text
VALIDATION_ERROR
BUSINESS_RULE_VIOLATION
INVALID_ENUM_VALUE
INVALID_REFERENCE
MISSING_REQUIRED_RELATION
```

## 429 Too Many Requests

Códigos internos:

```text
RATE_LIMIT_EXCEEDED
AGENT_EXECUTION_LIMIT_EXCEEDED
QUOTA_EXCEEDED
```

## 500 Internal Server Error

Códigos internos:

```text
INTERNAL_ERROR
UNEXPECTED_ERROR
```

A mensagem pública deverá ser genérica.

## 502 Bad Gateway

Códigos internos:

```text
UPSTREAM_SERVICE_ERROR
AI_PROVIDER_ERROR
EXTERNAL_API_ERROR
```

## 503 Service Unavailable

Códigos internos:

```text
SERVICE_UNAVAILABLE
DATABASE_UNAVAILABLE
EVENT_BUS_UNAVAILABLE
AI_PROVIDER_UNAVAILABLE
STORAGE_UNAVAILABLE
```

## 504 Gateway Timeout

Códigos internos:

```text
UPSTREAM_TIMEOUT
AI_PROVIDER_TIMEOUT
WORKFLOW_TIMEOUT
```

---

# Catálogo inicial de erros

## Autenticação

### `AUTHENTICATION_REQUIRED`

HTTP:

```text
401
```

Mensagem:

```text
É necessário autenticar para acessar este recurso.
```

### `INVALID_ACCESS_TOKEN`

HTTP:

```text
401
```

### `EXPIRED_ACCESS_TOKEN`

HTTP:

```text
401
```

### `SESSION_REVOKED`

HTTP:

```text
401
```

---

# Autorização

### `PERMISSION_DENIED`

HTTP:

```text
403
```

Detalhes recomendados:

```json
{
  "permission": "release.approve",
  "scope": "PROJECT",
  "resource_id": "rel_01"
}
```

### `SCOPE_ACCESS_DENIED`

HTTP:

```text
403
```

### `ENVIRONMENT_ACCESS_DENIED`

HTTP:

```text
403
```

### `EXPLICIT_DENY`

HTTP:

```text
403
```

### `AGENT_TOOL_NOT_ALLOWED`

HTTP:

```text
403
```

### `AGENT_PROJECT_ACCESS_DENIED`

HTTP:

```text
403
```

---

# Recursos

### `RESOURCE_NOT_FOUND`

HTTP:

```text
404
```

### `RESOURCE_ALREADY_EXISTS`

HTTP:

```text
409
```

### `RESOURCE_ARCHIVED`

HTTP:

```text
409
```

### `RESOURCE_CANCELLED`

HTTP:

```text
409
```

### `RESOURCE_LOCKED`

HTTP:

```text
409
```

### `RESOURCE_VERSION_MISMATCH`

HTTP:

```text
412
```

Detalhes:

```json
{
  "expected_version": 8,
  "current_version": 9
}
```

---

# Estados

### `INVALID_STATE_TRANSITION`

HTTP:

```text
409
```

Exemplo:

```json
{
  "error": {
    "code": "INVALID_STATE_TRANSITION",
    "message": "A transição solicitada não é permitida para o estado atual.",
    "details": {
      "resource_type": "project",
      "resource_id": "prj_01",
      "current_state": "IDEA",
      "requested_transition": "deploy_production",
      "allowed_transitions": [
        "start_discovery",
        "cancel"
      ]
    },
    "correlation_id": "cor_01",
    "timestamp": "2026-08-02T20:50:00Z"
  }
}
```

### `TERMINAL_STATE_REACHED`

HTTP:

```text
409
```

### `STATE_GUARD_FAILED`

HTTP:

```text
409
```

Detalhes:

```json
{
  "failed_guards": [
    "tests_passed",
    "security_review_approved"
  ]
}
```

---

# Aprovações

### `APPROVAL_REQUIRED`

HTTP:

```text
409
```

### `APPROVAL_NOT_FOUND`

HTTP:

```text
404
```

### `APPROVAL_EXPIRED`

HTTP:

```text
409
```

### `APPROVAL_ALREADY_DECIDED`

HTTP:

```text
409
```

### `APPROVAL_RESOURCE_CHANGED`

HTTP:

```text
409
```

### `APPROVER_CONFLICT`

HTTP:

```text
409
```

Usado quando segregação de funções impede a decisão.

---

# Idempotência

### `IDEMPOTENCY_KEY_REQUIRED`

HTTP:

```text
400
```

### `INVALID_IDEMPOTENCY_KEY`

HTTP:

```text
400
```

### `IDEMPOTENCY_CONFLICT`

HTTP:

```text
409
```

Exemplo:

```json
{
  "error": {
    "code": "IDEMPOTENCY_CONFLICT",
    "message": "A chave de idempotência já foi utilizada com outro conteúdo.",
    "details": {
      "idempotency_key": "01JABC123"
    },
    "correlation_id": "cor_01",
    "timestamp": "2026-08-02T20:50:00Z"
  }
}
```

### `IDEMPOTENCY_RESULT_UNAVAILABLE`

HTTP:

```text
503
```

---

# Validação

### `VALIDATION_ERROR`

HTTP:

```text
422
```

### Códigos por campo

```text
REQUIRED
INVALID_FORMAT
INVALID_ENUM
TOO_SHORT
TOO_LONG
OUT_OF_RANGE
INVALID_DATE
INVALID_URL
INVALID_EMAIL
INVALID_IDENTIFIER
DUPLICATE_VALUE
```

---

# Projetos

```text
PROJECT_NOT_FOUND
PROJECT_CODE_ALREADY_EXISTS
PROJECT_SLUG_ALREADY_EXISTS
PROJECT_NOT_APPROVED
PROJECT_ARCHIVED
PROJECT_CANCELLED
PROJECT_HAS_ACTIVE_WORKFLOWS
PROJECT_HAS_ACTIVE_DEPLOYMENTS
PROJECT_CANNOT_BE_ARCHIVED
```

---

# Discovery

```text
DISCOVERY_NOT_FOUND
DISCOVERY_ALREADY_ACTIVE
DISCOVERY_NOT_READY
DISCOVERY_REPORT_NOT_GENERATED
DISCOVERY_HAS_OPEN_QUESTIONS
DISCOVERY_VERSION_MISMATCH
DISCOVERY_ALREADY_APPROVED
```

---

# Referências

```text
REFERENCE_NOT_FOUND
REFERENCE_ALREADY_EXISTS
DUPLICATE_REFERENCE
REFERENCE_QUARANTINED
REFERENCE_PROCESSING_FAILED
REFERENCE_NOT_PROCESSABLE
REFERENCE_RETRY_LIMIT_REACHED
FILE_TOO_LARGE
UNSUPPORTED_FILE_TYPE
FILE_HASH_MISMATCH
FILE_STORAGE_ERROR
```

---

# Requisitos

```text
REQUIREMENT_NOT_FOUND
REQUIREMENT_CODE_ALREADY_EXISTS
REQUIREMENT_SOURCE_REQUIRED
REQUIREMENT_ACCEPTANCE_CRITERIA_REQUIRED
REQUIREMENT_NOT_APPROVED
REQUIREMENT_ALREADY_IMPLEMENTED
REQUIREMENT_NOT_VERIFIED
```

---

# Tarefas

```text
TASK_NOT_FOUND
TASK_DEPENDENCY_NOT_COMPLETED
TASK_ALREADY_ASSIGNED
TASK_AGENT_REQUIRED
TASK_RESULT_REQUIRED
TASK_BLOCKED
TASK_RETRY_LIMIT_REACHED
TASK_TIMEOUT
TASK_ALREADY_COMPLETED
TASK_PROJECT_ARCHIVED
```

---

# Workflows

```text
WORKFLOW_NOT_FOUND
WORKFLOW_ALREADY_RUNNING
WORKFLOW_NOT_PAUSED
WORKFLOW_STEP_NOT_READY
WORKFLOW_DEPENDENCY_FAILED
WORKFLOW_COMPENSATION_FAILED
WORKFLOW_TIMEOUT
WORKFLOW_RETRY_NOT_SAFE
```

---

# Agentes

```text
AGENT_NOT_FOUND
AGENT_OFFLINE
AGENT_NOT_IDLE
AGENT_ALREADY_RESERVED
AGENT_NOT_ASSIGNED_TO_PROJECT
AGENT_TOOL_NOT_ALLOWED
AGENT_EXECUTION_NOT_FOUND
AGENT_EXECUTION_TIMEOUT
AGENT_RESOURCE_LIMIT_EXCEEDED
AGENT_HEARTBEAT_EXPIRED
```

---

# Testes

```text
TEST_RUN_NOT_FOUND
TEST_RUN_ALREADY_STARTED
TEST_REPORT_REQUIRED
TESTS_FAILED
QUALITY_GATE_REJECTED
COVERAGE_BELOW_THRESHOLD
```

---

# Segurança

```text
SECURITY_FINDING_NOT_FOUND
CRITICAL_VULNERABILITY_OPEN
SECURITY_REVIEW_REQUIRED
SECURITY_REVIEW_REJECTED
RISK_ACCEPTANCE_REQUIRED
RISK_ACCEPTANCE_EXPIRED
SECRET_DETECTED
DEPENDENCY_VULNERABILITY_DETECTED
```

---

# Releases

```text
RELEASE_NOT_FOUND
RELEASE_VERSION_ALREADY_EXISTS
RELEASE_NOT_READY
RELEASE_VALIDATION_FAILED
RELEASE_APPROVAL_REQUIRED
RELEASE_ALREADY_PUBLISHED
RELEASE_IMMUTABLE
RELEASE_ARTIFACT_NOT_FOUND
```

---

# Deployments

```text
DEPLOYMENT_NOT_FOUND
DEPLOYMENT_APPROVAL_REQUIRED
DEPLOYMENT_RELEASE_NOT_APPROVED
DEPLOYMENT_ALREADY_RUNNING
DEPLOYMENT_FAILED
DEPLOYMENT_HEALTH_CHECK_FAILED
DEPLOYMENT_ROLLBACK_REQUIRED
ROLLBACK_VERSION_NOT_FOUND
ROLLBACK_FAILED
PRODUCTION_ACCESS_DENIED
```

---

# Eventos

```text
EVENT_NOT_FOUND
EVENT_INVALID_SCHEMA
EVENT_VERSION_UNSUPPORTED
EVENT_ALREADY_PROCESSED
EVENT_PROCESSING_FAILED
EVENT_RETRY_LIMIT_REACHED
EVENT_DEAD_LETTERED
```

---

# Auditoria

```text
AUDIT_RECORD_NOT_FOUND
AUDIT_EXPORT_FAILED
AUDIT_ACCESS_DENIED
AUDIT_RETENTION_POLICY_VIOLATION
```

---

# Infraestrutura

```text
DATABASE_UNAVAILABLE
EVENT_BUS_UNAVAILABLE
CACHE_UNAVAILABLE
OBJECT_STORAGE_UNAVAILABLE
AI_PROVIDER_UNAVAILABLE
SERVICE_UNAVAILABLE
RESOURCE_LIMIT_REACHED
STORAGE_LOW
BACKUP_FAILED
RESTORE_FAILED
```

---

# Mensagens públicas

As mensagens deverão:

- ser objetivas;
- evitar termos técnicos desnecessários;
- não culpar o usuário;
- não revelar detalhes internos;
- orientar quando houver ação possível.

Exemplo bom:

```text
A transição solicitada não é permitida para o estado atual.
```

Exemplo ruim:

```text
SQLAlchemyError na linha 427 porque status enum não bateu.
```

---

# Erros internos

Logs internos poderão registrar:

```text
exception_type
exception_message
stack_trace
service
module
function
host
container
correlation_id
request_id
actor_id
resource_id
```

Regras:

- segredos deverão ser mascarados;
- dados pessoais deverão ser minimizados;
- stack trace nunca deverá ser devolvido ao cliente;
- produção deverá usar logs estruturados.

---

# Logs estruturados

Exemplo:

```json
{
  "level": "ERROR",
  "service": "companyos-api",
  "event": "request_failed",
  "error_code": "RESOURCE_VERSION_MISMATCH",
  "correlation_id": "cor_01",
  "request_id": "req_01",
  "actor_id": "usr_01",
  "resource_type": "project",
  "resource_id": "prj_01",
  "http_status": 412,
  "timestamp": "2026-08-02T20:50:00Z"
}
```

---

# Auditoria de erros

Erros de segurança ou autorização deverão gerar auditoria.

Exemplos:

- tentativa de acessar outro projeto;
- tentativa de produção sem aprovação;
- agente usando ferramenta não permitida;
- alteração crítica sem permissão;
- tentativa de apagar auditoria;
- tentativa de aceitar risco sem autorização.

Nem todo erro de validação precisa gerar auditoria detalhada.

---

# Eventos de falha

Falhas relevantes poderão emitir eventos.

Exemplos:

```text
TaskFailed
WorkflowFailed
AgentExecutionFailed
ReferenceProcessingFailed
ReleaseValidationFailed
DeploymentFailed
HealthCheckFailed
RollbackFailed
ServiceUnhealthy
```

Os eventos deverão conter somente dados necessários e não sensíveis.

---

# Retry

## Erros temporários

Podem permitir retry:

```text
DATABASE_UNAVAILABLE
EVENT_BUS_UNAVAILABLE
AI_PROVIDER_UNAVAILABLE
UPSTREAM_TIMEOUT
SERVICE_UNAVAILABLE
```

## Erros permanentes

Normalmente não devem ser repetidos automaticamente:

```text
VALIDATION_ERROR
PERMISSION_DENIED
INVALID_STATE_TRANSITION
RESOURCE_NOT_FOUND
CRITICAL_VULNERABILITY_OPEN
```

## Backoff

Estratégia recomendada:

```text
exponential backoff
+
jitter
```

Exemplo:

```text
1s
2s
4s
8s
```

Limites deverão ser configuráveis.

---

# Dead-letter queue

Eventos ou tarefas que excederem tentativas deverão ser enviados para análise.

Dados mínimos:

```text
resource_id
event_id
error_code
attempt_count
last_error
correlation_id
failed_at
```

Reprocessamento deverá exigir:

- permissão;
- motivo;
- auditoria;
- validação de idempotência.

---

# Rate limiting

Resposta:

```http
429 Too Many Requests
Retry-After: 30
```

Exemplo:

```json
{
  "error": {
    "code": "RATE_LIMIT_EXCEEDED",
    "message": "O limite de requisições foi atingido. Tente novamente mais tarde.",
    "details": {
      "retry_after_seconds": 30
    },
    "correlation_id": "cor_01",
    "timestamp": "2026-08-02T20:50:00Z"
  }
}
```

---

# Erros em operações assíncronas

A solicitação inicial poderá retornar:

```http
202 Accepted
```

A falha posterior deverá aparecer no recurso de operação.

Exemplo:

```json
{
  "data": {
    "id": "op_01",
    "status": "FAILED",
    "error": {
      "code": "REFERENCE_PROCESSING_FAILED",
      "message": "Não foi possível processar a referência."
    }
  }
}
```

---

# Erros em eventos em tempo real

Para SSE:

```text
event: error
data: {"code":"STREAM_ACCESS_DENIED","message":"A assinatura não é permitida."}
```

Para WebSocket, a conexão deverá utilizar códigos de fechamento apropriados e mensagem segura.

---

# Internacionalização

Na primeira versão:

- `code` será estável e independente de idioma;
- `message` será retornada em português;
- futuramente poderá respeitar `Accept-Language`.

Exemplo:

```http
Accept-Language: pt-BR
```

Clientes não deverão depender do texto da mensagem para lógica.

---

# OpenAPI

Cada endpoint deverá documentar:

- código HTTP;
- código interno;
- schema;
- exemplo;
- condição;
- possível recuperação.

Exemplo conceitual:

```yaml
responses:
  "404":
    description: Projeto não encontrado
    content:
      application/json:
        schema:
          $ref: "#/components/schemas/ErrorResponse"
        examples:
          project_not_found:
            value:
              error:
                code: PROJECT_NOT_FOUND
                message: O projeto solicitado não foi encontrado.
```

---

# Testes obrigatórios

## Estrutura

- resposta contém `error`;
- resposta contém `code`;
- resposta contém `message`;
- resposta contém `correlation_id`;
- resposta contém `timestamp`.

## Segurança

- não retorna stack trace;
- não retorna segredo;
- não retorna token;
- não retorna senha;
- não retorna caminho sensível.

## Validação

- campos inválidos são listados;
- códigos por campo são estáveis;
- valores permitidos são informados quando apropriado.

## Domínio

- transição inválida retorna `409`;
- versão incompatível retorna `412`;
- aprovação ausente retorna `409`;
- permissão ausente retorna `403`;
- autenticação ausente retorna `401`.

## Infraestrutura

- falha temporária retorna código adequado;
- retry é indicado quando aplicável;
- `Retry-After` é enviado em rate limiting.

## Correlação

- mesmo `correlation_id` aparece na resposta e no log;
- erros críticos geram auditoria;
- eventos de falha mantêm a correlação.

---

# Critérios de aceite da Sprint

Este documento será considerado aprovado quando:

- a estrutura única de erro estiver definida;
- os códigos HTTP estiverem relacionados aos erros;
- os códigos internos estiverem padronizados;
- erros de validação estiverem estruturados;
- erros de autenticação e autorização estiverem definidos;
- erros de domínio estiverem catalogados;
- erros de infraestrutura estiverem catalogados;
- correlação estiver incorporada;
- respostas não expuserem detalhes sensíveis;
- retry e DLQ estiverem previstos;
- operações assíncronas tiverem tratamento de erro;
- o padrão puder ser transformado em schemas OpenAPI;
- os cenários puderem ser transformados em testes automatizados.
