# 🐧 Utilitários Linux — Soluções BatOps

Coleção de scripts utilitários para diagnóstico e operação em sistemas Linux.

---

## 📋 Scripts Disponíveis

| Script | Descrição | Requisitos |
|---|---|---|
| `get-linux-version.sh` | Detecta a versão/distribuição do Linux usando múltiplos métodos | N/A |
| `gravar-terminal.sh` | Grava sessões de terminal usando asciinema | asciinema |

---

## 🚀 Como Utilizar

### Exemplo — Detecção de Versão

```bash
chmod +x get-linux-version.sh
./get-linux-version.sh
```

---

## 🛠️ Detalhes Adicionais

### asciinema (gravar-terminal.sh)

O script `gravar-terminal.sh` irá instalar automaticamente o `asciinema` se não estiver presente (requer sudo).

---

## 📚 Referências

- [asciinema official docs](https://asciinema.org/docs/)
- [os-release standard](https://www.freedesktop.org/software/systemd/man/os-release.html)
