# Mission Control v0.3.0 — CompanyOS Assistant

## Base utilizada

A implementação é incremental sobre:

```text
Mission Control v0.2.1
Aparência instalada
branding_settings preservada
logo e temas preservados
```

O pacote não remove nem substitui o módulo de branding.

## Escopo

O CompanyOS Assistant permite consultar informações reais do
ambiente usando linguagem natural.

Primeira versão:

```text
somente leitura
sem criação de usuários
sem alteração de usuários
sem comandos de infraestrutura
```

## Ferramentas

```text
assistant.help
system.get_status
system.get_service
users.list
users.get
users.count
roles.list
roles.get
audit.list_recent
audit.count
```

## Exemplos

```text
Como estão os serviços?
O Redis está saudável?
Liste os usuários ativos.
Liste os usuários inativos.
Quantos usuários existem?
Procure o usuário maria.
Liste os perfis de acesso.
Mostre o perfil Operador.
Mostre os últimos eventos de auditoria.
Quantos eventos existem na auditoria?
```

## Arquitetura

```text
Usuário
   ↓
Interface Assistant
   ↓
Sessão + CSRF + RBAC + rate limiting
   ↓
Regras seguras ou Ollama
   ↓
Tool Registry
   ↓
SQLAlchemy / collect_statuses
   ↓
Componente visual
   ↓
Auditoria
```

## Princípio

```text
LLM interpreta.
Aplicação valida.
Ferramenta conhecida executa.
Auditoria registra.
```

## Integração com Ollama

Configuração já existente:

```text
Provider: Ollama
Modelo: qwen2.5-coder:3b
Contexto: 4096
Host: Windows com RX 7600
```

O modelo retorna apenas uma decisão JSON:

```json
{
  "type": "tool_call",
  "tool": "system.get_status",
  "arguments": {}
}
```

Perguntas comuns são reconhecidas também por regras locais seguras.
Isso mantém consultas básicas disponíveis quando o Ollama estiver
temporariamente indisponível.

O backend sempre produz os dados reais.

## Permissão

Nova permissão:

```text
assistant.use
```

Perfis que a recebem:

```text
admin
manager
operator
viewer
```

Cada ferramenta ainda exige a permissão do recurso:

```text
system.get_status → assistant.use + system.view
users.list        → assistant.use + users.view
roles.list        → assistant.use + roles.view
audit.list_recent → assistant.use + audit.view
```

Portanto, `assistant.use` não amplia sozinho o acesso do usuário.

## Rate limiting

```text
20 mensagens por minuto por usuário
Redis como backend principal
memória do processo como fallback
```

O fallback impede que uma falha no Redis derrube totalmente a
interface do Assistant.

## Dados permitidos de usuários

```text
username
nome
e-mail
perfil
status
último login
data de criação
```

## Dados proibidos

```text
password_hash
session_version
cookies
tokens
segredos
DATABASE_URL
REDIS_URL
RABBITMQ_URL
conteúdo do .env
```

## Segurança

O modelo não pode:

```text
executar shell
executar Docker
acessar Docker Socket
criar SQL
acessar diretamente o banco
ler o filesystem
ler o .env
alterar usuários
reiniciar serviços
```

A interface não usa `innerHTML`. Componentes são criados com
`textContent`, reduzindo risco de injeção de HTML.

## Auditoria

Eventos:

```text
assistant.message.received
assistant.message.responded
assistant.message.rejected
assistant.tool.executed
assistant.tool.denied
assistant.tool.failed
assistant.rate_limited
```

A mensagem completa não é armazenada pela auditoria.

São registrados somente dados operacionais, como:

```text
tamanho da mensagem
ferramenta
provedor
resultado
código de erro
request_id
```

## Interface

A tela contém:

```text
conversa
atalhos
cartão do modelo
status dos serviços
tabelas de usuários
tabelas de perfis
tabela de auditoria
resumos numéricos
mensagens de erro
```

A tela utiliza automaticamente a logo e o tema configurados na aba
`Aparência`.

## Arquivos novos

```text
apps/mission-control/app/assistant/__init__.py
apps/mission-control/app/assistant/orchestrator.py
apps/mission-control/app/assistant/provider.py
apps/mission-control/app/assistant/rate_limit.py
apps/mission-control/app/assistant/routes.py
apps/mission-control/app/assistant/schemas.py
apps/mission-control/app/assistant/tools.py
apps/mission-control/app/templates/assistant.html
apps/mission-control/app/static/assistant.css
apps/mission-control/app/static/assistant.js
scripts/install-mission-control-assistant.sh
scripts/bootstrap-mission-control-assistant.sh
scripts/test-mission-control-assistant.sh
```

## Arquivos modificados pelo instalador

```text
apps/mission-control/app/main.py
apps/mission-control/app/bootstrap.py
apps/mission-control/app/templates/base.html
```

O instalador não modifica:

```text
models.py
branding/
branding.html
branding-global.css
branding-page.css
branding-page.js
login.html
```

## Banco de dados

Esta fase não cria tabelas do Assistant.

Apenas a permissão `assistant.use` é adicionada à tabela de
permissões existente.

O histórico persistente de conversas será avaliado posteriormente.

## Versão

```text
Mission Control v0.3.0
```

## Próxima fase

Mission Control v0.3.1:

```text
users.create
users.activate
users.deactivate
users.change_role
ação proposta
confirmação explícita
expiração
formulário seguro para senha
```
