# Metabase + Supabase + pgAdmin

Stack unificada para operação local/self-hosted com:

- **Supabase oficial self-hosted** (upstream)
- **Metabase** para BI e dashboards
- **pgAdmin** para administração SQL

Esta pasta usa uma arquitetura em duas camadas:

1. **Base Supabase** (`./supabase`) sincronizada do repositório oficial.
2. **Overlay local** (`./docker-compose.yml`) com Metabase + pgAdmin + bootstrap SQL.

---

## Arquitetura

- API Gateway Supabase (Kong): `:8000`
- Supavisor (pooler Postgres): `:5432` (session), `:6543` (transaction)
- Metabase: `:3000`
- pgAdmin: `:5050`

Metabase e pgAdmin conectam no **Supavisor** (mesmo ecossistema do Supabase), evitando duplicar PostgreSQL.

---

## Pré-requisitos

- Docker Engine 24+
- Docker Compose v2+
- `git`
- `bash`

---

## Setup rápido

No diretório `docker/metabase+supabase+pgadmin`:

1. Sincronize os arquivos oficiais do Supabase:

```bash
./sync-supabase.sh
```

2. Edite `supabase/.env` e troque todos os placeholders de segurança.

3. (Opcional) Copie variáveis do overlay:

```bash
cp .env.example .env
```

4. Suba a stack completa:

```bash
./up.sh
```

---

## Scripts de operação

- `./up.sh` → sobe Supabase + Metabase + pgAdmin
- `./down.sh` → derruba stack
- `./logs.sh [service]` → logs contínuos
- `./ps.sh` → status dos containers
- `./sync-supabase.sh` → atualiza base oficial Supabase
- `./cli.sh <cmd>` → wrapper da Supabase CLI
- `./metabase-import.sh <arquivo.json>` → import de serialização do Metabase

---

## Plugins e dashboards do Metabase

- Plugins: `metabase/plugins/`
- Assets serializados: `metabase/dashboards/`

Após adicionar plugin, reinicie o serviço `metabase`.

---

## Como “alimentar” skills e agents com alta precisão

Use este template ao me pedir mudanças:

```text
Objetivo:
Ambiente (Linux/WSL, Docker/Compose versões):
Estado atual (comando + erro completo):
Escopo técnico (Supabase, Metabase, pgAdmin, plugins, dashboards, auth, functions):
Restrições (portas, proxy, sem sudo, segurança):
Saída esperada (arquivos, serviços, URLs e validações):
```

### Prompt recomendado para máxima eficácia

```text
Atue como arquiteto de stack Docker self-hosted.
Baseie-se na estrutura oficial do Supabase e faça overlay local para Metabase e pgAdmin.
Não duplique PostgreSQL.
Priorize: segurança, versionamento, automação de operação, e facilidade de upgrade.
Entregue: compose, scripts, checklist de validação, plano de rollback e backup.
```

---

## Upgrade seguro do Supabase

1. `./sync-supabase.sh` (ou `SUPABASE_REF=<tag> ./sync-supabase.sh`)
2. Revisar `supabase/CHANGELOG.md`
3. `./down.sh`
4. `./up.sh`
5. Validar serviços via `./ps.sh` e `./logs.sh`

---

## Estrutura da solução

```
metabase+supabase+pgadmin/
├── docker-compose.yml                  # Overlay (Metabase + pgAdmin + init SQL)
├── .env.example                        # Variáveis do overlay
├── up.sh                               # Start unificado
├── down.sh                             # Stop unificado
├── logs.sh                             # Logs unificados
├── ps.sh                               # Status unificado
├── sync-supabase.sh                    # Sync upstream do Supabase
├── cli.sh                              # Wrapper Supabase CLI
├── metabase-import.sh                  # Import de conteúdo serializado no Metabase
├── supabase/                           # Base oficial (gerada pelo sync)
├── volumes/db/init-scripts/10-metabase.sql
├── pgadmin/
│   ├── servers.template.json           # Template de conexão
│   ├── servers.json                    # Gerado no up.sh
│   ├── pgpassfile                      # Gerado no up.sh
│   └── data/
└── metabase/
    ├── plugins/
    ├── dashboards/
    └── data/
```
