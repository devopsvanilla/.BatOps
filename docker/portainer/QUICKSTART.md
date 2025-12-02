# ⚡ Quick Start - Portainer

## 🎯 Resumo
Solução completa para implantar Portainer em Docker (WSL) acessível do Windows via `https://portainer.local` com certificado auto-assinado.

## 🚀 Comece em 3 Passos

### Passo 1: Setup (Execute uma vez)
```bash
cd /home/devopsvanilla/.BatOps/docker/portainer
bash setup-portainer.sh
```
✅ Gera certificados  
✅ Cria diretórios  
✅ Valida dependências  

### Passo 2: Configurar DNS no Windows
Execute **como Administrador** no PowerShell:
```powershell
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force
```

Ou com script bash:
```bash
bash add-to-windows-hosts.sh
```

### Passo 3: Iniciar Portainer
```bash
bash run-portainer.sh start
```

## 🌐 Acessar
Abra no navegador Windows:
```
https://portainer.local
```

⚠️ **Certificado auto-assinado**: Clique em "Avançado" ou "Aceitar risco"

---

## 📋 Comandos Úteis

```bash
# Status
bash run-portainer.sh status

# Logs
bash run-portainer.sh logs

# Reiniciar
bash run-portainer.sh restart

# Parar
bash run-portainer.sh stop

# Diagnóstico
bash diagnose-portainer.sh

# Menu interativo
bash COMECE_AQUI.sh
```

---

## 🔐 Informações Técnicas

| Item | Valor |
|------|-------|
| **Host** | portainer.local |
| **Protocolo** | HTTPS (443) |
| **Certificado** | Auto-assinado (365 dias) |
| **Proxy** | Nginx |
| **Docker Socket** | /var/run/docker.sock |
| **Volume Data** | Docker volume |

---

## 🐛 Problemas Comuns

### "portainer.local não encontrado"
```powershell
# Verificar se foi adicionado
Get-Content C:\Windows\System32\drivers\etc\hosts | Select-String portainer

# Adicionar se necessário
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force
```

### "Connection refused"
```bash
# Verificar se está rodando
bash run-portainer.sh status

# Iniciar
bash run-portainer.sh start
```

### "Certificado inválido"
Comportamento normal para auto-assinado. Clique em "Avançado" no navegador.

---

## 📁 Arquivos

```
.
├── docker-compose.yml          # Configuração principal
├── nginx.conf                  # Proxy reverso
├── run-portainer.sh            # Gerenciar containers
├── setup-portainer.sh          # Setup inicial
├── generate-certificates.sh    # Gerar certificados
├── diagnose-portainer.sh       # Diagnosticar
├── add-to-windows-hosts.sh     # Configurar DNS
├── COMECE_AQUI.sh             # Menu interativo
├── README.md                   # Documentação completa
├── QUICKSTART.md              # Este arquivo
├── certs/                      # Certificados (gerado)
└── data/                       # Dados (gerado)
```

---

## ✅ Checklist

- [ ] Executar `bash setup-portainer.sh`
- [ ] Adicionar portainer.local ao hosts do Windows
- [ ] Executar `bash run-portainer.sh start`
- [ ] Acessar `https://portainer.local`
- [ ] Criar conta admin
- [ ] Conectar endpoint Docker

---

## 🔗 Links Úteis

- 📚 [Documentação Completa](README.md)
- 🐳 [Portainer Docs](https://docs.portainer.io/)
- 🔐 [WSL Networking](https://learn.microsoft.com/en-us/windows/wsl/networking)

---

**Última atualização**: Dezembro 2025
