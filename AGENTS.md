# Orientações para Agentes de IA (AGENTS.md)

Este documento estabelece as diretrizes de desenvolvimento, padrões de código e validações obrigatórias para qualquer agente ou automação que gere ou altere arquivos neste repositório.

---

## 🛡️ Validações Pré-Commit Obrigatórias

O repositório possui ganchos (*hooks*) configurados via `pre-commit` (`.pre-commit-config.yaml`). Toda modificação deve atender estritamente aos seguintes critérios antes de ser considerada concluída:

### 1. Espaços em Branco e Fim de Arquivo

- **`trailing-whitespace`**: Não deixe espaços em branco no final de linhas de nenhum arquivo (`.sh`, `.md`, `.yaml`, etc.).
- **`end-of-file-fixer`**: Todos os arquivos de texto devem terminar com exatamente uma quebra de linha (`\n`).

### 2. Segurança e Detecção de Segredos

- **`detect-private-key`**: **NUNCA** inclua delimitadores literais de chave privada (como `-----BEGIN ... PRIVATE KEY-----`), nem mesmo dentro de blocos de documentação Markdown (`README.md`), comentários ou exemplos. O analisador estático considera o padrão literal como chave exposta e aborta o commit. Em documentações, utilize descrições textuais ou formatos mascarados (ex.: `BEGIN <TIPO> KEY`).
- **`gitleaks`**: Não faça commit de tokens, credenciais reais, senhas em texto puro ou chaves de API.

### 3. Shell Scripts (`shellcheck` e `shfmt`)

- **`shellcheck`**:
  - Remova quaisquer variáveis não utilizadas ou não exportadas (aviso `SC2034`).
  - Declare e use variáveis de forma segura (`set -euo pipefail`).
  - Sempre valide a sintaxe com `shellcheck --severity=warning <arquivo.sh>`.
- **`shfmt`**: Formate shell scripts com indentação de 4 espaços (`-i 4 -ci`).

### 4. Arquivos Markdown (`markdownlint`)

- Siga a formatação padrão do Markdown:
  - Não adicione dois-pontos (`:`) ao final de cabeçalhos (ex.: use `### Opções disponíveis` em vez de `### Opções disponíveis:`).
  - Deixe exatamente uma linha em branco antes e depois de cabeçalhos, blocos de código e listas.
  - Não deixe múltiplos blocos de linhas em branco consecutivas.

### 5. Padrão de Commits (`conventional-pre-commit`)

- Mensagens de commit devem respeitar a especificação Conventional Commits com os tipos permitidos:
  - `feat`: Nova funcionalidade
  - `fix`: Correção de bug
  - `docs`: Alterações apenas em documentação
  - `style`: Formatação, espaços em branco, etc.
  - `refactor`: Refatoração de código sem alterar regra de negócio
  - `perf`: Melhorias de desempenho
  - `test`: Adição ou correção de testes
  - `build`: Alterações no sistema de build ou dependências
  - `ci`: Alterações em configurações de integração contínua
  - `chore`: Tarefas de manutenção ou ferramentas auxiliares

---

## 🧪 Procedimento de Verificação Pré-Finalização

Sempre que gerar ou editar arquivos, execute a verificação dos hooks antes de encerrar o turno:

```bash
pre-commit run --files <arquivos_alterados>
```

Se algum hook reportar falha ou modificar arquivos (como `trailing-whitespace` ou `markdownlint`), revise as alterações, corrija os avisos e execute novamente até que todos os hooks retornem `Passed`.
