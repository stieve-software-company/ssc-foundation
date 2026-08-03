# Sprint 1.2 — Plano de Configuração do MinIO

## Auditoria confirmada

```text
MinIO Server:     RELEASE.2025-09-07T16-13-09Z
MinIO Client mc:  RELEASE.2025-08-13T08-35-41Z
Health live:      OK
Health ready:     OK
Credenciais:      configuradas
Processo:         root no container
Volume:           ssc_minio_data
Uso do volume:    aproximadamente 136 KB
Conteúdo atual:   somente .minio.sys
Buckets atuais:   nenhum bucket de negócio
```

## Decisão de implantação

O cliente `mc` já está disponível dentro do container MinIO. Portanto:

- nenhuma ferramenta adicional será baixada;
- nenhuma nova imagem será adicionada;
- as credenciais continuarão somente no `.env`;
- aliases temporários serão criados em diretórios descartáveis;
- os scripts não exibirão usuário ou senha.

## Buckets

```text
companyos-references
companyos-artifacts
companyos-exports
companyos-backups
```

## Versionamento

Habilitado:

```text
companyos-references
companyos-artifacts
companyos-backups
```

Não habilitado:

```text
companyos-exports
```

Motivo:

- referências podem ser substituídas e precisam de recuperação;
- artefatos podem ter revisões;
- backups precisam de proteção contra sobrescrita;
- exports são entregas regeneráveis e terão ciclo de vida mais curto no futuro.

## Acesso

Todos os buckets serão privados:

```text
anonymous access: none
```

O acesso externo futuro será realizado com URLs assinadas e prazo de expiração.

## Lifecycle

Nenhuma regra destrutiva será aplicada nesta etapa.

Futuras regras candidatas:

```text
exports: expiração após prazo documentado
uploads multipart incompletos: limpeza controlada
versões antigas: janela de recuperação
backups: retenção própria e mais longa
```

## Estrutura

```text
MINIO_CONFIGURATION_PLAN.md
MINIO_OPERATIONS.md
infrastructure/config/minio/
├── README.md
└── buckets.json
scripts/
├── audit-minio.sh
├── bootstrap-minio.sh
└── test-minio-integration.sh
```

## Implantação

```text
1. validar buckets.json
2. aguardar MinIO ready
3. criar buckets ausentes
4. habilitar versionamento
5. remover qualquer acesso anônimo
6. criar marcador temporário no bucket de exports
7. recriar somente o container MinIO
8. validar persistência do marcador
9. remover o marcador
10. executar testes funcionais
```

## Testes funcionais

```text
health live
health ready
buckets obrigatórios
versionamento esperado
acesso privado
upload com SHA-256
metadados customizados
stat do objeto
listagem por prefixo
download autenticado
comparação SHA-256
negação de acesso anônimo
URL assinada
download por URL assinada
duas versões do mesmo objeto
persistência após recriação
limpeza integral dos objetos de teste
integração com Mission Control
```

Os objetos de teste usam somente:

```text
ssc-test/
```

## Critérios de conclusão

- [ ] buckets criados;
- [ ] buckets privados;
- [ ] versionamento configurado;
- [ ] health checks validados;
- [ ] upload e download validados;
- [ ] SHA-256 validado;
- [ ] metadados validados;
- [ ] URL assinada validada;
- [ ] acesso anônimo rejeitado;
- [ ] múltiplas versões validadas;
- [ ] persistência após recriação validada;
- [ ] Mission Control conectado;
- [ ] objetos temporários removidos;
- [ ] nenhum segredo no Git;
- [ ] commit enviado ao GitHub.
