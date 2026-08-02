# Roadmap da Stieve Software Company

## Objetivo

Definir a evolução da Stieve Software Company desde sua fundação documental até uma plataforma capaz de planejar, desenvolver, testar, publicar, operar e evoluir múltiplos projetos de software.

O roadmap é atualizado conforme entregas são validadas e novas decisões arquiteturais são aprovadas.

## Situação atual

```text
Fase 0 — Fundação              Concluída
Fase 1 — Infraestrutura Base   Em andamento
Sprint concluída               1.1 — Ambiente Docker
Sprint atual                   1.2 — Serviços de Infraestrutura
Próxima sprint                 1.3 — API Inicial
```

Última atualização:

```text
2026-08-02
```

# Princípios do roadmap

- Arquitetura antes da implementação
- Entregas incrementais e verificáveis
- Documentação contínua
- Segurança por padrão
- Testes obrigatórios
- Aprovação humana para ações críticas
- Uso prioritário de tecnologias gratuitas e open source
- Isolamento entre projetos
- Rastreabilidade de decisões e operações
- Backups e rollback antes de mudanças destrutivas
- Nenhuma fase deverá depender de funcionalidades ainda não validadas

# Fase 0 — Fundação

## Estado da fase

Concluída.

---

## Sprint 0.1 — Project Discovery

### Objetivo

Definir como uma ideia será transformada em uma especificação completa e aprovada.

### Entregas

- Processo de criação de projeto
- Central de referências
- Entrevista inteligente
- Discovery Report
- Project Knowledge Vault
- Estados do Discovery
- Aprovação humana obrigatória

### Estado

Concluída.

---

## Sprint 0.2 — SSC Mission Control UX

### Objetivo

Definir a experiência do usuário antes da implementação da plataforma.

### Entregas

- Navegação principal
- Dashboard
- Fluxo de criação de projeto
- Área de trabalho do projeto
- Sala de Operações
- Fluxos do usuário
- Aprovações humanas
- Wireframes conceituais

### Critério de conclusão

Todos os fluxos principais deverão estar documentados e aprovados antes da modelagem da API.

### Estado

Concluída.

---

## Sprint 0.3 — Modelo de Dados e API

### Objetivo

Transformar os fluxos do Mission Control em entidades, relacionamentos, permissões, eventos e endpoints.

### Entregas

- Modelo de dados
- Diagrama de entidades
- Estados e transições
- Contratos da API
- Padrão de respostas
- Padrão de erros
- Autenticação
- Autorização
- RBAC
- OpenAPI
- Swagger
- Versionamento `/api/v1`

### Estado

Concluída.

---

## Sprint 0.4 — Arquitetura da Plataforma

### Objetivo

Definir detalhadamente os componentes que formarão o CompanyOS.

### Entregas

- Arquitetura de componentes
- Arquitetura de serviços
- Event Bus
- Workflow Engine
- Agent Runtime
- Project Knowledge Vault
- Sistema de plugins
- Auditoria
- Observabilidade
- Estratégia de armazenamento
- Estratégia de isolamento

### Estado

Concluída.

---

# Fase 1 — Infraestrutura Base

## Estado da fase

Em andamento.

---

## Sprint 1.1 — Ambiente Docker

### Objetivo

Criar a base executável, reproduzível e segura para todos os serviços do CompanyOS.

### Entregas concluídas

- `.gitignore` para proteção de credenciais, dados e arquivos locais
- `.env.example` com todas as variáveis públicas
- `.env` privado com credenciais fortes
- Docker Compose com imagens versionadas
- Redes segmentadas
- Volumes persistentes
- Health checks
- Perfis opcionais `ai` e `observability`
- Script de bootstrap
- Script de validação
- Script de inicialização
- Script de parada
- Script de reinicialização
- Script de status
- Script de logs
- Script de atualização controlada
- Script de backup
- Script de restauração
- Makefile operacional
- Manual de operações Docker
- Teste de inicialização dos serviços básicos
- Teste de parada e reinicialização
- Teste de backup
- Teste de restauração

### Serviços validados

```text
PostgreSQL  healthy
RabbitMQ    healthy
Redis       healthy
MinIO       healthy
```

### Observação operacional

A porta `11434` já é utilizada por uma instalação existente do Ollama. O perfil Docker `ai` permanecerá desligado até a integração ser definida na Sprint 1.2.

### Critérios de conclusão

- Ambiente reproduzível
- Zero erros no validador
- Serviços básicos saudáveis
- Credenciais fora do Git
- Volumes persistentes
- Backup e restauração testados
- Operações documentadas

### Estado

Concluída.

---

## Sprint 1.2 — Serviços de Infraestrutura

### Objetivo

Configurar, integrar e validar os serviços compartilhados necessários para a execução segura do CompanyOS.

### Serviços

- PostgreSQL
- RabbitMQ
- Redis
- MinIO
- Ollama existente
- Prometheus
- Grafana
- Loki

### Entregas planejadas

#### Estrutura de configuração

- Diretórios versionados para configurações
- Convenções de nomes
- Templates públicos sem segredos
- Validação automática dos arquivos
- Documentação por serviço

#### PostgreSQL

- Banco principal do CompanyOS
- Schemas iniciais
- Extensões necessárias
- Usuário de aplicação com privilégios mínimos
- Usuário administrativo separado
- Script de inicialização
- Teste de conectividade
- Estratégia de migrações
- Política de backup lógico

#### RabbitMQ

- Virtual host do CompanyOS
- Usuário de aplicação
- Exchanges iniciais
- Filas iniciais
- Routing keys
- Dead-letter exchanges
- Dead-letter queues
- Política de retry
- Teste de publicação e consumo
- Documentação do catálogo inicial de eventos

#### Redis

- Banco lógico e convenções de chaves
- Autenticação
- Persistência AOF
- Política de memória
- Prefixos por domínio e projeto
- Teste de leitura, escrita e expiração
- Regras para uso como cache e coordenação

#### MinIO

- Buckets iniciais
- Convenções de caminhos
- Política de acesso
- Usuário de aplicação
- Versionamento quando aplicável
- Teste de upload e download
- Separação de artefatos, referências e backups

#### Ollama

- Descoberta da instalação existente
- Definição entre integração externa ou migração para Compose
- Health check
- Modelo inicial
- Teste de inferência
- Política de download e armazenamento de modelos
- Configuração futura por agente
- Documentação da porta `11434`

#### Observabilidade

- Configuração do Prometheus
- Configuração do Loki
- Configuração do Grafana
- Datasources automáticos
- Dashboard inicial de infraestrutura
- Coleta de métricas dos serviços
- Coleta de logs
- Política de retenção
- Health checks
- Teste do perfil `observability`

#### Testes e operação

- Teste de conectividade entre serviços
- Teste de autenticação por serviço
- Teste de persistência
- Teste de reinicialização
- Teste de backup após configurações
- Teste de restauração após configurações
- Atualização do validador
- Atualização do Makefile
- Atualização do manual operacional

### Critérios de conclusão

- Todos os arquivos de configuração validados
- Serviços básicos continuam saudáveis
- Ollama existente integrado e testado
- Observabilidade inicia sem erros
- Prometheus coleta métricas
- Loki recebe logs
- Grafana acessa os datasources
- PostgreSQL aceita conexão com usuário de aplicação
- RabbitMQ publica e consome uma mensagem de teste
- Redis executa leitura, escrita e expiração
- MinIO executa upload e download
- Backup e restauração continuam funcionando
- Nenhuma credencial real é versionada
- Documentação operacional atualizada

### Estado

Em andamento.

---

## Sprint 1.3 — API Inicial

### Objetivo

Criar a estrutura inicial executável da API do CompanyOS.

### Entregas

- FastAPI
- Estrutura modular
- Swagger
- OpenAPI
- Health check
- Readiness check
- Configuração tipada
- Logs estruturados
- Tratamento de erros
- Identificador de correlação
- Conexão com PostgreSQL
- Conexão com RabbitMQ
- Conexão com Redis
- Conexão com MinIO
- Integração inicial com Ollama
- Migrações com Alembic
- Testes unitários
- Testes de integração
- Container da API
- Pipeline inicial de qualidade

### Estado

Planejada.

---

# Fase 2 — CompanyOS Core

## Estado da fase

Planejada.

---

## Sprint 2.1 — Usuários e Autenticação

### Entregas

- Cadastro de usuários
- Login
- Tokens de acesso
- Tokens de renovação
- Logout
- Perfis
- Permissões
- Sessões
- Auditoria

---

## Sprint 2.2 — Projetos

### Entregas

- Criar projeto
- Atualizar projeto
- Listar projetos
- Arquivar projeto
- Estados
- Responsáveis
- Configurações
- Isolamento por projeto

---

## Sprint 2.3 — Referências

### Entregas

- Upload
- Links
- Metadados
- Hash
- Versionamento
- Processamento
- Estados
- Segurança
- Associação com requisitos

---

## Sprint 2.4 — Tarefas e Eventos

### Entregas

- Cadastro de tarefas
- Fila
- Atribuição
- Execução
- Retry
- Dead-letter queue
- Histórico
- Catálogo de eventos
- Correlação
- Idempotência

---

# Fase 3 — Agent Runtime

## Estado da fase

Planejada.

---

## Sprint 3.1 — Registro de Agentes

### Entregas

- Catálogo de agentes
- Capacidades
- Modelos
- Ferramentas
- Permissões
- Estados
- Health checks

---

## Sprint 3.2 — Execução Controlada

### Entregas

- Workspace isolado
- Execução em container
- Leitura e escrita de arquivos
- Git
- Testes
- Limite de recursos
- Timeout
- Auditoria
- Bloqueio de comandos perigosos

---

## Sprint 3.3 — Provedor de IA

### Entregas

- Interface de provedor
- Ollama
- Llama
- Modelos especializados
- Configuração por agente
- Limites de contexto
- Registro de consumo
- Fallback entre modelos

---

# Fase 4 — Diretoria Executiva

## Estado da fase

Planejada.

---

## Sprint 4.1 — Solution Architect

### Entregas

- Análise inicial
- Entrevista adaptativa
- Extração de requisitos
- Discovery Report
- Identificação de riscos

---

## Sprint 4.2 — Product Manager

### Entregas

- Épicos
- Histórias de usuário
- Critérios de aceite
- Priorização
- Backlog
- Roadmap do projeto

---

## Sprint 4.3 — Change Manager

### Entregas

- Solicitação de mudança
- Análise de impacto
- RFC
- Riscos
- Dependências
- Plano de implementação
- Plano de rollback

---

## Sprint 4.4 — Tech Lead

### Entregas

- Arquitetura técnica
- Divisão de tarefas
- Padrões
- Dependências
- Sequenciamento
- Revisão técnica

---

# Fase 5 — Engenharia

## Estado da fase

Planejada.

---

## Sprint 5.1 — Backend Engineer

### Entregas

- APIs
- Regras de negócio
- Persistência
- Migrações
- Integrações
- Testes

---

## Sprint 5.2 — Frontend Engineer

### Entregas

- Interface
- Componentes
- Navegação
- Integração com API
- Responsividade
- Acessibilidade

---

## Sprint 5.3 — QA Engineer

### Entregas

- Testes unitários
- Testes de integração
- Testes de interface
- Testes regressivos
- Critérios de qualidade
- Relatórios

---

## Sprint 5.4 — Security Engineer

### Entregas

- Revisão de código
- Análise de dependências
- Detecção de segredos
- Autenticação
- Autorização
- Relatório de vulnerabilidades

---

## Sprint 5.5 — Documentation Engineer

### Entregas

- Documentação técnica
- Documentação funcional
- Manual do usuário
- Changelog
- Documentação da API
- Guias operacionais

---

# Fase 6 — Releases e Deployments

## Estado da fase

Planejada.

---

## Sprint 6.1 — Release Manager

### Entregas

- Validação de qualidade
- Validação de segurança
- Changelog
- Versionamento
- Aprovações
- Tags Git
- Artefatos

---

## Sprint 6.2 — Deployment Manager

### Entregas

- Build
- Backup
- Migrações
- Deploy em desenvolvimento
- Deploy em homologação
- Deploy em produção
- Health checks
- Smoke tests
- Rollback

---

## Sprint 6.3 — Infrastructure Manager

### Entregas

- Ambientes
- Domínios
- HTTPS
- Redes
- Volumes
- Monitoramento
- Backups
- Restauração
- Capacidade

---

# Fase 7 — SSC Mission Control

## Estado da fase

Planejada.

---

## Sprint 7.1 — Dashboard

### Entregas

- Projetos
- Agentes
- Tarefas
- Aprovações
- Alertas
- Recursos
- Atividades recentes

---

## Sprint 7.2 — Gestão de Projetos

### Entregas

- Criação
- Discovery
- Referências
- Requisitos
- Arquitetura
- Backlog
- Releases
- Deployments

---

## Sprint 7.3 — Sala de Operações

### Entregas

- Agentes em tempo real
- Tarefas
- Workflows
- Eventos
- Filas
- Alertas
- Aprovações humanas
- Controles autorizados

---

## Sprint 7.4 — Assistente Executivo

### Entregas

- Consulta em linguagem natural
- Resumo dos projetos
- Identificação de riscos
- Identificação de bloqueios
- Recomendações
- Aprovações pendentes

---

# Fase 8 — Projeto Genesis

## Estado da fase

Planejada.

## Objetivo

Validar o ciclo completo da Stieve Software Company com um projeto real.

## Processo

1. Criar o projeto no Mission Control
2. Enviar referências
3. Realizar Discovery
4. Aprovar especificação
5. Criar arquitetura
6. Criar backlog
7. Desenvolver
8. Testar
9. Revisar segurança
10. Documentar
11. Criar release
12. Publicar em homologação
13. Aprovar
14. Publicar em produção
15. Monitorar
16. Solicitar uma melhoria
17. Processar a mudança pelo Change Manager

---

# Fase 9 — Evolução

## Estado da fase

Futura.

## Possíveis evoluções

- Múltiplas máquinas
- Múltiplas GPUs
- Execução distribuída
- Kubernetes
- Novos provedores de IA
- Marketplace de agentes
- Marketplace de plugins
- Portal para clientes
- Cobrança
- Multiempresa
- SaaS pública
- SDK externo
- Aplicativo móvel
- Integrações com plataformas externas

---

# Critério para SSC v1.0

A versão 1.0 será considerada concluída quando o proprietário conseguir:

- Acessar o Mission Control pelo navegador
- Criar um projeto
- Enviar referências
- Realizar uma entrevista
- Aprovar o Discovery Report
- Gerar arquitetura e backlog
- Acompanhar os agentes
- Desenvolver uma funcionalidade
- Executar testes
- Executar revisão de segurança
- Criar uma release
- Publicar em homologação
- Autorizar produção
- Executar rollback
- Solicitar uma mudança
- Consultar todo o histórico pelo Knowledge Vault

---

# Histórico de marcos

| Data | Marco |
|---|---|
| 2026-08-02 | Fase 0 concluída |
| 2026-08-02 | Sprint 1.1 — Ambiente Docker concluída |
| 2026-08-02 | Sprint 1.2 — Serviços de Infraestrutura iniciada |
