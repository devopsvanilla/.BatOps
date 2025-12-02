# Troubleshooting - Portainer

## Testes de Conectividade

### Teste 1: Resolver DNS
```bash
# WSL
nslookup portainer.local
dig portainer.local

# Windows PowerShell
[System.Net.Dns]::GetHostAddresses("portainer.local")
```

### Teste 2: Connectivity HTTPS
```bash
# Verificar se HTTPS está respondendo
curl -k https://portainer.local
curl -k https://127.0.0.1:443
curl -k https://127.0.0.1:9443
```

### Teste 3: Verificar Portas Abertas
```bash
# Listar portas abertas
netstat -tuln | grep LISTEN

# Verificar porta específica
ss -tuln | grep ":443"
ss -tuln | grep ":80"
ss -tuln | grep ":9443"
```

## Problemas e Soluções

### ❌ Erro: "Unable to find image 'portainer/portainer-ce:latest'"

**Causa**: Imagem não foi baixada

**Solução**:
```bash
# Puxar imagem manualmente
docker pull portainer/portainer-ce:latest

# Tentar iniciar novamente
bash run-portainer.sh start
```

### ❌ Erro: "Cannot connect to Docker daemon"

**Causa**: Docker daemon não está rodando ou socket não está acessível

**Solução**:
```bash
# Verificar status do Docker
docker ps

# Reiniciar Docker (no WSL)
sudo systemctl restart docker

# Verificar permissões do socket
ls -la /var/run/docker.sock

# Se necessário, adicionar permissões
sudo usermod -aG docker $USER
newgrp docker
```

### ❌ Erro: "Port 443 already in use"

**Causa**: Outra aplicação está usando a porta

**Solução**:
```bash
# Encontrar processo usando porta 443
sudo lsof -i :443

# Ou com netstat
sudo netstat -tuln | grep ":443"

# Alterar porta no docker-compose.yml
# Editar: ports: ["8443:443"]
# Então acessar: https://portainer.local:8443
```

### ❌ Erro: "Certificate verification failed"

**Causa**: Navegador rejeitando certificado auto-assinado

**Solução**:
```bash
# Chrome/Edge: Clique "Avançado" → "Continuar para portainer.local (inseguro)"
# Firefox: Clique "Avançado" → "Adicionar Exceção"
# Safari: Clique "Mostrar Detalhes" → "Acessar este site"

# Ou use curl com -k flag
curl -k https://portainer.local/api/status
```

### ❌ Erro: "Connection refused"

**Causa**: Portainer não está rodando

**Solução**:
```bash
# Verificar status
bash run-portainer.sh status

# Ver logs detalhados
bash run-portainer.sh logs

# Iniciar
bash run-portainer.sh start

# Aguardar 10 segundos
sleep 10

# Testar novamente
curl -k https://portainer.local
```

### ❌ Erro: "getaddrinfo: Name or service not known"

**Causa**: DNS não está resolvendo portainer.local

**Solução**:
```bash
# Verificar hosts do Windows
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String portainer

# Adicionar se não estiver
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force

# Limpar DNS cache Windows
ipconfig /flushdns

# Testar DNS
nslookup portainer.local
```

### ❌ Erro: "Nginx: upstream timed out"

**Causa**: Portainer está lento ou não respondendo

**Solução**:
```bash
# Verificar logs do Portainer
docker logs portainer

# Verificar uso de recursos
docker stats portainer

# Reiniciar containers
bash run-portainer.sh restart

# Aumentar timeout no nginx.conf se necessário
# proxy_connect_timeout 600s;
```

### ❌ Erro: "Permission denied" ao gerar certificados

**Causa**: Falta de permissões em diretório

**Solução**:
```bash
# Verificar permissões
ls -la /home/devopsvanilla/.BatOps/docker/portainer/

# Dar permissões
chmod 755 /home/devopsvanilla/.BatOps/docker/portainer/
chmod 755 /home/devopsvanilla/.BatOps/docker/portainer/*.sh

# Criar diretório certs com permissões
mkdir -p /home/devopsvanilla/.BatOps/docker/portainer/certs
chmod 755 /home/devopsvanilla/.BatOps/docker/portainer/certs
```

### ❌ Erro: "Docker volume already exists"

**Causa**: Volume foi criado anteriormente

**Solução**:
```bash
# Ver volumes
docker volume ls

# Remover volume específico (cuidado: perderá dados!)
docker volume rm portainer_portainer-data

# Limpar tudo
docker volume prune
```

## Performance

### Otimizar Performance

```bash
# Aumentar limite de arquivos
ulimit -n 65536

# Verificar cache de DNS
cat /etc/resolv.conf

# Monitorar uso de recursos
docker stats

# Limpar dados desnecessários
docker system prune
docker volume prune
docker image prune
```

## Backup e Restore

### Backup de Dados
```bash
# Fazer backup do volume
docker run --rm -v portainer_portainer-data:/data -v $(pwd):/backup \
  alpine tar czf /backup/portainer-backup.tar.gz -C / data

# Ou usar rsync
docker run --rm -v portainer_portainer-data:/data \
  alpine tar czf /data-backup.tar.gz /data
```

### Restore de Dados
```bash
# Restaurar volume
docker run --rm -v portainer_portainer-data:/data -v $(pwd):/backup \
  alpine tar xzf /backup/portainer-backup.tar.gz -C /
```

## Logs Avançados

### Aumentar verbosidade dos logs
```bash
# Ver logs do nginx
docker logs portainer-nginx -f

# Ver logs do Portainer
docker logs portainer -f

# Ver logs com timestamp
docker logs --timestamps portainer

# Ver últimas 100 linhas
docker logs --tail 100 portainer
```

### Logs do Docker Daemon
```bash
# No WSL
journalctl -u docker -n 100 -f

# Ou verificar arquivo de log
sudo tail -f /var/log/docker.log
```

## Reset Completo

### Limpar Tudo e Recomeçar
```bash
# Parar containers
bash run-portainer.sh stop

# Remover containers
docker compose down

# Remover volume (CUIDADO: perderá dados!)
docker volume rm portainer_portainer-data

# Remover rede
docker network prune -f

# Regenerar certificados
bash generate-certificates.sh

# Recomeçar
bash run-portainer.sh start
```

## Verificações de Segurança

### Verificar Certificado
```bash
# Ver informações do certificado
openssl x509 -in ./certs/portainer.crt -text -noout

# Verificar datas de validade
openssl x509 -in ./certs/portainer.crt -noout -dates

# Verificar subject alternativos
openssl x509 -in ./certs/portainer.crt -noout -text | grep -A 1 "Subject Alternative Name"

# Verificar fingerprint
openssl x509 -in ./certs/portainer.crt -noout -fingerprint
```

### Verificar Chave Privada
```bash
# Verificar se a chave está correta
openssl rsa -in ./certs/portainer.key -check

# Verificar tamanho da chave
openssl rsa -in ./certs/portainer.key -text -noout | grep "Private-Key:"
```

## Monitoramento Contínuo

### Script de Monitoramento
```bash
#!/bin/bash
# monitor-portainer.sh

while true; do
    clear
    echo "=== Status Portainer ==="
    docker ps --filter "name=portainer"
    echo ""
    echo "=== Uso de Recursos ==="
    docker stats --no-stream portainer
    echo ""
    echo "=== Teste HTTP ==="
    curl -s -k https://portainer.local/api/status | head -20
    echo ""
    sleep 10
done
```

Execute com:
```bash
chmod +x monitor-portainer.sh
./monitor-portainer.sh
```

## Contato e Documentação

- 📖 [README Completo](README.md)
- ⚡ [Quick Start](QUICKSTART.md)
- 🐳 [Portainer Official](https://docs.portainer.io/)
- 🔐 [WSL Docs](https://learn.microsoft.com/en-us/windows/wsl/)
- 📦 [Docker Docs](https://docs.docker.com/)
