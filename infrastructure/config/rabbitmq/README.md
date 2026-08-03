# Configuração RabbitMQ

## Arquivo canônico

```text
definitions.json
```

O arquivo contém somente:

- vhost;
- exchanges;
- filas;
- bindings;
- políticas.

Não contém usuários, senhas ou permissões.

## Aplicação

```bash
./scripts/bootstrap-rabbitmq.sh
```

O bootstrap:

1. valida o `.env`;
2. valida o JSON;
3. aguarda o RabbitMQ;
4. copia temporariamente o JSON para o container;
5. executa `rabbitmqctl import_definitions`;
6. remove a cópia temporária;
7. executa os testes.

## Reexecução

O bootstrap é idempotente para os recursos declarados com as mesmas
propriedades.

Não altere manualmente tipo, durabilidade ou argumentos imutáveis de uma fila
já existente. Mudanças desse tipo exigem migração planejada.
