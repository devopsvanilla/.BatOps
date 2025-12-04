# Configuração para Uso com Contexto Docker Remoto

Este guia explica como configurar e usar este projeto com um servidor Docker remoto via SSH.

## 📋 Pré-requisitos

1. **Servidor remoto** com Docker instalado
2. **Acesso SSH** configurado com chave pública (sem senha)
3. **Docker CLI** instalado localmente
4. **Permissões** adequadas no servidor remoto

## 🔑 Configurar Autenticação SSH (Se necessário)

Se você ainda não configurou a autenticação por chave SSH:

### 1. Gerar chave SSH (se não tiver)

```bash
ssh-keygen -t ed25519 -C "seu-email@example.com"
```

### 2. Copiar chave para o servidor remoto

```bash
ssh-copy-id user@remote-host
```

### 3. Testar conexão

```bash
ssh user@remote-host
```

Você deve conseguir conectar **sem digitar senha**.

## 🐳 Configurar Contexto Docker Remoto

### 1. Criar o contexto Docker apontando para o servidor remoto

```bash
docker context create mssql-remote \
  --docker "host=ssh://user@remote-host"
```

**Substitua:**
- `mssql-remote` → nome que você quer dar ao contexto
- `user` → seu usuário SSH no servidor remoto
- `remote-host` → IP ou hostname do servidor remoto

**Exemplos:**

```bash
# Usando IP
docker context create production \
  --docker "host=ssh://devops@192.168.1.100"

# Usando hostname
docker context create staging \
  --docker "host=ssh://ubuntu@staging.empresa.com"

# Usando porta SSH customizada
docker context create custom-port \
  --docker "host=ssh://user@remote-host:2222"
```

### 2. Ativar o contexto remoto

```bash
docker context use mssql-remote
```

### 3. Verificar conexão

```bash
# Ver contexto atual
docker context show

# Testar conexão
docker ps

# Listar imagens no servidor remoto
docker images
```

Se tudo estiver correto, você verá os containers e imagens do **servidor remoto**.

## 🚀 Usar o Script up.sh com Contexto Remoto

Com o contexto remoto ativado, basta executar:

```bash
./up.sh
```

O script **automaticamente**:

1. ✅ Detecta que você está usando contexto remoto
2. ✅ Identifica o host SSH e usuário
3. ✅ Sincroniza os arquivos necessários (`docker-compose.yml`, `.env`)
4. ✅ Cria o diretório remoto se necessário
5. ✅ Lista as redes Docker disponíveis no servidor remoto
6. ✅ Permite selecionar ou criar uma rede
7. ✅ Prepara volumes nomeados e aplica permissões compatíveis com Linux (UID 10001)
8. ✅ Executa `docker compose up -d` no servidor remoto
9. ✅ Exibe URLs de acesso corretas (usando o IP do servidor remoto)

### Caminho do Projeto no Servidor Remoto

O script tentará detectar automaticamente o caminho em:

- `~/docker/mssql+sqlpad/`
- `~/.BatOps/docker/mssql+sqlpad/`

Se não encontrar, solicitará que você informe o caminho.

**Dica:** Crie o diretório previamente:

```bash
ssh user@remote-host "mkdir -p ~/docker/mssql+sqlpad"
```

## 🌐 Acessar os Serviços

Após a execução bem-sucedida, acesse:

- **SQLPad:** `http://remote-host:3000`
- **SQL Server:** `remote-host:1433`

**Substitua `remote-host`** pelo IP ou hostname do seu servidor remoto.

## 🔄 Alternar entre Contextos

### Listar contextos disponíveis

```bash
docker context ls
```

Exemplo de saída:

```text
NAME            DESCRIPTION                         DOCKER ENDPOINT
default         Current DOCKER_HOST...              unix:///var/run/docker.sock
mssql-remote    Remote server for MSSQL             ssh://user@remote-host
```

### Mudar para contexto remoto

```bash
docker context use mssql-remote
```

### Voltar ao contexto local

```bash
docker context use default
```

### Ver contexto atual

```bash
docker context show
```

## 📊 Gerenciar Containers Remotos

Com o contexto remoto ativo, todos os comandos Docker são executados no servidor remoto:

```bash
# Ver status dos containers
docker compose ps

# Ver logs
docker compose logs -f

# Parar containers
docker compose down

# Reiniciar containers
docker compose restart

# Ver logs de um serviço específico
docker compose logs -f mssql
```

### Comandos diretos via SSH (alternativa)

Se preferir executar comandos diretamente via SSH:

```bash
# Ver containers
ssh user@remote-host "cd ~/docker/mssql+sqlpad && docker compose ps"

# Ver logs
ssh user@remote-host "cd ~/docker/mssql+sqlpad && docker compose logs -f"

# Parar containers
ssh user@remote-host "cd ~/docker/mssql+sqlpad && docker compose down"
```

## 🔧 Atualizar Configurações

Se você modificar o `.env` ou `docker-compose.yml` localmente:

1. **Execute novamente o script:**

   ```bash
   ./up.sh
   ```

   O script sincronizará automaticamente os arquivos atualizados.

2. **Ou sincronize manualmente:**

   ```bash
   scp .env user@remote-host:~/docker/mssql+sqlpad/.env
   scp docker-compose.yml user@remote-host:~/docker/mssql+sqlpad/docker-compose.yml
   ```

3. **Reinicie os containers:**

  ```bash
  docker compose up -d --force-recreate
  ```

## 🛡️ Segurança

### Firewall no Servidor Remoto

Se os serviços não estiverem acessíveis, verifique o firewall:

```bash
# Ubuntu/Debian (UFW)
sudo ufw allow 1433/tcp
sudo ufw allow 3000/tcp

# CentOS/RHEL (firewalld)
sudo firewall-cmd --permanent --add-port=1433/tcp
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

### Restrições de Acesso

Para maior segurança, considere:

1. **Usar VPN** ou túnel SSH para acessar os serviços
2. **Configurar firewall** para permitir acesso apenas de IPs específicos
3. **Usar senhas fortes** no `.env`
4. **Habilitar SSL/TLS** para conexões SQL Server

### Túnel SSH (Acesso Seguro)

Se não quiser expor as portas publicamente, use túnel SSH:

```bash
# Túnel para SQLPad
ssh -L 3000:localhost:3000 user@remote-host

# Túnel para SQL Server
ssh -L 1433:localhost:1433 user@remote-host

# Ambos em um único comando
ssh -L 3000:localhost:3000 -L 1433:localhost:1433 user@remote-host
```

Depois acesse localmente:

- SQLPad: `http://localhost:3000`
- SQL Server: `localhost:1433`

## 🆘 Troubleshooting

### Erro: "Cannot connect to the Docker daemon"

```bash
# Verificar se o contexto está correto
docker context show

# Testar SSH manualmente
ssh user@remote-host docker ps

# Recriar contexto
docker context rm mssql-remote
docker context create mssql-remote --docker "host=ssh://user@remote-host"
docker context use mssql-remote
```

### Erro: "Permission denied"

```bash
# Adicionar usuário ao grupo docker no servidor remoto
ssh user@remote-host "sudo usermod -aG docker $USER"

# Fazer logout/login ou reiniciar sessão
ssh user@remote-host "newgrp docker"
```

### Erro: "Network not found"

```bash
# Criar rede manualmente no servidor remoto
ssh user@remote-host "docker network create mssql-network"

# Ou execute o script novamente
./up.sh
```

### Arquivos não sincronizados

```bash
# Sincronizar manualmente
scp docker-compose.yml user@remote-host:~/docker/mssql+sqlpad/
scp .env user@remote-host:~/docker/mssql+sqlpad/
scp .env-sample user@remote-host:~/docker/mssql+sqlpad/
```

## 📝 Exemplo Completo

```bash
# 1. Configurar SSH (se necessário)
ssh-copy-id devops@192.168.1.100

# 2. Criar contexto Docker
docker context create producao --docker "host=ssh://devops@192.168.1.100"

# 3. Ativar contexto
docker context use producao

# 4. Verificar conexão
docker ps

# 5. Executar script
./up.sh

# 6. Acessar serviços
# SQLPad: http://192.168.1.100:3000
# SQL Server: 192.168.1.100:1433

# 7. Ver logs
docker compose logs -f

# 8. Voltar ao contexto local quando terminar
docker context use default
```

## 💡 Dicas

- **Mantenha contextos organizados**: Use nomes descritivos (`dev`, `staging`, `prod`)
- **Documente servidores**: Anote IPs, usuários e caminhos dos projetos
- **Backup do .env**: Faça backup das configurações antes de alterações
- **Monitore recursos**: Use `docker stats` para monitorar uso de CPU/memória
- **Logs centralizados**: Configure logging apropriado para produção

## 🔗 Links Úteis

- [Docker Context Documentation](https://docs.docker.com/engine/context/working-with-contexts/)
- [Docker over SSH](https://docs.docker.com/engine/security/protect-access/#use-ssh-to-protect-the-docker-daemon-socket)
- [SSH Key Setup](https://www.ssh.com/academy/ssh/copy-id)
  