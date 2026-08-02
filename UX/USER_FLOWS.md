# Fluxos Principais do Usuário

## Objetivo

Definir como o proprietário da Stieve Software Company utilizará o SSC Mission Control durante todo o ciclo de vida dos projetos.

## Fluxo 1 — Criar um novo projeto

```text
Dashboard
  ↓
Criar novo projeto
  ↓
Informações iniciais
  ↓
Problema, objetivo e usuários
  ↓
Definição do escopo
  ↓
Envio de referências
  ↓
Análise automática
  ↓
Entrevista com o Solution Architect
  ↓
Discovery Report
  ↓
Ajustes ou aprovação
  ↓
Arquitetura e backlog
```

O desenvolvimento não poderá começar antes da aprovação humana do Discovery Report.

## Fluxo 2 — Enviar referências

```text
Projeto
  ↓
Referências
  ↓
Enviar arquivo ou adicionar link
  ↓
Classificar e descrever
  ↓
Processamento automático
  ↓
Extração de informações
  ↓
Relacionamento com requisitos
```

Tipos aceitos incluem documentos, planilhas, imagens, vídeos, áudios, links, APIs e repositórios Git.

## Fluxo 3 — Responder à entrevista

```text
Projeto
  ↓
Discovery
  ↓
Pergunta do Solution Architect
  ↓
Resposta do usuário
  ↓
Atualização da especificação
  ↓
Nova pergunta ou conclusão
```

A entrevista deverá evitar perguntas repetidas e registrar a origem de cada resposta.

## Fluxo 4 — Solicitar uma alteração

```text
Projeto
  ↓
Nova solicitação
  ↓
Descrição e referências
  ↓
Change Manager
  ↓
Análise de impacto
  ↓
RFC
  ↓
Aprovação humana
  ↓
Atualização da documentação e do backlog
```

## Fluxo 5 — Acompanhar o desenvolvimento

```text
Projeto
  ↓
Sala de Operações
  ↓
Agentes, tarefas e workflows
  ↓
Eventos, bloqueios e aprovações
```

O usuário poderá consultar agente, tarefa, arquivos alterados, testes, erros e decisões pendentes.

## Fluxo 6 — Aprovar uma entrega

```text
Projeto
  ↓
Pendências
  ↓
Entrega aguardando aprovação
  ↓
Evidências e riscos
  ↓
Aprovar ou rejeitar
  ↓
Registro da decisão
```

## Fluxo 7 — Criar uma release

```text
Projeto
  ↓
Releases
  ↓
Selecionar tarefas concluídas
  ↓
Testes e segurança
  ↓
Documentação e changelog
  ↓
Release Manager
  ↓
Aprovação ou rejeição
```

## Fluxo 8 — Publicar em homologação

```text
Release aprovada
  ↓
Build e backup
  ↓
Migrações
  ↓
Deploy em homologação
  ↓
Health checks e smoke tests
  ↓
Validação
```

## Fluxo 9 — Publicar em produção

```text
Homologação aprovada
  ↓
Solicitação de produção
  ↓
Confirmação humana
  ↓
Backup e deploy
  ↓
Migrações e health checks
  ↓
Monitoramento
  ↓
Sucesso ou rollback
```

## Fluxo 10 — Realizar rollback

```text
Falha detectada
  ↓
Pausar publicação
  ↓
Restaurar versão anterior
  ↓
Validar banco e serviços
  ↓
Registrar incidente
  ↓
Notificar usuário
```

## Fluxo 11 — Consultar uma decisão

```text
Projeto
  ↓
Knowledge Vault
  ↓
ADR ou RFC
  ↓
Contexto, alternativas e consequências
```

## Fluxo 12 — Consultar o estado da empresa

```text
Dashboard
  ↓
Assistente executivo
  ↓
Pergunta em linguagem natural
  ↓
Consulta ao CompanyOS
  ↓
Resumo da situação
```

## Critérios de aceite

- O usuário consegue criar e detalhar um projeto.
- O usuário consegue enviar referências e responder à entrevista.
- O usuário consegue solicitar mudanças e acompanhar agentes.
- O usuário consegue aprovar decisões, releases e deployments.
- O usuário consegue acompanhar rollback e consultar decisões anteriores.
