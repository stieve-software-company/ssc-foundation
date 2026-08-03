# Sprint 1.2 — Baseline da Infraestrutura

## Data da auditoria

```text
2026-08-03
```

## Objetivo

Registrar o estado real da infraestrutura antes das configurações da Sprint 1.2.

## Git

Estado:

```text
working tree clean
```

Últimos commits:

```text
8cc0058 fix: include Mission Control in integrated backups
063ea90 feat: upgrade Mission Control with users roles and system dashboard
96527e4 feat: add first Mission Control login screen
ae3ff6c docs: conclude Sprint 1.1 and start Sprint 1.2
```

Conclusão:

- repositório local limpo;
- branch `main`;
- branch sincronizada com `origin/main`;
- Mission Control v0.2 e correção do backup versionados.

## Sistema operacional

Hostname:

```text
stieve-software-company
```

Kernel:

```text
Linux 7.0.0-28-generic x86_64 GNU/Linux
```

IP principal da VM:

```text
192.168.3.19
```

## Recursos da VM

Memória:

```text
Total:      14 GiB
Disponível: 13 GiB
Swap:       0 B
```

Disco raiz:

```text
Total:      49 GiB
Usado:      8.8 GiB
Disponível: 38 GiB
Uso:        19%
```

Conclusão:

- memória disponível suficiente para a infraestrutura atual;
- espaço em disco adequado;
- não existe swap configurada;
- escolha do primeiro modelo de IA deverá considerar os 14 GiB de RAM e o hardware gráfico disponível.

## Docker

Versões:

```text
Docker Engine: 29.7.1
Docker Compose: v5.3.1
```

## Containers ativos

```text
minio             healthy
mission-control   healthy
postgres          healthy
rabbitmq          healthy
redis             healthy
```

Mission Control:

```text
porta:    8080
bind:     0.0.0.0
versão:   0.2.0
database: connected
```

Health check:

```json
{
  "status": "healthy",
  "service": "ssc-mission-control",
  "version": "0.2.0",
  "database": "connected"
}
```

## Volumes persistentes

```text
ssc_minio_data
ssc_postgres_data
ssc_rabbitmq_data
ssc_redis_data
```

Todos os volumes estão associados ao projeto Compose `ssc`.

## Redes Docker

```text
ssc_application
ssc_data
ssc_public
```

Ainda não foram criadas em execução:

```text
ssc_execution
ssc_observability
```

Essas redes serão utilizadas quando os perfis de IA e observabilidade forem ativados.

## Exposição de portas

Portas visíveis no host:

```text
127.0.0.1:11434  Ollama
0.0.0.0:8080     Mission Control
```

Os serviços de dados não estão publicados externamente neste momento:

```text
PostgreSQL
RabbitMQ
Redis
MinIO
```

Eles estão acessíveis somente pelas redes Docker internas, o que reduz a superfície de exposição.

## Ollama

Estado do serviço:

```text
active
```

Endpoint local:

```text
http://127.0.0.1:11434
```

Modelos instalados:

```text
0
```

Situação atual:

- Ollama instalado diretamente na VM;
- serviço ativo;
- API respondendo;
- nenhum modelo baixado;
- escutando somente em `127.0.0.1`;
- containers ainda não conseguem acessar a API por `host.docker.internal`.

## Decisão preliminar para o Ollama

O serviço existente será preservado.

Antes de alterá-lo, será necessário:

1. identificar versão do Ollama;
2. identificar CPU;
3. identificar GPU;
4. verificar a unidade systemd;
5. definir um endereço seguro para acesso dos containers;
6. selecionar o primeiro modelo compatível;
7. testar inferência local;
8. testar inferência a partir do Mission Control.

Não será criado um segundo Ollama em container enquanto o serviço da VM puder atender à arquitetura.

## Riscos identificados

### Ausência de swap

A VM não possui swap.

Isso pode aumentar o risco de encerramento de processos por falta de memória durante:

- carregamento de modelos maiores;
- builds simultâneos;
- observabilidade completa;
- múltiplos agentes em execução.

A necessidade de swap será avaliada após identificar o modelo inicial.

### Ollama limitado ao localhost

Ollama escuta somente em:

```text
127.0.0.1:11434
```

Essa configuração é segura para o host, mas impede acesso direto pelos containers.

A correção deverá evitar exposição desnecessária à rede local.

### Nenhum modelo instalado

Ainda não é possível executar agentes ou testes reais de inferência.

## Estado da Sprint 1.2

```text
Baseline de infraestrutura: concluído
Estrutura de configuração: próximo passo
Integração Ollama: pendente
Observabilidade: pendente
Topologia RabbitMQ: pendente
Buckets MinIO: pendente
Configuração Redis: pendente
Configuração PostgreSQL: pendente
```

## Próxima atividade

Executar a auditoria de hardware e da instalação do Ollama para escolher a estratégia de integração e o primeiro modelo.
