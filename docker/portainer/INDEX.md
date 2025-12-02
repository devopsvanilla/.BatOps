# 🚀 Portainer Setup - Índice Completo

## 📂 Estrutura do Projeto

```
/home/devopsvanilla/.BatOps/docker/portainer/
│
├── 📄 COMECE_AQUI.sh              ← 🌟 COMECE AQUI (menu interativo)
├── 📄 QUICKSTART.md               ← Quick start em 3 passos
├── 📄 README.md                   ← Documentação completa
├── 📄 TROUBLESHOOTING.md          ← Guia de problemas
│
├── 🔧 Scripts Executáveis
│  ├── setup-portainer.sh          ← Setup inicial (execute uma vez)
│  ├── run-portainer.sh            ← Gerenciar containers (start/stop/logs)
│  ├── generate-certificates.sh    ← Gerar certificados SSL
│  ├── diagnose-portainer.sh       ← Diagnosticar problemas
│  └── add-to-windows-hosts.sh     ← Configurar DNS Windows
│
├── 🐳 Configuração Docker
│  ├── docker-compose.yml          ← Manifest dos containers
│  └── nginx.conf                  ← Proxy reverso (portainer.local)
│
├── 🔐 Certificados (gerados automaticamente)
│  └── certs/
│       ├── portainer.crt          ← Certificado público
│       └── portainer.key          ← Chave privada
│
├── 💾 Dados Persistentes
│  └── data/                       ← Volume Docker
│
└── ⚙️  Configuração
    └── .gitignore                 ← Exclusões Git
```

---

## ⚡ Começar em 5 Minutos

### Opção 1: Menu Interativo (Recomendado para iniciantes)
```bash
cd /home/devopsvanilla/.BatOps/docker/portainer
bash COMECE_AQUI.sh
```
👉 Abre um menu com todas as opções

### Opção 2: Linha de Comando (Para usuários avançados)
```bash
cd /home/devopsvanilla/.BatOps/docker/portainer

# 1. Setup
bash setup-portainer.sh

# 2. Configurar DNS (no PowerShell Windows como Administrador)
Add-Content -Path C:\Windows\System32\drivers\etc\hosts -Value "`n127.0.0.1`t`tportainer.local" -Force

# 3. Iniciar
bash run-portainer.sh start

# 4. Acessar
# https://portainer.local
```

---

## 📖 Documentação por Tópico

### 🎯 Primeiros Passos
1. Leia [QUICKSTART.md](QUICKSTART.md) - Começo rápido em 3 passos
2. Execute [setup-portainer.sh](setup-portainer.sh) - Setup inicial

### 📚 Guias Detalhados
- [README.md](README.md) - Documentação completa (características, segurança, configuração)
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Resolver problemas comuns

### 🔧 Scripts Disponíveis

| Script | Função | Comando |
|--------|--------|---------|
| `setup-portainer.sh` | Setup inicial | `bash setup-portainer.sh` |
| `run-portainer.sh` | Gerenciar containers | `bash run-portainer.sh start/stop/restart/logs/status` |
| `generate-certificates.sh` | Gerar/renovar certificados | `bash generate-certificates.sh` |
| `diagnose-portainer.sh` | Diagnosticar problemas | `bash diagnose-portainer.sh` |
| `add-to-windows-hosts.sh` | Instruções DNS Windows | `bash add-to-windows-hosts.sh` |
| `COMECE_AQUI.sh` | Menu interativo | `bash COMECE_AQUI.sh` |

---

## 🎯 Casos de Uso Comuns

### ✅ Primeira Execução
```bash
bash setup-portainer.sh              # Setup
bash run-portainer.sh start          # Iniciar
# Abrir: https://portainer.local
```

### ✅ Parar Temporariamente
```bash
bash run-portainer.sh stop
```

### ✅ Reiniciar
```bash
bash run-portainer.sh restart
```

### ✅ Ver Logs
```bash
bash run-portainer.sh logs           # Com -f para seguir
```

### ✅ Diagnosticar Problemas
```bash
bash diagnose-portainer.sh
```

### ✅ Renovar Certificados
```bash
bash generate-certificates.sh
bash run-portainer.sh restart
```

---

## 🌐 Acesso

### URL Principal
```
https://portainer.local
```

### URLs Alternativas
```
https://127.0.0.1                    # Direct HTTPS (porta 443)
https://127.0.0.1:9443              # Portainer direct (porta 9443)
http://portainer.local               # HTTP (redireciona para HTTPS)
```

### IPs e Hosts
```bash
# IP da WSL
hostname -I

# Hostname da WSL
hostname

# Testar DNS do Windows
nslookup portainer.local             # WSL
ping portainer.local                 # Windows PowerShell
```

---

## 🔐 Segurança

### Certificado
- ✅ Auto-assinado (válido por 365 dias)
- ✅ RSA 4096 bits
- ✅ Domain: `portainer.local`
- ✅ SubjectAlt: `*.portainer.local`, `127.0.0.1`

### HTTPS Obrigatório
- ✅ HTTP (80) redireciona para HTTPS (443)
- ✅ HSTS habilitado
- ✅ Headers de segurança configurados

### Boas Práticas
1. Crie senha admin forte
2. Mantenha certificados atualizados
3. Faça backup regular do volume
4. Configure firewall conforme necessário

---

## 📊 Informações Técnicas

### Serviços Docker
- **Portainer**: `portainer/portainer-ce:latest`
- **Nginx**: `nginx:alpine`

### Portas
| Porta | Serviço | Protocolo |
|-------|---------|-----------|
| 80 | Nginx HTTP | HTTP |
| 443 | Nginx HTTPS | HTTPS |
| 8000 | Portainer Agent | TCP |
| 9000 | Portainer HTTP | HTTP |
| 9443 | Portainer HTTPS | HTTPS |

### Volumes
- `portainer-data` - Dados persistentes
- Docker Socket (`/var/run/docker.sock`) - Acesso ao Docker

### Rede
- `portainer-network` - Rede bridge Docker

---

## 🆘 Problemas Frequentes

### "portainer.local não encontrado"
→ Veja [Configurar DNS no Windows](TROUBLESHOOTING.md#problema-portainerlocal-não-pode-ser-encontrado)

### "Connection refused"
→ Verifique se está rodando: `bash run-portainer.sh status`

### "Certificado não confiável"
→ Normal para auto-assinado. Clique "Avançado" no navegador.

### Mais problemas?
→ Consulte [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para soluções detalhadas

---

## 📞 Suporte Rápido

### Ver Status
```bash
bash run-portainer.sh status
```

### Ver Logs
```bash
bash run-portainer.sh logs
```

### Executar Diagnóstico
```bash
bash diagnose-portainer.sh
```

### Menu Interativo
```bash
bash COMECE_AQUI.sh
```

---

## 🔄 Fluxo de Atualização

### Atualizar Imagem Portainer
```bash
docker pull portainer/portainer-ce:latest
bash run-portainer.sh restart
```

### Renovar Certificados
```bash
bash generate-certificates.sh
bash run-portainer.sh restart
```

### Limpar Dados (Cuidado!)
```bash
bash run-portainer.sh stop
docker volume rm portainer_portainer-data
bash run-portainer.sh start
```

---

## 📚 Referências Externas

- 🐳 [Portainer Official](https://www.portainer.io/)
- 📖 [Portainer Documentation](https://docs.portainer.io/)
- 🔗 [Docker Compose Reference](https://docs.docker.com/compose/)
- 🌐 [Nginx Documentation](https://nginx.org/en/docs/)
- 🔐 [OpenSSL Manual](https://www.openssl.org/docs/)
- 💻 [WSL Networking](https://learn.microsoft.com/en-us/windows/wsl/networking)

---

## 📝 Versão e Data

- **Data de Criação**: Dezembro 2025
- **Versão**: 1.0
- **Portainer**: CE (Community Edition) Latest
- **Nginx**: Alpine Latest
- **Certificado**: Auto-assinado, válido até Dezembro 2026

---

## ✨ Próximos Passos

1. ✅ Execute: `bash setup-portainer.sh`
2. ✅ Configure: `bash add-to-windows-hosts.sh` (ou manual)
3. ✅ Inicie: `bash run-portainer.sh start`
4. ✅ Acesse: `https://portainer.local`
5. ✅ Configure: Crie conta admin
6. ✅ Explore: Gerencie seus containers!

---

**🎉 Tudo pronto! Comece com `bash COMECE_AQUI.sh` ou `bash QUICKSTART.md`**
