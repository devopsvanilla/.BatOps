# 🤝 Como Contribuir

Obrigado pelo interesse em contribuir com o **BatOps**! Este documento descreve as diretrizes e o processo para contribuição.

---

## 📋 Sumário

- [Código de Conduta](#-código-de-conduta)
- [Como Começar](#-como-começar)
- [Fluxo de Trabalho](#-fluxo-de-trabalho)
- [Padrão de Commits](#-padrão-de-commits)
- [Estrutura de uma Solução](#-estrutura-de-uma-solução)
- [Documentação](#-documentação)
- [Revisão de Código](#-revisão-de-código)

---

## 📜 Código de Conduta

- Seja respeitoso e construtivo nas interações.
- Foque em soluções, não em problemas.
- Documente suas decisões técnicas.

---

## 🚀 Como Começar

1. **Fork** o repositório
2. **Clone** o seu fork:

```bash
git clone https://github.com/<seu-usuario>/batops.git
cd batops
```

3. Adicione o repositório original como `upstream`:

```bash
git remote add upstream https://github.com/devopsvanilla/batops.git
```

4. Mantenha seu fork atualizado:

```bash
git fetch upstream
git checkout main
git merge upstream/main
```

---

## 🔀 Fluxo de Trabalho

Utilizamos **Gitflow baseado em Pull Requests**:

### Branches

| Tipo | Padrão | Uso |
|---|---|---|
| `feature/<nome>` | `feature/add-monitoring-alerts` | Novas funcionalidades |
| `fix/<nome>` | `fix/docker-reset-permissions` | Correções de bugs |
| `hotfix/<nome>` | `hotfix/ssh-diagnostics-crash` | Correções urgentes em produção |
| `docs/<nome>` | `docs/update-docker-guide` | Alterações de documentação |
| `refactor/<nome>` | `refactor/simplify-port-scanner` | Refatorações sem mudança funcional |
| `ci/<nome>` | `ci/add-shellcheck-pipeline` | Alterações em CI/CD |

### Processo

1. Crie uma branch a partir de `main`:

```bash
git checkout main
git pull origin main
git checkout -b feature/minha-nova-feature
```

2. Faça suas alterações e commits (veja [Padrão de Commits](#-padrão-de-commits)).

3. Envie para o seu fork:

```bash
git push origin feature/minha-nova-feature
```

4. Abra um **Pull Request** para a branch `main` do repositório original.

5. Aguarde a revisão e aprovação.

### Regras

- Todo merge para `main` deve ser via **Pull Request**.
- PRs devem passar por **todos os checks do CI** antes do merge.
- Utilize **Squash and Merge** para manter o histórico limpo.
- Remova branches após o merge.

---

## 📝 Padrão de Commits

Seguimos a especificação **[Conventional Commits](https://www.conventionalcommits.org/pt-br/)**:

```
<tipo>[escopo opcional]: <descrição>

[corpo opcional]

[rodapé(s) opcional(is)]
```

### Tipos Permitidos

| Tipo | Uso |
|---|---|
| `feat` | Nova funcionalidade |
| `fix` | Correção de bug |
| `docs` | Alteração em documentação |
| `style` | Formatação (sem mudança de lógica) |
| `refactor` | Refatoração de código |
| `perf` | Melhoria de performance |
| `test` | Adição/correção de testes |
| `build` | Mudanças no build ou dependências |
| `ci` | Mudanças em CI/CD |
| `chore` | Tarefas diversas (manutenção) |
| `revert` | Reversão de commit anterior |

### Exemplos

```
feat(docker): adiciona stack do Grafana com Prometheus
fix(proxmox): corrige detecção de disco no create-proxmox-vm
docs: atualiza índice do README com novas soluções
ci: adiciona validação shellcheck no pipeline
```

---

## 📁 Estrutura de uma Solução

Ao adicionar uma nova solução, siga esta estrutura:

```
solucao/
├── README.md           # Documentação da solução
├── script-principal.sh # Script principal (ou .py, .ps1, etc.)
├── assets/             # Imagens e materiais de apoio (se necessário)
├── docs/               # Documentação complementar (se necessário)
└── THIRDPARTY.md       # Soluções de terceiros utilizadas (se aplicável)
```

---

## 📖 Documentação

Toda solução **deve** incluir documentação com as seguintes seções:

1. **Objetivo** — O que faz e qual problema resolve
2. **Diagrama da Solução** — Representação visual (Mermaid quando possível)
3. **Requisitos e Dependências** — Pré-requisitos e versões mínimas
4. **Como Utilizar e Resultados Esperados** — Instruções com exemplos de saída
5. **Guia de Solução de Problemas** — Troubleshooting
6. **Referências** — Links para documentação oficial
7. **Isenção de Responsabilidade** — Disclaimer sobre uso

Ao criar ou alterar código, **atualize simultaneamente** a documentação correspondente e o [README.md](README.md) principal (índice).

---

## 🔍 Revisão de Código

### O que verificamos

- ✅ Código segue as boas práticas da linguagem/ferramenta
- ✅ Documentação está presente e atualizada
- ✅ Scripts Bash possuem `set -euo pipefail` e passam no `shellcheck`
- ✅ Não há segredos ou credenciais hardcoded
- ✅ `.gitignore` está adequado
- ✅ Commits seguem Conventional Commits

### Dicas para uma boa PR

- Mantenha as PRs pequenas e focadas
- Descreva o **porquê** da mudança, não apenas o **quê**
- Inclua exemplos de uso quando relevante
- Teste seus scripts antes de submeter

---

## 📄 Licença

Ao contribuir, você concorda que suas contribuições serão licenciadas sob a [Licença MIT](LICENSE) do projeto.
