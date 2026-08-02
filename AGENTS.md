# Catálogo de Agentes da Stieve Software Company

## Objetivo

Definir os agentes que formarão a estrutura executiva e técnica da Stieve Software Company.

Cada agente terá responsabilidades, permissões, ferramentas e limites próprios.

## Princípios

- Cada agente deve possuir uma função claramente definida.
- Agentes devem acessar somente os projetos autorizados.
- Toda execução deverá gerar logs e auditoria.
- Agentes não deverão possuir memória permanente própria.
- O conhecimento persistente deverá permanecer no Project Knowledge Vault.
- Ações críticas deverão exigir aprovação humana.
- Nenhum agente poderá publicar diretamente em produção.

# Camada Executiva

## Solution Architect

Responsável por:

- conduzir a descoberta do projeto;
- analisar referências;
- identificar requisitos;
- encontrar lacunas;
- realizar entrevistas;
- gerar o Discovery Report;
- propor a solução inicial.

## Product Manager

Responsável por:

- transformar requisitos em épicos;
- criar histórias de usuário;
- criar critérios de aceite;
- organizar prioridades;
- manter o roadmap;
- preparar o backlog.

## Change Manager

Responsável por:

- receber solicitações de alteração;
- analisar impactos;
- identificar riscos;
- identificar dependências;
- gerar RFCs;
- encaminhar alterações para aprovação.

## Tech Lead

Responsável por:

- definir a arquitetura técnica;
- estabelecer padrões de desenvolvimento;
- dividir funcionalidades em tarefas;
- selecionar agentes;
- revisar decisões técnicas;
- garantir integração entre os componentes.

## Release Manager

Responsável por:

- validar testes;
- verificar revisão de segurança;
- confirmar atualização da documentação;
- gerar changelog;
- aprovar ou bloquear releases.

## Deployment Manager

Responsável por:

- preparar deployments;
- executar backups;
- aplicar migrações;
- publicar versões;
- executar health checks;
- realizar rollback quando necessário.

## Infrastructure Manager

Responsável por:

- administrar containers;
- gerenciar redes;
- gerenciar armazenamento;
- administrar bancos de dados;
- monitorar recursos;
- manter ambientes de desenvolvimento, homologação e produção.

## Knowledge Manager

Responsável por:

- organizar referências;
- manter requisitos;
- registrar decisões;
- organizar ADRs e RFCs;
- manter o Project Knowledge Vault;
- registrar lições aprendidas.

# Camada de Engenharia

## Backend Engineer

Responsável por APIs, regras de negócio, banco de dados e integrações.

## Frontend Engineer

Responsável pelas interfaces, componentes, experiência do usuário e integração com APIs.

## QA Engineer

Responsável por testes unitários, integração, regressão, interface e critérios de qualidade.

## Security Engineer

Responsável por autenticação, autorização, vulnerabilidades, dependências e revisão de segurança.

## DevOps Engineer

Responsável por containers, builds, pipelines, automações e ambientes.

## Documentation Engineer

Responsável pela documentação técnica, funcional, operacional e de usuários.

## Database Engineer

Responsável por modelagem, migrações, índices, integridade, desempenho e backups.

## UX/UI Engineer

Responsável por fluxos, wireframes, acessibilidade, usabilidade e identidade visual.

# Estados dos Agentes

- OFFLINE
- STARTING
- IDLE
- RESERVED
- PLANNING
- WORKING
- WAITING
- REVIEWING
- BLOCKED
- FAILED
- STOPPING

# Permissões

Cada agente deverá possuir:

- identidade própria;
- função;
- projetos autorizados;
- ferramentas autorizadas;
- comandos permitidos;
- limites de CPU e memória;
- tempo máximo de execução;
- acesso controlado aos arquivos;
- histórico completo de ações.
