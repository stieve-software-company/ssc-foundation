# Integração Oficial — Ollama no Windows e CompanyOS na VM

## Estado validado

```text
Windows:       192.168.3.18
VM Ubuntu:     192.168.3.19
Ollama:        http://192.168.3.18:11434
Modelo:        qwen2.5-coder:3b
Parâmetros:    3.1B
Quantização:   Q4_K_M
Contexto:      4096
Aceleração:    modelo integralmente na VRAM da RX 7600
```

A comunicação da VM com a API do Ollama já foi validada.

## Arquitetura

```text
Windows
├── RX 7600
└── Ollama
    └── qwen2.5-coder:3b
            │
            │ TCP 11434 permitido somente para 192.168.3.19
            ▼
Ubuntu Server / VirtualBox
└── CompanyOS
    ├── Mission Control
    ├── PostgreSQL
    ├── RabbitMQ
    ├── Redis
    └── MinIO
```

## Objetivo desta implantação

- manter o hardware fora do código;
- configurar o provedor por `.env`;
- validar a existência do modelo no painel;
- executar inferência real a partir da VM;
- confirmar uso da VRAM;
- permitir migração futura para Proxmox alterando apenas a configuração.

## Arquivos do pacote

```text
OLLAMA_EXTERNAL_INTEGRATION.md
.env.example
compose.access.yaml
apps/mission-control/app/config.py
apps/mission-control/app/system_status.py
scripts/configure-ollama-external.sh
scripts/test-ollama-integration.sh
```

## Variáveis adicionadas

```env
AI_PROVIDER=ollama
OLLAMA_DEPLOYMENT_MODE=external
OLLAMA_BASE_URL=http://192.168.3.18:11434
OLLAMA_MODEL=qwen2.5-coder:3b
OLLAMA_DEFAULT_MODEL=qwen2.5-coder:3b
OLLAMA_CONTEXT_LENGTH=4096
OLLAMA_KEEP_ALIVE=10m
OLLAMA_REQUEST_TIMEOUT_SECONDS=120
OLLAMA_VERIFY_MODEL=true
```

O IP real fica somente no `.env`, que continua fora do Git.

## Instalação

### 1. Backup

```bash
cd "$HOME/workspace/ssc-foundation"
./scripts/backup.sh --yes
```

### 2. Extrair o pacote

Copie `ollama_companyos_integration.zip` para a pasta compartilhada e execute:

```bash
cd "$HOME/workspace/ssc-foundation"

cp "/media/sf_ssc_share/ollama_companyos_integration.zip" .

unzip -o ollama_companyos_integration.zip

rm ollama_companyos_integration.zip
```

### 3. Permissões

```bash
chmod +x \
  scripts/configure-ollama-external.sh \
  scripts/test-ollama-integration.sh
```

### 4. Configurar o `.env`

```bash
./scripts/configure-ollama-external.sh \
  --url "http://192.168.3.18:11434" \
  --model "qwen2.5-coder:3b" \
  --context 4096 \
  --keep-alive "10m" \
  --timeout 120
```

O script:

- testa a API;
- confirma que o modelo existe;
- cria cópia privada do `.env`;
- altera somente variáveis do Ollama;
- preserva permissão `600`;
- não exibe senhas.

### 5. Validar os arquivos

```bash
python3 -m compileall -q apps/mission-control/app \
  && echo "[OK] Código Python válido"

docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  config --quiet \
  && echo "[OK] Compose válido"
```

### 6. Reconstruir o Mission Control

```bash
./scripts/start-access.sh
```

### 7. Testar a integração

```bash
./scripts/test-ollama-integration.sh
```

O teste verifica:

- API do Windows;
- versão do Ollama;
- modelo instalado;
- inferência real;
- modelo carregado;
- VRAM;
- acesso a partir do container Mission Control;
- health check do Mission Control.

## Resultado esperado

```text
[OK] API do Ollama respondeu.
[OK] Modelo qwen2.5-coder:3b disponível.
[OK] Inferência concluída.
[OK] Modelo carregado integralmente na GPU.
[OK] Mission Control acessa o Ollama.
[OK] Integração Ollama concluída.
```

## Validação no painel

Acesse:

```text
http://192.168.3.19:8080
```

Depois:

```text
Sistema
```

O cartão do Ollama deverá mostrar o modelo configurado e a versão do servidor.

## Segurança

A porta `11434` não deve ser encaminhada no roteador.

A regra do Firewall do Windows deve continuar restrita a:

```text
origem:  192.168.3.19
destino: 192.168.3.18
porta:   TCP 11434
```

A API do Ollama não deve ser exposta diretamente à internet.

## Migração futura

No Proxmox, o código continuará igual. Será necessário alterar apenas:

```env
OLLAMA_BASE_URL=http://NOVO-ENDERECO:11434
```

ou, caso o Ollama esteja em uma rede Docker:

```env
OLLAMA_BASE_URL=http://ollama:11434
```

## Rollback

A configuração anterior do `.env` fica em:

```text
infrastructure/backups/config/
```

Para reverter os arquivos versionados antes do commit:

```bash
git restore \
  .env.example \
  compose.access.yaml \
  apps/mission-control/app/config.py \
  apps/mission-control/app/system_status.py

rm -f \
  OLLAMA_EXTERNAL_INTEGRATION.md \
  scripts/configure-ollama-external.sh \
  scripts/test-ollama-integration.sh
```

O `.env` deve ser restaurado manualmente a partir da cópia privada mais recente.

## Critérios de conclusão

- [ ] arquivos instalados;
- [ ] `.env` configurado;
- [ ] Compose validado;
- [ ] Mission Control reconstruído;
- [ ] API acessível a partir do container;
- [ ] modelo encontrado;
- [ ] inferência concluída;
- [ ] uso de VRAM confirmado;
- [ ] painel Sistema mostra Ollama saudável;
- [ ] `.env` continua ignorado pelo Git;
- [ ] alterações versionadas.
