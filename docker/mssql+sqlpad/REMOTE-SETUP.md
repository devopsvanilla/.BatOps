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

Após criar/selecionar um contexto remoto (`docker context create ...` + `docker context use ...`), execute:

```
./up.sh
```

O script lista todos os contextos, permite trocar o contexto padrão e executa `docker compose` com `--context <nome>`. Nada é copiado para o host remoto; o Docker CLI envia o compose diretamente ao daemon daquele contexto.

### 🔌 Escolha correta da rede Docker

Quando o `up.sh` detectar que o `docker-compose.yml` não define redes, ele perguntará qual rede deve ser usada. Para expor as portas `1433` (SQL Server) e `3000` (SQLPad) no host remoto, escolha **0** (rede padrão do Compose, que gera automaticamente algo como `mssqlsqlpad_default`) ou selecione/crie uma rede **bridge** com nome próprio (ex.: `mssql-network`). A rede global chamada `bridge`, assim como `host`, `none`, `docker_gwbridge` ou `null`, é reservada do Docker e não aceita aliases usados pelo Compose — o script agora bloqueia essas escolhas. Mantenha-se em redes `bridge` personalizadas para que os serviços fiquem acessíveis.

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

Com o contexto remoto ativo, todos os comandos Docker são automaticamente direcionados ao servidor remoto. Exemplos:

```bash
docker compose ps             # status dos serviços
docker compose logs -f        # logs
docker compose down           # parar serviços
docker compose restart        # reiniciar
```

Se desejar ver o contexto usado em qualquer momento:

```bash
docker context show
```

## 🔧 Atualizar Configurações

Edite `.env` ou `docker-compose.yml` localmente e execute `./up.sh` novamente. O compose atualizado será aplicado diretamente ao contexto selecionado, sem necessidade de copiar arquivos para o host remoto.

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

Não é preciso sincronizar manualmente; o compose é enviado via contexto. Se ainda assim preferir copiar arquivos, use `scp`, mas não é requisito para o script.

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
