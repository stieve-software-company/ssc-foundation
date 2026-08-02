# Sala de Operações

## Objetivo

Acompanhar em tempo real agentes, tarefas, workflows, filas, eventos, recursos, alertas e aprovações da Stieve Software Company.

## Indicadores principais

- Agentes online, trabalhando, bloqueados e com falha
- Tarefas pendentes, executando, bloqueadas e com falha
- Workflows ativos e pausados
- Aprovações humanas pendentes
- Estado das filas
- Saúde dos serviços
- Uso de CPU, memória, GPU e armazenamento

## Cartão do agente

Cada agente deverá apresentar:

- Nome e função
- Estado
- Projeto e tarefa atual
- Modelo de IA
- Início e duração da execução
- Progresso
- Ferramentas utilizadas
- CPU, memória e GPU
- Última atividade e último erro

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

## Timeline de eventos

A tela deverá apresentar eventos cronológicos com:

- Data e hora
- Projeto
- Agente ou usuário
- Tipo
- Tarefa ou workflow
- Severidade
- Resultado
- Identificador de correlação

## Workflows

Cada workflow deverá exibir:

- Nome e projeto
- Estado e etapa atual
- Etapas concluídas e futuras
- Dependências e bloqueios
- Tentativas
- Tempo total
- Aprovações pendentes

## Filas

Cada fila deverá exibir:

- Nome
- Consumidores
- Mensagens pendentes e em processamento
- Mensagens com erro
- Tempo médio de espera
- Dead-letter queue
- Última atividade

## Filtros

- Projeto
- Agente
- Departamento
- Estado
- Tipo de evento
- Workflow
- Tarefa
- Severidade
- Período

## Controles humanos

Usuários autorizados poderão:

- Pausar, continuar ou cancelar workflows
- Cancelar ou reexecutar tarefas
- Alterar prioridades
- Bloquear ou liberar agentes
- Solicitar explicações
- Aprovar ou rejeitar decisões
- Abrir incidentes

## Alertas

Níveis:

- INFO
- WARNING
- ERROR
- CRITICAL

Exemplos:

- Agente sem resposta
- Fila crescendo
- Tarefa acima do timeout
- Serviço indisponível
- Teste falhou
- Vulnerabilidade crítica
- Deployment falhou
- Recurso próximo do limite

## Atualização em tempo real

A implementação deverá utilizar preferencialmente WebSocket ou Server-Sent Events. Polling será permitido apenas como solução temporária.

## Segurança

A Sala de Operações não disponibilizará terminal livre. Toda ação passará por autenticação, autorização, validação, auditoria e execução isolada.

## Critérios de aceite

- Exibir agentes, tarefas, workflows, filas e eventos
- Permitir filtros
- Destacar aprovações e alertas
- Permitir somente controles autorizados
- Registrar todas as ações
- Não oferecer shell irrestrito
