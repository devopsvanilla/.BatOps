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

### Iniciar os serviços

```bash
docker-compose up -d
```

### Parar os serviços

```bash
docker-compose down
```

### Parar e remover volumes (CUIDADO: apaga dados!)

```bash
docker-compose down -v
```

### Ver logs

```bash
# Todos os serviços
docker-compose logs -f

# Apenas SQL Server
docker-compose logs -f mssql

# Apenas SQLPad
docker-compose logs -f sqlpad
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

Esta configuração utiliza **volumes nomeados do Docker** para persistência de dados. Os volumes são criados automaticamente pelo Docker e armazenados em:

```
/var/lib/docker/volumes/
```

### Volumes criados:

- `mssql-data` → `/var/lib/docker/volumes/mssql_mssql-data/_data` - Dados do banco
- `mssql-log` → `/var/lib/docker/volumes/mssql_mssql-log/_data` - Logs do SQL Server
- `mssql-secrets` → `/var/lib/docker/volumes/mssql_mssql-secrets/_data` - Certificados e segredos
- `sqlpad-data` → `/var/lib/docker/volumes/mssql_sqlpad-data/_data` - Dados e configurações do SQLPad

**Nota:** O prefixo `mssql_` vem do nome do diretório onde está o `docker-compose.yml`.

### Usar diretórios locais (bind mounts)

Se preferir armazenar os dados em diretórios específicos no host, você pode configurar as variáveis de ambiente no `.env`:

```bash
MSSQL_DATA_VOLUME=./data/mssql-data
MSSQL_LOG_VOLUME=./data/mssql-log
MSSQL_SECRETS_VOLUME=./data/mssql-secrets
SQLPAD_DATA_VOLUME=./data/sqlpad-data
```

Isso criará os dados nos diretórios relativos ao `docker-compose.yml`.

### Comandos úteis para gerenciar volumes:

```bash
# Listar volumes
docker volume ls

# Inspecionar um volume
docker volume inspect mssql_mssql-data

# Backup de um volume
docker run --rm -v mssql_mssql-data:/data -v $(pwd):/backup ubuntu tar czf /backup/mssql-backup.tar.gz /data

# Restaurar um volume
docker run --rm -v mssql_mssql-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/mssql-backup.tar.gz -C /
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
| `MSSQL_HEALTHCHECK_START_PERIOD` | Período de grace inicial | `30s` |

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
docker-compose ps
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
- Verifique se a senha atende aos requisitos de complexidade
- Verifique memória disponível (mínimo 2GB): `free -h`
- Verifique os logs: `docker-compose logs mssql`
- Verifique se `ACCEPT_EULA=Y` está configurado

### SQLPad não conecta ao SQL Server
- Aguarde o SQL Server estar healthy: `docker-compose ps`
- Verifique se a senha no `.env` está correta em ambas as seções (MSSQL e SQLPad)
- Verifique os logs: `docker-compose logs sqlpad`
- Verifique a conectividade de rede: `docker exec sqlpad ping mssql`

### Porta já em uso
- Altere as portas no arquivo `.env` (`MSSQL_PORT` e `SQLPAD_PORT`)
- Verifique processos usando as portas: `sudo netstat -tlnp | grep -E ':(1433|3000)'`
- Ou use: `sudo lsof -i :1433` e `sudo lsof -i :3000`

### Problemas de permissão nos volumes
- Verifique permissões: `ls -la /var/lib/docker/volumes/`
- Se usar bind mounts, garanta que o diretório tenha permissões adequadas
- O container roda como usuário `mssql` (UID 10001)

### Esqueci a senha do SA
- Pare o container: `docker-compose down`
- Edite o `.env` com nova senha
- Remova os volumes: `docker-compose down -v` (ATENÇÃO: apaga os dados!)
- Inicie novamente: `docker-compose up -d`
