# Project Discovery

## Objetivo

Definir o processo utilizado pela Stieve Software Company para transformar uma ideia inicial em uma especificação clara, estruturada, revisada e aprovada antes do início do desenvolvimento.

Nenhum projeto deverá começar diretamente pelo código.

## Princípio

Todo projeto deverá seguir o fluxo:

```text
IDEIA
  ↓
COLETA DE CONTEXTO
  ↓
ANÁLISE DE REFERÊNCIAS
  ↓
ENTREVISTA INTELIGENTE
  ↓
EXTRAÇÃO DE REQUISITOS
  ↓
DISCOVERY REPORT
  ↓
APROVAÇÃO HUMANA
  ↓
ARQUITETURA
  ↓
BACKLOG
  ↓
DESENVOLVIMENTO
```
Responsável principal

O Solution Architect será responsável por conduzir o processo de descoberta.

Ele deverá trabalhar em conjunto com:

Product Manager
Knowledge Manager
Tech Lead
Change Manager
Usuário responsável pelo projeto
Criação inicial do projeto

A criação deverá registrar:

Nome do projeto
Código interno
Nome curto
Descrição inicial
Problema principal
Objetivo
Área de negócio
Responsável
Prioridade
Nível de confidencialidade
Tipo de solução
Público usuário
Data de criação
Tipos de solução

O projeto poderá ser classificado como:

Sistema Web
Aplicativo móvel
API
Automação
Integração
Plataforma SaaS
Sistema interno
Serviço de backend
Biblioteca
Ferramenta de dados
Outro
Contexto inicial

O usuário deverá poder explicar livremente:

Como o processo funciona atualmente
Quais problemas existem
Quem participa
Quais decisões são tomadas
Quais sistemas são utilizados
Quais resultados são esperados
Quais limitações existem
O que não deverá fazer parte do projeto
Central de referências

O usuário poderá enviar:

PDFs
Documentos DOCX
Planilhas XLSX
Arquivos CSV
Arquivos TXT
Arquivos Markdown
Apresentações
Imagens
Capturas de tela
Wireframes
Diagramas
Vídeos
Áudios
Links
Repositórios Git
Documentações de APIs
Exemplos de sistemas
Normas e regulamentos
Metadados das referências

Cada referência deverá registrar:

Identificador
Projeto
Nome
Tipo
Origem
Descrição
Finalidade
Categoria
Importância
Versão
Data de envio
Usuário responsável
Hash do arquivo
Estado de processamento
Permissão de uso
Observações
Categorias de referência

Uma referência poderá ser classificada como:

Regra de negócio
Referência funcional
Referência visual
Referência técnica
Referência de fluxo
Documento oficial
Exemplo positivo
Exemplo negativo
Processo atual
Integração
Restrição
Regulamentação
Estados das referências
UPLOADED
QUEUED
PROCESSING
PROCESSED
FAILED
NEEDS_REVIEW
ARCHIVED
Processamento das referências

O processamento deverá:

Validar o tipo do arquivo.
Calcular o hash.
Verificar duplicidade.
Extrair o conteúdo.
Identificar idioma.
Identificar entidades.
Identificar regras.
Identificar requisitos.
Identificar dúvidas.
Armazenar o resultado no Knowledge Vault.
Entrevista inteligente

A entrevista deverá ser adaptativa.

O Solution Architect deverá:

analisar todo o contexto disponível;
identificar lacunas;
criar perguntas relevantes;
evitar perguntas já respondidas;
solicitar exemplos quando necessário;
pedir confirmação em pontos críticos;
registrar todas as respostas;
atualizar a especificação progressivamente.
Tipos de perguntas

As perguntas poderão aceitar:

Texto livre
Escolha única
Múltipla escolha
Número
Data
Valor monetário
Escala
Priorização
Confirmação
Upload de arquivo
Seleção de usuário
Seleção de processo
Regras da entrevista
Não repetir perguntas respondidas.
Explicar termos técnicos.
Permitir salvar e continuar depois.
Permitir responder "ainda não definido".
Registrar a origem de cada resposta.
Diferenciar fato, hipótese e decisão.
Destacar respostas contraditórias.
Solicitar aprovação para decisões importantes.
Extração de requisitos

Os requisitos poderão ser classificados como:

Funcionais
Não funcionais
Regras de negócio
Integrações
Segurança
Desempenho
Disponibilidade
Auditoria
Usabilidade
Acessibilidade
Privacidade
Infraestrutura
Operacionais
Estrutura de um requisito

Cada requisito deverá possuir:

Identificador
Título
Descrição
Tipo
Prioridade
Origem
Responsável
Estado
Critérios de aceite
Dependências
Riscos
Referências relacionadas
Data de criação
Histórico de alterações
Estados dos requisitos
DRAFT
PROPOSED
NEEDS_REVIEW
APPROVED
REJECTED
IMPLEMENTED
VERIFIED
DEPRECATED
Discovery Report

O Discovery Report deverá conter:

Resumo executivo

Descrição simples da solução proposta.

Problema

Descrição do problema atual e suas causas.

Objetivos

Resultados que o projeto deverá alcançar.

Público usuário

Perfis que utilizarão o sistema.

Processos

Processos atuais e processos propostos.

Escopo

Funcionalidades incluídas na primeira versão.

Fora do escopo

Funcionalidades explicitamente excluídas.

Requisitos funcionais

Comportamentos esperados do sistema.

Requisitos não funcionais

Segurança, desempenho, disponibilidade, acessibilidade e outros.

Regras de negócio

Regras que controlam decisões e validações.

Integrações

Sistemas, APIs, serviços e bases externas.

Restrições

Limitações técnicas, financeiras, legais ou operacionais.

Riscos

Riscos funcionais, técnicos, de segurança e infraestrutura.

Dúvidas pendentes

Informações ainda não definidas.

Arquitetura inicial

Proposta preliminar de componentes e tecnologias.

Complexidade

Classificação inicial:

Baixa
Média
Alta
Muito alta
Próximos passos

Atividades necessárias após aprovação.

Fluxo de aprovação

Após a geração do Discovery Report, o usuário poderá:

Aprovar
Solicitar ajustes
Responder dúvidas
Adicionar referências
Reabrir entrevista
Salvar como rascunho
Cancelar o projeto
Regra de bloqueio

O projeto não poderá entrar em desenvolvimento enquanto estiver em um destes estados:

DRAFT
COLLECTING_CONTEXT
PROCESSING_REFERENCES
INTERVIEWING
GENERATING_DISCOVERY
WAITING_APPROVAL
CHANGES_REQUESTED
CANCELLED

Somente projetos com estado APPROVED poderão avançar para planejamento técnico.

Estados do Discovery
DRAFT
COLLECTING_CONTEXT
PROCESSING_REFERENCES
INTERVIEWING
EXTRACTING_REQUIREMENTS
GENERATING_DISCOVERY
WAITING_APPROVAL
CHANGES_REQUESTED
APPROVED
CANCELLED
Project Knowledge Vault

O Knowledge Vault deverá armazenar:

Project Vault
├── original-idea
├── uploaded-files
├── extracted-content
├── references
├── interviews
├── requirements
├── business-rules
├── decisions
├── architecture
├── backlog
├── code-knowledge
├── tests
├── releases
├── incidents
└── lessons-learned
Rastreabilidade

Toda informação relevante deverá registrar sua origem.

Exemplo:

Referência
  ↓
Informação extraída
  ↓
Requisito
  ↓
História de usuário
  ↓
Tarefa
  ↓
Código
  ↓
Teste
  ↓
Release
Auditoria

O processo deverá registrar:

Quem criou o projeto
Quem enviou referências
Quais referências foram processadas
Quais informações foram extraídas
Quais perguntas foram feitas
Quais respostas foram recebidas
Quais requisitos foram criados
Quem aprovou o Discovery Report
Quando a aprovação ocorreu
Eventos principais
ProjectCreated
ReferenceUploaded
ReferenceProcessingStarted
ReferenceProcessed
DiscoveryStarted
InterviewQuestionCreated
InterviewAnswerReceived
RequirementExtracted
BusinessRuleExtracted
DiscoveryReportGenerated
DiscoveryChangesRequested
DiscoveryApproved
Critérios de aceite
O usuário consegue criar um projeto.
O usuário consegue explicar a ideia em linguagem natural.
O usuário consegue enviar referências.
As referências possuem estado de processamento.
O Solution Architect consegue identificar lacunas.
A entrevista é adaptativa.
Os requisitos possuem origem rastreável.
O Discovery Report pode ser revisado.
A aprovação humana é obrigatória.
O desenvolvimento é bloqueado antes da aprovação.
Todo o processo fica armazenado no Knowledge Vault.
