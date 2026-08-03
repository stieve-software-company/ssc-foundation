# SSC Mission Control v0.2

## Visão geral

A v0.2 transforma a primeira tela de login em um painel administrativo conectado ao PostgreSQL e aos serviços da infraestrutura do CompanyOS.

## Inicialização

Antes do upgrade:

```bash
make backup
```

Depois de copiar os arquivos:

```bash
./scripts/start-access.sh
```

O serviço criará as tabelas necessárias e, quando não existir nenhum usuário, criará o administrador inicial usando:

```text
SSC_ADMIN_USERNAME
SSC_ADMIN_PASSWORD_HASH
```

Essas variáveis já estão configuradas no `.env`.

## Primeiro login

Após entrar, acesse:

```text
Meu perfil
```

Complete:

- nome;
- e-mail;
- telefone;
- cargo;
- departamento;
- fuso horário;
- idioma;
- biografia.

## Administração de usuários

A área **Usuários** permite:

- criar;
- editar;
- trocar perfil;
- redefinir senha;
- ativar;
- desativar.

O sistema não permite desativar o próprio usuário nem remover o último administrador ativo.

## Perfis

Perfis predefinidos:

| Perfil | Uso |
|---|---|
| Administrador | acesso completo |
| Gestor | gestão de usuários e visualização operacional |
| Operador | operação e consulta |
| Visualizador | acesso somente de leitura |

Perfis personalizados podem ser criados pela interface.

## Estado do sistema

A área **Sistema** verifica:

- PostgreSQL;
- RabbitMQ;
- Redis;
- MinIO;
- Ollama.

Essas verificações são somente leitura.

## Endpoints

| Endpoint | Função |
|---|---|
| `/health` | saúde da aplicação e banco |
| `/login` | autenticação |
| `/app` | dashboard |
| `/profile` | perfil pessoal |
| `/users` | usuários |
| `/roles` | perfis e permissões |
| `/audit` | auditoria |
| `/system` | estado dos serviços |

## Segurança

- cookies HttpOnly;
- SameSite Strict;
- sessão assinada;
- CSRF em operações autenticadas;
- senha PBKDF2;
- autorização por permissão;
- headers de segurança;
- sessão invalidada quando a senha muda.

## Parada

```bash
./scripts/stop-access.sh
```

## Teste rápido

```bash
./scripts/test-access.sh
```

## Observação

O painel não recebe o socket Docker. Ações de iniciar, parar ou excluir containers não serão expostas diretamente nesta versão.
