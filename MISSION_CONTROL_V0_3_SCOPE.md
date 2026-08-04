# Mission Control v0.3.0 — Escopo Consolidado

## Objetivo

Atualizar o Mission Control com dois módulos integrados:

```text
CompanyOS Assistant
Aparência
```

A aba `Aparência` fará parte da mesma implantação do Mini Agent e definirá a
identidade visual usada por todo o Mission Control, incluindo a tela do
Assistant.

## Navegação

```text
Visão geral
Assistant
Usuários
Perfis e permissões
Auditoria
Sistema
Aparência
Perfil
```

## Módulo Assistant

Primeira entrega somente leitura:

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

Exemplos:

```text
Como estão os serviços?
O Redis está saudável?
Liste os usuários ativos.
Quantos usuários existem?
Quais são os perfis cadastrados?
Mostre os eventos recentes de auditoria.
```

## Módulo Aparência

Permitirá:

```text
enviar uma logo
remover a logo personalizada
selecionar um tema pronto
criar esquema de cores personalizado
restaurar o visual padrão
```

Formatos de logo:

```text
PNG
JPEG
WebP
```

Limite inicial:

```text
2 MB
```

Temas iniciais:

```text
Midnight
Ocean
Forest
Ember
Slate
Personalizado
```

## Aplicação da identidade visual

A logo e o tema serão aplicados em:

```text
tela de login
barra lateral
dashboard
Assistant
usuários
perfis
auditoria
sistema
aparência
perfil
```

O Assistant não terá um esquema visual independente. Ele sempre utilizará a
identidade visual ativa do Mission Control.

## Persistência

### Assistant

A Fase 1 não precisa armazenar conversas permanentemente.

Serão persistidos apenas os eventos necessários na auditoria existente.

O histórico completo de conversas será adicionado em uma fase posterior.

### Aparência

Será criada a tabela:

```text
branding_settings
```

Ela armazenará:

```text
tema
cores
logo
tipo da imagem
nome original
data da alteração
usuário responsável
```

A logo ficará no PostgreSQL, evitando um volume adicional no container do
Mission Control.

## Permissões

Novas permissões:

```text
assistant.use
branding.manage
```

Regras:

```text
assistant.use + system.view → consultar serviços
assistant.use + users.view  → consultar usuários
assistant.use + roles.view  → consultar perfis
assistant.use + audit.view  → consultar auditoria
branding.manage             → alterar logo e cores
```

O perfil Administrador receberá as duas permissões.

Os demais perfis receberão `assistant.use`, mas cada ferramenta continuará
dependendo das permissões já existentes.

A permissão `branding.manage` não será concedida automaticamente aos demais
perfis.

## Arquitetura segura do Assistant

```text
Usuário
   ↓
Interface do Assistant
   ↓
Sessão + CSRF + RBAC + rate limiting
   ↓
Ollama interpreta a intenção
   ↓
Tool Registry valida a ferramenta
   ↓
Backend executa uma consulta conhecida
   ↓
Auditoria registra o resultado
```

Princípio:

```text
LLM interpreta.
Aplicação valida.
Serviço executa.
Auditoria registra.
```

## Restrições

O modelo não poderá:

```text
executar shell
executar Docker
montar Docker Socket
ler o .env
criar SQL
consultar diretamente o banco
ler hashes de senha
receber credenciais
alterar usuários nesta primeira fase
```

## Interface do Assistant

A tela terá:

```text
área de conversa
campo de pergunta
atalhos rápidos
cartões de status
tabelas de usuários e perfis
mensagens de erro seguras
identificação do modelo Ollama
```

Atalhos:

```text
Status dos serviços
Consultar Redis
Listar usuários ativos
Listar usuários inativos
Contar usuários
Listar perfis
Auditoria recente
Ajuda
```

## Interface da Aparência

A tela terá:

```text
pré-visualização da logo
upload da logo
temas prontos
seletores de cores
restauração do padrão
```

Todas as alterações exigirão:

```text
login
branding.manage
CSRF válido
validação do arquivo
auditoria
```

## Rate limiting do Assistant

Configuração inicial:

```text
20 mensagens por minuto por usuário
Redis como backend principal
memória local como fallback
timeout do Ollama: 120 segundos
```

## Auditoria

Eventos do Assistant:

```text
assistant.message.received
assistant.message.responded
assistant.message.rejected
assistant.tool.requested
assistant.tool.executed
assistant.tool.denied
assistant.tool.failed
assistant.rate_limited
assistant.provider.failed
```

Eventos da Aparência:

```text
branding.theme.updated
branding.logo.updated
branding.logo.removed
branding.reset
```

Não serão registrados:

```text
senhas
tokens
cookies
conteúdo do .env
credenciais
mensagens completas desnecessárias
```

## Versões

### Mission Control v0.3.0

```text
Assistant somente leitura
Aparência
logo personalizada
temas
RBAC
CSRF
rate limiting
auditoria
Ollama estruturado
testes integrados
```

### Mission Control v0.3.1

```text
users.create
users.activate
users.deactivate
users.change_role
ações propostas
confirmação explícita
expiração
formulário seguro para senha
```

## Ordem de implantação

```text
1. backup integrado
2. instalação dos arquivos
3. criação das permissões
4. criação da tabela branding_settings
5. construção da imagem
6. recriação somente do Mission Control
7. teste do Assistant
8. teste de logo e tema
9. teste de RBAC
10. teste de auditoria
11. confirmação visual
12. commit e push
```

## Critérios de conclusão

- [ ] aba Assistant criada;
- [ ] aba Aparência criada;
- [ ] logo aplicada globalmente;
- [ ] temas aplicados globalmente;
- [ ] permissão assistant.use criada;
- [ ] permissão branding.manage criada;
- [ ] Ollama retorna tool calls estruturadas;
- [ ] status real dos serviços;
- [ ] usuários sem campos sensíveis;
- [ ] perfis consultáveis;
- [ ] auditoria consultável;
- [ ] RBAC validado;
- [ ] CSRF validado;
- [ ] rate limiting validado;
- [ ] upload de logo validado;
- [ ] persistência visual validada;
- [ ] testes automatizados;
- [ ] backup realizado;
- [ ] commit enviado ao GitHub.

## Decisão

O pacote separado de branding não será tratado como uma versão independente.

A implementação será consolidada em um único pacote:

```text
mission_control_v030
```

Esse pacote entregará o Mini Agent e a personalização visual juntos.
