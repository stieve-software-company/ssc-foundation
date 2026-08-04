# Operações da aba Aparência

## Endereço

```text
http://192.168.3.19:8080/branding
```

A opção `Aparência` aparece no menu para usuários com:

```text
branding.manage
```

## Implantação

```bash
./scripts/install-mission-control-branding.sh
./scripts/bootstrap-mission-control-branding.sh
```

## Teste

```bash
./scripts/test-mission-control-branding.sh
```

O teste integrado altera temporariamente o tema e a logo, valida os endpoints e
restaura a configuração anterior ao final.

## Alterar tema

1. abra `Aparência`;
2. selecione um dos temas;
3. clique em `Aplicar tema`.

## Criar tema personalizado

1. selecione `Personalizado`;
2. escolha as cinco cores;
3. mantenha fundo e superfícies escuros;
4. clique em `Aplicar tema`.

## Enviar logo

1. selecione PNG, JPEG ou WebP;
2. mantenha o arquivo abaixo de 2 MB;
3. clique em `Enviar logo`.

Uma imagem quadrada ou horizontal com fundo transparente produz o melhor
resultado.

## Restaurar

O botão `Restaurar aparência padrão`:

```text
remove a logo personalizada
restaura o tema Midnight
```

## Diagnóstico

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  ps mission-control
```

```bash
docker compose \
  --env-file .env \
  -f compose.yaml \
  -f compose.access.yaml \
  logs --tail=150 mission-control
```

## Backup

O instalador preserva os arquivos modificados em:

```text
infrastructure/backups/config/mission-control-branding-<data>
```

A configuração persistida também é protegida pelo backup do volume:

```text
ssc_postgres_data
```

Nunca execute:

```text
docker compose down -v
```
