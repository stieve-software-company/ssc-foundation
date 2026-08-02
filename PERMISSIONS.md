# Permissões e Controle de Acesso da Stieve Software Company

## Objetivo

Definir o modelo de autorização do CompanyOS e do SSC Mission Control.

Este documento estabelece:

- papéis de usuários;
- papéis técnicos de agentes;
- permissões;
- escopos;
- regras de herança;
- negações explícitas;
- segregação de funções;
- aprovações humanas;
- acesso por projeto e ambiente;
- auditoria;
- critérios de teste.

O modelo será usado como base para:

- autenticação e autorização;
- RBAC;
- políticas de segurança;
- contratos da API;
- interface do Mission Control;
- execução controlada de agentes;
- aprovações;
- auditoria;
- testes automatizados.

---

# Princípios

## Negação por padrão

Toda ação deverá ser negada quando não existir permissão explícita.

```text
sem permissão explícita
  ↓
acesso negado
```

## Menor privilégio

Usuários, agentes e serviços deverão possuir somente as permissões necessárias para suas funções.

## Escopo obrigatório

Toda permissão deverá ser avaliada dentro de um escopo.

Escopos iniciais:

```text
ORGANIZATION
PROJECT
ENVIRONMENT
RESOURCE
EXECUTION
```

## Separação entre autenticação e autorização

Autenticação responde:

```text
Quem é o ator?
```

Autorização responde:

```text
O ator pode executar esta ação neste recurso?
```

## Aprovação não substitui permissão

Uma aprovação humana não concede acesso automaticamente.

Para executar uma ação crítica, o ator deverá possuir:

```text
permissão válida
+
aprovação válida
+
estado permitido
+
guardas atendidas
```

## Auditoria obrigatória

Toda ação sensível deverá registrar:

```text
actor_type
actor_id
permission
scope
resource_type
resource_id
decision
reason
correlation_id
created_at
```

---

# Modelo de autorização

A autorização será baseada em:

```text
RBAC
+
escopo
+
atributos do recurso
+
estado
+
nível de risco
+
aprovação humana
```

Fluxo:

```text
Solicitação
  ↓
Autenticação
  ↓
Identificação do ator
  ↓
Resolução de papéis
  ↓
Resolução de permissões
  ↓
Validação do escopo
  ↓
Validação do recurso
  ↓
Validação do estado
  ↓
Validação do risco
  ↓
Validação da aprovação
  ↓
Permitir ou negar
  ↓
Auditoria
```

---

# Tipos de ator

## USER

Pessoa que utiliza o Mission Control ou a API.

## AGENT

Agente de IA registrado no CompanyOS.

## SERVICE

Serviço interno autenticado.

## SYSTEM

Processo interno controlado pelo CompanyOS.

---

# Papéis de usuários

## OWNER

Proprietário da organização.

Responsabilidades:

- aprovar decisões estratégicas;
- administrar a organização;
- autorizar produção;
- aprovar mudanças críticas;
- aceitar riscos;
- administrar políticas;
- delegar funções.

O `OWNER` não deverá ser usado para atividades operacionais rotineiras.

## ADMIN

Administrador da plataforma.

Responsabilidades:

- gerenciar usuários;
- gerenciar papéis;
- administrar configurações;
- cadastrar agentes;
- administrar projetos;
- consultar auditoria.

Restrições:

- não poderá substituir o proprietário em aprovações reservadas;
- não poderá apagar auditorias;
- não poderá remover o último proprietário.

## PROJECT_MANAGER

Gestor de projeto.

Responsabilidades:

- administrar projetos autorizados;
- conduzir Discovery;
- organizar backlog;
- solicitar mudanças;
- acompanhar tarefas;
- solicitar releases;
- administrar membros do projeto dentro dos limites permitidos.

## HUMAN_DEVELOPER

Desenvolvedor humano.

Responsabilidades:

- consultar requisitos;
- criar e atualizar tarefas técnicas;
- trabalhar em código autorizado;
- executar testes;
- enviar entregas para revisão.

Restrições:

- não poderá aprovar sua própria release quando segregação for exigida;
- não poderá fazer deploy direto em produção.

## SECURITY_REVIEWER

Responsável por revisão de segurança.

Responsabilidades:

- revisar achados;
- confirmar vulnerabilidades;
- validar correções;
- recomendar bloqueios;
- participar de aprovação de risco.

## RELEASE_APPROVER

Responsável por aprovar releases.

Responsabilidades:

- validar evidências;
- revisar testes;
- revisar segurança;
- revisar documentação;
- aprovar ou rejeitar releases.

## DEPLOYMENT_OPERATOR

Responsável por executar deployments autorizados.

Responsabilidades:

- executar publicação;
- validar health checks;
- iniciar rollback autorizado;
- registrar resultado.

## AUDITOR

Responsável por consulta independente.

Permissões:

- leitura de auditoria;
- leitura de eventos;
- leitura de aprovações;
- leitura de configurações relevantes;
- exportação controlada de relatórios.

Restrições:

- não altera recursos operacionais.

## VIEWER

Acesso somente para consulta aos recursos autorizados.

## AGENT

Papel técnico atribuído a identidades de agentes.

Nunca deverá possuir permissões administrativas amplas.

---

# Papéis técnicos de agentes

## CEO_AGENT

Pode:

- consultar estado geral;
- consolidar métricas;
- identificar riscos;
- recomendar prioridades;
- solicitar aprovações;
- gerar resumos executivos.

Não pode:

- aprovar decisões críticas;
- alterar permissões;
- publicar em produção;
- apagar registros.

## SOLUTION_ARCHITECT

Pode:

- consultar referências;
- conduzir Discovery;
- criar perguntas;
- propor requisitos;
- gerar Discovery Report;
- propor arquitetura inicial.

Não pode:

- aprovar o próprio Discovery;
- iniciar desenvolvimento sem aprovação.

## PRODUCT_MANAGER

Pode:

- criar épicos;
- criar histórias;
- priorizar backlog;
- propor roadmap;
- relacionar requisitos.

Não pode:

- alterar decisões técnicas aprovadas sem RFC;
- aprovar release de forma automática.

## CHANGE_MANAGER

Pode:

- receber solicitações;
- criar RFC;
- analisar impacto;
- solicitar aprovação;
- relacionar dependências.

Não pode:

- executar mudança não aprovada;
- autorizar produção.

## TECH_LEAD

Pode:

- criar arquitetura técnica;
- dividir tarefas;
- definir dependências;
- revisar entregas;
- atribuir tarefas técnicas.

Não pode:

- ignorar políticas de segurança;
- aprovar deployment de produção sem autorização humana.

## ENGINEERING_AGENT

Inclui:

```text
BACKEND_ENGINEER
FRONTEND_ENGINEER
DATABASE_ENGINEER
DEVOPS_ENGINEER
DOCUMENTATION_ENGINEER
UX_UI_ENGINEER
```

Pode:

- ler contexto autorizado;
- trabalhar em tarefa atribuída;
- alterar arquivos permitidos;
- criar branch;
- gerar commit;
- executar testes permitidos;
- gerar documentação;
- enviar resultado para revisão.

Não pode:

- acessar outro projeto;
- alterar sua própria permissão;
- executar shell irrestrito;
- alterar produção;
- ler segredos diretamente;
- fazer `push --force` na branch principal.

## QA_ENGINEER

Pode:

- consultar requisitos;
- criar casos de teste;
- executar testes;
- registrar falhas;
- aprovar quality gate quando autorizado.

Não pode:

- alterar resultado de teste manualmente;
- marcar teste falho como aprovado sem evidência.

## SECURITY_ENGINEER

Pode:

- analisar código;
- analisar dependências;
- registrar achados;
- confirmar vulnerabilidades;
- validar correções;
- bloquear release por política.

Não pode:

- aceitar risco crítico sem aprovação humana;
- remover evidências.

## RELEASE_MANAGER

Pode:

- criar release;
- iniciar validação;
- solicitar aprovação;
- publicar release aprovada.

Não pode:

- aprovar a própria release quando houver segregação;
- ignorar teste ou segurança obrigatória.

## DEPLOYMENT_MANAGER

Pode:

- preparar deployment;
- executar deployment autorizado;
- executar health checks;
- iniciar rollback autorizado.

Não pode:

- aprovar o próprio deployment em produção;
- publicar versão não aprovada.

## INFRASTRUCTURE_MANAGER

Pode:

- consultar recursos;
- administrar serviços autorizados;
- gerenciar ambientes;
- executar backup;
- restaurar ambiente autorizado.

Não pode:

- alterar políticas críticas;
- acessar segredos sem mecanismo controlado;
- desabilitar auditoria.

## KNOWLEDGE_MANAGER

Pode:

- organizar Knowledge Vault;
- relacionar fontes;
- versionar conhecimento;
- arquivar itens;
- registrar decisões e lições.

Não pode:

- alterar evidência histórica aprovada;
- remover rastreabilidade.

---

# Convenção de permissões

Formato:

```text
resource.action
```

Exemplos:

```text
project.create
project.read
project.update
project.archive
task.assign
release.approve
deployment.production
```

Quando necessário:

```text
resource.subresource.action
```

Exemplos:

```text
project.member.add
project.member.remove
agent.tool.execute
security.risk.accept
```

---

# Catálogo inicial de permissões

## Organização

```text
organization.read
organization.update
organization.archive
organization.settings.read
organization.settings.update
```

## Usuários

```text
user.create
user.read
user.update
user.disable
user.invite
user.session.revoke
```

## Papéis e permissões

```text
role.create
role.read
role.update
role.delete
role.assign
role.revoke
permission.read
permission.manage
```

## Projetos

```text
project.create
project.read
project.update
project.pause
project.resume
project.archive
project.cancel
project.delete
project.member.add
project.member.update
project.member.remove
project.agent.assign
project.agent.remove
```

## Discovery

```text
discovery.start
discovery.read
discovery.update
discovery.submit
discovery.review
discovery.approve
discovery.cancel
```

## Referências

```text
reference.create
reference.read
reference.update
reference.process
reference.retry
reference.review
reference.archive
reference.delete
reference.quarantine.read
reference.quarantine.release
```

## Requisitos

```text
requirement.create
requirement.read
requirement.update
requirement.submit
requirement.review
requirement.approve
requirement.reject
requirement.deprecate
```

## Decisões

```text
decision.create
decision.read
decision.update
decision.submit
decision.approve
decision.reject
decision.supersede
```

## Backlog

```text
epic.create
epic.read
epic.update
epic.cancel

story.create
story.read
story.update
story.prioritize
story.cancel
```

## Tarefas

```text
task.create
task.read
task.update
task.assign
task.enqueue
task.start
task.block
task.unblock
task.complete
task.fail
task.retry
task.cancel
task.approve
```

## Workflows

```text
workflow.create
workflow.read
workflow.start
workflow.pause
workflow.resume
workflow.cancel
workflow.retry
workflow.approve
```

## Agentes

```text
agent.register
agent.read
agent.update
agent.start
agent.stop
agent.block
agent.unblock
agent.assign
agent.permission.override
agent.tool.execute
agent.execution.read
agent.execution.cancel
```

## Aprovações

```text
approval.create
approval.read
approval.approve
approval.reject
approval.cancel
approval.reassign
```

## Testes

```text
test.create
test.read
test.execute
test.cancel
test.report.read
test.quality_gate.approve
test.quality_gate.reject
```

## Segurança

```text
security.finding.create
security.finding.read
security.finding.confirm
security.finding.update
security.finding.resolve
security.finding.reopen
security.false_positive.mark
security.risk.accept
security.review.approve
security.review.reject
```

## Releases

```text
release.create
release.read
release.update
release.validate
release.submit
release.approve
release.reject
release.publish
release.deprecate
```

## Deployments

```text
deployment.create
deployment.read
deployment.approve
deployment.cancel
deployment.development
deployment.testing
deployment.staging
deployment.production
deployment.rollback
deployment.logs.read
```

## Infraestrutura

```text
infrastructure.read
infrastructure.service.start
infrastructure.service.stop
infrastructure.service.restart
infrastructure.backup.create
infrastructure.backup.read
infrastructure.restore
infrastructure.configuration.read
infrastructure.configuration.update
```

## Eventos

```text
event.read
event.publish
event.retry
event.dead_letter.read
event.dead_letter.reprocess
```

## Auditoria

```text
audit.read
audit.export
audit.retention.manage
```

## Knowledge Vault

```text
knowledge.create
knowledge.read
knowledge.update
knowledge.version
knowledge.archive
knowledge.delete
```

## Incidentes

```text
incident.create
incident.read
incident.update
incident.assign
incident.contain
incident.resolve
incident.close
incident.reopen
```

---

# Escopos

## ORGANIZATION

Permissão válida para toda a organização.

Exemplo:

```text
role = ADMIN
permission = user.invite
scope = ORGANIZATION
scope_id = org_01
```

## PROJECT

Permissão válida somente para um projeto.

Exemplo:

```text
role = PROJECT_MANAGER
permission = task.assign
scope = PROJECT
scope_id = prj_01
```

## ENVIRONMENT

Permissão limitada a um ambiente.

Exemplo:

```text
permission = deployment.staging
scope = ENVIRONMENT
scope_id = prj_01:staging
```

## RESOURCE

Permissão sobre um recurso específico.

Exemplo:

```text
permission = approval.approve
scope = RESOURCE
scope_id = apr_01
```

## EXECUTION

Permissão temporária para uma execução.

Exemplo:

```text
permission = agent.tool.execute
scope = EXECUTION
scope_id = exe_01
```

---

# Herança

## Regra geral

Permissões poderão ser herdadas de um escopo superior.

Exemplo:

```text
ORGANIZATION
  ↓
PROJECT
  ↓
ENVIRONMENT
  ↓
RESOURCE
```

## Limite

A herança não poderá ultrapassar:

- organização;
- projeto;
- ambiente;
- recurso;
- execução autorizada.

## Exemplo

Um `ADMIN` com `project.read` em `ORGANIZATION` poderá ler os projetos da organização.

Um `PROJECT_MANAGER` com `project.read` em `PROJECT prj_01` não poderá ler `prj_02`.

---

# Negação explícita

O modelo deverá suportar negação explícita.

Prioridade:

```text
DENY
  >
ALLOW
```

Exemplo:

```text
ALLOW deployment.staging no projeto
DENY deployment.staging para ambiente staging-europe
```

Resultado:

```text
acesso negado em staging-europe
```

Uso recomendado:

- bloqueio temporário;
- incidente;
- suspensão;
- conflito de função;
- ambiente restrito;
- usuário afastado;
- agente comprometido.

---

# Resolução de acesso

A decisão deverá considerar:

```text
1. identidade válida
2. sessão válida
3. ator ativo
4. organização correta
5. recurso existente
6. papel ativo
7. permissão ativa
8. escopo compatível
9. ausência de negação
10. estado permitido
11. risco permitido
12. aprovação válida
13. política adicional atendida
```

Pseudocódigo:

```text
if actor is inactive:
    deny

if explicit deny exists:
    deny

if permission not granted:
    deny

if scope does not include resource:
    deny

if state does not allow action:
    deny

if action requires approval and no valid approval exists:
    deny

allow
```

---

# Permissões temporárias

Permissões temporárias deverão possuir:

```text
starts_at
expires_at
granted_by
reason
scope
```

Exemplos:

- apoio emergencial;
- análise de incidente;
- acesso temporário a ambiente;
- execução específica de ferramenta;
- substituição operacional.

Permissão expirada deverá ser ignorada automaticamente.

---

# Permissões de agentes

Cada agente deverá receber permissões por:

```text
definição do agente
+
projeto
+
tarefa
+
execução
+
ferramenta
```

## Restrições obrigatórias

Agentes não poderão:

- alterar suas próprias permissões;
- atribuir papéis;
- criar usuários;
- aprovar ações críticas;
- acessar projeto não atribuído;
- executar ferramenta não autorizada;
- sair do workspace autorizado;
- acessar segredo diretamente;
- desabilitar auditoria;
- apagar logs;
- fazer deploy direto em produção.

## Permissão de ferramenta

Uma ferramenta deverá ser autorizada separadamente.

Exemplos:

```text
tool.file.read
tool.file.write
tool.git.branch.create
tool.git.commit
tool.test.execute
tool.container.run
tool.database.read
tool.database.migrate
```

## Restrições por caminho

Exemplo:

```text
allowed_paths:
  - /workspace/prj_01/src
  - /workspace/prj_01/tests

denied_paths:
  - /etc
  - /root
  - /var/run/docker.sock
  - /workspace/prj_02
```

## Restrições por comando

Exemplo:

```text
allowed_commands:
  - pytest
  - npm test
  - git diff
  - git status

denied_commands:
  - rm -rf /
  - shutdown
  - reboot
  - chmod -R 777 /
  - docker system prune
```

---

# Ambientes

## DEVELOPMENT

Permissões mais flexíveis, mantendo isolamento e auditoria.

## TESTING

Alterações somente por workflows e tarefas autorizadas.

## STAGING

Acesso restrito a responsáveis técnicos e deployment operators.

## PRODUCTION

Acesso extremamente restrito.

Produção deverá exigir:

```text
permissão específica
+
release aprovada
+
aprovação humana
+
deployment aprovado
+
auditoria
```

Permissões de produção não deverão ser herdadas automaticamente de desenvolvimento.

---

# Segregação de funções

## Princípio

A mesma pessoa ou agente não deverá controlar todas as etapas de uma ação crítica.

## Casos obrigatórios

### Release

Quem cria uma release não deverá ser seu único aprovador.

### Deployment de produção

Quem solicita não deverá ser o único aprovador e executor quando a equipe permitir separação.

### Aceite de risco

Quem detecta ou corrige a vulnerabilidade não deverá aceitar sozinho o risco crítico.

### Permissões administrativas

Quem solicita acesso crítico não deverá aprová-lo sozinho.

### Exclusão

Quem solicita exclusão de projeto ou dados deverá ter aprovação independente.

---

# Aprovações e permissões

## Discovery

```text
discovery.approve
```

Exige:

- relatório submetido;
- versão válida;
- aprovador humano;
- ausência de bloqueios.

## Release

```text
release.approve
```

Exige:

- testes aprovados;
- segurança revisada;
- documentação atualizada;
- changelog;
- rollback planejado.

## Produção

```text
deployment.production
```

Exige:

- release aprovada;
- ambiente autorizado;
- backup;
- health checks;
- aprovação humana válida.

## Rollback

```text
deployment.rollback
```

Exige:

- incidente ou falha registrada;
- versão anterior;
- plano de reversão;
- aprovação quando aplicável.

## Aceite de risco

```text
security.risk.accept
```

Exige:

- achado confirmado;
- justificativa;
- prazo;
- responsável;
- plano de mitigação;
- aprovação autorizada.

---

# Matriz inicial de papéis

Legenda:

```text
R = leitura
W = criação ou alteração
A = aprovação
X = execução
- = não permitido por padrão
```

| Recurso | OWNER | ADMIN | PROJECT_MANAGER | HUMAN_DEVELOPER | SECURITY_REVIEWER | RELEASE_APPROVER | DEPLOYMENT_OPERATOR | AUDITOR | VIEWER |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Organização | A | W | R | - | R | R | R | R | R |
| Usuários | A | W | R | - | - | - | - | R | - |
| Papéis | A | W | R | - | - | - | - | R | - |
| Projetos | A | W | W | R | R | R | R | R | R |
| Discovery | A | W | W | R | R | R | R | R | R |
| Requisitos | A | W | W | W | R | R | R | R | R |
| Tarefas | A | W | W | W | R | R | R | R | R |
| Agentes | A | W | W | R | R | R | R | R | R |
| Testes | A | W | W | X | R | R | R | R | R |
| Segurança | A | W | R | R | W/A | R | R | R | R |
| Releases | A | W | W | R | R | A | R | R | R |
| Deployments | A | W | R | R | R | R | X | R | R |
| Auditoria | A | R | R | R limitada | R | R | R | R | - |

A matriz é uma referência inicial. A implementação deverá utilizar permissões granulares.

---

# Respostas da API

## Acesso permitido

A API continua normalmente.

## Acesso negado por autenticação

```http
401 Unauthorized
```

Exemplo:

```json
{
  "error": {
    "code": "AUTHENTICATION_REQUIRED",
    "message": "É necessário autenticar para acessar este recurso."
  }
}
```

## Acesso negado por autorização

```http
403 Forbidden
```

Exemplo:

```json
{
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "O ator não possui permissão para executar esta ação.",
    "details": {
      "permission": "release.approve",
      "scope": "PROJECT",
      "resource_id": "rel_01"
    }
  }
}
```

## Aprovação necessária

```http
409 Conflict
```

Exemplo:

```json
{
  "error": {
    "code": "APPROVAL_REQUIRED",
    "message": "Esta ação exige uma aprovação válida.",
    "details": {
      "approval_type": "DEPLOYMENT",
      "resource_id": "dep_01"
    }
  }
}
```

---

# Auditoria de autorização

Decisões relevantes deverão registrar:

```text
ALLOW
DENY
```

Campos:

```text
actor_type
actor_id
roles
permission
scope_type
scope_id
resource_type
resource_id
decision
reason
source_ip
correlation_id
created_at
```

Negações críticas deverão ser visíveis na auditoria.

Exemplos:

- tentativa de acessar outro projeto;
- tentativa de produção sem aprovação;
- agente tentando executar ferramenta não autorizada;
- usuário tentando atribuir papel superior;
- tentativa de aceitar risco sem permissão.

---

# Cache de permissões

Permissões poderão ser armazenadas em cache para desempenho.

Regras:

- cache deverá possuir expiração curta;
- alteração de papel deverá invalidar cache;
- bloqueio de ator deverá invalidar cache imediatamente;
- permissões críticas deverão ser revalidadas;
- cache nunca deverá substituir a fonte oficial.

---

# Banco de dados

Entidades recomendadas:

```text
Role
Permission
RolePermission
UserRoleAssignment
AgentPermissionAssignment
PermissionOverride
AccessPolicy
ApprovalRequest
AuditLog
```

## UserRoleAssignment

Campos:

```text
id
user_id
role_id
scope_type
scope_id
starts_at
expires_at
status
granted_by
created_at
```

## AgentPermissionAssignment

Campos:

```text
id
agent_instance_id
permission_id
scope_type
scope_id
task_id
execution_id
starts_at
expires_at
status
granted_by
created_at
```

## PermissionOverride

Campos:

```text
id
actor_type
actor_id
permission_id
effect
scope_type
scope_id
reason
starts_at
expires_at
created_by
created_at
```

Efeitos:

```text
ALLOW
DENY
```

---

# Eventos

Eventos recomendados:

```text
RoleCreated
RoleUpdated
RoleAssigned
RoleRevoked

PermissionGranted
PermissionRevoked
PermissionDenied

UserBlocked
UserUnblocked

AgentPermissionGranted
AgentPermissionRevoked
AgentBlocked

ApprovalRequested
ApprovalGranted
ApprovalRejected

CriticalAccessAttempted
```

Eventos de permissão não deverão conter segredos.

---

# Testes obrigatórios

## Testes positivos

- papel possui permissão;
- escopo inclui recurso;
- estado permite ação;
- aprovação válida existe;
- acesso é autorizado.

## Testes negativos

- ator não autenticado;
- ator desativado;
- papel sem permissão;
- recurso em outro projeto;
- ambiente não autorizado;
- negação explícita;
- aprovação ausente;
- aprovação expirada;
- estado incompatível;
- permissão temporária expirada.

## Testes de segregação

- criador não aprova sozinho a release;
- solicitante não aprova sozinho acesso crítico;
- agente não aprova produção;
- deployment operator não cria aprovação falsa;
- security engineer não aceita sozinho risco crítico.

## Testes de agentes

- agente acessa somente projeto atribuído;
- agente usa somente ferramenta autorizada;
- agente não altera permissões;
- agente não acessa segredos;
- agente não executa comando bloqueado;
- agente não acessa produção.

---

# Critérios de aceite da Sprint

Este documento será considerado aprovado quando:

- papéis iniciais estiverem definidos;
- catálogo de permissões estiver documentado;
- escopos estiverem definidos;
- negação por padrão estiver estabelecida;
- negação explícita tiver precedência;
- permissões de agentes estiverem limitadas;
- produção exigir permissão e aprovação;
- segregação de funções estiver documentada;
- respostas de autorização da API estiverem definidas;
- auditoria estiver incorporada;
- o modelo puder ser implementado no PostgreSQL;
- os cenários puderem ser transformados em testes automatizados.
