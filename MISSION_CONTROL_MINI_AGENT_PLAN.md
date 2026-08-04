# Mission Control v0.3 — Mini Agent Operacional

## Visão

Adicionar ao Mission Control um assistente interno capaz de responder perguntas
sobre o ambiente e executar operações administrativas autorizadas.

Exemplos:

```text
Qual é o status dos serviços?
O Redis está saudável?
Quais usuários estão ativos?
Liste os administradores.
Quantos eventos de auditoria ocorreram hoje?
Crie um usuário para Maria.
Desative o usuário joao.
```

## Nome inicial

```text
CompanyOS Assistant
```

Nome curto na interface:

```text
Assistant
```

## Objetivo da versão 0.3

Entregar um mini agent que:

- converse em linguagem natural;
- consulte dados reais do Mission Control;
- apresente status dos serviços;
- liste usuários e perfis;
- consulte auditoria;
- proponha operações administrativas;
- execute operações somente após autorização;
- respeite RBAC;
- registre tudo na auditoria;
- use o Ollama externo já integrado;
- nunca execute shell livre;
- nunca receba acesso ao Docker Socket;
- nunca entregue segredos ao modelo.

## Arquitetura

```text
Usuário
   │
   ▼
Mission Control UI
   │
   ▼
Assistant API
   │
   ├── autenticação da sessão
   ├── RBAC
   ├── CSRF
   ├── rate limiting
   ├── validação da mensagem
   └── contexto seguro
         │
         ▼
    Ollama / qwen2.5-coder:3b
         │
         ▼
    Tool Call estruturada
         │
         ▼
    Tool Registry do Mission Control
         │
         ├── status dos serviços
         ├── usuários
         ├── perfis e permissões
         ├── auditoria
         └── operações administrativas
```

O modelo não executa ações diretamente.

Ele apenas pode solicitar uma ferramenta conhecida por meio de uma estrutura
validada pela aplicação.

## Princípio central

```text
LLM interpreta.
Aplicação valida.
Usuário confirma.
Serviço executa.
Auditoria registra.
```

## Ferramentas da primeira versão

### Ferramentas somente de leitura

```text
system.get_status
system.get_service
users.list
users.get
users.count
roles.list
roles.get
audit.list_recent
audit.count
assistant.help
```

### Ferramentas de alteração

```text
users.create
users.activate
users.deactivate
users.change_role
users.reset_password
```

As ferramentas de alteração somente serão habilitadas depois que a camada de
confirmação estiver validada.

## Exemplos

### Status geral

Pergunta:

```text
Como estão os serviços?
```

Fluxo:

```text
1. modelo identifica system.get_status;
2. aplicação valida dashboard.view;
3. collect_statuses consulta os serviços;
4. resposta é montada com dados reais;
5. auditoria registra assistant.tool.executed.
```

Resposta esperada:

```text
Todos os serviços estão disponíveis.

Mission Control: saudável
PostgreSQL: disponível
RabbitMQ: disponível
Redis: disponível
MinIO: disponível
Ollama: disponível
```

### Listagem de usuários

Pergunta:

```text
Liste os usuários ativos.
```

Fluxo:

```text
1. modelo identifica users.list;
2. aplicação exige users.view;
3. consulta SQLAlchemy é executada;
4. campos sensíveis são removidos;
5. resultado é apresentado.
```

Campos permitidos:

```text
id
username
nome
e-mail
perfil
ativo
último login
criado em
```

Campos proibidos:

```text
password_hash
session_version
tokens
segredos
dados internos de autenticação
```

### Criação de usuário

Pergunta:

```text
Crie um usuário para Maria.
```

O agent não criará imediatamente.

Ele deverá coletar:

```text
nome completo
username
e-mail
perfil
```

Depois mostrará:

```text
Operação proposta

Nome: Maria da Silva
Username: maria.silva
E-mail: maria@empresa.com
Perfil: Operador

Confirmar criação?
```

A execução exigirá:

```text
permissão users.create
CSRF válido
confirmação explícita
revalidação no servidor
registro de auditoria
```

## Senha do novo usuário

A senha não deve ser digitada na conversa enviada ao modelo.

Primeira implementação recomendada:

```text
1. admin conversa com o agent;
2. agent prepara a criação;
3. interface abre um formulário seguro;
4. senha é preenchida fora da conversa;
5. senha vai diretamente ao backend;
6. hash é calculado;
7. texto da senha nunca é enviado ao Ollama;
8. usuário é marcado para troca de senha.
```

Evolução posterior:

```text
convite de ativação com token temporário
```

## Confirmação de ações

Toda alteração terá dois estágios:

```text
PROPOSED
CONFIRMED
```

Estrutura:

```json
{
  "action_id": "uuid",
  "tool": "users.create",
  "status": "PROPOSED",
  "summary": "Criar o usuário maria.silva",
  "expires_at": "data e hora",
  "arguments": {
    "username": "maria.silva",
    "email": "maria@empresa.com",
    "role_id": 2
  }
}
```

O backend não confiará nos argumentos retornados pelo navegador.

Na confirmação, todos os dados serão revalidados.

## Permissões

Novas permissões sugeridas:

```text
assistant.use
assistant.view_history
assistant.use_read_tools
assistant.propose_actions
assistant.confirm_actions
assistant.admin
```

Cada ferramenta também validará as permissões já existentes.

Exemplos:

```text
users.list   → assistant.use + users.view
users.create → assistant.use + users.create
roles.list   → assistant.use + roles.view
audit.list   → assistant.use + audit.view
system.get   → assistant.use + system.view
```

## Perfis iniciais

### Administrador

```text
leitura
proposta
confirmação
histórico
```

### Operador

```text
leitura conforme permissões
sem criação de usuários
sem alteração de perfis
```

### Visualizador

```text
status básico
ajuda
sem dados administrativos
```

## Auditoria

Eventos sugeridos:

```text
assistant.message.received
assistant.message.responded
assistant.tool.requested
assistant.tool.denied
assistant.tool.executed
assistant.action.proposed
assistant.action.confirmed
assistant.action.cancelled
assistant.action.expired
assistant.provider.failed
```

A auditoria deve registrar:

```text
usuário
data e hora
ação
ferramenta
recurso
resultado
latência
action_id
```

Não registrar:

```text
senhas
tokens
cookies
segredos
conteúdo confidencial desnecessário
```

## Persistência

Novas tabelas sugeridas:

### assistant_conversations

```text
id
user_id
title
created_at
updated_at
archived_at
```

### assistant_messages

```text
id
conversation_id
role
content
tool_name
tool_status
created_at
```

### assistant_actions

```text
id
conversation_id
requested_by_user_id
tool_name
arguments_json
status
expires_at
confirmed_at
executed_at
result_json
created_at
```

## Contexto enviado ao modelo

O modelo receberá somente:

```text
mensagem atual
últimas mensagens necessárias
lista das ferramentas permitidas
nome e perfil do usuário
permissões relevantes
resumo do ambiente
```

Não receberá:

```text
hashes de senha
credenciais
cookies
conteúdo do .env
DATABASE_URL
REDIS_URL
RABBITMQ_URL
tokens internos
dados de outros usuários sem necessidade
```

## Integração com Ollama

Configuração atual utilizada:

```text
Provider: Ollama
Modelo: qwen2.5-coder:3b
Contexto: 4096
Host: Windows com RX 7600
```

A comunicação deverá usar resposta estruturada.

Formato de decisão:

```json
{
  "type": "tool_call",
  "tool": "system.get_status",
  "arguments": {}
}
```

Ou resposta sem ferramenta:

```json
{
  "type": "message",
  "content": "Resposta ao usuário"
}
```

## Validação da resposta do modelo

A aplicação validará:

```text
JSON válido
tipo permitido
ferramenta registrada
argumentos esperados
tipos corretos
limites de tamanho
permissão do usuário
operação de leitura ou escrita
necessidade de confirmação
```

Qualquer saída inválida vira uma resposta segura, sem execução.

## Tool Registry

Estrutura proposta:

```python
ToolDefinition(
    name="system.get_status",
    description="Retorna o status dos serviços.",
    required_permissions={"assistant.use", "system.view"},
    mode="read",
    handler=get_system_status,
)
```

Cada ferramenta terá:

```text
nome
descrição
schema de entrada
schema de saída
permissões
modo read/write
handler
timeout
campos sensíveis
```

## Segurança

### Proibido

```text
shell livre
execução de comandos Docker
montagem do Docker Socket
SQL criado pelo modelo
consulta direta sem service layer
acesso ao sistema de arquivos
leitura do .env
alteração de infraestrutura
exibição de hashes
criação sem confirmação
desativação do último administrador
```

### Obrigatório

```text
RBAC
CSRF
auditoria
confirmação para escrita
timeouts
limite de mensagem
limite de contexto
rate limiting
schemas rígidos
sanitização de saída
tratamento de indisponibilidade do Ollama
```

## Interface

Nova navegação:

```text
Dashboard
Assistant
Usuários
Perfis
Sistema
Auditoria
Perfil
```

Tela do Assistant:

```text
┌──────────────────────────────────────────────────────┐
│ CompanyOS Assistant                                  │
├──────────────────────────────────────────────────────┤
│                                                      │
│ Assistant: Como posso ajudar?                        │
│                                                      │
│ Você: Como estão os serviços?                        │
│                                                      │
│ Assistant: Todos estão disponíveis...                │
│                                                      │
│ [cartão de status dos serviços]                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│ Digite uma pergunta...                       Enviar  │
└──────────────────────────────────────────────────────┘
```

Atalhos:

```text
Status dos serviços
Listar usuários
Usuários inativos
Eventos recentes
Ajuda
```

## Respostas visuais

As ferramentas podem retornar componentes estruturados:

```text
texto
tabela
cartão de status
cartão de usuário
confirmação de ação
mensagem de erro
```

O modelo não gerará HTML.

A interface renderizará componentes permitidos pelo backend.

## Rate limiting

Sugestão inicial:

```text
20 mensagens por minuto por usuário
5 ações administrativas por minuto
2 requisições simultâneas por usuário
timeout do Ollama: 120 segundos
```

## Tratamento de falhas

### Ollama indisponível

```text
O assistente de linguagem está indisponível.
O painel e as funções administrativas continuam funcionando.
```

### Ferramenta indisponível

```text
Não foi possível consultar o Redis neste momento.
Os demais serviços continuam disponíveis.
```

### Sem permissão

```text
Seu perfil não possui permissão para executar essa operação.
```

### Saída inválida do modelo

```text
Não consegui interpretar a solicitação com segurança.
Reformule a pergunta.
```

## Estrutura de código proposta

```text
apps/mission-control/app/
├── assistant/
│   ├── __init__.py
│   ├── schemas.py
│   ├── prompts.py
│   ├── provider.py
│   ├── orchestrator.py
│   ├── registry.py
│   ├── permissions.py
│   ├── sanitization.py
│   └── tools/
│       ├── __init__.py
│       ├── system_tools.py
│       ├── user_tools.py
│       ├── role_tools.py
│       └── audit_tools.py
├── services/
│   ├── user_service.py
│   ├── role_service.py
│   └── audit_service.py
├── templates/
│   └── assistant.html
└── static/
    ├── assistant.css
    └── assistant.js
```

## Refatoração necessária

O Mission Control atual possui operações administrativas concentradas na
aplicação principal.

Antes de permitir que o agent use essas operações, a lógica deve ser extraída
para services reutilizáveis.

Exemplo:

```text
rota HTML → user_service.create_user()
tool agent → user_service.create_user()
```

Isso evita duplicação e garante que os mesmos controles sejam usados nos dois
caminhos.

## Fases de entrega

### Fase 1 — Assistant somente leitura

```text
nova tela
chat
Ollama
status dos serviços
listagem de usuários
listagem de perfis
auditoria recente
RBAC
auditoria do agent
testes
```

Nenhuma escrita.

### Fase 2 — Ações propostas

```text
criar usuário
ativar usuário
desativar usuário
alterar perfil
resetar senha
action_id
expiração
confirmação
```

### Fase 3 — Convites e automação segura

```text
convite por token
troca obrigatória de senha
notificações
histórico de conversas
favoritos
resumos automáticos
```

## Primeira entrega recomendada

Mission Control v0.3.0:

```text
Assistant somente leitura
system.get_status
system.get_service
users.list
users.get
roles.list
audit.list_recent
assistant.help
```

Depois da validação:

Mission Control v0.3.1:

```text
users.create com confirmação
users.activate
users.deactivate
users.change_role
```

## Testes

### Segurança

```text
usuário sem assistant.use recebe 403
ferramenta sem permissão é negada
modelo não pode inventar ferramenta
modelo não pode enviar SQL
mensagem grande é rejeitada
senha nunca vai ao Ollama
ação write exige confirmação
último admin não pode ser desativado
CSRF inválido não executa ação
```

### Funcionais

```text
pergunta de status retorna dados reais
listagem respeita filtros
usuários inativos são listados
Ollama indisponível produz fallback
tool call inválida não executa nada
auditoria registra cada operação
```

### Integração

```text
PostgreSQL
Redis
RabbitMQ
MinIO
Ollama
Mission Control
```

## Critérios de conclusão da Fase 1

- [ ] tela Assistant criada;
- [ ] nova permissão assistant.use;
- [ ] chamadas ao Ollama estruturadas;
- [ ] tool registry implementado;
- [ ] somente ferramentas read-only;
- [ ] status real dos serviços;
- [ ] usuários sem campos sensíveis;
- [ ] perfis e auditoria consultáveis;
- [ ] RBAC validado por ferramenta;
- [ ] mensagens auditadas;
- [ ] rate limiting;
- [ ] testes automatizados;
- [ ] backup realizado;
- [ ] documentação atualizada;
- [ ] commit enviado ao GitHub.

## Próximo passo

Auditar a estrutura completa atual do Mission Control e gerar o pacote da Fase
1 do Assistant somente leitura.
