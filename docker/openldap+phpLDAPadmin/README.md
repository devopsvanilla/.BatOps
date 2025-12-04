# OpenLDAP + phpLDAPadmin (Docker Compose)

Stack pronto para rodar OpenLDAP com armazenamento persistente e a interface web phpLDAPadmin. Agora há um script interativo (`deploy.sh`) que cuidará da escolha de contextos Docker, redes e execução do `docker compose`, facilitando inclusive o uso de contextos remotos.

## Pré-requisitos

- Docker CLI 24+ (plugin `docker compose` habilitado).
- Acesso aos contextos Docker que você pretende usar (locais ou remotos).
- Bash 4+ (já presente na maioria das distros Linux).

> Se o seu daemon estiver em um host remoto, certifique-se de que o contexto escolhido possua permissões para criar redes, volumes e containers.

## Implantação assistida (`deploy.sh`)

O script orienta todas as decisões importantes:

1. **Lista os contextos Docker** disponíveis e permite escolher qual será usado. Caso diferente do atual, o script chama `docker context use` para torná-lo o padrão.
2. **Garante o `.env`** (copiando de `.env-sample` se necessário).
3. **Lista as redes Docker** existentes no contexto selecionado. Você pode usar a rede padrão, selecionar uma existente ou criar uma nova na hora.
4. **Atualiza automaticamente o `.env`** com as variáveis `LDAP_DOCKER_NETWORK_NAME` e `LDAP_DOCKER_NETWORK_EXTERNAL` quando uma rede externa é escolhida.
5. **Executa o `docker compose up -d`** respeitando o contexto ativo. Há suporte para `--dry-run` (pré-visualização) e `--mock` (modo didático sem chamar o Docker real).

Uso típico:

```bash
cd /home/devopsvanilla/.BatOps/docker/openldap+phpLDAPadmin
./deploy.sh
```

Opções extras:

- `./deploy.sh --dry-run`: mostra tudo o que seria feito sem alterar o ambiente.
- `./deploy.sh --mock --dry-run`: simula contextos/redes quando você não tem Docker instalado (útil para testes neste repositório).

### O que esperar durante a execução

- **Seleção do contexto**: basta digitar o número exibido na lista. `ENTER` mantém o contexto atual.
- **Seleção de rede**: `ENTER` deixa o Compose criar a rede padrão do projeto. Digite `0` para criar uma nova rede ou escolha um número correspondente a uma rede existente.
- **Confirmação final**: antes do `docker compose up -d`, o script mostra um resumo e pede confirmação.

### Bind mounts x contextos remotos

Os volumes continuam como bind mounts (`./data/slapd/database`, `./data/slapd/config`). O Docker cria esses diretórios automaticamente no host que executa o daemon. Em contextos remotos, garanta que o caminho relativo exista (a maneira mais simples é clonar este repositório também no host remoto). Caso prefira usar redes externas já presentes no host remoto, basta selecioná-las quando o script listar as opções.

## Variáveis de ambiente principais

Todas ficam em `.env`:

- `LDAP_ORGANISATION`, `LDAP_DOMAIN`, `LDAP_BASE_DN`: identidade do diretório.
- `LDAP_ADMIN_PASSWORD`, `LDAP_ADMIN_DN`: credenciais administrativas.
- `LDAP_READONLY_USER`, `LDAP_READONLY_USER_USERNAME`, `LDAP_READONLY_USER_PASSWORD`: usuário somente leitura opcional.
- `LDAP_TLS`: `true` habilita LDAPS (porta 636). Lembre-se de fornecer certificados em `./certs`.
- `LDAP_PORT_389`, `LDAP_PORT_636`, `PHPLDAPADMIN_HTTP_PORT`, `PHPLDAPADMIN_HTTPS_PORT`: mapeamentos de portas.
- `PHPLDAPADMIN_LDAP_HOSTS`: host/serviço visto pelo phpLDAPadmin (por padrão o nome do serviço `openldap`).
- `LDAP_DOCKER_NETWORK_NAME` / `LDAP_DOCKER_NETWORK_EXTERNAL`: preenchidas automaticamente pelo `deploy.sh` quando você opta por uma rede externa.

## Persistência

Os dados vivem no host através dos seguintes bind mounts:

- `./data/slapd/database` → `/var/lib/ldap`
- `./data/slapd/config` → `/etc/ldap/slapd.d`

O script cria esses diretórios automaticamente (quando não estamos no modo `--mock`).

## Bootstrap de LDIFs (opcional)

Arquivos `.ldif` colocados em `./bootstrap` são importados apenas na primeira inicialização do diretório (quando `data/slapd/*` ainda não existe). Exemplo mínimo (`./bootstrap/00-base.ldif`):

```ldif
dn: ou=People,dc=example,dc=com
objectClass: organizationalUnit
ou: People

dn: ou=Groups,dc=example,dc=com
objectClass: organizationalUnit
ou: Groups
```

Para reaplicar o bootstrap, remova os diretórios `data/slapd/config` e `data/slapd/database` antes de subir novamente (atenção: isso apaga os dados atuais).

## Habilitando TLS (LDAPS)

1. Ajuste `LDAP_TLS=true` no `.env`.
2. Coloque `ca.crt`, `tls.crt` e `tls.key` em `./certs`.
3. (Opcional) configure `PHPLDAPADMIN_HTTPS=true` para expor o painel via HTTPS.
4. Recrie os serviços com `./deploy.sh` ou `docker compose up -d`.

## Healthchecks e observabilidade

- O serviço OpenLDAP é verificado com um `ldapsearch` simples contra o `LDAP_BASE_DN`.
- O phpLDAPadmin é validado com um `wget --spider` no porto 80.

Checar status/logs:

```bash
docker compose ps
docker compose logs -f openldap
docker compose logs -f phpldapadmin
```


## Operações comuns

```bash
# Parar / iniciar
docker compose stop
docker compose start

# Recriar mantendo dados
docker compose up -d --force-recreate

# Remover tudo (inclusive dados!)
docker compose down
rm -rf data/slapd/database data/slapd/config
```

## Resolução de problemas

- **Erro de bind**: confirme se `LDAP_ADMIN_DN` pertence ao mesmo `LDAP_BASE_DN` configurado.
- **Bootstrap não executa**: limpe `data/slapd/*` para forçar a reinstalação.
- **TLS falha**: confira permissões e correspondência dos certificados.
- **phpLDAPadmin não conecta**: mantenha `PHPLDAPADMIN_LDAP_HOSTS=openldap` ou ajuste para o host correto na rede escolhida.

## Segurança

- Troque todas as senhas padrão antes de expor o serviço.
- Prefira ambientes com TLS habilitado (`LDAP_TLS=true`).
- Limite o bind das portas a IPs específicos (ex.: `127.0.0.1:389:389`).

## Estrutura do diretório

```text
docker/openldap+phpLDAPadmin/
├── deploy.sh
├── docker-compose.yml
├── .env-sample
├── README.md
├── data/
│   └── slapd/
│       ├── database/
│       └── config/
├── bootstrap/
├── certs/
└── pla/
```

## Testes rápidos

Use o modo simulado para validar o fluxo sem Docker:

```bash
./deploy.sh --mock --dry-run <<'EOF'



EOF
```

O script percorrerá as etapas, mostrará o resumo e não executará nenhum comando real. Para um teste real, remova `--mock` e confirme quando o resumo for exibido.

---

Bom hacking de diretórios LDAP! Agora é só ajustar o `.env` e deixar o `deploy.sh` guiar a implantação.
