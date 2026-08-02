# ADR-0001 — Architecture First

## Status

Aprovada.

## Data

2026-08-02

## Decisão

A Stieve Software Company adotará o princípio:

> Arquitetura primeiro. Automação sempre.

Nenhuma funcionalidade importante deverá iniciar diretamente pela implementação.

Antes do desenvolvimento, deverá existir documentação suficiente para definir:

- objetivo;
- experiência do usuário;
- requisitos;
- regras de negócio;
- riscos;
- modelo de dados;
- APIs;
- eventos;
- segurança;
- critérios de aceite.

## Contexto

A Stieve Software Company será composta por:

- múltiplos projetos;
- agentes executivos;
- agentes de engenharia;
- serviços;
- filas;
- eventos;
- workflows;
- bancos de dados;
- repositórios;
- ambientes;
- ferramentas de execução;
- infraestrutura.

Permitir que agentes iniciem alterações sem planejamento aumentaria o risco de:

- retrabalho;
- código incompatível;
- documentação desatualizada;
- falhas de segurança;
- decisões conflitantes;
- perda de rastreabilidade;
- dependências incorretas;
- dificuldade de manutenção.

## Abordagem adotada

O desenvolvimento seguirá uma abordagem Outside-In:

```text
Experiência do usuário
        ↓
Fluxos
        ↓
Requisitos
        ↓
Regras de negócio
        ↓
Modelo de dados
        ↓
APIs
        ↓
Eventos
        ↓
Arquitetura técnica
        ↓
Implementação
        ↓
Testes
        ↓
Segurança
        ↓
Release
        ↓
Deployment
```
## Regras
### Regra 1

Nenhum projeto poderá iniciar o desenvolvimento antes da aprovação do Discovery Report.

### Regra 2

Toda decisão arquitetural relevante deverá gerar uma ADR.

### Regra 3

Toda mudança relevante em um projeto existente deverá gerar uma RFC.

### Regra 4

Toda funcionalidade deverá possuir critérios de aceite.

### Regra 5

Toda implementação deverá estar associada a uma tarefa rastreável.

### Regra 6

Toda entrega deverá possuir evidências de teste.

### Regra 7

Toda release deverá passar por validação de qualidade e segurança.

### Regra 8

Todo deployment em produção deverá exigir aprovação humana.

### Regra 9

Nenhum agente poderá alterar silenciosamente decisões já aprovadas.

### Regra 10

A documentação deverá evoluir junto com o código.

## Exceções

Correções emergenciais poderão utilizar um processo reduzido, mas ainda deverão registrar:

problema;
impacto;
alteração realizada;
responsável;
testes;
resultado;
plano de reversão;
documentação posterior.

A exceção deverá ser registrada e auditada.

## Consequências positivas
Maior consistência entre serviços
Redução de retrabalho
Melhor documentação
Melhor rastreabilidade
Maior segurança
Facilidade de manutenção
Melhor integração entre agentes
Menor dependência de um modelo específico de IA
Evolução mais previsível
Facilidade para adicionar novos projetos
## Consequências negativas
Maior esforço inicial de planejamento
Entregas visuais podem demorar mais no início
Exige disciplina na atualização dos documentos
Algumas decisões precisarão de aprovação humana
## Alternativas consideradas
### Implementar primeiro e documentar depois

Rejeitada porque aumenta o risco de documentação incompleta e decisões inconsistentes.

### Permitir autonomia total aos agentes

Rejeitada para decisões críticas, pois poderia gerar alterações sem controle, auditoria ou aprovação.

### Usar somente prompts como especificação

Rejeitada porque prompts isolados não oferecem rastreabilidade, versionamento e contexto suficiente.

## Aplicação

Esta decisão se aplica a:

CompanyOS
Mission Control
Agent Runtime
Agentes executivos
Agentes de engenharia
APIs
Banco de dados
Event Bus
Workflows
Plugins
Infraestrutura
Projetos desenvolvidos pela SSC
## Critérios de conformidade

Uma funcionalidade estará em conformidade quando possuir:

objetivo definido;
requisito registrado;
critérios de aceite;
impacto analisado;
documentação atualizada;
implementação rastreável;
testes;
revisão de segurança quando aplicável.
## Revisão

Esta ADR poderá ser revisada caso o processo se torne excessivamente burocrático ou não atenda à evolução da plataforma.

Qualquer alteração deverá gerar uma nova ADR que substitua esta decisão.
