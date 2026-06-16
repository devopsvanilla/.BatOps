# Microsoft SQL Server + SQLPad Docker Setup

Esta configuração fornece uma implantação completa do Microsoft SQL Server 2022 com SQLPad para gerenciamento e consultas SQL através de interface web.
### Método Recomendado: Script up.sh

O script `up.sh` agora utiliza **exclusivamente contextos Docker**. Ele lista os contextos disponíveis, permite selecionar um novo (tornando-o o padrão via `docker context use`) e executa o `docker compose` apontando diretamente para esse contexto, sem nenhuma sincronização manual de arquivos. Volumes são sempre gerenciados pelo Docker, seja local ou remoto.

```bash
./up.sh
```

**Principais capacidades:**

- 🧭 Seleção interativa de contexto Docker (local, SSH, TCP etc.).
- 🔁 Caso selecione outro contexto, ele é promovido a padrão automaticamente.
- 📦 Volumes nomeados são sempre criados e gerenciados pelo Docker (sem binds em hosts remotos).
- 🌐 Funciona com qualquer contexto (remoto ou local) sem exigir diretórios no host de destino.
- 📡 Se o `docker-compose.yml` não definir redes, o script oferece opções para usar redes existentes do contexto ou criar uma nova (network externa) e gera um arquivo override temporário.
- 📊 Exibe resumo final com URLs, portas e contexto empregado.

#### Trabalhando com Contextos Remotos

1. Crie um contexto via SSH ou TCP normalmente (`docker context create ...`).
2. Execute `./up.sh` e escolha o contexto remoto (ou mantenha o atual se já estiver ativo).
3. A execução ocorre no Docker Engine daquele contexto, sem cópia de arquivos — o compose é enviado via CLI diretamente.

Para detalhes adicionais sobre configuração de contexto, consulte [REMOTE-SETUP.md](REMOTE-SETUP.md).

### Método Tradicional

Você ainda pode executar manualmente:

```bash
docker compose up -d --build
```

Lembre-se: este comando roda no contexto atual. Use `docker context show` para conferir antes.

## 🌐 Acesso

Ao término do script será exibido o host correspondente ao contexto. Para contextos locais a URL padrão permanece `http://localhost:3000`; em contextos remotos o host será o endpoint configurado.
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

- **URL:** <http://localhost:3000>
- **Usuário:** <admin@sqlpad.com> (ou conforme configurado em `.env`)
- **Senha:** SenhaAdminSqlpad (ou conforme configurado em `.env`)
- **Conexão pré-configurada:** MSSQL Server

### SQL Server (Conexão Direta)

- **Host:** localhost
- **Porta:** 1433
- **Usuário:** sa
- **Senha:** Conforme configurado em `.env`
- **String de conexão:** `Server=localhost,1433;Database=master;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;`

## 🛠️ Ferramentas de Cliente SQL Server

Clientes como SQLPad, Azure Data Studio, SSMS, `sqlcmd`, DBeaver ou a extensão MSSQL do VS Code funcionam normalmente. Use o host/porta exibidos ao final do script (ex.: `localhost:1433` ou `10.0.0.5:1433`).

## 📊 Volumes e Persistência de Dados

O `docker-compose.yml` utiliza **volumes nomeados externos** para garantir compatibilidade total com Linux e permitir que o `up.sh` prepare permissões antes do deploy. Por padrão, o script cria (ou reaproveita) os seguintes volumes:

- `mssql-data` → `/var/lib/docker/volumes/mssql-data/_data` — arquivos de banco
- `mssql-log` → `/var/lib/docker/volumes/mssql-log/_data` — logs do SQL Server
- `mssql-secrets` → `/var/lib/docker/volumes/mssql-secrets/_data` — secrets/certificados
- `sqlpad-data` → `/var/lib/docker/volumes/sqlpad-data/_data` — dados do SQLPad

> 🛠️ O `up.sh` garante que esses volumes existam e aplica `chown 10001:0` (usuário do SQL Server) automaticamente usando uma imagem utilitária Linux. Evite criar/editá-los manualmente se estiver usando o script.

> ℹ️ Os nomes `mssql-data`, `mssql-log`, `mssql-secrets` e `sqlpad-data` são fixos e sempre gerenciados pelo próprio Docker. Não há mais variáveis no `.env` para sobrescrever caminhos ou transformar os volumes em bind mounts — isso evita conflitos de permissão, especialmente após a mudança do SQL Server 2022 para execução como usuário não-root.

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
| `SQLPAD_NETWORK` | Nome da rede Docker | `mssql-network` |
| `SQLPAD_BUILD_NAMESERVERS` | Lista de DNS usada **apenas** durante o build da imagem customizada (separada por vírgulas) | `8.8.8.8,8.8.4.4` |

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

### Erro "Couldn't find the 'xsel' binary and fallback didn't work"

Esse aviso aparece porque o SQLPad depende do utilitário `xsel` (via biblioteca `clipboardy`) para habilitar o botão de copiar resultados. A imagem oficial não traz o pacote instalado. O Dockerfile localizado em `sqlpad/` já adiciona o `xsel`, portanto execute o deploy com `docker compose up -d --build` (ou use o `./up.sh`, que já dispara o build) para garantir que a imagem customizada seja utilizada. Caso veja o log novamente, rode um rebuild manual:

```bash
docker compose build sqlpad
docker compose up -d sqlpad
```

### Falha no build: "Temporary failure resolving 'deb.debian.org'"

Durante o `docker build`, o `apt-get` roda dentro do container de build e não herda o bloco `dns` configurado para os serviços em runtime. Se o host remoto exigir servidores DNS específicos, defina `SQLPAD_BUILD_NAMESERVERS` no `.env` (ex.: `SQLPAD_BUILD_NAMESERVERS=192.168.0.1,1.1.1.1`) e execute novamente `./up.sh` ou `docker compose up -d --build`. O valor informado será escrito em `/etc/resolv.conf` apenas durante o processo de build, permitindo que o download do pacote `xsel` funcione mesmo em ambientes isolados.

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

### SQLPad falha com "unable to find user sqlpad" ou erros de permissão em `/usr/app/public`

As versões mais recentes da imagem oficial `sqlpad/sqlpad:latest` executam como `root` e não incluem mais o usuário `sqlpad` por padrão. Nosso `Dockerfile` customizado garante a criação desse usuário antes de trocar o contexto (`USER sqlpad`) **e** ajusta a posse de `/usr/app/public` para permitir que o processo renomeie `index.html` durante o bootstrap. Caso você mantenha um fork ou modifique o build, verifique se há blocos semelhantes:

```dockerfile
RUN if ! id -u sqlpad >/dev/null 2>&1; then \
    useradd --create-home --shell /bin/bash sqlpad; \
  fi; \
  chown -R sqlpad:sqlpad /usr/app/public
```

Sem o usuário ou as permissões adequadas o Docker daemon não encontra a entrada no `/etc/passwd` e/ou o processo do SQLPad não consegue renomear arquivos estáticos, terminando com `EACCES`.

### Porta já em uso

- Ajuste `MSSQL_PORT` ou `SQLPAD_PORT` no `.env`.
- Descubra quem usa a porta: `sudo netstat -tlnp | grep -E ':(1433|3000)'`.
- Alternativa: `sudo lsof -i :1433` e `sudo lsof -i :3000`.

### Problemas de permissão nos volumes

- Liste e inspecione volumes: `docker volume ls`, `docker volume inspect mssql-data`.
- Garanta que cada volume tenha proprietário `10001:0` (use o script ou os comandos da seção de volumes).
- Para bind mounts customizados, ajuste manualmente as permissões do diretório host.

> ℹ️ Desde o SQL Server 2022 os containers executam como usuário não-root `mssql` (UID 10001). Conforme a [documentação oficial da Microsoft](https://learn.microsoft.com/en-us/sql/linux/sql-server-linux-configure-docker?view=sql-server-2017#buildnonrootcontainer), volumes montados precisam pertencer a esse usuário; caso contrário o bootstrap falha com mensagens como `Access is denied` ao copiar `master.mdf`.

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
