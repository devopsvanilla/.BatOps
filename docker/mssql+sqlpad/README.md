# Microsoft SQL Server + SQLPad Docker Setup

Esta configuração fornece uma implantação completa do Microsoft SQL Server 2022 com SQLPad para gerenciamento e consultas SQL através de interface web.

## 🚀 Componentes

- **Microsoft SQL Server 2022** (latest) - Porta padrão: 1433
- **SQLPad** (latest) - Porta padrão: 3000

## 📋 Pré-requisitos

- Docker Engine 20.10+
- Docker Compose 2.0+
- Mínimo 2GB de RAM disponível
- Mínimo 10GB de espaço em disco

**Para uso com contexto remoto (adicional):**

- Servidor remoto com Docker instalado
- Acesso SSH configurado com chave pública (sem senha)
- Contexto Docker remoto configurado (veja [REMOTE-SETUP.md](REMOTE-SETUP.md))

## ⚙️ Configuração

1. **Copie o arquivo `.env-sample` para `.env`**:
   ```bash
   cp .env-sample .env
   ```

2. **Edite o arquivo `.env`** e altere as senhas padrão:
   ```bash
   MSSQL_SA_PASSWORD=YourStrong!Passw0rd
   SQLPAD_ADMIN_PASSWORD=admin
   ```

   **IMPORTANTE:** A senha do SQL Server deve ter pelo menos 8 caracteres e incluir letras maiúsculas, minúsculas, números e símbolos.

3. **Personalize outras configurações** conforme necessário (portas, memória, etc.)

## 🎯 Uso

### Método Recomendado: Script up.sh

O script `up.sh` facilita a inicialização dos serviços com seleção interativa de rede Docker e suporte para contextos locais e remotos:

```bash
./up.sh
```

**Funcionalidades do up.sh:**

- 🧭 Lista todos os **contextos Docker** disponíveis e permite trocar para o desejado antes do deploy
- 🔍 Mostra as redes Docker do contexto selecionado, permitindo escolher ou criar uma nova na hora
- 🧱 Prepara automaticamente os volumes persistentes (cria, ajusta permissões 10001:0 e garante compatibilidade Linux)
- 🌐 Detecta automaticamente se o contexto é local ou remoto (SSH) e ajusta todo o fluxo
- 🔁 Sincroniza arquivos com hosts remotos e executa o `docker compose` diretamente neles
- 🔧 Mantém DNS e variáveis de ambiente atualizadas, inclusive a rede escolhida no `.env`
- 📊 Exibe um resumo com URLs de acesso, portas e contexto ativo ao final
- 🔑 Usa as chaves SSH existentes (sem necessidade de senha) para contextos remotos

**Fluxo automatizado:**

1. Detecta o contexto Docker atual, lista os demais e permite trocar antes do deploy.
2. Lista as redes disponíveis nesse contexto (local ou remoto), sugere a configurada no `.env` e abre opção para criar outra.
3. Cria/ajusta os volumes nomeados exigidos (inclusive permissões corretas para o usuário `mssql`, garantindo compatibilidade total com Linux).
4. Executa `docker compose up -d` no local correto (shell atual ou host remoto via SSH) e valida o health check antes de exibir as URLs finais.

**Ideal para:**

- Integrar containers em redes Docker existentes
- Trabalhar com contextos Docker remotos
- Evitar problemas de resolução de DNS em builds remotos
- Ter controle total sobre a rede utilizada
- Deploy automatizado em servidores remotos

#### Usando com Contexto Docker Remoto (SSH)

O script possui suporte completo para contextos Docker remotos configurados via SSH. Ele automaticamente:

1. Detecta se o contexto atual é remoto
2. Identifica o host e usuário SSH
3. Sincroniza os arquivos necessários (`docker-compose.yml`, `.env`, etc.) com o servidor remoto
4. Executa o `docker compose` no servidor remoto
5. Exibe URLs de acesso corretas (usando o IP/hostname do servidor remoto)

**📘 Para instruções detalhadas sobre configuração e uso de contextos remotos, consulte: [REMOTE-SETUP.md](REMOTE-SETUP.md)**

**Pré-requisitos para uso remoto:**

- Chave SSH configurada no servidor remoto (autenticação sem senha)
- Contexto Docker remoto configurado

**Exemplo rápido de configuração de contexto Docker remoto:**

```bash
# Criar contexto Docker via SSH
docker context create remote-server \
  --docker "host=ssh://user@remote-host"

# Ativar o contexto remoto
docker context use remote-server

# Executar o script (ele detectará automaticamente que é remoto)
./up.sh
```

O script solicitará o caminho do projeto no servidor remoto ou tentará detectá-lo automaticamente nos seguintes locais:

- `~/docker/mssql+sqlpad/`
- `~/.BatOps/docker/mssql+sqlpad/`

**Comandos úteis para contextos remotos:**

```bash
# Listar contextos disponíveis
docker context ls

# Ver contexto atual
docker context show

# Alternar entre contextos
docker context use <nome-do-contexto>

# Voltar ao contexto local
docker context use default
```

### Método Tradicional: `docker compose`

> 💡 Use esta abordagem apenas se já tiver criado os volumes nomeados manualmente (veja seção de volumes). O script `up.sh` cuida disso automaticamente.

#### Iniciar os serviços

```bash
docker compose up -d
```

#### Parar os serviços

```bash
docker compose down
```

#### Parar e remover volumes (CUIDADO: apaga dados!)

```bash
docker compose down -v
```

#### Ver logs

```bash
# Todos os serviços
docker compose logs -f

# Apenas SQL Server
docker compose logs -f mssql

# Apenas SQLPad
docker compose logs -f sqlpad
```

## 🌐 Acesso

### SQLPad (Interface Web)
- **URL:** http://localhost:3000
- **Usuário:** admin@sqlpad.com (ou conforme configurado em `.env`)
- **Senha:** SenhaAdminSqlpad (ou conforme configurado em `.env`)
- **Conexão pré-configurada:** MSSQL Server

### SQL Server (Conexão Direta)
- **Host:** localhost
- **Porta:** 1433
- **Usuário:** sa
- **Senha:** Conforme configurado em `.env`
- **String de conexão:** `Server=localhost,1433;Database=master;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;`

## 🛠️ Ferramentas de Cliente SQL Server

Você pode conectar ao SQL Server usando:

- **SQLPad** (interface web incluída)
- **Azure Data Studio**
- **SQL Server Management Studio (SSMS)**
- **sqlcmd** (linha de comando)
- **DBeaver**
- **VS Code** com extensão MSSQL

### Exemplo de conexão com sqlcmd (dentro do container):

```bash
docker exec -it mssql-server /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P 'YourStrong!Passw0rd'
```

## 📊 Volumes e Persistência de Dados

O `docker-compose.yml` utiliza **volumes nomeados externos** para garantir compatibilidade total com Linux e permitir que o `up.sh` prepare permissões antes do deploy. Por padrão, o script cria (ou reaproveita) os seguintes volumes:

- `mssql-data` → `/var/lib/docker/volumes/mssql-data/_data` — arquivos de banco
- `mssql-log` → `/var/lib/docker/volumes/mssql-log/_data` — logs do SQL Server
- `mssql-secrets` → `/var/lib/docker/volumes/mssql-secrets/_data` — secrets/certificados
- `sqlpad-data` → `/var/lib/docker/volumes/sqlpad-data/_data` — dados do SQLPad

> 🛠️ O `up.sh` garante que esses volumes existam e aplica `chown 10001:0` (usuário do SQL Server) automaticamente usando uma imagem utilitária Linux. Evite criar/editá-los manualmente se estiver usando o script.

### Criar volumes manualmente (caso não execute o script)

```bash
docker volume create mssql-data
docker volume create mssql-log
docker volume create mssql-secrets
docker volume create sqlpad-data

# Ajustar permissões para o usuário mssql (10001)
docker run --rm -v mssql-data:/mnt busybox:1.36.1 chown -R 10001:0 /mnt
docker run --rm -v mssql-log:/mnt busybox:1.36.1 chown -R 10001:0 /mnt
docker run --rm -v mssql-secrets:/mnt busybox:1.36.1 chown -R 10001:0 /mnt
```

Só depois execute `docker compose up -d`. Sem esse preparo o container falhará ao copiar os arquivos iniciais (erro `Access is denied`).

### Bind mounts (opcional)

Se realmente precisar usar diretórios locais em vez de volumes nomeados, será necessário editar o `docker-compose.yml` para remover o `external: true` e apontar para o caminho desejado. O script `up.sh` **não** dá suporte a essa variação.

### Comandos úteis para gerenciar volumes

```bash
# Listar volumes gerenciados
docker volume ls

# Inspecionar um volume
docker volume inspect mssql-data

# Backup de um volume nomeado
docker run --rm -v mssql-data:/data -v $(pwd):/backup ubuntu \
  tar czf /backup/mssql-data-backup.tar.gz /data

# Restaurar um volume
docker run --rm -v mssql-data:/data -v $(pwd):/backup ubuntu \
  tar xzf /backup/mssql-data-backup.tar.gz -C /
```

## 🔧 Configurações Disponíveis

Todas as configurações podem ser ajustadas no arquivo `.env`. Abaixo está a lista completa de variáveis disponíveis:

### SQL Server - Configurações Principais

| Variável | Descrição | Padrão | Valores Possíveis |
|----------|-----------|--------|-------------------|
| `ACCEPT_EULA` | Aceitar EULA da Microsoft | `Y` | `Y` ou `N` |
| `MSSQL_SA_PASSWORD` | Senha do usuário SA | `SuaSenhaForteAqui` | Mín. 8 caracteres (maiúsculas, minúsculas, números, símbolos) |
| `MSSQL_PID` | Edição do SQL Server | `Developer` | `Developer`, `Express`, `Standard`, `Enterprise`, `Web` |
| `MSSQL_AGENT_ENABLED` | Habilitar SQL Server Agent | `true` | `true`, `false` |
| `MSSQL_COLLATION` | Collation do servidor | `SQL_Latin1_General_CP1_CI_AS` | Qualquer collation válida |
| `MSSQL_MEMORY_LIMIT_MB` | Limite de memória em MB | `2048` | Número em MB |
| `MSSQL_PORT` | Porta de exposição | `1433` | Qualquer porta disponível |

### SQL Server - Configurações de Container

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `MSSQL_CONTAINER_NAME` | Nome do container | `mssql-server` |
| `MSSQL_HOSTNAME` | Hostname do container | `mssql` |
| `MSSQL_DATA_VOLUME` | Volume de dados | `mssql-data` |
| `MSSQL_LOG_VOLUME` | Volume de logs | `mssql-log` |
| `MSSQL_SECRETS_VOLUME` | Volume de secrets | `mssql-secrets` |
| `MSSQL_NETWORK` | Nome da rede Docker | `mssql-network` |

### SQL Server - Health Check

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `MSSQL_HEALTHCHECK_INTERVAL` | Intervalo entre verificações | `10s` |
| `MSSQL_HEALTHCHECK_TIMEOUT` | Timeout da verificação | `5s` |
| `MSSQL_HEALTHCHECK_RETRIES` | Tentativas antes de unhealthy | `5` |
| `MSSQL_HEALTHCHECK_START_PERIOD` | Período de grace inicial | `60s` |

### SQLPad - Configurações Principais

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `SQLPAD_ADMIN` | Email do administrador | `admin@sqlpad.com` |
| `SQLPAD_ADMIN_PASSWORD` | Senha do administrador | `SenhaAdminSqlpad` |
| `SQLPAD_APP_LOG_LEVEL` | Nível de log da aplicação | `info` |
| `SQLPAD_WEB_LOG_LEVEL` | Nível de log web | `warn` |
| `SQLPAD_SEED_DATA_PATH` | Caminho para dados iniciais | `/etc/sqlpad/seed-data` |
| `SQLPAD_PORT` | Porta de exposição | `3000` |

### SQLPad - Configurações de Conexão

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `SQLPAD_CONNECTION_NAME` | Nome da conexão exibida | `MSSQL Server` |
| `SQLPAD_CONNECTION_HOST` | Host do SQL Server | `mssql` |
| `SQLPAD_CONNECTION_PORT` | Porta do SQL Server | `1433` |
| `SQLPAD_CONNECTION_USERNAME` | Usuário de conexão | `sa` |
| `SQLPAD_CONNECTION_MULTI_STATEMENT` | Habilitar múltiplas queries | `true` |
| `SQLPAD_CONNECTION_IDLE_TIMEOUT` | Timeout de conexão ociosa (ms) | `30000` |
| `SQLPAD_DATABASE` | Database padrão | `master` |

### SQLPad - Configurações de Container

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `SQLPAD_CONTAINER_NAME` | Nome do container | `sqlpad` |
| `SQLPAD_HOSTNAME` | Hostname do container | `sqlpad` |
| `SQLPAD_DATA_VOLUME` | Volume de dados | `sqlpad-data` |
| `SQLPAD_NETWORK` | Nome da rede Docker | `mssql-network` |

### SQLPad - Health Check

| Variável | Descrição | Padrão |
|----------|-----------|--------|
| `SQLPAD_HEALTHCHECK_INTERVAL` | Intervalo entre verificações | `10s` |
| `SQLPAD_HEALTHCHECK_TIMEOUT` | Timeout da verificação | `5s` |
| `SQLPAD_HEALTHCHECK_RETRIES` | Tentativas antes de unhealthy | `3` |
| `SQLPAD_HEALTHCHECK_START_PERIOD` | Período de grace inicial | `10s` |

## 🔍 Health Checks

Ambos os serviços incluem health checks configurados:

- **SQL Server:** Verifica conectividade via sqlcmd a cada 10s
- **SQLPad:** Verifica disponibilidade da API a cada 10s

Para verificar o status:

```bash
docker compose ps
```

## ⚠️ Notas de Segurança

1. **Altere as senhas padrão** antes de usar em produção
2. A senha do SQL Server deve seguir os requisitos de complexidade (mínimo 8 caracteres com maiúsculas, minúsculas, números e símbolos)
3. Considere usar secrets do Docker em ambientes de produção
4. Restrinja o acesso às portas usando firewall se necessário
5. Para produção, considere usar bind mounts em vez de volumes nomeados para maior controle dos dados
6. Não exponha as portas publicamente sem proteção adequada (VPN, firewall, autenticação forte)

## 📝 Licença

- Microsoft SQL Server: Verifique os termos da licença Microsoft (EULA)
- SQLPad: MIT License

## 🆘 Troubleshooting

### SQL Server não inicia

- Verifique se a senha atende aos requisitos de complexidade.
- Garanta memória suficiente (mínimo 2 GB): `free -h`.
- Consulte os logs: `docker compose logs mssql`.
- Confira se `ACCEPT_EULA=Y` está definido.

### SQLPad não conecta ao SQL Server

- Aguarde o SQL Server ficar **healthy**: `docker compose ps`.
- Verifique se as senhas do `.env` são consistentes entre MSSQL e SQLPad.
- Consulte os logs: `docker compose logs sqlpad`.
- Teste conectividade interna: `docker exec sqlpad ping -c1 mssql`.

### Porta já em uso

- Ajuste `MSSQL_PORT` ou `SQLPAD_PORT` no `.env`.
- Descubra quem usa a porta: `sudo netstat -tlnp | grep -E ':(1433|3000)'`.
- Alternativa: `sudo lsof -i :1433` e `sudo lsof -i :3000`.

### Problemas de permissão nos volumes

- Liste e inspecione volumes: `docker volume ls`, `docker volume inspect mssql-data`.
- Garanta que cada volume tenha proprietário `10001:0` (use o script ou os comandos da seção de volumes).
- Para bind mounts customizados, ajuste manualmente as permissões do diretório host.

### Esqueci a senha do SA

- Pare os serviços: `docker compose down`.
- Atualize a senha no `.env`.
- (Opcional) Remova volumes para criar usuário/DB do zero: `docker compose down -v` (⚠️ apaga dados!).
- Suba novamente: `docker compose up -d`.

### Problemas de DNS em contexto remoto

- Prefira `./up.sh`, que injeta os servidores DNS automaticamente.
- Alternativa manual (por serviço no `docker-compose.yml`):

  ```yaml
  dns:
    - 8.8.8.8
    - 8.8.4.4
  dns_search:
    - .
  ```

- Refaça o deploy para aplicar mudanças: `docker compose up -d --build`.

### Problemas com contexto Docker remoto via SSH

#### Arquivos não encontrados no host remoto

- O `up.sh` sincroniza tudo automaticamente; verifique o caminho informado.
- Confirme permissões de escrita no diretório remoto.

#### Autenticação SSH falha

- Teste acesso direto: `ssh user@remote-host`.
- Gere/Copie a chave se necessário:

  ```bash
  ssh-keygen -t ed25519 -C "seu-email@example.com"
  ssh-copy-id user@remote-host
  ssh user@remote-host
  ```

#### Contexto Docker não conecta

- Inspecione o contexto: `docker context inspect nome-do-contexto`.
- Recrie se preciso:

  ```bash
  docker context rm nome-do-contexto
  docker context create nome-do-contexto --docker "host=ssh://user@remote-host"
  docker context use nome-do-contexto
  ```

#### Rede não encontrada no host remoto

- O script cria a rede automaticamente; se falhar, crie manualmente:

  ```bash
  ssh user@remote-host "docker network create mssql-network"
  ```
