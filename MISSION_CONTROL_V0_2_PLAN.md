# Mission Control v0.2 — Plano de Upgrade

## Objetivo

Transformar a primeira tela de login em um painel administrativo funcional do CompanyOS.

A versão v0.2 deverá centralizar:

- autenticação;
- dados pessoais;
- usuários;
- perfis de acesso;
- permissões;
- auditoria;
- saúde dos serviços;
- navegação administrativa.

## Resultado esperado hoje

```text
Login
  ↓
Dashboard
  ├── Meu perfil
  ├── Usuários
  ├── Perfis e permissões
  ├── Auditoria
  └── Estado do sistema
```

## Entregas

### Autenticação

- autenticação usando usuários armazenados no PostgreSQL;
- manutenção do hash PBKDF2 já configurado;
- sessões assinadas;
- cookie HttpOnly;
- proteção SameSite;
- token CSRF para formulários administrativos;
- invalidação de sessões após alteração de senha;
- bloqueio de usuário inativo.

### Perfil pessoal

Dados disponíveis após o login:

- nome completo;
- e-mail;
- telefone;
- cargo;
- departamento;
- fuso horário;
- idioma;
- biografia;
- alteração de senha.

O primeiro administrador será criado automaticamente a partir do usuário e do hash já existentes no `.env`.

Após o primeiro login, o administrador poderá completar seus dados pela tela **Meu perfil**.

### Usuários

- listar usuários;
- criar usuário;
- editar usuário;
- definir perfil de acesso;
- ativar ou desativar;
- trocar senha;
- consultar último acesso;
- impedir que o último administrador ativo seja removido.

### Perfis e permissões

Perfis iniciais:

- Administrador;
- Gestor;
- Operador;
- Visualizador.

Também será possível criar perfis personalizados.

Permissões iniciais:

- visualizar dashboard;
- visualizar usuários;
- criar usuários;
- editar usuários;
- ativar e desativar usuários;
- visualizar perfis;
- gerenciar perfis;
- visualizar auditoria;
- visualizar sistema;
- editar o próprio perfil.

### Auditoria

Eventos registrados:

- login válido;
- login inválido;
- logout;
- perfil atualizado;
- senha alterada;
- usuário criado;
- usuário atualizado;
- usuário ativado ou desativado;
- perfil criado;
- perfil atualizado.

### Integração dos serviços

O painel consultará:

- PostgreSQL;
- RabbitMQ;
- Redis;
- MinIO;
- Ollama instalado na máquina.

O painel mostrará estado, latência e detalhes resumidos.

### Segurança

- nenhuma senha em texto puro;
- nenhuma credencial enviada ao navegador;
- formulários protegidos por CSRF;
- rotas protegidas por permissão;
- usuário de aplicação sem acesso ao socket Docker;
- headers de segurança;
- validação de e-mail;
- política mínima de senha;
- proteção contra desativação do último administrador.

## Decisão sobre controle de containers

A v0.2 não montará `/var/run/docker.sock` dentro da interface.

Montar o socket permitiria ao painel controlar toda a máquina e criar containers privilegiados. O controle operacional será implementado depois por um serviço separado, com ações permitidas, aprovação e auditoria.

Nesta versão, o painel oferece controle de usuários, perfis, permissões e visualização da saúde da infraestrutura.

## Banco de dados

Tabelas criadas automaticamente:

```text
users
roles
permissions
role_permissions
audit_events
```

O mecanismo automático de criação é temporário para o MVP. A Sprint 1.3 substituirá essa inicialização por migrações Alembic versionadas.

## Critérios de conclusão

- [ ] aplicação inicia;
- [ ] PostgreSQL é conectado;
- [ ] administrador inicial é criado;
- [ ] login continua funcionando;
- [ ] perfil pessoal pode ser completado;
- [ ] novo usuário pode ser criado;
- [ ] usuário pode ser editado;
- [ ] usuário pode ser desativado;
- [ ] perfis aparecem na interface;
- [ ] perfil personalizado pode ser criado;
- [ ] permissões são aplicadas;
- [ ] auditoria registra ações;
- [ ] estado dos serviços aparece no painel;
- [ ] logout funciona;
- [ ] `.env` continua fora do Git.

## Limites desta entrega

Ainda não fazem parte da v0.2:

- envio de e-mail;
- recuperação de senha por e-mail;
- autenticação multifator;
- SSO;
- upload de foto;
- controle direto de containers;
- acesso público pela internet;
- HTTPS;
- bloqueio distribuído contra força bruta.

Esses recursos serão adicionados em etapas posteriores.
