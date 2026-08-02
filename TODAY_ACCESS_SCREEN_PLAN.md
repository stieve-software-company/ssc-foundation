# Meta de Hoje — Primeira Tela de Acesso do CompanyOS

## Objetivo

Entregar hoje uma primeira versão funcional e segura da tela de acesso do SSC Mission Control.

A entrega deverá permitir:

- abrir a interface pelo navegador;
- informar usuário e senha;
- validar as credenciais no servidor;
- criar uma sessão protegida;
- acessar uma página interna;
- encerrar a sessão;
- consultar um health check;
- executar tudo em container Docker.

## Endereço esperado

```text
http://IP-DA-VM:8080
```

## Escopo do MVP

### Incluído

- FastAPI
- HTML renderizado no servidor
- CSS responsivo
- formulário de login
- senha armazenada somente como hash PBKDF2
- sessão assinada
- cookie HttpOnly
- cookie SameSite Strict
- headers básicos de segurança
- página interna protegida
- logout
- health check
- Dockerfile
- Compose complementar
- script de configuração
- script de inicialização
- script de parada

### Não incluído ainda

- cadastro de usuários
- recuperação de senha
- múltiplos usuários
- banco de dados de identidade
- RBAC completo
- autenticação multifator
- frontend React
- acesso de produção pela internet

Esses itens continuam planejados para as próximas sprints.

## Estrutura criada

```text
apps/
└── mission-control/
    ├── app/
    │   ├── __init__.py
    │   ├── main.py
    │   ├── security.py
    │   ├── static/
    │   │   └── styles.css
    │   └── templates/
    │       ├── home.html
    │       └── login.html
    ├── Dockerfile
    └── requirements.txt

compose.access.yaml

scripts/
├── configure-access.py
├── start-access.sh
└── stop-access.sh
```

## Fluxo de execução

1. Extrair o pacote na raiz do repositório.
2. Executar `python3 scripts/configure-access.py`.
3. Informar usuário e senha.
4. Executar `./scripts/start-access.sh`.
5. Abrir o endereço exibido no terminal.
6. Fazer login.
7. Confirmar que a página interna foi exibida.
8. Testar logout.
9. Registrar os arquivos no Git.

## Critérios de conclusão

- [ ] Configuração de acesso criada
- [ ] Container construído
- [ ] Health check saudável
- [ ] Tela de login abre no navegador
- [ ] Credenciais válidas permitem acesso
- [ ] Credenciais inválidas são rejeitadas
- [ ] Página interna exige sessão
- [ ] Logout encerra a sessão
- [ ] Nenhum segredo foi versionado
- [ ] Arquivos enviados ao GitHub

## Observação de segurança

Este MVP é adequado para desenvolvimento local e rede controlada.

Ele não deve ser exposto diretamente à internet sem HTTPS, proxy reverso, proteção contra força bruta, política de usuários e revisão de segurança.
