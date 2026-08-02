# Sala de Operações

## Objetivo

A Sala de Operações será a área do SSC Mission Control destinada ao acompanhamento dos agentes, tarefas, workflows, filas, eventos e alertas da Stieve Software Company.

## Visão geral

A tela deverá apresentar:

- Agentes online
- Agentes trabalhando
- Agentes bloqueados
- Tarefas pendentes
- Tarefas em execução
- Tarefas com falha
- Workflows ativos
- Aprovações pendentes
- Alertas da plataforma
- Saúde dos serviços

## Estados dos agentes

- OFFLINE
- STARTING
- IDLE
- RESERVED
- PLANNING
- WORKING
- WAITING
- REVIEWING
- BLOCKED
- FAILED
- STOPPING

## Estados das tarefas

- PENDING
- QUEUED
- ASSIGNED
- RUNNING
- WAITING_APPROVAL
- BLOCKED
- RETRYING
- COMPLETED
- FAILED
- CANCELLED

## Controles humanos

Usuários autorizados poderão:

- Pausar workflows
- Continuar workflows
- Cancelar tarefas
- Reexecutar tarefas
- Alterar prioridades
- Bloquear agentes
- Solicitar explicações
- Aprovar ou rejeitar decisões
- Abrir incidentes

## Segurança

A Sala de Operações não disponibilizará terminal livre.

Todas as ações deverão passar por:

1. Autenticação
2. Autorização
3. Validação
4. Auditoria
5. Execução isolada
6. Registro do resultado

## Critérios de aceite

- Exibir agentes e seus estados
- Exibir tarefas e workflows
- Exibir eventos
- Exibir filas
- Destacar aprovações humanas
- Registrar todas as ações
- Não oferecer terminal livre
