# 🔍 Diagnóstico de Rede e Segurança — Soluções BatOps

Ferramentas para monitoramento de portas, firewall, conectividade SSH e auditoria de sites.

---

## 📋 Scripts Disponíveis

| Script | Descrição |
|---|---|
| `list-ports-and-firewall.sh` | Relatório completo de portas (ss/netstat) e regras de firewall (UFW/iptables) |
| `list-ports-simple.sh` | Versão simplificada e rápida para listagem de portas em uso |
| `audit-site-simple.sh` | Auditoria básica de disponibilidade e headers de sites |
| `get-ssh-diagnostics.sh` | Diagnóstico de autenticação (senha/chave) e cloud-init SSH |

---

## 🚀 Como Utilizar

### 1. Diagnóstico de Portas e Firewall

```bash
chmod +x list-ports-and-firewall.sh
sudo ./list-ports-and-firewall.sh
```

### 2. Diagnóstico de SSH

```bash
chmod +x get-ssh-diagnostics.sh
sudo ./get-ssh-diagnostics.sh
```

---

## 🛠️ Detalhes e Requisitos

### Dependências Comuns

- `net-tools` (para `netstat`) ou `iproute2` (para `ss`)
- `ufw` / `iptables`
- `lsof` (opcional, para informações detalhadas de processo)

### Permissões

A maioria dos scripts requer **root/sudo** para exibir informações completas de processos de outros usuários ou configurações do sistema (firewall).

---

## 📚 Referências

- [Nmap Security Scanner](https://nmap.org/)
- [UFW - Uncomplicated Firewall](https://help.ubuntu.com/community/UFW)
- [OpenSSH Documentation](https://www.openssh.com/manual.html)
