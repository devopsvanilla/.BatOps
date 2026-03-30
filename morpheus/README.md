# 🏗️ Morpheus Data — Soluções BatOps

Soluções para automação e diagnóstico do Morpheus Data Enterprise.

---

## 📋 Soluções Disponíveis

| Script | Descrição | Documentação |
|---|---|---|
| `setup-morpheus-nfs.sh` | Instalação e configuração de servidor NFS para storage | [docs](SETUP-NFS.md) |
| `set-morpheus-logback.sh` | Backup e restauração de logs da UI do Morpheus | N/A |
| `delete-morpheus-logs.sh` | Limpeza rápida de logs da interface Health | N/A |
| `list-morpheus-aws-permissions.sh` | Teste de permissões de perfil AWS para integração | N/A |

---

## 🚀 Como Utilizar

### Requisitos Gerais

- Acesso root/sudo no servidor Morpheus
- AWS CLI configurado (para o script de permissões)

### Exemplo — Limpeza de Logs

```bash
chmod +x delete-morpheus-logs.sh
sudo ./delete-morpheus-logs.sh
```

---

## 🛠️ Detalhes Adicionais

Consulte os arquivos individuais ou a documentação específica (`SETUP-NFS.md`) para detalhes sobre parâmetros e pré-requisitos.

---

## 📚 Referências

- [Morpheus Data Enterprise Documentation](https://docs.morpheusdata.com/)
- [Morpheus Health Documentation](https://docs.morpheusdata.com/en/latest/administration/health/health.html)
