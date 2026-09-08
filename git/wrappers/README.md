# 🏗️ Git Helpers — Soluções BatOps

Soluções para gerenciar e facilitar o trabalho com repositórios Git.

---

## 📋 Scripts Disponíveis

| Script | Descrição |
|---|---|
| `git-resetall.sh` | Descarta todas as alterações (staged, unstaged, untracked) |
| `cd-git-root.sh` | Navega automaticamente para a raiz do repositório Git corrente |

---

## 🚀 Como Utilizar

### Exemplo — Reset de Repositório

```bash
chmod +x git-resetall.sh
./git-resetall.sh
```

---

## 🛠️ Detalhes Adicionais

### git-resetall.sh

O script pergunta por confirmação antes de descartar dados valiosos. Ele limpa inclusive arquivos `.env` se não estiverem no `.gitignore`.

---

## 📚 Referências

- [Official Git Documentation](https://git-scm.com/doc)
- [Git Clean Manual](https://git-scm.com/docs/git-clean)
