# Catálogo de Eventos da Stieve Software Company

## Objetivo

Definir os eventos utilizados pelo CompanyOS para comunicação entre projetos, agentes, workflows e serviços.

A arquitetura será orientada por eventos. Os componentes não deverão depender diretamente uns dos outros quando puderem se comunicar por meio do Event Bus.

## Estrutura padrão

Todo evento deverá conter:

- event_id
- event_type
- event_version
- timestamp
- source
- project_id
- correlation_id
- causation_id
- actor_id
- payload
- metadata

## Exemplo

```json
{
  "event_id": "evt_01",
  "event_type": "ProjectCreated",
  "event_version": 1,
  "timestamp": "2026-08-02T16:30:00Z",
  "source": "company-os",
  "project_id": "prj_01",
  "correlation_id": "cor_01",
  "causation_id": null,
  "actor_id": "user_01",
  "payload": {
    "name": "Projeto Genesis"
  },
  "metadata": {
    "environment": "development"
  }
}
```
Eventos de Projetos
ProjectCreated

Emitido quando um projeto é criado.

ProjectUpdated

Emitido quando informações gerais do projeto são alteradas.

ProjectApproved

Emitido quando o Discovery Report é aprovado.

ProjectPaused

Emitido quando o projeto é pausado.

ProjectArchived

Emitido quando o projeto é arquivado.

Eventos de Referências
ReferenceUploaded

Emitido quando um arquivo, link ou outra referência é adicionada.

ReferenceProcessingStarted

Emitido quando o processamento da referência começa.

ReferenceProcessed

Emitido quando a referência foi analisada com sucesso.

ReferenceProcessingFailed

Emitido quando ocorre erro no processamento.

InformationExtracted

Emitido quando informações relevantes são extraídas de uma referência.

Eventos de Discovery
DiscoveryStarted

Emitido quando o Solution Architect inicia a descoberta.

InterviewQuestionCreated

Emitido quando uma nova pergunta é criada.

InterviewAnswerReceived

Emitido quando o usuário responde uma pergunta.

RequirementExtracted

Emitido quando um requisito é identificado.

BusinessRuleExtracted

Emitido quando uma regra de negócio é identificada.

DiscoveryReportGenerated

Emitido quando o relatório de descoberta é gerado.

DiscoveryChangesRequested

Emitido quando o usuário solicita ajustes.

DiscoveryApproved

Emitido quando o usuário aprova o relatório.

Eventos de Requisitos
RequirementCreated

Emitido quando um requisito é criado.

RequirementUpdated

Emitido quando um requisito é alterado.

RequirementApproved

Emitido quando um requisito é aprovado.

RequirementRejected

Emitido quando um requisito é rejeitado.

Eventos de Tarefas
TaskCreated

Emitido quando uma tarefa é criada.

TaskQueued

Emitido quando uma tarefa entra na fila.

TaskAssigned

Emitido quando uma tarefa é atribuída a um agente.

TaskStarted

Emitido quando a execução começa.

TaskBlocked

Emitido quando a tarefa encontra um impedimento.

TaskWaitingApproval

Emitido quando a tarefa aguarda aprovação humana.

TaskCompleted

Emitido quando a tarefa é concluída.

TaskFailed

Emitido quando a tarefa falha.

TaskRetryScheduled

Emitido quando uma nova tentativa é agendada.

TaskCancelled

Emitido quando a tarefa é cancelada.

Eventos de Agentes
AgentRegistered

Emitido quando um agente é registrado.

AgentStarted

Emitido quando o agente inicia.

AgentOnline

Emitido quando o agente fica disponível.

AgentReserved

Emitido quando o agente é reservado para uma tarefa.

AgentExecutionStarted

Emitido quando o agente inicia uma execução.

AgentExecutionCompleted

Emitido quando a execução termina com sucesso.

AgentExecutionFailed

Emitido quando a execução falha.

AgentBlocked

Emitido quando o agente é bloqueado.

AgentOffline

Emitido quando o agente fica indisponível.

Eventos de Workflows
WorkflowCreated

Emitido quando um workflow é criado.

WorkflowStarted

Emitido quando o workflow inicia.

WorkflowStepStarted

Emitido quando uma etapa inicia.

WorkflowStepCompleted

Emitido quando uma etapa termina.

WorkflowPaused

Emitido quando o workflow é pausado.

WorkflowResumed

Emitido quando o workflow é retomado.

WorkflowCompleted

Emitido quando o workflow termina.

WorkflowFailed

Emitido quando o workflow falha.

WorkflowCancelled

Emitido quando o workflow é cancelado.

Eventos de Qualidade
TestSuiteStarted

Emitido quando uma suíte de testes inicia.

TestSuitePassed

Emitido quando os testes são aprovados.

TestSuiteFailed

Emitido quando os testes falham.

CoverageCalculated

Emitido quando a cobertura é calculada.

QualityGateApproved

Emitido quando os critérios de qualidade são atendidos.

QualityGateRejected

Emitido quando os critérios não são atendidos.

Eventos de Segurança
SecurityReviewStarted

Emitido quando a revisão de segurança começa.

VulnerabilityDetected

Emitido quando uma vulnerabilidade é encontrada.

SecretDetected

Emitido quando um segredo é detectado no código.

SecurityReviewApproved

Emitido quando a revisão é aprovada.

SecurityReviewRejected

Emitido quando a revisão é rejeitada.

Eventos de Releases
ReleaseCreated

Emitido quando uma release é criada.

ReleaseValidationStarted

Emitido quando a validação começa.

ReleaseApproved

Emitido quando a release é aprovada.

ReleaseRejected

Emitido quando a release é rejeitada.

ReleasePublished

Emitido quando a release é publicada.

Eventos de Deployment
DeploymentRequested

Emitido quando um deployment é solicitado.

DeploymentApproved

Emitido quando o deployment é autorizado.

DeploymentStarted

Emitido quando a publicação começa.

DeploymentCompleted

Emitido quando a publicação termina.

DeploymentFailed

Emitido quando a publicação falha.

HealthCheckPassed

Emitido quando os testes de saúde são aprovados.

HealthCheckFailed

Emitido quando os testes de saúde falham.

RollbackStarted

Emitido quando o rollback começa.

RollbackCompleted

Emitido quando o rollback termina.

RollbackFailed

Emitido quando o rollback falha.

Eventos de Aprovação Humana
HumanApprovalRequested

Emitido quando uma decisão humana é necessária.

HumanApprovalGranted

Emitido quando a ação é aprovada.

HumanApprovalRejected

Emitido quando a ação é rejeitada.

HumanApprovalExpired

Emitido quando a solicitação expira.

Eventos de Infraestrutura
ServiceStarted

Emitido quando um serviço inicia.

ServiceStopped

Emitido quando um serviço para.

ServiceUnhealthy

Emitido quando um serviço apresenta falha.

ResourceLimitReached

Emitido quando CPU, memória, GPU ou armazenamento alcança o limite.

StorageLow

Emitido quando o espaço disponível está baixo.

Entrega e confiabilidade

Os eventos deverão suportar:

persistência;
repetição segura;
idempotência;
retry;
dead-letter queue;
versionamento;
rastreabilidade;
correlação entre execuções.
Regras
Eventos publicados não deverão ser alterados.
Mudanças de estrutura deverão gerar uma nova versão.
Consumidores deverão ignorar campos desconhecidos.
Informações sensíveis não deverão ser incluídas no payload.
Falhas deverão ser enviadas para uma dead-letter queue.
Toda publicação deverá ser registrada em auditoria.
