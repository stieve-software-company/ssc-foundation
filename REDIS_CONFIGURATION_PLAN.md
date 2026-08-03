# Sprint 1.2 — Plano de Configuração do Redis

## Auditoria confirmada

```text
Redis:                  8.8.1
Autenticação:           ativa
Usuário autenticado:    default
Chaves existentes:      0
Volume:                  ssc_redis_data
AOF:                     ativo
appendfsync:             everysec
RDB:                     ativo
Memória máxima:          256 MB
Política atual:          allkeys-lru
protected-mode:          no
bind:                    * -::*
Conexões rejeitadas:     0
Evictions:               0
Persistência:            saudável
```

## Leitura da auditoria

### Persistência

A configuração atual já combina:

```text
AOF
RDB
```

O AOF usa:

```text
appendfsync everysec
aof-use-rdb-preamble yes
```

A configuração será preservada e transferida para um arquivo `redis.conf`
versionado.

### Fragmentação

A auditoria mostrou:

```text
used_memory:             aproximadamente 853 KB
used_memory_rss:         aproximadamente 9.7 MB
mem_fragmentation_ratio: 11.90
```

Esse índice elevado ocorre com um conjunto de dados praticamente vazio. O valor
será acompanhado quando o Redis tiver uma carga real, sem ajuste prematuro.

### Segurança

O Redis está protegido por senha e a porta do host permanece vinculada ao
endereço local definido pelo Compose.

A configuração oficial adicionará:

```text
protected-mode yes
bind 0.0.0.0
```

O bind em todas as interfaces é interno ao container. O acesso externo continua
limitado pelo bind do Docker e pelas redes do Compose.

## Decisão de eviction

A política atual é:

```text
allkeys-lru
```

Ela é adequada para cache puro, mas o Redis do CompanyOS também será usado para:

```text
locks
idempotência
sessões
rate limiting
estado temporário
heartbeats
```

A eviction silenciosa de uma chave de lock ou idempotência pode comprometer a
correção de um fluxo.

A política desta etapa será:

```text
noeviction
```

Ao atingir o limite, escritas que exigem mais memória falharão de forma visível,
sem apagar chaves existentes.

## Evolução planejada

Quando a carga justificar, o serviço será separado em:

```text
redis-coordination   noeviction
redis-cache          allkeys-lru ou allkeys-lfu
```

## Configuração-alvo

```text
appendonly yes
appendfsync everysec
aof-use-rdb-preamble yes
save 3600 1
save 300 100
save 60 10000
maxmemory 256mb
maxmemory-policy noeviction
protected-mode yes
bind 0.0.0.0
maxclients 200
```

## Namespaces

```text
ssc:session:
ssc:cache:
ssc:lock:
ssc:idempotency:
ssc:rate:
ssc:workflow:
ssc:agent:
ssc:system:
ssc:test:
```

## Arquivos

```text
REDIS_CONFIGURATION_PLAN.md
REDIS_OPERATIONS.md
infrastructure/config/redis/README.md
infrastructure/config/redis/redis.conf
scripts/install-redis-configuration.sh
scripts/bootstrap-redis.sh
scripts/test-redis-integration.sh
```

## Implantação

```text
1. backup integrado
2. instalação dos arquivos
3. atualização controlada de compose.yaml
4. atualização de .env.example
5. atualização privada do .env
6. marcador temporário de persistência
7. WAITAOF local
8. recriação somente do Redis
9. confirmação do marcador
10. testes funcionais pelo Mission Control
```

## Critérios de conclusão

- [ ] configuração instalada;
- [ ] Compose válido;
- [ ] `.env` permanece privado;
- [ ] Redis recriado sem remover o volume;
- [ ] AOF validado;
- [ ] RDB validado;
- [ ] persistência após recriação validada;
- [ ] política `noeviction` validada;
- [ ] autenticação validada;
- [ ] acesso sem senha rejeitado;
- [ ] namespaces validados;
- [ ] TTL validado;
- [ ] lock validado;
- [ ] idempotência validada;
- [ ] incremento atômico validado;
- [ ] Mission Control conectado;
- [ ] nenhum segredo no Git;
- [ ] commit enviado ao GitHub.
