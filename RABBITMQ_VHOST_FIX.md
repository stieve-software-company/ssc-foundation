# Correção do Virtual Host do RabbitMQ

## Diagnóstico

O Mission Control se conecta usando:

```text
amqp://...@rabbitmq:5672/development
```

Nesse formato, o virtual host solicitado ao RabbitMQ é:

```text
development
```

Porém, a configuração inicial declarava:

```env
RABBITMQ_DEFAULT_VHOST=/development
```

Esses nomes não são iguais.

O painel confirmou o problema:

```text
NOT_ALLOWED - vhost development not found
```

## Decisão

Padronizar o nome do virtual host como:

```text
development
```

Sem barra inicial.

A correção:

- atualiza o `.env` privado;
- atualiza `.env.example`;
- atualiza o valor padrão em `compose.yaml`;
- cria o vhost `development`;
- aplica permissões ao usuário configurado;
- preserva o volume RabbitMQ;
- não remove o vhost antigo;
- não exibe senhas;
- testa a conexão pelo container Mission Control.

## Arquivos

```text
RABBITMQ_VHOST_FIX.md
scripts/configure-rabbitmq-vhost.sh
scripts/test-rabbitmq-integration.sh
```

## Instalação

Copie `rabbitmq_vhost_fix.zip` para a pasta compartilhada e execute:

```bash
cd "$HOME/workspace/ssc-foundation"

cp "/media/sf_ssc_share/rabbitmq_vhost_fix.zip" .

unzip -o rabbitmq_vhost_fix.zip

rm rabbitmq_vhost_fix.zip

chmod +x \
  scripts/configure-rabbitmq-vhost.sh \
  scripts/test-rabbitmq-integration.sh
```

## Aplicar a correção

```bash
./scripts/configure-rabbitmq-vhost.sh
```

O script é idempotente e pode ser executado novamente.

## Validar

```bash
./scripts/test-rabbitmq-integration.sh
```

Resultado esperado:

```text
[OK] Virtual host development existe.
[OK] Permissões do usuário estão configuradas.
[OK] Mission Control conectou ao RabbitMQ.
[OK] Integração RabbitMQ concluída.
```

## Validar no painel

Acesse:

```text
http://192.168.3.19:8080
```

Abra:

```text
Sistema
```

O cartão RabbitMQ deverá apresentar:

```text
Disponível
conexão AMQP aceita
```

## Segurança

O script não imprime:

- senha do RabbitMQ;
- conteúdo completo do `.env`;
- URL AMQP completa.

Uma cópia privada da configuração anterior é criada em:

```text
infrastructure/backups/config/rabbitmq-vhost-<data-hora>/
```

## Arquivos que deverão aparecer no Git

```text
M .env.example
M compose.yaml
?? RABBITMQ_VHOST_FIX.md
?? scripts/configure-rabbitmq-vhost.sh
?? scripts/test-rabbitmq-integration.sh
```

O `.env` não deverá aparecer porque continua protegido pelo `.gitignore`.

## Baseline da Sprint 1.2

O arquivo `SPRINT_1_2_BASELINE.md` deve permanecer sem commit até:

1. o RabbitMQ aparecer saudável no painel;
2. a conexão AMQP ser validada;
3. o documento ser atualizado com o resultado real.
