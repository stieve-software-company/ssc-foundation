# CompanyOS — Operações do Redis

## Papel do serviço

O Redis é uma camada temporária e operacional. O PostgreSQL continua sendo a
fonte de verdade do CompanyOS.

Usos autorizados:

```text
sessões
cache
locks distribuídos
idempotência
rate limiting
estado temporário de workflows
heartbeats de agentes
coordenação de curta duração
```

Não usar como armazenamento definitivo de:

```text
projetos
usuários
auditoria
credenciais
artefatos
configuração permanente
histórico de workflows
```

## Persistência

A instância usa AOF e RDB simultaneamente:

```text
appendonly yes
appendfsync everysec
save 3600 1
save 300 100
save 60 10000
```

O AOF é a representação mais completa usada na inicialização quando ambos
estão ativos.

## Limite de memória

```text
maxmemory 256mb
maxmemory-policy noeviction
```

Ao atingir o limite, escritas que precisam alocar memória podem falhar. Isso é
preferível a apagar silenciosamente locks, marcadores de idempotência ou
sessões.

Sinais que exigem ação:

```text
used_memory próximo de maxmemory
comandos rejeitados por OOM
latência crescente
aof_current_size crescendo continuamente
evicted_keys diferente de zero
```

Com `noeviction`, `evicted_keys` deve permanecer zero.

## Convenção de chaves

Formato:

```text
ssc:<domínio>:<escopo>:<identificador>
```

Exemplos:

```text
ssc:session:user:123
ssc:cache:project:abc
ssc:lock:workflow:456
ssc:idempotency:event:uuid
ssc:rate:login:ip:192.168.3.10
ssc:workflow:state:uuid
ssc:agent:heartbeat:agent-id
ssc:system:health:last-check
```

## TTL obrigatório

Toda chave temporária deve possuir TTL.

Referência inicial:

```text
session:             duração da sessão
cache:               5 a 60 minutos
lock:                30 segundos a 15 minutos
idempotência:        24 horas
rate limiting:       duração da janela
workflow temporário: duração do workflow com margem
heartbeat:           30 a 120 segundos
```

Chaves sem TTL deverão ser justificadas em documentação.

## Locks

Aquisição:

```text
SET <chave> <token-único> NX PX <tempo>
```

Liberação:

```text
comparar o token e remover atomicamente com Lua
```

Nunca remova um lock sem validar que o token ainda pertence ao mesmo processo.

## Idempotência

Aquisição inicial:

```text
SET ssc:idempotency:<tipo>:<id> <estado> NX EX 86400
```

Quando o comando retorna falso, o identificador já foi registrado.

O PostgreSQL deverá assumir esse papel quando a garantia precisar sobreviver por
tempo indefinido.

## Cache

O cache compartilha a instância de coordenação nesta fase. Portanto:

- todo cache deve ter TTL;
- o cache não poderá consumir memória sem limite;
- cargas grandes deverão usar MinIO ou PostgreSQL;
- a futura separação de instâncias permitirá usar uma política LRU.

## Banco lógico

O CompanyOS usa:

```text
DB 0
```

O isolamento é feito por namespace, não por bancos lógicos diferentes.

## Segurança

- senha somente no `.env`;
- `redis.conf` não contém senha;
- conexão sem autenticação é rejeitada;
- a porta do host permanece local;
- o serviço está na rede Docker de dados;
- valores não devem conter tokens ou senhas sem criptografia apropriada;
- comandos destrutivos não fazem parte dos scripts operacionais.

## Testes

```bash
./scripts/test-redis-integration.sh
```

Os testes usam somente:

```text
ssc:test:
```

As chaves temporárias são removidas ao final.

## Diagnóstico

Estado:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  ps redis
```

Logs:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  logs --tail=100 redis
```

Configuração efetiva sem exibir a senha:

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  exec -T redis sh -ec '
    export REDISCLI_AUTH="$REDIS_PASSWORD"
    redis-cli --no-auth-warning CONFIG GET \
      appendonly \
      appendfsync \
      maxmemory \
      maxmemory-policy \
      protected-mode \
      bind
  '
```

## Backup

O volume:

```text
ssc_redis_data
```

continua incluído no backup integrado do CompanyOS.

Não execute:

```text
docker compose down -v
```

Esse comando removeria volumes persistentes.
