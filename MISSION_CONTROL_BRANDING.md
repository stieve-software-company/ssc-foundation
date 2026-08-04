# Mission Control v0.2.1 — Aba Aparência

## Objetivo

Adicionar uma área administrativa para personalizar:

```text
logo
tema
fundo
superfícies
cor de destaque
cor de destaque secundária
```

## Persistência

As configurações são armazenadas no PostgreSQL na tabela:

```text
branding_settings
```

A logo também fica no PostgreSQL como conteúdo binário. Assim, a identidade
visual sobrevive à recriação do container sem criar um volume adicional.

## Permissão

```text
branding.manage
```

O perfil Administrador recebe a permissão automaticamente porque ele possui
todas as permissões registradas.

Outros perfis não recebem acesso automático à aba.

## Temas incluídos

```text
Midnight
Ocean
Forest
Ember
Slate
Personalizado
```

## Logo

Formatos aceitos:

```text
PNG
JPEG
WebP
```

Limite:

```text
2 MB
```

O backend verifica a assinatura real da imagem. Alterar apenas a extensão do
arquivo não contorna a validação.

SVG enviado pelo usuário não é aceito.

## Aplicação global

A logo e o tema aparecem em:

```text
tela de login
barra lateral
páginas internas
```

Os endpoints públicos de CSS e logo são necessários para estilizar a tela de
login, mas não expõem credenciais ou configurações sensíveis.

## Auditoria

```text
branding.theme.updated
branding.logo.updated
branding.logo.removed
branding.reset
```

## Arquivos novos

```text
apps/mission-control/app/branding/__init__.py
apps/mission-control/app/branding/routes.py
apps/mission-control/app/branding/service.py
apps/mission-control/app/templates/branding.html
apps/mission-control/app/static/branding-global.css
apps/mission-control/app/static/branding-page.css
apps/mission-control/app/static/branding-page.js
scripts/install-mission-control-branding.sh
scripts/bootstrap-mission-control-branding.sh
scripts/test-mission-control-branding.sh
```

## Arquivos modificados pelo instalador

```text
apps/mission-control/app/main.py
apps/mission-control/app/models.py
apps/mission-control/app/bootstrap.py
apps/mission-control/app/templates/base.html
apps/mission-control/app/templates/login.html
```

## Segurança

- RBAC com `branding.manage`;
- CSRF em todas as alterações;
- máximo de 2 MB por logo;
- PNG, JPEG e WebP validados por assinatura;
- SVG de usuário bloqueado;
- nenhuma escrita no filesystem do container;
- nenhuma credencial nova;
- auditoria de todas as alterações;
- nenhuma nova dependência Python;
- nenhum Docker Socket.

## Versão

```text
Mission Control v0.2.1
```

O CompanyOS Assistant permanece planejado para a versão `0.3.0`.
