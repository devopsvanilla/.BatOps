# 🪟 Windows PowerShell — Soluções BatOps

Soluções para operação e otimização no Windows usando PowerShell.

---

## 📋 Scripts Disponíveis

| Script | Descrição | Requisitos |
|---|---|---|
| `Compact-WSL.ps1` | Compactação de discos VHDX do WSL com backup seguro | PowerShell 5.1+, Administrador |
| `Reset-GitHubCopilotVSCode.ps1` | Reseta extensões e dados residuais do GitHub Copilot no VS Code | PowerShell 5.1+ |

---

## 🚀 Como Utilizar

### Execução de Scripts PowerShell

Para rodar os scripts, é necessário habilitar a política de execução ou usar as seguintes opções:

```powershell
powershell -ExecutionPolicy Bypass -File .\Compact-WSL.ps1
```

### Exemplo — Compactação WSL

O script solicita o nome da distribuição e realiza o backup em `~/WSL_Backups/` antes de compactar. Requer execução como **Administrador**.

---

## 📚 Referências

- [Official Microsoft WSL Documentation](https://learn.microsoft.com/en-us/windows/wsl/)
- [Virtual Disk Service (diskpart)](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/diskpart)
