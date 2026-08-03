# Configuração Redis

## Arquivo canônico

```text
redis.conf
```

O arquivo não contém senha.

Valores específicos do ambiente são passados pelo Compose:

```text
REDIS_PASSWORD
REDIS_MAXMEMORY
REDIS_MAXMEMORY_POLICY
```

## Instalação

```bash
./scripts/install-redis-configuration.sh
```

O instalador:

- cria backup privado;
- atualiza `compose.yaml`;
- atualiza `.env.example`;
- atualiza somente as variáveis necessárias do `.env`;
- preserva a permissão `600` do `.env`;
- valida o Compose;
- não reinicia o serviço.

## Implantação

```bash
./scripts/bootstrap-redis.sh
```

O bootstrap:

- cria um marcador temporário;
- confirma o fsync local com `WAITAOF`;
- recria somente o container Redis;
- preserva o volume;
- confirma o marcador após a recriação;
- remove o marcador;
- executa os testes funcionais.

## Testes

```bash
./scripts/test-redis-integration.sh
```

## Política de memória

```text
noeviction
```

A decisão protege dados de coordenação contra remoção automática.

O cache será separado em outra instância quando houver carga suficiente.
