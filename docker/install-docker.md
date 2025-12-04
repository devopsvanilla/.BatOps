# Instalação e Configuração do Docker com TLS

Este guia descreve como instalar e configurar o Docker em um servidor Ubuntu para acesso remoto seguro com TLS (Transport Layer Security).

## 📋 Índice

- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Verificação](#verificação)
- [Configuração do Cliente](#configuração-do-cliente)
- [Exemplos de Uso](#exemplos-de-uso)
- [Solução de Problemas](#solução-de-problemas)
- [Segurança](#segurança)

## 🔧 Pré-requisitos

### No Servidor (Host Docker)

- Ubuntu 20.04 LTS ou superior
- Usuário com privilégios sudo
- Pacotes necessários (o script verifica e oferece instalação):
  - `curl`
  - `ca-certificates`
  - `gnupg`
  - `lsb-release`
  - `openssl`

### No Cliente (Computador que irá acessar)

- Docker instalado (para usar comandos docker remotamente)
- Certificados TLS copiados do servidor
- Conectividade de rede com o servidor na porta 2376

## 🚀 Instalação

### Passo 1: Fazer Download do Script

```bash
cd /caminho/para/.BatOps/docker
```

### Passo 2: Dar Permissão de Execução

```bash
chmod +x install-docker.sh
```

### Passo 3: Executar o Script

```bash
sudo ./install-docker.sh
```

### O que o Script Faz

O script executa automaticamente as seguintes tarefas:

1. ✅ **Verifica requisitos do sistema**
   - Confirma que é Ubuntu
   - Verifica pacotes necessários
   - Oferece instalação de pacotes faltantes

2. 🔍 **Detecta informações do host**
   - Captura o hostname do servidor
   - Identifica o endereço IP da interface de rede principal

3. 🐳 **Instala o Docker**
   - Adiciona repositório oficial do Docker
   - Instala Docker Engine, CLI e plugins
   - Adiciona usuário ao grupo docker

4. 🔐 **Gera certificados TLS**
   - Cria uma Certificate Authority (CA) própria
   - Gera certificado do servidor (incluindo IP e hostname)
   - Gera certificado do cliente para autenticação mútua
   - Salva certificados em `/etc/docker/certs`

5. ⚙️ **Configura Docker Daemon**
   - Configura TLS com verificação obrigatória
   - Habilita acesso via TCP na porta 2376
   - Mantém socket Unix local

6. 🔥 **Configura Firewall**
   - Libera porta 2376/TCP no UFW (se ativo)

7. 📦 **Prepara certificados do cliente**
   - Copia certificados para `~/docker-client-certs`
   - Ajusta permissões adequadas

## ✔️ Verificação

### Verificar Status do Docker no Servidor

```bash
sudo systemctl status docker
```

### Testar Docker Localmente

```bash
# Pode ser necessário fazer logout/login primeiro para aplicar permissões do grupo
docker ps
```

### Verificar Porta TLS

```bash
sudo netstat -tlnp | grep 2376
```

Deve mostrar algo como:
```
tcp6       0      0 :::2376                 :::*                    LISTEN      1234/dockerd
```

## 🖥️ Configuração do Cliente

### Passo 1: Copiar Certificados do Servidor

No **servidor**, os certificados do cliente estão em:
```
~/docker-client-certs/
├── ca.pem
├── cert.pem
└── key.pem
```

Copie estes arquivos para o seu **computador cliente**. Você pode usar `scp`:

```bash
# No computador cliente, execute:
mkdir -p ~/docker-certs
scp usuario@IP_DO_SERVIDOR:~/docker-client-certs/* ~/docker-certs/
```

Ou use qualquer método de transferência de arquivos (USB, SFTP, etc.).

### Passo 2: Ajustar Permissões dos Certificados

No **computador cliente**:

```bash
chmod 0400 ~/docker-certs/key.pem
chmod 0444 ~/docker-certs/ca.pem ~/docker-certs/cert.pem
```

### Passo 3: Configurar Variáveis de Ambiente

#### Opção A: Temporário (apenas para a sessão atual)

```bash
export DOCKER_HOST=tcp://IP_DO_SERVIDOR:2376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=~/docker-certs
```

#### Opção B: Permanente (adicionar ao ~/.bashrc ou ~/.zshrc)

```bash
echo 'export DOCKER_HOST=tcp://IP_DO_SERVIDOR:2376' >> ~/.bashrc
echo 'export DOCKER_TLS_VERIFY=1' >> ~/.bashrc
echo 'export DOCKER_CERT_PATH=~/docker-certs' >> ~/.bashrc
source ~/.bashrc
```

### Passo 4: Testar Conexão

```bash
docker ps
docker info
docker version
```

## 📝 Exemplos de Uso

### Usar Variáveis de Ambiente

```bash
export DOCKER_HOST=tcp://192.168.1.100:2376
export DOCKER_TLS_VERIFY=1
export DOCKER_CERT_PATH=~/docker-certs

docker ps
docker images
docker run hello-world
```

### Usar Parâmetros na Linha de Comando

```bash
docker --tlsverify \
  --tlscacert=~/docker-certs/ca.pem \
  --tlscert=~/docker-certs/cert.pem \
  --tlskey=~/docker-certs/key.pem \
  -H=tcp://192.168.1.100:2376 \
  ps
```

### Executar Container Remoto

```bash
docker run -d -p 80:80 nginx
```

### Docker Compose com Host Remoto

```bash
# Com variáveis de ambiente configuradas
docker compose up -d

# Ou especificando o host
docker --tlsverify -H=tcp://192.168.1.100:2376 compose up -d
```

### Criar Context do Docker (Recomendado)

Contextos permitem alternar facilmente entre diferentes hosts Docker:

```bash
# Criar contexto
docker context create remote-docker \
  --docker "host=tcp://192.168.1.100:2376,ca=~/docker-certs/ca.pem,cert=~/docker-certs/cert.pem,key=~/docker-certs/key.pem"

# Listar contextos
docker context ls

# Usar contexto
docker context use remote-docker

# Agora todos os comandos docker vão para o servidor remoto
docker ps

# Voltar para o contexto local
docker context use default
```

## 🔧 Solução de Problemas

### Erro: "Cannot connect to the Docker daemon"

**Causa**: Docker não está rodando ou não está acessível.

**Solução no servidor**:
```bash
sudo systemctl status docker
sudo systemctl restart docker
sudo journalctl -xeu docker
```

### Erro: "certificate signed by unknown authority"

**Causa**: Certificados não estão corretos ou o caminho está errado.

**Solução**:
```bash
# Verificar se os arquivos existem
ls -la ~/docker-certs/

# Verificar permissões
chmod 0400 ~/docker-certs/key.pem
chmod 0444 ~/docker-certs/ca.pem ~/docker-certs/cert.pem

# Verificar variáveis de ambiente
echo $DOCKER_CERT_PATH
echo $DOCKER_TLS_VERIFY
echo $DOCKER_HOST
```

### Erro: "connection refused"

**Causa**: Firewall bloqueando ou porta incorreta.

**Solução no servidor**:
```bash
# Verificar se a porta está aberta
sudo netstat -tlnp | grep 2376

# Verificar firewall
sudo ufw status
sudo ufw allow 2376/tcp

# Verificar se o Docker está escutando na porta correta
sudo ss -tlnp | grep dockerd
```

### Permissões do Grupo Docker Não Aplicadas

**Causa**: Precisa fazer logout/login após ser adicionado ao grupo docker.

**Solução**:
```bash
# Verificar se está no grupo
groups

# Fazer logout e login novamente, ou usar:
newgrp docker
```

### Verificar Logs do Docker

```bash
# No servidor
sudo journalctl -u docker.service -f
sudo journalctl -u docker.service --no-pager | tail -100
```

### Testar Certificados Manualmente

```bash
# Verificar certificado do servidor
openssl s_client -connect IP_DO_SERVIDOR:2376 -CAfile ~/docker-certs/ca.pem

# Verificar detalhes do certificado
openssl x509 -in ~/docker-certs/cert.pem -text -noout
```

## 🔒 Segurança

### Boas Práticas

1. **Proteja os Certificados**
   - Nunca compartilhe `key.pem` publicamente
   - Use permissões restritivas (0400 para chaves privadas)
   - Faça backup em local seguro

2. **Firewall**
   - Limite o acesso à porta 2376 apenas a IPs confiáveis
   ```bash
   sudo ufw allow from 192.168.1.0/24 to any port 2376
   ```

3. **Rotação de Certificados**
   - Os certificados gerados são válidos por 365 dias
   - Planeje renovação antes do vencimento
   - Considere usar certificados de curta duração

4. **Monitoramento**
   - Monitore logs do Docker regularmente
   - Audite containers e imagens periodicamente

5. **Atualizações**
   - Mantenha o Docker atualizado
   ```bash
   sudo apt update
   sudo apt upgrade docker-ce docker-ce-cli containerd.io
   ```

### Verificar Data de Expiração dos Certificados

```bash
openssl x509 -in /etc/docker/certs/server-cert.pem -noout -dates
openssl x509 -in ~/docker-certs/cert.pem -noout -dates
```

### Revogar Acesso

Para revogar o acesso de um cliente:
1. Gere novos certificados no servidor
2. Reinicie o Docker daemon
3. Distribua novos certificados apenas para clientes autorizados

### Limitar Acesso por IP (Recomendado)

```bash
# Permitir apenas rede local
sudo ufw delete allow 2376/tcp
sudo ufw allow from 192.168.1.0/24 to any port 2376

# Ou permitir IP específico
sudo ufw allow from 192.168.1.50 to any port 2376
```

## 📚 Referências

- [Docker Documentation - Protect the Docker daemon socket](https://docs.docker.com/engine/security/protect-access/)
- [Docker TLS Configuration](https://docs.docker.com/engine/security/https/)
- [OpenSSL Documentation](https://www.openssl.org/docs/)

## 🆘 Suporte

Se encontrar problemas:

1. Verifique os logs: `sudo journalctl -u docker.service`
2. Verifique a configuração: `cat /etc/docker/daemon.json`
3. Teste a conectividade: `telnet IP_DO_SERVIDOR 2376`
4. Valide os certificados conforme seção de troubleshooting

---

**Nota**: Este setup usa certificados auto-assinados adequados para redes internas. Para ambientes de produção expostos à internet, considere usar certificados de uma CA reconhecida.
