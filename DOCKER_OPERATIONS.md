# Operações Docker do CompanyOS

## 1. Objetivo

Este documento descreve como preparar, validar, iniciar, interromper, monitorar, atualizar, copiar e restaurar a infraestrutura Docker do CompanyOS.

A infraestrutura desta etapa fornece os serviços básicos para as próximas fases da plataforma:

- PostgreSQL;
- RabbitMQ;
- Redis;
- MinIO;
- Ollama, como perfil opcional;
- Prometheus, Loki e Grafana, como perfil opcional de observabilidade.

A operação deve ser feita a partir da raiz do repositório:

```bash
cd "$HOME/workspace/ssc-foundation"
```

---

## 2. Arquivos da infraestrutura

A estrutura operacional da Sprint 1.1 é composta por:

```text
ssc-foundation/
├── .env
├── .env.example
├── .gitignore
├── compose.yaml
├── Makefile
├── DOCKER_OPERATIONS.md
├── data/
│   ├── artifacts/
│   ├── temporary/
│   └── workspaces/
├── infrastructure/
│   ├── backups/
│   │   ├── archives/
│   │   ├── restore-reports/
│   │   └── update-snapshots/
│   └── config/
└── scripts/
    ├── backup.sh
    ├── bootstrap.sh
    ├── logs.sh
    ├── restart.sh
    ├── restore.sh
    ├── start.sh
    ├── status.sh
    ├── stop.sh
    ├── update.sh
    └── validate.sh
```

Os diretórios de dados e backup podem não aparecer no Git quando estão vazios ou ignorados.

---

## 3. Requisitos

A máquina deve possuir:

- Ubuntu Server;
- Git;
- Docker Engine;
- Docker Compose;
- usuário com acesso ao Docker;
- pelo menos 10 GB livres em disco;
- 4 GB de memória para os serviços básicos;
- 8 GB ou mais para executar também IA e observabilidade.

Verifique o ambiente com:

```bash
docker version
docker compose version
git --version
```

Verifique o acesso ao daemon:

```bash
docker info
```

O comando deve funcionar sem `sudo`.

---

## 4. Arquivos de ambiente

### 4.1 `.env.example`

O `.env.example` é público e deve ser versionado no Git.

Ele contém:

- nomes das variáveis;
- portas;
- versões das imagens;
- valores de exemplo;
- placeholders `CHANGE_ME`.

Ele nunca deve conter credenciais reais.

### 4.2 `.env`

O `.env` contém as configurações privadas da instalação.

Ele deve:

- existir somente na máquina de execução;
- possuir permissão `600`;
- estar ignorado pelo Git;
- não conter `CHANGE_ME`;
- não ser enviado ao GitHub;
- não ser incluído em backups do projeto.

Verifique as permissões:

```bash
stat -c '%a %n' .env
```

Resultado esperado:

```text
600 .env
```

Confirme a proteção do Git:

```bash
git check-ignore -v .env
```

Confirme que ele não está rastreado:

```bash
git ls-files --error-unmatch .env
```

O último comando deve terminar informando que o arquivo não é conhecido pelo Git.

---

## 5. Serviços

### 5.1 Serviços básicos

Os serviços básicos são iniciados por padrão:

| Serviço | Função |
|---|---|
| PostgreSQL | Banco de dados relacional principal |
| RabbitMQ | Barramento de eventos e mensageria |
| Redis | Cache, estados temporários e coordenação |
| MinIO | Armazenamento de artefatos e objetos |

### 5.2 Perfil `ai`

O perfil `ai` contém:

| Serviço | Função |
|---|---|
| Ollama | Execução local de modelos de linguagem |

Esse perfil não é iniciado pelo `start.sh`.

Nesta instalação, a porta `11434` já está ocupada por um Ollama existente. Isso é esperado e não afeta os serviços básicos.

Antes de iniciar o Ollama pelo Compose, verifique o processo existente:

```bash
sudo ss -lntp | grep ':11434'
```

Também pode ser útil verificar:

```bash
systemctl status ollama
```

Não execute dois serviços Ollama na mesma porta.

### 5.3 Perfil `observability`

O perfil `observability` contém:

| Serviço | Função |
|---|---|
| Prometheus | Coleta de métricas |
| Loki | Armazenamento de logs |
| Grafana | Painéis e visualização |

Esse perfil não é iniciado nesta sprint.

A configuração de métricas, fontes de dados e painéis será concluída na Sprint 1.2 antes do uso operacional desse perfil.

---

## 6. Preparação inicial

Execute o bootstrap:

```bash
./scripts/bootstrap.sh
```

Ou use:

```bash
make bootstrap
```

O bootstrap:

1. verifica Docker e Docker Compose;
2. verifica os arquivos obrigatórios;
3. cria os diretórios necessários;
4. protege o `.env`;
5. confirma que o `.env` está ignorado;
6. valida o `compose.yaml`;
7. não inicia containers.

Depois execute a validação completa:

```bash
./scripts/validate.sh
```

Ou:

```bash
make check
```

O resultado esperado deve terminar com:

```text
Erros:  0
```

O aviso sobre a porta `11434` é aceito enquanto o perfil `ai` permanecer desligado.

---

## 7. Operações principais

### 7.1 Ajuda

Liste os comandos disponíveis:

```bash
make help
```

### 7.2 Iniciar

Inicie os serviços básicos:

```bash
make start
```

Comando equivalente:

```bash
./scripts/start.sh
```

O processo:

1. executa a validação;
2. inicia PostgreSQL, RabbitMQ, Redis e MinIO;
3. aguarda os health checks;
4. confirma que todos estão saudáveis.

Resultado esperado:

```text
postgres: healthy
rabbitmq: healthy
redis: healthy
minio: healthy
```

### 7.3 Parar

Interrompa os serviços básicos:

```bash
make stop
```

Comando equivalente:

```bash
./scripts/stop.sh
```

Os containers e volumes são preservados.

### 7.4 Reiniciar

Execute uma reinicialização controlada:

```bash
make restart
```

Comando equivalente:

```bash
./scripts/restart.sh
```

O script chama `stop.sh`, aguarda a liberação dos recursos e chama `start.sh`.

### 7.5 Consultar o estado

```bash
make status
```

Comando equivalente:

```bash
./scripts/status.sh
```

O relatório mostra:

- containers;
- estado;
- saúde;
- CPU;
- memória;
- redes;
- volumes;
- armazenamento;
- portas;
- perfis configurados.

Resumo esperado:

```text
Containers em execução: 4
Containers unhealthy:   0
```

### 7.6 Exibir containers

```bash
make ps
```

### 7.7 Listar serviços

```bash
make compose-services
```

### 7.8 Listar perfis

```bash
make compose-profiles
```

### 7.9 Validar o Compose

```bash
make compose-config
```

---

## 8. Logs

### 8.1 Todos os serviços

```bash
make logs
```

O padrão é exibir as últimas 100 linhas.

Para alterar a quantidade:

```bash
make logs TAIL=200
```

### 8.2 Serviço específico

```bash
make logs-service SERVICE=postgres
```

Exemplo com mais linhas:

```bash
make logs-service SERVICE=rabbitmq TAIL=300
```

### 8.3 Acompanhamento em tempo real

Use diretamente o script:

```bash
./scripts/logs.sh minio --follow
```

Finalize com:

```text
Ctrl + C
```

### 8.4 Listar nomes válidos

```bash
./scripts/logs.sh --list
```

---

## 9. Atualização

O script de atualização não altera automaticamente as versões declaradas no `.env`.

Para mudar uma versão:

1. revise a nova versão;
2. altere a variável de imagem correspondente no `.env`;
3. altere também o `.env.example` quando a versão passar a ser o padrão oficial;
4. execute a validação;
5. faça backup;
6. execute a atualização.

### 9.1 Atualizar serviços básicos

```bash
make update
```

Sem confirmação interativa:

```bash
make update-yes
```

### 9.2 Fluxo da atualização

O processo:

1. valida o ambiente;
2. registra as imagens atuais;
3. cria um snapshot em `infrastructure/backups/update-snapshots`;
4. baixa as imagens configuradas;
5. recria os serviços selecionados;
6. preserva volumes;
7. aguarda os health checks;
8. registra o estado final.

### 9.3 Perfis opcionais

Existem comandos para:

```bash
make update-ai
make update-observability
make update-all
```

Eles não devem ser usados nesta etapa:

- o Ollama já ocupa a porta `11434`;
- a observabilidade ainda receberá seus arquivos de configuração;
- `update-all` inclui ambos os perfis.

---

## 10. Backup

### 10.1 Criar backup

```bash
make backup
```

Sem confirmação:

```bash
make backup-yes
```

O backup:

1. valida o ambiente;
2. identifica os serviços ativos;
3. identifica os volumes do projeto;
4. baixa a imagem auxiliar antes da parada;
5. interrompe os serviços ativos;
6. compacta cada volume;
7. valida cada arquivo;
8. gera checksums SHA-256;
9. reinicia os serviços que estavam ativos;
10. confirma os health checks.

### 10.2 Local dos backups

```text
infrastructure/backups/archives/AAAA-MM-DD_HH-MM-SS/
```

Estrutura:

```text
AAAA-MM-DD_HH-MM-SS/
├── checksums.sha256
├── metadata/
│   ├── .env.example
│   ├── compose.yaml
│   ├── containers-after.txt
│   ├── containers-before.txt
│   ├── docker-version.txt
│   └── manifest.env
└── volumes/
    ├── ssc_minio_data.tar.gz
    ├── ssc_postgres_data.tar.gz
    ├── ssc_rabbitmq_data.tar.gz
    └── ssc_redis_data.tar.gz
```

O `.env` real não é copiado.

### 10.3 Backup mantendo os serviços parados

```bash
make backup-no-restart
```

Use apenas quando houver manutenção logo depois.

### 10.4 Conferir o último backup

```bash
LAST_BACKUP="$(
  find infrastructure/backups/archives \
    -mindepth 1 \
    -maxdepth 1 \
    -type d \
    | sort \
    | tail -n 1
)"

echo "$LAST_BACKUP"
find "$LAST_BACKUP" -maxdepth 2 -type f -printf '%p %k KB\n'
```

---

## 11. Restauração

A restauração substitui o conteúdo atual dos volumes selecionados.

### 11.1 Listar backups

```bash
make restore-list
```

Ou:

```bash
./scripts/restore.sh --list
```

### 11.2 Restaurar o backup mais recente

```bash
make restore-latest
```

Quando solicitado, digite:

```text
RESTAURAR
```

### 11.3 Proteções da restauração

Antes de alterar os volumes, o script:

1. valida o manifesto;
2. confirma que o backup foi concluído;
3. verifica os checksums;
4. testa os arquivos compactados;
5. rejeita caminhos inseguros;
6. confirma a identidade do projeto;
7. cria um backup de segurança do estado atual;
8. para os serviços;
9. restaura os volumes;
10. reinicia os serviços anteriormente ativos;
11. aguarda os health checks;
12. cria um relatório.

### 11.4 Relatórios

Os relatórios ficam em:

```text
infrastructure/backups/restore-reports/
```

### 11.5 Restauração sem confirmação

Existe o comando:

```bash
make restore-latest-yes
```

Use somente em automações controladas. Em operação manual, prefira `make restore-latest`.

---

## 12. Volumes

Liste os volumes do projeto:

```bash
make volumes
```

Os volumes principais são:

```text
ssc_postgres_data
ssc_rabbitmq_data
ssc_redis_data
ssc_minio_data
```

Os perfis opcionais possuem volumes próprios, que serão criados quando ativados.

Nunca execute:

```bash
docker compose down -v
```

A opção `-v` remove os volumes e pode apagar permanentemente os dados.

Também não remova volumes manualmente sem um backup validado.

---

## 13. Redes

Liste as redes do projeto:

```bash
make networks
```

A arquitetura prevê redes separadas para:

- exposição pública;
- aplicação;
- dados;
- execução;
- observabilidade.

Essa separação reduz o acesso desnecessário entre componentes.

---

## 14. Segurança operacional

Regras obrigatórias:

1. Nunca versionar `.env`.
2. Nunca colar senhas em issues, commits ou documentação.
3. Manter `.env` com permissão `600`.
4. Executar `make check` antes de iniciar ou atualizar.
5. Criar backup antes de alterações de imagem ou configuração.
6. Não expor portas em `0.0.0.0` sem necessidade e proteção.
7. Não usar tags `latest`.
8. Não executar `docker compose down -v`.
9. Não editar arquivos dentro dos volumes diretamente.
10. Não ativar perfis opcionais sem validar suas dependências.

Verificação rápida:

```bash
make security-check
```

---

## 15. Rotina recomendada

### 15.1 Início do trabalho

```bash
cd "$HOME/workspace/ssc-foundation"
make check
make start
make status
```

### 15.2 Durante o trabalho

```bash
make status
make logs-service SERVICE=postgres
```

### 15.3 Antes de manutenção

```bash
make backup
make status
```

### 15.4 Depois de manutenção

```bash
make check
make start
make status
```

### 15.5 Encerrar a VM

```bash
make stop
```

Depois confirme:

```bash
make ps
```

---

## 16. Solução de problemas

### 16.1 Porta `11434` ocupada

Sintoma:

```text
[AVISO] Porta 11434 já está em uso.
```

Causa esperada:

- Ollama já instalado e ativo fora do Compose.

Diagnóstico:

```bash
sudo ss -lntp | grep ':11434'
systemctl status ollama
```

Ação:

- mantenha o perfil `ai` desligado;
- não execute `make update-ai`;
- não execute `make update-all`;
- decida na Sprint 1.2 se o Ollama existente será integrado ou substituído.

### 16.2 Serviço unhealthy

Consulte:

```bash
make status
make logs-service SERVICE=postgres TAIL=300
```

Substitua `postgres` pelo serviço afetado.

Tente uma reinicialização controlada:

```bash
make restart
```

Não remova volumes como primeira tentativa.

### 16.3 Docker daemon inacessível

Verifique:

```bash
systemctl status docker
```

Inicie quando necessário:

```bash
sudo systemctl start docker
```

Teste:

```bash
docker info
```

### 16.4 Permissão negada no Docker

Verifique os grupos do usuário:

```bash
groups
```

O grupo `docker` deve aparecer.

Quando o usuário tiver sido adicionado recentemente ao grupo, encerre a sessão SSH e entre novamente.

### 16.5 `.env` com permissão incorreta

Corrija:

```bash
chmod 600 .env
```

### 16.6 `.env` rastreado pelo Git

Não envie o commit.

Remova somente do índice, preservando o arquivo local:

```bash
git rm --cached .env
```

Confirme que `.env` está no `.gitignore` e execute:

```bash
make security-check
```

Caso uma credencial real já tenha sido enviada ao GitHub, ela deve ser substituída imediatamente.

### 16.7 Porta de serviço básico ocupada

Identifique o processo:

```bash
sudo ss -lntp
```

Não encerre processos desconhecidos sem confirmar sua função.

A solução pode ser:

- parar o serviço conflitante;
- escolher outra porta no `.env`;
- validar novamente com `make check`.

### 16.8 Pouco espaço em disco

Verifique:

```bash
df -h
docker system df
```

Consulte imagens sem uso:

```bash
docker image ls
```

Não execute limpezas agressivas sem verificar o que será removido.

### 16.9 Backup interrompido

O script tenta reiniciar os serviços automaticamente quando a falha ocorre antes ou durante a cópia.

Depois da falha:

```bash
make status
make logs
```

Um diretório parcial pode permanecer em:

```text
infrastructure/backups/archives/
```

Não use um backup cujo manifesto não tenha:

```text
status=success
```

### 16.10 Restauração interrompida

Quando um volume já foi alterado, o script mantém os serviços parados para evitar inicialização com dados incompletos.

Consulte a mensagem final e o relatório em:

```text
infrastructure/backups/restore-reports/
```

Use o backup de segurança criado automaticamente para recuperar o estado anterior.

---

## 17. Git

Arquivos que devem ser versionados:

```text
.env.example
.gitignore
compose.yaml
Makefile
DOCKER_OPERATIONS.md
scripts/*.sh
```

Arquivos que não devem ser versionados:

```text
.env
infrastructure/backups/
data/
logs/
segredos
arquivos temporários
```

Confira antes de cada commit:

```bash
git status
git diff --cached
```

Adicione arquivos explicitamente:

```bash
git add DOCKER_OPERATIONS.md
```

Evite adicionar arquivos indiscriminadamente durante a implantação.

---

## 18. Critérios de conclusão da Sprint 1.1

A Sprint 1.1 é considerada concluída quando:

- [x] `.gitignore` protege dados locais e credenciais;
- [x] `.env.example` documenta as variáveis;
- [x] `.env` privado foi criado;
- [x] `compose.yaml` foi validado;
- [x] bootstrap foi executado;
- [x] validação terminou com zero erros;
- [x] PostgreSQL está healthy;
- [x] RabbitMQ está healthy;
- [x] Redis está healthy;
- [x] MinIO está healthy;
- [x] parada e reinicialização foram testadas;
- [x] consulta de status foi testada;
- [x] consulta de logs foi disponibilizada;
- [x] atualização controlada foi disponibilizada;
- [x] backup foi executado;
- [x] restauração foi executada;
- [x] Makefile centraliza as operações;
- [x] documentação operacional foi criada.

---

## 19. Próxima etapa

A próxima etapa é a Sprint 1.2 — Serviços de Infraestrutura.

Ela deverá incluir:

- configurações persistentes dos serviços;
- convenções de exchanges, filas e routing keys;
- bancos e schemas iniciais;
- buckets e políticas do MinIO;
- integração com o Ollama existente;
- configuração do Prometheus;
- configuração do Loki;
- configuração do Grafana;
- testes de conectividade entre serviços;
- health checks de infraestrutura;
- documentação dos contratos operacionais.

---

## 20. Referência rápida

```bash
make help
make bootstrap
make check
make start
make stop
make restart
make status
make ps
make logs
make logs-service SERVICE=postgres TAIL=200
make update
make backup
make restore-list
make restore-latest
make volumes
make networks
make git-status
```

Estado esperado da infraestrutura básica:

```text
PostgreSQL  healthy
RabbitMQ    healthy
Redis       healthy
MinIO       healthy
Ollama      não iniciado pelo Compose
Prometheus  não iniciado
Loki        não iniciado
Grafana     não iniciado
```
