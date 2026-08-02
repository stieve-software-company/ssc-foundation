# SSC Mission Control

## Objetivo

O SSC Mission Control será o portal Web usado para administrar completamente a Stieve Software Company.

Ele será a interface entre o proprietário, o CompanyOS, os projetos e os agentes.

## Funcionalidades principais

Por meio do Mission Control, o usuário poderá:

- criar e administrar projetos;
- enviar arquivos, links e referências;
- responder entrevistas de descoberta;
- aprovar especificações;
- solicitar mudanças;
- acompanhar agentes e tarefas;
- consultar eventos e logs;
- aprovar releases;
- publicar projetos;
- monitorar a infraestrutura;
- administrar usuários e permissões.

## Navegação principal

- Dashboard
- Projetos
- Sala de Operações
- Colaboradores
- Tarefas
- Workflows
- Knowledge Base
- RFCs
- ADRs
- Releases
- Deployments
- Infraestrutura
- Eventos
- Auditoria
- Configurações

## Dashboard

O dashboard deverá apresentar:

- projetos ativos;
- projetos aguardando aprovação;
- agentes online;
- agentes ocupados;
- tarefas pendentes;
- tarefas em execução;
- tarefas com falha;
- releases pendentes;
- deployments recentes;
- alertas de segurança;
- saúde dos serviços;
- consumo de CPU, memória, GPU e armazenamento.

## Ações rápidas

- Criar novo projeto
- Solicitar alteração
- Abrir Sala de Operações
- Consultar aprovações pendentes
- Visualizar alertas
- Abrir projetos recentes

## Assistente executivo

O usuário poderá conversar em linguagem natural com a camada executiva.

Exemplos:

- Como estão os projetos?
- Existe alguma tarefa bloqueada?
- Quais projetos aguardam aprovação?
- Qual agente está sobrecarregado?
- Quais riscos precisam da minha atenção?
- O que aconteceu hoje na empresa?

## Atualizações em tempo real

O portal deverá receber atualizações sobre:

- agentes;
- tarefas;
- workflows;
- eventos;
- testes;
- análises de segurança;
- releases;
- deployments;
- infraestrutura.

A implementação poderá utilizar WebSocket ou Server-Sent Events.

## Segurança

O Mission Control não deverá disponibilizar acesso livre ao terminal do servidor.

Todas as ações deverão passar:

1. pela API;
2. pelo sistema de permissões;
3. pela auditoria do CompanyOS.

Ações críticas deverão exigir confirmação humana.
