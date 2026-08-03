# Sprint 1.2 — Plano da Topologia RabbitMQ

## Auditoria confirmada

```text
RabbitMQ:                 4.3.4
rabbitmq_management:      ativo
rabbitmq_prometheus:      ativo
Vhost operacional:        development
Vhost legado:             /development
Usuário atual:            companyos
Tag atual:                administrator
Permissões no vhost:      configure/read/write = .*
Exchanges customizadas:   nenhuma
Filas:                    nenhuma
Bindings:                 nenhum
Políticas:                nenhuma
Parâmetros:               nenhum
```

## Decisões

### Virtual host

Toda a topologia será criada em:

```text
development
```

O vhost legado `/development` não será removido automaticamente.

### Importação

A topologia será importada explicitamente depois que o RabbitMQ estiver
saudável:

```text
rabbitmqctl import_definitions
```

O arquivo de definições não contém:

- usuários;
- senhas;
- hashes de senha;
- permissões;
- parâmetros secretos.

As credenciais continuam somente no `.env`.

### Tipo das filas

Nesta etapa serão utilizadas filas:

```text
classic
durable=true
auto_delete=false
```

A implantação atual possui um único nó e é um ambiente de desenvolvimento.

### Retry

A ideia inicial de uma única exchange de retry foi refinada para três exchanges:

```text
companyos.retry.5s
companyos.retry.30s
companyos.retry.5m
```

Motivo: depois do TTL, cada fila encaminha a mensagem para
`companyos.commands` preservando a routing key original.

## Exchanges

```text
companyos.commands       direct
companyos.events         topic
companyos.retry.5s       direct
companyos.retry.30s      direct
companyos.retry.5m       direct
companyos.dead-letter    topic
```

## Filas

```text
companyos.workflow.commands
companyos.agent.commands
companyos.audit.events
companyos.notifications.events
companyos.retry.5s
companyos.retry.30s
companyos.retry.5m
companyos.dead-letter
```

## Routing keys

### Commands

```text
workflow.execute
workflow.cancel
agent.execute
agent.cancel
```

### Events

```text
workflow.started
workflow.completed
workflow.failed
agent.started
agent.completed
agent.failed
audit.recorded
notification.requested
```

## Políticas

```text
companyos-work-dead-letter
companyos-event-dead-letter
companyos-retry-5s
companyos-retry-30s
companyos-retry-5m
```

## Dead-letter

Filas de commands e events encaminham rejeições definitivas para:

```text
exchange: companyos.dead-letter
fila:     companyos.dead-letter
binding:  #
```

## Fluxo de retry

```text
Consumer recebe command
        ↓
Incrementa x-ssc-retry-count
        ↓
Publica cópia na exchange de retry escolhida
        ↓
Confirma a publicação
        ↓
ACK na mensagem original
        ↓
TTL expira na fila de retry
        ↓
RabbitMQ envia para companyos.commands
        ↓
Routing key original é preservada
```

## Dívidas técnicas registradas

### Vhost legado

```text
/development
```

Será auditado separadamente antes de qualquer remoção.

### Usuário administrativo

O usuário `companyos` possui a tag:

```text
administrator
```

Em uma etapa posterior serão separados:

```text
companyos_service
companyos_admin
```

Esta implantação não altera credenciais nem tags.

## Critérios de conclusão

- [ ] definições validadas;
- [ ] exchanges importadas;
- [ ] filas importadas;
- [ ] bindings importados;
- [ ] políticas aplicadas;
- [ ] command routing testado;
- [ ] event routing testado;
- [ ] retry de 5 segundos testado;
- [ ] dead-letter testado;
- [ ] importação idempotente;
- [ ] nenhum segredo versionado;
- [ ] documentação versionada;
- [ ] commit enviado ao GitHub.
