# Wireframes Conceituais do SSC Mission Control

## Objetivo

Registrar a estrutura visual inicial das principais telas antes da implementação do frontend.

## Dashboard

```text
┌──────────────────────────────────────────────────────────┐
│ Stieve Software Company                       Usuário ▾  │
├───────────────┬──────────────────────────────────────────┤
│ Dashboard     │ Projetos ativos: 3                      │
│ Projetos      │ Agentes online: 8                       │
│ Operações     │ Tarefas executando: 5                   │
│ Colaboradores │ Aprovações pendentes: 2                 │
│ Releases      │                                          │
│ Deployments   │ [ Criar novo projeto ]                  │
│ Knowledge     │                                          │
│ Infraestrutura│ Projetos recentes                       │
│ Configurações │ Oficina 45% | Cooperativa 20%           │
└───────────────┴──────────────────────────────────────────┘
```

## Novo Projeto

```text
┌──────────────────────────────────────────────────────────┐
│ Novo Projeto                                  Etapa 1/8 │
├──────────────────────────────────────────────────────────┤
│ Nome do projeto                                           │
│ [____________________________________________________]   │
│                                                          │
│ Explique sua ideia                                        │
│ [                                                    ]   │
│ [                                                    ]   │
│                                                          │
│ [ Salvar rascunho ]                     [ Continuar ]    │
└──────────────────────────────────────────────────────────┘
```

## Central de Referências

```text
┌──────────────────────────────────────────────────────────┐
│ Referências do Projeto                                   │
├──────────────────────────────────────────────────────────┤
│ [ Enviar arquivo ] [ Adicionar link ] [ Gravar áudio ]  │
│                                                          │
│ regras.pdf       Regra de negócio       Processado      │
│ dashboard.png    Referência visual      Processando     │
│ exemplo.com      Referência funcional   Pendente        │
└──────────────────────────────────────────────────────────┘
```

## Entrevista

```text
┌──────────────────────────────────────────────────────────┐
│ Solution Architect                                       │
├──────────────────────────────────────────────────────────┤
│ Quem poderá aprovar uma solicitação?                     │
│                                                          │
│ ( ) Um responsável                                       │
│ ( ) Vários responsáveis                                  │
│ ( ) Aprovação automática                                 │
│ ( ) Depende do valor                                     │
│                                                          │
│ [ Explicar ]                            [ Responder ]    │
└──────────────────────────────────────────────────────────┘
```

## Área do Projeto

```text
┌──────────────────────────────────────────────────────────┐
│ ERP Cooperativa        DISCOVERY                  32%    │
├──────────────────────────────────────────────────────────┤
│ Visão | Discovery | Referências | Requisitos | ...      │
├──────────────────────────────────────────────────────────┤
│ Pendências                                               │
│ • Responder 3 perguntas                                  │
│ • Aprovar Discovery Report                               │
│                                                          │
│ Atividade recente                                        │
│ • Documento analisado                                    │
│ • 12 requisitos extraídos                                │
└──────────────────────────────────────────────────────────┘
```

## Sala de Operações

```text
┌──────────────────────────────────────────────────────────┐
│ Sala de Operações                                        │
├──────────────────────────────────────────────────────────┤
│ Solution Architect  WORKING   ERP Cooperativa           │
│ Product Manager     WAITING   --                        │
│ Backend Engineer    WORKING   Projeto Oficina           │
│ QA Engineer         REVIEWING Projeto Oficina           │
│ Security Engineer   IDLE      --                        │
│                                                          │
│ Eventos em tempo real                                    │
│ 16:08 TASK-102 concluída                                 │
│ 16:09 Testes iniciados                                   │
└──────────────────────────────────────────────────────────┘
```

## Critérios de aceite

- Representar Dashboard, Novo Projeto, Referências, Entrevista, Projeto e Operações
- Manter as ações críticas visíveis
- Priorizar clareza e rastreabilidade
- Servir de base para protótipo interativo futuro
