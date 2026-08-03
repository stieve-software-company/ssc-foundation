# CompanyOS — Topologia de Eventos RabbitMQ

## Objetivo

Definir o primeiro contrato operacional do barramento de mensagens do
CompanyOS.

Esta topologia é o ponto de integração entre:

- Mission Control;
- Workflow Engine;
- Agent Runtime;
- auditoria;
- notificações;
- serviços futuros.

## Ambiente atual

```text
RabbitMQ:     4.3.4
Virtual host: development
Protocolo:    AMQP 0-9-1
```

## Convenções

### Nomes

Todos os recursos próprios começam com:

```text
companyos.
```

### Mensagens

Mensagens de negócio devem ser publicadas com:

```text
delivery_mode=2
content_type=application/json
```

### Envelope mínimo

```json
{
  "event_id": "UUID",
  "event_type": "workflow.started",
  "occurred_at": "ISO-8601",
  "project_id": "UUID",
  "correlation_id": "UUID",
  "causation_id": "UUID ou null",
  "actor": {
    "type": "user|agent|system",
    "id": "identificador"
  },
  "payload": {}
}
```

## Exchanges

### companyos.commands

```text
tipo:       direct
durável:    sim
finalidade: comandos destinados a um executor específico
```

Routing keys:

```text
workflow.execute
workflow.cancel
agent.execute
agent.cancel
```

### companyos.events

```text
tipo:       topic
durável:    sim
finalidade: fatos que já ocorreram
```

Famílias iniciais:

```text
workflow.*
agent.*
audit.*
notification.*
```

### companyos.retry.5s

```text
tipo:       direct
durável:    sim
atraso:     5 segundos
retorno:    companyos.commands
```

### companyos.retry.30s

```text
tipo:       direct
durável:    sim
atraso:     30 segundos
retorno:    companyos.commands
```

### companyos.retry.5m

```text
tipo:       direct
durável:    sim
atraso:     5 minutos
retorno:    companyos.commands
```

### companyos.dead-letter

```text
tipo:       topic
durável:    sim
finalidade: falhas definitivas e mensagens rejeitadas
```

## Filas operacionais

### companyos.workflow.commands

Bindings:

```text
companyos.commands → workflow.execute
companyos.commands → workflow.cancel
```

Responsável futuro:

```text
Workflow Engine
```

### companyos.agent.commands

Bindings:

```text
companyos.commands → agent.execute
companyos.commands → agent.cancel
```

Responsável futuro:

```text
Agent Runtime
```

### companyos.audit.events

Binding:

```text
companyos.events → audit.#
```

Responsável futuro:

```text
Audit Service
```

### companyos.notifications.events

Binding:

```text
companyos.events → notification.#
```

Responsável futuro:

```text
Notification Service
```

## Retry

### Regra do consumidor

Ao decidir tentar novamente, o consumidor não deve usar:

```text
basic.nack(requeue=true)
```

em loop indefinido.

O fluxo previsto é:

1. ler `x-ssc-retry-count`;
2. incrementar o contador;
3. selecionar uma exchange de retry;
4. publicar uma cópia com a mesma routing key;
5. aguardar confirmação da publicação;
6. executar ACK na mensagem original.

Exemplo:

```text
Tentativa 1 → companyos.retry.5s
Tentativa 2 → companyos.retry.30s
Tentativa 3 → companyos.retry.5m
Tentativa 4 → rejeição definitiva
```

Header controlado pela aplicação:

```text
x-ssc-retry-count
```

O RabbitMQ também registra mortes e expirações no header:

```text
x-death
```

### Preservação da routing key

Uma mensagem publicada em:

```text
exchange:    companyos.retry.5s
routing key: workflow.execute
```

expira e retorna para:

```text
exchange:    companyos.commands
routing key: workflow.execute
```

## Dead-letter

Commands e events rejeitados com:

```text
basic.reject(requeue=false)
```

ou:

```text
basic.nack(requeue=false)
```

são encaminhados para:

```text
companyos.dead-letter
```

A fila:

```text
companyos.dead-letter
```

recebe todas as routing keys por meio do binding:

```text
#
```

## Idempotência

Consumidores deverão considerar:

```text
event_id
correlation_id
```

antes de executar efeitos externos.

O recebimento duplicado não pode produzir:

- dois deploys;
- duas alterações de projeto;
- dois registros financeiros;
- duas notificações equivalentes;
- duas execuções do mesmo agente.

## Ordenação

A ordenação é garantida somente dentro de uma mesma fila e pode ser afetada por:

- múltiplos consumidores;
- redelivery;
- retries;
- falhas de conexão;
- processamento paralelo.

Fluxos que exigem ordem deverão usar uma chave lógica e controle no serviço.

## Segurança

- nenhum segredo está no arquivo de definições;
- recursos estão isolados no vhost `development`;
- a porta AMQP não está publicada para a rede local;
- permissões e usuários serão endurecidos em etapa posterior;
- mensagens não devem transportar senhas ou tokens em texto puro.

## Evolução prevista

```text
Sprint atual:
  commands
  events
  retry
  dead-letter

Etapas futuras:
  schemas versionados
  outbox transacional
  inbox/idempotência
  métricas por routing key
  alertas de dead-letter
  tracing distribuído
  isolamento por projeto
```
