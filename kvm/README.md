# 📦 KVM & QEMU — Soluções BatOps

Utilitários para gerenciamento de imagens e virtualização em nível de host (QEMU/KVM).

---

## 📋 Soluções Disponíveis

| Script | Descrição |
|---|---|
| `convert-ovn2qcow2` | Conversão manual de imagens/snapshots OVN para formato QCOW2 |

---

## 🚀 Como Utilizar

### Exemplo — Conversão de Imagem OVN

Consulte o diretório [convert-ovn2qcow2/](convert-ovn2qcow2/) para os scripts de conversão e especificações de uso.

---

## 🛠️ Detalhes e Requisitos

- `qemu-utils` instalado (para `qemu-img`)
- Acesso de leitura ao storage de origem (OVN/Proxmox)

---

## 📚 Referências

- [QEMU 공식 문서](https://www.qemu.org/docs/master/)
- [Proxmox Disk Management](https://pve.proxmox.com/wiki/Storage:_ZFS#_disk_management)
