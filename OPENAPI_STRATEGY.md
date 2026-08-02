# Estratégia OpenAPI da Stieve Software Company

## Objetivo

Definir a estratégia oficial para criação, manutenção, validação e publicação da especificação OpenAPI do CompanyOS.

Este documento estabelece:

- versão do OpenAPI;
- organização dos arquivos;
- convenções de schemas;
- documentação dos endpoints;
- autenticação e autorização;
- erros;
- paginação;
- filtros;
- idempotência;
- concorrência;
- operações assíncronas;
- eventos em tempo real;
- geração de clientes;
- geração de documentação;
- validação automática;
- testes de contrato;
- versionamento;
- critérios de aceite.

A especificação OpenAPI será a fonte oficial dos contratos HTTP da plataforma.

---

# Princípios

## Contract-first

A API deverá ser especificada antes ou junto da implementação.

Fluxo esperado:

```text
requisito aprovado
  ↓
contrato OpenAPI
  ↓
revisão técnica
  ↓
implementação
  ↓
testes de contrato
  ↓
publicação
```

## Fonte única de verdade

A especificação OpenAPI deverá ser a referência oficial para:

- endpoints;
- métodos HTTP;
- parâmetros;
- schemas;
- respostas;
- erros;
- autenticação;
- exemplos;
- versionamento;
- geração de clientes.

A documentação manual não deverá contradizer a especificação.

## Compatibilidade

Mudanças deverão ser classificadas como:

```text
COMPATIBLE
DEPRECATED
BREAKING
```

Mudanças incompatíveis exigirão:

- nova versão da API;
- período de migração;
- documentação;
- aprovação técnica;
- registro em ADR ou RFC quando aplicável.

## Automação

A especificação deverá ser validada automaticamente no pipeline.

Nenhuma alteração deverá ser aceita quando:

- o YAML estiver inválido;
- referências estiverem quebradas;
- schemas estiverem inconsistentes;
- operações não possuírem identificador;
- erros obrigatórios não estiverem documentados;
- regras de segurança não estiverem declaradas.

---

# Versão do OpenAPI

A versão inicial recomendada será:

```yaml
openapi: 3.1.0
```

Motivos:

- melhor compatibilidade com JSON Schema;
- suporte moderno;
- validação mais expressiva;
- evolução futura mais simples.

Caso uma ferramenta crítica não suporte OpenAPI 3.1, poderá ser usada temporariamente:

```yaml
openapi: 3.0.3
```

Essa exceção deverá ser documentada.

---

# Estrutura dos arquivos

Estrutura recomendada:

```text
openapi/
├── openapi.yaml
├── paths/
│   ├── auth.yaml
│   ├── projects.yaml
│   ├── discovery.yaml
│   ├── references.yaml
│   ├── requirements.yaml
│   ├── decisions.yaml
│   ├── backlog.yaml
│   ├── tasks.yaml
│   ├── workflows.yaml
│   ├── agents.yaml
│   ├── approvals.yaml
│   ├── tests.yaml
│   ├── security.yaml
│   ├── releases.yaml
│   ├── deployments.yaml
│   ├── events.yaml
│   ├── audit.yaml
│   ├── knowledge.yaml
│   ├── incidents.yaml
│   └── operations.yaml
├── components/
│   ├── schemas/
│   │   ├── common.yaml
│   │   ├── errors.yaml
│   │   ├── auth.yaml
│   │   ├── projects.yaml
│   │   ├── discovery.yaml
│   │   ├── references.yaml
│   │   ├── requirements.yaml
│   │   ├── tasks.yaml
│   │   ├── workflows.yaml
│   │   ├── agents.yaml
│   │   ├── approvals.yaml
│   │   ├── releases.yaml
│   │   └── deployments.yaml
│   ├── parameters/
│   │   ├── pagination.yaml
│   │   ├── filtering.yaml
│   │   ├── sorting.yaml
│   │   └── headers.yaml
│   ├── responses/
│   │   ├── errors.yaml
│   │   ├── pagination.yaml
│   │   └── async.yaml
│   ├── securitySchemes/
│   │   └── bearer.yaml
│   ├── headers/
│   │   └── common.yaml
│   └── examples/
│       ├── projects.yaml
│       ├── tasks.yaml
│       ├── releases.yaml
│       └── errors.yaml
└── generated/
    ├── openapi.bundle.yaml
    └── openapi.bundle.json
```

---

# Arquivo principal

Exemplo inicial:

```yaml
openapi: 3.1.0

info:
  title: CompanyOS API
  version: 0.1.0
  description: API oficial da Stieve Software Company.

servers:
  - url: http://localhost:8000/api/v1
    description: Ambiente local

tags:
  - name: Auth
  - name: Projects
  - name: Discovery
  - name: References
  - name: Requirements
  - name: Tasks
  - name: Workflows
  - name: Agents
  - name: Approvals
  - name: Releases
  - name: Deployments
  - name: Audit

security:
  - bearerAuth: []

paths:
  /projects:
    $ref: ./paths/projects.yaml#/~1projects

components:
  securitySchemes:
    bearerAuth:
      $ref: ./components/securitySchemes/bearer.yaml
```

---

# Bundling

Durante o desenvolvimento, a especificação poderá ser dividida em vários arquivos.

Para publicação, deverá ser gerado um arquivo único:

```text
openapi/generated/openapi.bundle.yaml
```

Esse arquivo será usado por:

- Swagger UI;
- Redoc;
- geração de clientes;
- validação de contrato;
- publicação externa;
- testes automatizados.

---

# Convenções de nomes

## operationId

Toda operação deverá possuir `operationId` único.

Formato recomendado:

```text
<verbo><Recurso>
```

Exemplos:

```text
createProject
listProjects
getProject
updateProject
transitionProject
createTask
approveRelease
requestDeployment
rollbackDeployment
```

## Schemas

Schemas deverão usar PascalCase.

Exemplos:

```text
Project
ProjectCreateRequest
ProjectUpdateRequest
ProjectResponse
ProjectListResponse
ErrorResponse
ValidationErrorResponse
```

## Propriedades

Propriedades JSON deverão usar `snake_case`.

Exemplos:

```text
project_id
created_at
correlation_id
approval_required
```

## Tags

Tags deverão usar nomes de domínio em inglês.

Exemplos:

```text
Projects
Tasks
Releases
Deployments
```

---

# Schemas comuns

## Identificador

```yaml
ResourceId:
  type: string
  minLength: 5
  maxLength: 64
  examples:
    - prj_01JABC123
```

## Data e hora

```yaml
DateTime:
  type: string
  format: date-time
  examples:
    - 2026-08-02T20:50:00Z
```

## Versão do recurso

```yaml
ResourceVersion:
  type: integer
  minimum: 1
  examples:
    - 8
```

## Correlation ID

```yaml
CorrelationId:
  type: string
  minLength: 8
  maxLength: 128
  examples:
    - cor_01JABC123
```

---

# Envelope de resposta

## Recurso único

```yaml
ProjectResponse:
  type: object
  required:
    - data
    - meta
  properties:
    data:
      $ref: ./projects.yaml#/Project
    meta:
      $ref: ./common.yaml#/ResponseMeta
```

## Meta

```yaml
ResponseMeta:
  type: object
  required:
    - correlation_id
  properties:
    correlation_id:
      $ref: ./common.yaml#/CorrelationId
```

## Coleção

```yaml
ProjectListResponse:
  type: object
  required:
    - data
    - meta
  properties:
    data:
      type: array
      items:
        $ref: ./projects.yaml#/Project
    meta:
      $ref: ./common.yaml#/PaginatedMeta
```

---

# Paginação

## Parâmetros

```yaml
Page:
  name: page
  in: query
  required: false
  schema:
    type: integer
    minimum: 1
    default: 1

PageSize:
  name: page_size
  in: query
  required: false
  schema:
    type: integer
    minimum: 1
    maximum: 100
    default: 20
```

## Resposta

```yaml
PaginationMeta:
  type: object
  required:
    - page
    - page_size
    - total_items
    - total_pages
  properties:
    page:
      type: integer
    page_size:
      type: integer
    total_items:
      type: integer
    total_pages:
      type: integer
```

---

# Filtros

Cada endpoint deverá declarar explicitamente seus filtros.

Exemplo:

```yaml
parameters:
  - name: status
    in: query
    schema:
      type: array
      items:
        $ref: ../components/schemas/projects.yaml#/ProjectStatus
    style: form
    explode: true
```

Filtros não documentados não deverão ser aceitos silenciosamente.

---

# Ordenação

Parâmetro padrão:

```yaml
Sort:
  name: sort
  in: query
  required: false
  schema:
    type: string
    examples:
      - name
      - -created_at
      - priority,-created_at
```

Campos permitidos deverão ser descritos no endpoint.

---

# Campos e relacionamentos

## Fields

```yaml
Fields:
  name: fields
  in: query
  required: false
  schema:
    type: string
```

## Include

```yaml
Include:
  name: include
  in: query
  required: false
  schema:
    type: string
```

As opções permitidas deverão ser documentadas.

---

# Autenticação

## Bearer token

```yaml
bearerAuth:
  type: http
  scheme: bearer
  bearerFormat: JWT
```

## Endpoint público

Endpoints públicos deverão declarar:

```yaml
security: []
```

Exemplos:

- `/health`;
- `/ready`;
- login;
- documentação pública autorizada.

---

# Autorização

A especificação deverá documentar permissões por extensão customizada.

Exemplo:

```yaml
x-permissions:
  - project.create

x-scope: ORGANIZATION
x-risk-level: MEDIUM
x-approval-required: false
```

Exemplo crítico:

```yaml
x-permissions:
  - deployment.production

x-scope: ENVIRONMENT
x-risk-level: CRITICAL
x-approval-required: true
```

Essas extensões poderão ser usadas para:

- documentação;
- testes;
- geração de políticas;
- validação de implementação;
- interface do Mission Control.

---

# Cabeçalhos comuns

## X-Correlation-ID

```yaml
X-Correlation-ID:
  name: X-Correlation-ID
  in: header
  required: false
  schema:
    type: string
```

## Idempotency-Key

```yaml
Idempotency-Key:
  name: Idempotency-Key
  in: header
  required: true
  schema:
    type: string
    minLength: 8
    maxLength: 128
```

## If-Match

```yaml
If-Match:
  name: If-Match
  in: header
  required: true
  schema:
    type: string
  examples:
    currentVersion:
      value: '"8"'
```

---

# Idempotência

Operações idempotentes por chave deverão declarar:

```yaml
x-idempotency-required: true
```

Exemplo:

```yaml
post:
  operationId: createProject
  x-idempotency-required: true
  parameters:
    - $ref: ../components/parameters/headers.yaml#/Idempotency-Key
```

Respostas possíveis:

```text
201 Created
200 OK
409 Conflict
```

---

# Concorrência otimista

Operações mutáveis deverão declarar:

```yaml
x-optimistic-concurrency: true
```

E exigir:

```text
If-Match
```

Respostas possíveis:

```text
200 OK
412 Precondition Failed
```

---

# Transições de estado

Operações de transição deverão usar schema comum.

## Requisição

```yaml
TransitionRequest:
  type: object
  required:
    - transition
  properties:
    transition:
      type: string
    reason:
      type:
        - string
        - "null"
      maxLength: 2000
```

## Resposta

```yaml
TransitionResponseData:
  type: object
  required:
    - resource_type
    - resource_id
    - previous_state
    - current_state
    - transition
    - changed
    - version
  properties:
    resource_type:
      type: string
    resource_id:
      type: string
    previous_state:
      type: string
    current_state:
      type: string
    transition:
      type: string
    changed:
      type: boolean
    version:
      type: integer
```

---

# Erros

Todos os endpoints deverão referenciar schemas padronizados.

## ErrorResponse

```yaml
ErrorResponse:
  type: object
  required:
    - error
  properties:
    error:
      $ref: ./errors.yaml#/Error
```

## Error

```yaml
Error:
  type: object
  required:
    - code
    - message
    - correlation_id
    - timestamp
  properties:
    code:
      type: string
    message:
      type: string
    details:
      type:
        - object
        - "null"
      additionalProperties: true
    correlation_id:
      type: string
    timestamp:
      type: string
      format: date-time
```

## Respostas reutilizáveis

```yaml
Unauthorized:
  description: Autenticação necessária ou inválida

Forbidden:
  description: Permissão insuficiente

NotFound:
  description: Recurso não encontrado

Conflict:
  description: Conflito de domínio

ValidationError:
  description: Dados inválidos

PreconditionFailed:
  description: Versão do recurso incompatível

RateLimited:
  description: Limite de requisições excedido

InternalError:
  description: Erro interno seguro
```

---

# Exemplos

Todo endpoint principal deverá possuir exemplos de:

- requisição válida;
- resposta válida;
- erro de validação;
- erro de autorização;
- erro de domínio.

Exemplo:

```yaml
examples:
  invalidTransition:
    value:
      error:
        code: INVALID_STATE_TRANSITION
        message: A transição solicitada não é permitida para o estado atual.
        details:
          current_state: IDEA
          requested_transition: deploy_production
        correlation_id: cor_01
        timestamp: 2026-08-02T20:50:00Z
```

---

# Enums

Enums deverão ser reutilizados.

Exemplo:

```yaml
ProjectStatus:
  type: string
  enum:
    - IDEA
    - DISCOVERY
    - WAITING_APPROVAL
    - PLANNING
    - DEVELOPMENT
    - TESTING
    - STAGING
    - PRODUCTION
    - EVOLUTION
    - PAUSED
    - ARCHIVED
    - CANCELLED
```

Regras:

- não duplicar enums em vários arquivos;
- documentar novos valores;
- avaliar compatibilidade;
- clientes deverão tratar valores desconhecidos de forma segura.

---

# Campos obrigatórios

Schemas deverão usar `required` explicitamente.

Exemplo:

```yaml
ProjectCreateRequest:
  type: object
  required:
    - name
    - problem_statement
    - objective
    - solution_type
    - owner_id
```

Campos não obrigatórios deverão ter comportamento padrão documentado.

---

# Nullabilidade

No OpenAPI 3.1:

```yaml
type:
  - string
  - "null"
```

Campos opcionais não deverão ser automaticamente considerados nulos.

Diferença:

```text
campo ausente
≠
campo nulo
```

---

# Formatos

Formatos recomendados:

```text
date-time
date
email
uri
uuid
binary
```

Identificadores internos com prefixo poderão usar `pattern`.

Exemplo:

```yaml
ProjectId:
  type: string
  pattern: '^prj_[0-9A-HJKMNP-TV-Z]{10,26}$'
```

---

# Uploads

Exemplo:

```yaml
requestBody:
  required: true
  content:
    multipart/form-data:
      schema:
        type: object
        required:
          - file
          - name
        properties:
          file:
            type: string
            format: binary
          name:
            type: string
          category:
            $ref: ../components/schemas/references.yaml#/ReferenceCategory
```

Limites deverão ser descritos.

---

# Operações assíncronas

Operações que retornam `202 Accepted` deverão usar schema comum.

```yaml
AsyncOperationResponse:
  type: object
  required:
    - data
    - meta
  properties:
    data:
      $ref: ./common.yaml#/AsyncOperation
    meta:
      $ref: ./common.yaml#/ResponseMeta
```

Estados:

```text
QUEUED
RUNNING
COMPLETED
FAILED
CANCELLED
```

Toda operação deverá fornecer:

```text
operation_id
status
resource_type
resource_id
```

---

# Health checks

Endpoints:

```text
GET /health
GET /ready
GET /version
```

Eles deverão possuir schemas simples e estáveis.

O endpoint `/metrics` não será documentado como público quando estiver restrito à infraestrutura.

---

# Eventos em tempo real

OpenAPI documenta HTTP, mas não descreve completamente SSE ou WebSocket.

A estratégia será:

- documentar o endpoint SSE no OpenAPI;
- documentar o formato dos eventos;
- criar documentação complementar;
- avaliar AsyncAPI em sprint futura.

Extensão recomendada:

```yaml
x-streaming: sse
```

Exemplo:

```yaml
/api/v1/stream:
  get:
    operationId: streamEvents
    x-streaming: sse
```

---

# AsyncAPI futura

Eventos do RabbitMQ deverão ser documentados futuramente com AsyncAPI.

Estrutura futura prevista:

```text
asyncapi/
├── asyncapi.yaml
├── channels/
├── messages/
└── schemas/
```

A especificação OpenAPI permanecerá responsável pelo HTTP.

A especificação AsyncAPI será responsável por:

- eventos;
- filas;
- tópicos;
- produtores;
- consumidores;
- mensagens;
- versões de eventos.

---

# Ferramentas previstas

Ferramentas possíveis:

```text
FastAPI
Pydantic
Swagger UI
Redoc
Spectral
Redocly CLI
openapi-generator
Schemathesis
Prism
```

A escolha final deverá priorizar:

- ferramentas gratuitas;
- integração com CI;
- suporte a OpenAPI 3.1;
- manutenção ativa;
- facilidade de uso;
- possibilidade de execução local.

---

# FastAPI

FastAPI poderá gerar parte da especificação automaticamente.

Entretanto, o contrato aprovado deverá controlar a implementação.

Estratégias possíveis:

## Estratégia A — OpenAPI manual como fonte principal

```text
OpenAPI
  ↓
implementação
```

Vantagem:

- controle total do contrato.

Desvantagem:

- maior esforço de sincronização.

## Estratégia B — FastAPI gera OpenAPI

```text
código
  ↓
OpenAPI
```

Vantagem:

- simplicidade inicial.

Desvantagem:

- risco de o contrato depender demais da implementação.

## Estratégia recomendada

Modelo híbrido controlado:

```text
contrato aprovado
  ↓
schemas e rotas FastAPI
  ↓
OpenAPI gerado
  ↓
comparação automática
```

A especificação gerada não poderá divergir do contrato aprovado.

---

# Validação estática

O pipeline deverá executar:

```text
lint
bundle
validate
breaking-change check
```

Validações mínimas:

- sintaxe YAML;
- referências válidas;
- `operationId` único;
- tags válidas;
- schemas válidos;
- exemplos válidos;
- respostas de erro;
- segurança declarada;
- descriptions obrigatórias;
- versão definida.

---

# Regras de lint

Exemplos de regras:

```text
operationId obrigatório
summary obrigatório
description obrigatória
tags obrigatórias
responses obrigatórias
security obrigatória
4xx documentado
5xx documentado
schemas sem propriedades livres desnecessárias
```

Exceções deverão ser justificadas.

---

# Testes de contrato

## Provider tests

Validam que a API implementada responde conforme a especificação.

## Consumer tests

Validam que clientes utilizam somente recursos documentados.

## Testes automáticos

Ferramentas poderão gerar casos a partir do OpenAPI.

Cenários:

- payload válido;
- campo obrigatório ausente;
- enum inválido;
- tipo inválido;
- autorização ausente;
- recurso inexistente;
- conflito;
- limite;
- resposta fora do schema.

---

# Mock server

Antes da implementação, poderá ser criado um servidor mock baseado no OpenAPI.

Usos:

- validar fluxo do Mission Control;
- testar integrações;
- revisar contratos;
- desenvolver frontend antecipadamente;
- demonstrar comportamento.

O mock não substitui testes reais.

---

# Geração de clientes

Clientes poderão ser gerados para:

```text
TypeScript
Python
Go
```

O cliente oficial inicial deverá priorizar:

```text
TypeScript
```

Motivo:

- integração com Mission Control;
- tipagem;
- validação;
- produtividade no frontend.

Regras:

- código gerado deverá ficar em diretório separado;
- não editar manualmente código gerado;
- regenerar após mudanças;
- versionar a especificação usada;
- testar o cliente gerado.

Estrutura possível:

```text
clients/
├── typescript/
├── python/
└── go/
```

---

# Documentação interativa

## Swagger UI

Uso:

- exploração da API;
- autenticação;
- execução controlada de chamadas;
- apoio ao desenvolvimento.

## Redoc

Uso:

- documentação de leitura;
- organização por domínio;
- exemplos;
- publicação.

Ambas deverão utilizar o mesmo bundle.

---

# Segurança da documentação

A documentação pública não deverá expor:

- endpoints administrativos internos;
- exemplos com segredos;
- hosts internos;
- tokens;
- detalhes de infraestrutura;
- dados pessoais;
- rotas experimentais não aprovadas.

Ambientes internos poderão possuir documentação ampliada.

---

# Versionamento da API

## Versão na URL

```text
/api/v1
```

## Versão da especificação

O campo:

```yaml
info:
  version: 0.1.0
```

representa a versão da especificação.

## Versionamento semântico

Formato:

```text
MAJOR.MINOR.PATCH
```

Regras:

- `MAJOR`: mudança incompatível;
- `MINOR`: funcionalidade compatível;
- `PATCH`: correção de documentação ou contrato compatível.

---

# Depreciação

Operações depreciadas deverão usar:

```yaml
deprecated: true
```

Também deverão documentar:

- substituição;
- data de encerramento;
- motivo;
- plano de migração.

Extensões possíveis:

```yaml
x-sunset-date: 2027-12-31
x-successor-operation: listProjectsV2
```

---

# Detecção de breaking changes

O pipeline deverá comparar:

```text
especificação anterior
versus
nova especificação
```

Mudanças a bloquear:

- remoção de endpoint;
- remoção de método;
- remoção de campo;
- campo opcional tornando-se obrigatório;
- alteração de tipo;
- remoção de enum;
- mudança de resposta;
- alteração de segurança;
- alteração incompatível de parâmetro.

---

# Pull requests

Toda alteração de contrato deverá incluir:

- descrição;
- motivo;
- impacto;
- compatibilidade;
- exemplos;
- testes;
- atualização de documentação;
- ADR ou RFC quando necessário.

Checklist:

```text
[ ] OpenAPI validado
[ ] lint aprovado
[ ] bundle gerado
[ ] exemplos validados
[ ] breaking changes avaliadas
[ ] testes atualizados
[ ] cliente regenerado quando aplicável
[ ] documentação atualizada
```

---

# Pipeline inicial

Fluxo recomendado:

```text
1. instalar dependências
2. validar YAML
3. executar lint
4. gerar bundle
5. validar bundle
6. comparar breaking changes
7. executar testes de contrato
8. gerar documentação
9. gerar cliente TypeScript
10. publicar artefatos
```

---

# Artefatos do pipeline

Artefatos recomendados:

```text
openapi.bundle.yaml
openapi.bundle.json
swagger-ui/
redoc/
typescript-client/
validation-report.json
breaking-change-report.json
```

---

# Governança

## Responsável técnico

O Solution Architect define padrões.

## Responsável de implementação

O Tech Lead garante aderência.

## Responsável de qualidade

O QA Agent valida contratos e testes.

## Responsável de segurança

O Security Agent revisa autenticação, autorização e exposição de dados.

## Aprovação

Mudanças incompatíveis deverão exigir aprovação humana.

---

# Relação com documentos existentes

A especificação deverá seguir:

```text
DATA_MODEL.md
STATE_MACHINES.md
PERMISSIONS.md
API_CONTRACTS.md
ERROR_STANDARD.md
EVENTS.md
SECURITY.md
```

Conflitos deverão ser resolvidos antes da implementação.

---

# Primeira entrega OpenAPI

A primeira especificação deverá incluir:

```text
/health
/ready
/version

/api/v1/auth/login
/api/v1/auth/refresh
/api/v1/auth/logout
/api/v1/auth/me

/api/v1/projects
/api/v1/projects/{project_id}
/api/v1/projects/{project_id}/transitions
```

Schemas iniciais:

```text
LoginRequest
TokenResponse
CurrentUserResponse

Project
ProjectCreateRequest
ProjectUpdateRequest
ProjectResponse
ProjectListResponse

TransitionRequest
TransitionResponse

ErrorResponse
ValidationErrorResponse
```

---

# Critérios de aceite da Sprint

Este documento será considerado aprovado quando:

- a versão OpenAPI estiver definida;
- a estrutura de arquivos estiver definida;
- convenções de nomes estiverem definidas;
- schemas comuns estiverem documentados;
- autenticação estiver modelada;
- autorização estiver representada;
- erros estiverem padronizados;
- paginação e filtros estiverem previstos;
- idempotência estiver representada;
- concorrência otimista estiver representada;
- operações assíncronas estiverem documentadas;
- validação automática estiver definida;
- testes de contrato estiverem previstos;
- geração de clientes estiver definida;
- publicação de documentação estiver prevista;
- breaking changes forem detectáveis;
- a primeira entrega OpenAPI estiver delimitada.
