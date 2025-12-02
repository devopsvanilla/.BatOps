# Portainer Docker Setup para WSL com Certificado Auto-Assinado

Uma solução completa para implantar o Portainer no Docker da WSL, acessível via Windows com um domínio customizado (`portainer.local`) usando certificado SSL auto-assinado.

## 📋 Características

- ✅ Acesso via HTTPS com domínio customizado (`portainer.local`)
- ✅ Certificado SSL auto-assinado (sem necessidade de CA)
- ✅ Proxy reverso Nginx para melhor performance
- ✅ Acessível do Windows sem edições complicadas
- ✅ Gerenciamento de containers Docker local
- ✅ Interface web responsiva do Portainer CE
- ✅ Suporte a WebSocket
- ✅ Health checks automáticos

## 🚀 Início Rápido

### 1. Setup Inicial (execute uma vez)

```bash
cd /home/devopsvanilla/.BatOps/docker/portainer
bash setup-portainer.sh
```

Este script irá:
- Verificar dependências (Docker, Docker Compose, OpenSSL)
- Gerar certificados auto-assinados
- Criar diretórios necessários

### 2. Configurar DNS no Windows

Adicione `portainer.local` ao arquivo hosts do Windows. Execute **como Administrador**:

**Opção A: PowerShell (Recomendado)**
```powershell
$hostsPath = "C:\Windows\System32\drivers\etc\hosts"
$entry = "127.0.0.1`t`tportainer.local"
if ((Get-Content $hostsPath) -notcontains $entry) {
    Add-Content -Path $hostsPath -Value "`n$entry" -Force
    Write-Host "portainer.local adicionado ao hosts!" -ForegroundColor Green
}
```

**Opção B: Script Bash (WSL)**
```bash
bash add-to-windows-hosts.sh  # Mostra instruções detalhadas
```

**Opção C: Manual**
- Abra `C:\Windows\System32\drivers\etc\hosts` com Bloco de Notas (como Administrador)
- Adicione a linha: `127.0.0.1    portainer.local`
- Salve o arquivo

### 3. Iniciar Portainer

```bash
bash run-portainer.sh start
```

### 4. Acessar

Abra no navegador:
```
https://portainer.local
```

## 📁 Estrutura de Arquivos

```
.BatOps/docker/portainer/
├── docker-compose.yml          # Configuração dos containers
├── nginx.conf                  # Configuração do proxy reverso
├── generate-certificates.sh    # Script para gerar certificados SSL
├── setup-portainer.sh          # Script de setup inicial
├── run-portainer.sh            # Script para gerenciar Portainer
├── add-to-windows-hosts.sh     # Script para configurar hosts do Windows
├── README.md                   # Esta documentação
├── certs/                      # Certificados SSL (gerado automaticamente)
│   ├── portainer.crt           # Certificado público
│   └── portainer.key           # Chave privada
└── data/                       # Dados persistentes (gerado automaticamente)
    └── portainer-data/         # Volume Docker para dados
```

## 🛠️ Comandos Disponíveis

### Gerenciar Portainer

```bash
# Iniciar
bash run-portainer.sh start

# Parar
bash run-portainer.sh stop

# Reiniciar
bash run-portainer.sh restart

# Ver logs
bash run-portainer.sh logs

# Ver status
bash run-portainer.sh status
```

### Gerenciar Certificados

```bash
# Regenerar certificados
bash generate-certificates.sh
```

## 🔐 Certificados SSL

Os certificados são **auto-assinados**, o que significa:

1. ✅ Não requerem uma Autoridade de Certificação (CA)
2. ✅ São gratuitos e ilimitados
3. ⚠️ Navegadores mostrarão um aviso de segurança
4. ⚠️ Válidos por 365 dias (configure renovação conforme necessário)

### Aceitar Certificado no Navegador

Ao acessar `https://portainer.local`:

1. **Chrome/Edge**: Clique em "Avançado" → "Continuar para portainer.local (inseguro)"
2. **Firefox**: Clique em "Avançado" → "Adicionar Exceção"
3. **Safari**: Clique em "Mostrar Detalhes" → "Acessar este site"

## 🌐 Acesso via Windows

### Via Hostname (Recomendado)

```
https://portainer.local
```

### Via IP Local

Se preferir usar IP, descubra o IP da WSL:

```bash
# No WSL
hostname -I

# No Windows PowerShell
wsl hostname -I
```

Então acesse: `https://<WSL-IP>:443`

## 🐳 Serviços Docker

### Portainer
- **Imagem**: `portainer/portainer-ce:latest`
- **Container**: `portainer`
- **Portas**:
  - 8000 (Portainer Agent)
  - 9443 (HTTPS)
  - 9000 (HTTP → HTTPS redirect)
- **Volumes**: 
  - Docker Socket: `/var/run/docker.sock`
  - Dados: `/data` (volume Docker)

### Nginx Proxy
- **Imagem**: `nginx:alpine`
- **Container**: `portainer-nginx`
- **Portas**:
  - 80 (HTTP → HTTPS redirect)
  - 443 (HTTPS)
- **Funcionalidade**:
  - Proxy reverso para Portainer
  - Suporte a WebSocket
  - SSL/TLS com certificados auto-assinados
  - Headers de segurança

## 🔧 Configurações Personalizadas

### Alterar Hostname

Para usar um domínio diferente (ex: `my-portainer.local`):

1. Edite `nginx.conf`:
   ```nginx
   server_name meu-portainer.local;
   ```

2. Regenere certificados:
   ```bash
   # Edite generate-certificates.sh e altere:
   # -subj "/C=BR/ST=SP/L=Sao Paulo/O=DevOps/CN=meu-portainer.local"
   bash generate-certificates.sh
   ```

3. Reinicie:
   ```bash
   bash run-portainer.sh restart
   ```

### Alterar Timezone

No `docker-compose.yml`, altere a variável de ambiente:
```yaml
environment:
  - TZ=Europe/London  # Por exemplo
```

### Alterar Portas

Para usar portas diferentes, edite `docker-compose.yml`:

```yaml
ports:
  - "8443:443"   # HTTPS em porta 8443
  - "8080:80"    # HTTP em porta 8080
```

## 🔒 Segurança

### Boas Práticas Implementadas

1. ✅ HTTPS obrigatório
2. ✅ HTTP redireciona para HTTPS
3. ✅ Headers de segurança configurados:
   - `Strict-Transport-Security`
   - `X-Frame-Options`
   - `X-Content-Type-Options`
   - `X-XSS-Protection`
4. ✅ Socket Docker em modo read-only
5. ✅ Containers sem privilégios elevados
6. ✅ Restart automático em caso de falha

### Recomendações Adicionais

1. **Senha forte**: Crie uma senha robusta ao configurar a primeira conta
2. **Firewall**: Configure o firewall para aceitar apenas conexões locais
3. **Renovação de Certificados**: Regenere os certificados anualmente
4. **Backups**: Faça backup regular do volume `portainer-data`

## 📊 Monitoramento

### Verificar Status

```bash
bash run-portainer.sh status
```

### Ver Logs

```bash
bash run-portainer.sh logs

# Ou com Docker
docker logs portainer
docker logs portainer-nginx
```

### Health Check

```bash
# Verificar conectividade
curl -k https://portainer.local/api/status

# Com DNS resolution
curl -k -H "Host: portainer.local" https://127.0.0.1/api/status
```

## 🐛 Troubleshooting

### Problema: "Certificado não confiável"

**Solução**: Este é o comportamento esperado de certificados auto-assinados. Adicione uma exceção no navegador.

### Problema: "portainer.local não pode ser encontrado"

**Solução**: Verifique se o host foi adicionado corretamente:

```powershell
# No Windows PowerShell
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String "portainer"
```

Se não estiver lá, execute como Administrador:
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force
```

### Problema: "Connection refused"

**Solução**: Verifique se o Portainer está rodando:

```bash
bash run-portainer.sh status
```

Se não estiver, inicie:

```bash
bash run-portainer.sh start
```

### Problema: "Certificate verify failed"

**Solução**: Use a flag `-k` com curl ou adicione uma exceção no navegador:

```bash
curl -k https://portainer.local
```

### Problema: Containers não iniciam

**Solução**: Verifique os logs:

```bash
bash run-portainer.sh logs
```

Verifique se os certificados existem:

```bash
ls -la ./certs/
```

Se não, execute o setup:

```bash
bash setup-portainer.sh
```

## 📚 Referências

- [Portainer Documentation](https://docs.portainer.io/)
- [Nginx Reverse Proxy](https://nginx.org/en/docs/)
- [Docker Compose Reference](https://docs.docker.com/compose/compose-file/)
- [WSL Networking](https://learn.microsoft.com/en-us/windows/wsl/networking)
- [OpenSSL Certificate Generation](https://www.openssl.org/docs/)

## 📝 Licença

Este projeto está sob a licença MIT. Veja LICENSE para detalhes.

## ✨ Próximos Passos

1. ✅ Execute: `bash setup-portainer.sh`
2. ✅ Configure o DNS do Windows
3. ✅ Execute: `bash run-portainer.sh start`
4. ✅ Acesse: `https://portainer.local`
5. ✅ Configure a primeira conta admin
6. ✅ Conecte o endpoint Docker local

## 🤝 Suporte

Para issues ou dúvidas, consulte a documentação do Portainer ou execute:

```bash
bash run-portainer.sh status
```

---

**Última atualização**: Dezembro 2025
