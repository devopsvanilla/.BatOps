# 🖥️ Proxmox VE — Soluções BatOps

Soluções para automação e diagnóstico em ambientes de virtualização Proxmox VE.

---

## 📋 Scripts Disponíveis

| Script | Descrição |
|---|---|
| `create-proxmox-vm.sh` | Criação interativa de VMs Ubuntu 24.04 com Cloud-Init |
| `get-proxmox-cloudinit-diagnostics.sh` | Script de diagnóstico completo de Cloud-Init dentro da VM |

---

## 🚀 Como Utilizar

### 1. Criando uma VM

```bash
chmod +x create-proxmox-vm.sh
sudo ./create-proxmox-vm.sh <nome_vm> <ip_static>
```

### 2. Diagnóstico Cloud-Init (Executar dentro da VM)

```bash
chmod +x get-proxmox-cloudinit-diagnostics.sh
sudo ./get-proxmox-cloudinit-diagnostics.sh
```

---

## 🛠️ Detalhes Adicionais

### Referência de Parâmetros (create-proxmox-vm)

- Nome da VM e IP são obrigatórios no comando inicial.
- O script solicita interativamente: bridge, storage, memória, cores, etc.

### Diagnóstico de Cloud-Init

O script de diagnóstico deve ser copiado para dentro da VM criada para analisar falhas de Provisioning SSH, rede ou usuários.

---

## 📚 Referências

- [Proxmox VE Documentation](https://pve.proxmox.com/pve-docs/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
