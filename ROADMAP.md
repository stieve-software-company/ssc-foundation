# Roadmap da Stieve Software Company

## Objetivo

Definir a evolução da Stieve Software Company desde sua fundação documental até uma plataforma capaz de planejar, desenvolver, testar, publicar e evoluir múltiplos projetos de software.

O roadmap poderá ser atualizado conforme novas decisões forem aprovadas.

## Situação atual

```text
Fase 0 — Fundação              Concluída
Fase 1 — Infraestrutura Base   Em andamento
Sprint atual                   1.1 — Ambiente Docker
```

Última atualização:

```text
2026-08-02
```

# Princípios do roadmap

- Arquitetura antes da implementação
- Entregas incrementais
- Documentação contínua
- Segurança por padrão
- Testes obrigatórios
- Aprovação humana para ações críticas
- Uso prioritário de tecnologias gratuitas e open source
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

### Entregas

- Docker Compose
- Redes
- Volumes
- Variáveis de ambiente
- Health checks
- Scripts de inicialização
- Scripts de atualização
- Scripts de backup

### Estado

Em andamento.

---

## Sprint 1.2 — Serviços de infraestrutura

### Objetivo

Disponibilizar os serviços compartilhados necessários para a execução do CompanyOS.

### Serviços iniciais

- PostgreSQL
- RabbitMQ
- Redis
- Ollama
- MinIO ou armazenamento equivalente
- Prometheus
- Grafana
- Loki

### Estado

Planejada.

---

## Sprint 1.3 — API inicial

### Objetivo

Criar a estrutura inicial executável da API do CompanyOS.

### Entregas

- FastAPI
- Swagger
- OpenAPI
- Health check
- Configuração
- Logs estruturados
- Tratamento de erros
- Migrações com Alembic

### Estado

Planejada.

---

# Fase 2 — CompanyOS Core

## Sprint 2.1 — Usuários e autenticação

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

## Sprint 2.4 — Tarefas e eventos

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

# Fase 3 — Agent Runtime

## Sprint 3.1 — Registro de agentes

### Entregas

- Catálogo de agentes
- Capacidades
- Modelos
- Ferramentas
- Permissões
- Estados
- Health checks

## Sprint 3.2 — Execução controlada

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

# Fase 4 — Diretoria Executiva

## Sprint 4.1 — Solution Architect

### Entregas

- Análise inicial
- Entrevista adaptativa
- Extração de requisitos
- Discovery Report
- Identificação de riscos

## Sprint 4.2 — Product Manager

### Entregas

- Épicos
- Histórias de usuário
- Critérios de aceite
- Priorização
- Backlog
- Roadmap do projeto

## Sprint 4.3 — Change Manager

### Entregas

- Solicitação de mudança
- Análise de impacto
- RFC
- Riscos
- Dependências
- Plano de implementação
- Plano de rollback

## Sprint 4.4 — Tech Lead

### Entregas

- Arquitetura técnica
- Divisão de tarefas
- Padrões
- Dependências
- Sequenciamento
- Revisão técnica

# Fase 5 — Engenharia

## Sprint 5.1 — Backend Engineer

### Entregas

- APIs
- Regras de negócio
- Persistência
- Migrações
- Integrações
- Testes

## Sprint 5.2 — Frontend Engineer

### Entregas

- Interface
- Componentes
- Navegação
- Integração com API
- Responsividade
- Acessibilidade

## Sprint 5.3 — QA Engineer

### Entregas

- Testes unitários
- Testes de integração
- Testes de interface
- Testes regressivos
- Critérios de qualidade
- Relatórios

## Sprint 5.4 — Security Engineer

### Entregas

- Revisão de código
- Análise de dependências
- Detecção de segredos
- Autenticação
- Autorização
- Relatório de vulnerabilidades

## Sprint 5.5 — Documentation Engineer

### Entregas

- Documentação técnica
- Documentação funcional
- Manual do usuário
- Changelog
- Documentação da API
- Guias operacionais

# Fase 6 — Releases e Deployments

## Sprint 6.1 — Release Manager

### Entregas

- Validação de qualidade
- Validação de segurança
- Changelog
- Versionamento
- Aprovações
- Tags Git
- Artefatos

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

# Fase 7 — SSC Mission Control

## Sprint 7.1 — Dashboard

### Entregas

- Projetos
- Agentes
- Tarefas
- Aprovações
- Alertas
- Recursos
- Atividades recentes

## Sprint 7.2 — Gestão de projetos

### Entregas

- Criação
- Discovery
- Referências
- Requisitos
- Arquitetura
- Backlog
- Releases
- Deployments

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

## Sprint 7.4 — Assistente executivo

### Entregas

- Consulta em linguagem natural
- Resumo dos projetos
- Identificação de riscos
- Identificação de bloqueios
- Recomendações
- Aprovações pendentes

# Fase 8 — Projeto Genesis

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

# Fase 9 — Evolução

Possíveis evoluções futuras:

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
