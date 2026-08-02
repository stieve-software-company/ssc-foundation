# Política de Segurança da Stieve Software Company

## Objetivo

Definir os princípios e controles de segurança da Stieve Software Company, do CompanyOS, do SSC Mission Control, dos agentes e dos projetos administrados pela plataforma.

A segurança deverá existir desde o início do desenvolvimento e não ser adicionada apenas antes da publicação.

## Princípios

- Menor privilégio
- Negação por padrão
- Defesa em profundidade
- Isolamento entre projetos
- Segredos fora do código
- Auditoria obrigatória
- Aprovação humana para ações críticas
- Validação de todas as entradas
- Execução isolada
- Segurança por padrão
- Rastreabilidade completa

## Escopo

Esta política abrange:

- SSC Mission Control
- CompanyOS
- APIs
- Banco de dados
- Event Bus
- Agent Runtime
- Agentes
- Workspaces
- Repositórios Git
- Uploads
- Knowledge Vault
- Infraestrutura
- Releases
- Deployments
- Backups
- Logs
- Integrações externas

# Identidade e autenticação

Cada usuário e agente deverá possuir uma identidade exclusiva.

A autenticação deverá suportar:

- Nome de usuário ou e-mail
- Senha protegida por hash seguro
- Tokens de acesso com expiração
- Tokens de renovação
- Revogação de sessões
- Bloqueio após tentativas excessivas
- Autenticação multifator em versões futuras

Não será permitido compartilhar contas entre pessoas ou agentes.

# Autorização

O CompanyOS utilizará controle de acesso baseado em papéis e permissões.

## Perfis iniciais

### Proprietário

Acesso completo à empresa e aos projetos.

### Administrador

Gerencia usuários, agentes, projetos e configurações autorizadas.

### Gestor de Projeto

Administra somente os projetos permitidos.

### Desenvolvedor Humano

Consulta e altera recursos técnicos autorizados.

### Leitor

Possui acesso somente para consulta.

### Agente

Identidade técnica com permissões limitadas à sua função e tarefa.

## Regras

- Toda permissão deverá ser explícita.
- A ausência de permissão deverá resultar em bloqueio.
- Permissões deverão ser avaliadas por projeto.
- Ações críticas deverão exigir autorização adicional.
- Agentes não deverão herdar permissões administrativas.

# Segurança dos agentes

Cada agente deverá possuir:

- Identidade própria
- Função definida
- Projetos autorizados
- Ferramentas autorizadas
- Diretórios permitidos
- Comandos permitidos
- Limite de CPU
- Limite de memória
- Limite de tempo
- Limite de tentativas
- Histórico de execução

## Restrições

Um agente não poderá:

- Acessar outro projeto sem autorização
- Ler segredos diretamente
- Alterar sua própria permissão
- Desabilitar auditoria
- Publicar diretamente em produção
- Apagar logs
- Alterar políticas de segurança
- Executar comandos fora do ambiente autorizado

# Execução de comandos

Os agentes não deverão receber acesso livre ao terminal da máquina principal.

Toda execução deverá passar por uma camada controlada.

Essa camada deverá:

1. Validar o comando solicitado
2. Verificar a permissão do agente
3. Validar o diretório de execução
4. Aplicar timeout
5. Limitar recursos
6. Registrar entrada e saída
7. Bloquear comandos proibidos
8. Executar preferencialmente em container isolado
9. Registrar o resultado na auditoria

## Comandos de alto risco

Comandos classificados como alto risco deverão ser bloqueados ou exigir aprovação humana.

Exemplos de operações críticas:

- Exclusão em massa
- Alteração de permissões do sistema
- Modificação de usuários
- Acesso a dispositivos da máquina
- Alteração do serviço Docker
- Desligamento do servidor
- Modificação da rede principal
- Remoção de bancos ou volumes
- Publicação em produção

# Isolamento entre projetos

Cada projeto deverá possuir:

- Workspace próprio
- Repositório próprio
- Knowledge Vault próprio
- Configurações próprias
- Permissões próprias
- Ambientes próprios
- Logs identificados pelo projeto

Um projeto não deverá acessar:

- Arquivos de outro projeto
- Banco de outro projeto
- Segredos de outro projeto
- Eventos privados de outro projeto
- Ambientes de outro projeto

# Segurança da API

A API deverá utilizar:

- HTTPS em ambientes públicos
- Autenticação obrigatória
- Autorização por recurso
- Validação de entrada
- Limitação de requisições
- Paginação
- Registro de auditoria
- Identificador de correlação
- Tratamento seguro de erros
- Versionamento em `/api/v1`

A documentação Swagger não deverá expor:

- Segredos
- Tokens reais
- Credenciais
- Dados pessoais
- Informações internas desnecessárias

## Respostas de erro

Erros públicos não deverão apresentar:

- Stack traces
- Senhas
- Queries completas
- Caminhos internos sensíveis
- Variáveis de ambiente
- Detalhes de infraestrutura

# Upload de arquivos

Todo arquivo enviado deverá passar por:

1. Validação de extensão
2. Validação do tipo real do arquivo
3. Limite de tamanho
4. Geração de hash
5. Verificação de duplicidade
6. Armazenamento isolado
7. Análise de segurança
8. Extração controlada
9. Registro de auditoria

Arquivos não deverão ser executados automaticamente.

O nome original do arquivo não deverá ser usado diretamente como caminho de armazenamento.

# Segredos

Segredos não poderão ser armazenados no Git.

Exemplos:

- Senhas
- Tokens
- Chaves privadas
- Credenciais de banco
- Chaves de APIs
- Certificados privados
- Cookies de sessão

Segredos deverão ser fornecidos por:

- Variáveis de ambiente
- Docker secrets
- Gerenciador de segredos
- Arquivos protegidos fora do repositório

Arquivos `.env` deverão estar no `.gitignore`.

# Banco de dados

O banco deverá utilizar:

- Usuários separados por serviço
- Permissões mínimas
- Conexões autenticadas
- Migrações versionadas
- Backups
- Testes de restauração
- Registro de alterações críticas
- Criptografia quando necessária

A aplicação não deverá utilizar o usuário administrador do banco para operações normais.

# Event Bus

Os eventos deverão possuir:

- Origem identificada
- Tipo
- Versão
- Projeto
- Correlação
- Timestamp
- Validação de payload

Eventos não deverão conter:

- Senhas
- Tokens
- Chaves privadas
- Dados sensíveis desnecessários
- Conteúdo integral de documentos confidenciais

Consumidores deverão validar os eventos antes de processá-los.

# Logs e auditoria

Toda ação importante deverá registrar:

- Usuário ou agente
- Projeto
- Ação
- Recurso
- Data e hora
- Resultado
- Identificador de correlação
- Endereço de origem, quando aplicável
- Motivo da falha, quando aplicável

## Regras

- Logs não deverão conter segredos.
- Agentes não poderão apagar auditorias.
- A auditoria deverá ser protegida contra alterações.
- Logs deverão possuir política de retenção.
- Acesso aos logs deverá ser controlado.

# Segurança do Git

Os projetos deverão utilizar:

- Branch principal protegida
- Commits identificáveis
- Revisão antes de merge
- Verificação de segredos
- Histórico preservado
- Tags para releases

Agentes não deverão executar `push --force` na branch principal.

Mudanças produzidas por agentes deverão ocorrer em branches específicas.

# Dependências e cadeia de suprimentos

Toda dependência deverá ser:

- Identificada
- Versionada
- Verificada
- Avaliada quanto à licença
- Avaliada quanto a vulnerabilidades

Imagens Docker deverão:

- Utilizar versões fixas
- Evitar execução como root
- Possuir somente os pacotes necessários
- Ser reconstruídas regularmente
- Ser analisadas antes de produção

# Releases

Uma release somente poderá ser aprovada quando:

- Testes obrigatórios forem aprovados
- Revisão de segurança for concluída
- Vulnerabilidades críticas forem tratadas
- Documentação estiver atualizada
- Changelog estiver disponível
- Artefatos forem identificados
- Plano de rollback existir

# Deploy em produção

Deploy em produção deverá exigir:

- Release aprovada
- Autorização humana
- Backup válido
- Plano de rollback
- Migrações revisadas
- Health checks
- Smoke tests
- Monitoramento ativo

Nenhum agente de desenvolvimento poderá publicar diretamente em produção.

# Backups

Os backups deverão incluir, conforme o projeto:

- Banco de dados
- Configurações
- Documentos
- Knowledge Vault
- Artefatos
- Metadados necessários

Backups deverão possuir:

- Data e hora
- Projeto
- Versão
- Integridade verificada
- Política de retenção
- Teste periódico de restauração

# Incidentes

Um incidente de segurança deverá registrar:

- Identificador
- Data e hora
- Projeto afetado
- Descrição
- Severidade
- Impacto
- Evidências
- Contenção
- Correção
- Responsável
- Lições aprendidas

## Severidades

- LOW
- MEDIUM
- HIGH
- CRITICAL

Incidentes críticos deverão poder pausar automaticamente:

- Workflows
- Agentes
- Releases
- Deployments

# Aprovação humana obrigatória

As seguintes ações deverão exigir aprovação humana:

- Publicação em produção
- Rollback de produção
- Exclusão de projeto
- Exclusão de dados
- Alteração de permissões administrativas
- Liberação de vulnerabilidade crítica
- Alteração de política de segurança
- Acesso excepcional entre projetos
- Execução classificada como alto risco

# Privacidade

A plataforma deverá armazenar somente os dados necessários.

Deverá permitir:

- Identificar dados pessoais
- Controlar acesso
- Registrar finalidade
- Definir retenção
- Corrigir dados
- Remover dados quando aplicável
- Registrar acesso a informações sensíveis

# Critérios mínimos de aceite

- Usuários e agentes possuem identidade individual.
- Permissões são avaliadas por projeto.
- Agentes executam tarefas em ambiente controlado.
- Projetos permanecem isolados.
- Segredos não são armazenados no Git.
- Uploads são validados.
- Ações críticas exigem aprovação.
- Deploy em produção possui controle humano.
- Logs e auditoria são obrigatórios.
- Existe processo de incidente.
- Existe processo de backup e restauração.
- A política de segurança pode ser rastreada e atualizada.
