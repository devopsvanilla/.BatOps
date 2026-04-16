# Metabase + PostgreSQL + pgAdmin

Stack Docker Compose com [Metabase](https://www.metabase.com/) para análise e visualização de dados, [PostgreSQL 16](https://www.postgresql.org/) como banco de dados de backend e [pgAdmin 4](https://www.pgadmin.org/) para administração do banco de dados.

## Serviços

| Serviço    | Imagem padrão                  | Porta padrão | Descrição                            |
|------------|-------------------------------|--------------|---------------------------------------|
| `metabase` | `metabase/metabase:latest`    | `3000`       | Interface de BI e dashboards          |
| `postgres` | `postgres:16`                 | `5432`       | Banco de dados do Metabase            |
| `pgadmin`  | `dpage/pgadmin4:latest`       | `5050`       | Interface web de administração do PG  |

Todos os serviços são conectados na rede interna `metanet1` (bridge). O Metabase e o pgAdmin só sobem após o PostgreSQL estar saudável (`healthcheck`).

## Pré-requisitos

- Docker Engine 20.10+
- Docker Compose v2.x (`docker compose`)

## Configuração inicial

### 1. Gere senhas aleatórias e salve nos arquivos de secrets

Execute a partir do diretório desta stack (`docker/metabase+pgsql/`):

```bash

openssl rand -base64 32 | tr -d '\n' > secrets/postgres_password.txt
openssl rand -base64 32 | tr -d '\n' > secrets/pgadmin_password.txt
chmod 600 secrets/*.txt
```

Verifique as senhas geradas (opcional):

```bash
echo "postgres : $(cat secrets/postgres_password.txt)"
echo "pgadmin  : $(cat secrets/pgadmin_password.txt)"
```

> Os arquivos `*.txt` dentro de `secrets/` estão protegidos pelo `.gitignore` e **não serão versionados**.

### 2. (Opcional) Crie um arquivo `.env` para sobrescrever variáveis

```dotenv
# Imagens
METABASE_IMAGE=metabase/metabase:v0.52.0
POSTGRES_IMAGE=postgres:16

# Identificadores dos containers
METABASE_CONTAINER_NAME=metabase
POSTGRES_CONTAINER_NAME=postgres
PGADMIN_CONTAINER_NAME=pgadmin

# Banco de dados
POSTGRES_USER=metabase
POSTGRES_DB=metabaseappdb
POSTGRES_HOSTNAME=postgres

# Portas publicadas no host
METABASE_PORT=3000
POSTGRES_PUBLISHED_PORT=5432
PGADMIN_PORT=5050

# IP de bind (use 127.0.0.1 para expor somente localmente)
HOST_BIND_IP=0.0.0.0

# pgAdmin
PGADMIN_DEFAULT_EMAIL=admin@admin.com

# Rede Docker
DOCKER_NETWORK_NAME=metanet1
```

## Executar a stack

Use o script `up.sh` — ele gera o `pgpassfile` do pgAdmin a partir dos secrets e ajusta as permissões antes de subir os containers:

```bash
./up.sh
```

Parâmetros extras do `docker compose up` são repassados diretamente (ex: `./up.sh --build`).

Para gerenciar a stack manualmente após o boot inicial:

```bash
# Acompanhar os logs
docker compose logs -f

# Verificar status dos containers
docker compose ps
```

## Acessar os serviços

| Serviço    | URL                         | Credenciais padrão                                    |
|------------|-----------------------------|-------------------------------------------------------|
| Metabase   | <http://localhost:3000>       | Configurado no primeiro acesso via assistente web     |
| pgAdmin    | <http://localhost:5050>       | Email: `admin@admin.com` / Senha: `secrets/pgadmin_password.txt` |
| PostgreSQL | `localhost:5432`            | Usuário: `metabase` / Senha: `secrets/postgres_password.txt`     |

O pgAdmin já vem pré-configurado com o servidor PostgreSQL da stack (`Metabase PostgreSQL`). Ao fazer login, o servidor aparece em **Servers** sem necessidade de senha adicional.

## Segurança

As senhas são gerenciadas via **Docker secrets** (montadas em `/run/secrets/` como arquivos `tmpfs`):

- Não ficam expostas em `docker inspect`
- Não aparecem como variáveis de ambiente no processo
- O `pgpassfile` do pgAdmin é gerado pelo `up.sh` a partir do secret — nunca fica com senha hardcoded

> Para criptografia dos secrets em repouso, considere usar **Docker Swarm** com `docker stack deploy`.

## Parar a stack

```bash
# Parar e remover containers (dados persistidos nos volumes)
docker compose down

# Parar, remover containers E volumes de dados (atenção: destrói os dados)
docker compose down -v
```

## Estrutura de arquivos

```
metabase+pgsql/
├── docker-compose.yml         # Definição da stack
├── up.sh                      # Script de inicialização (gera pgpassfile e sobe a stack)
├── secrets/
│   ├── .gitignore             # Protege os arquivos de senha do git
│   ├── postgres_password.txt  # Senha do PostgreSQL (gerar com openssl)
│   └── pgadmin_password.txt   # Senha do pgAdmin (gerar com openssl)
├── pgadmin/
│   ├── servers.json           # Pré-registro do servidor PG no pgAdmin
│   ├── pgpassfile             # Gerado pelo up.sh — não versionar
│   └── data/                  # Volume persistente do pgAdmin (gerado em runtime)
└── data/
    └── postgres/              # Volume persistente do PostgreSQL (gerado em runtime)
```
