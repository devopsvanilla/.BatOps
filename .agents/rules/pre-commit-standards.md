# Diretrizes de Qualidade e Pre-Commit (Google Antigravity)

**Objetivo**: Garantir que todo código ou documentação produzido passe com sucesso nas validações de pré-commit do repositório (`.pre-commit-config.yaml`).

## Regras Obrigatórias

### 1. Shell Scripts (`shellcheck` & `shfmt`)
- **SC2155 (Declaração e Atribuição Separadas)**: NUNCA combine declarações como `local`, `readonly` ou `export` com atribuição de retorno de comandos `$(...)` na mesma linha.
  ```bash
  # INCORRETO (mascara códigos de retorno no shellcheck):
  readonly timestamp="$(date +"%Y%m%d_%H%M%S")"
  local output="$(some_cmd)"

  # CORRETO:
  local timestamp
  timestamp="$(date +"%Y%m%d_%H%M%S")"
  readonly timestamp

  local output
  output="$(some_cmd)"
  ```
- **SC2034**: Nunca deixe variáveis declaradas que não são utilizadas.
- **Formatação**: O `shfmt` exige indentação de 4 espaços com `-ci` (continuation indent).

### 2. Espaços em Branco e Fim de Arquivo
- **Trailing Whitespace**: Nenhum arquivo deve ter espaços em branco no final das linhas. Preste atenção especial a:
  - Textos dentro de blocos heredoc (`cat <<EOF`) e banners ASCII.
  - Linhas em branco ou listas em arquivos Markdown (`.md`).
- **End of File**: Todo arquivo deve terminar com uma única quebra de linha (`\n`).

### 3. Segredos e Chaves
- **Chaves Privadas**: Nunca use delimitadores literais de chave como `-----BEGIN ... PRIVATE KEY-----` mesmo em documentação (`README.md`). Use formas ofuscadas ou descrições textuais.

### 4. Ciclo de Validação Pré-Commit
Antes de finalizar qualquer tarefa ou antes de realizar/sugerir um commit:
1. Execute `pre-commit run --files <arquivos_alterados>`.
2. Se hooks aplicarem alterações automáticas (`trailing-whitespace`, `shfmt`, `end-of-file-fixer`), adicione-os ao stage (`git add`).
3. Re-execute o `pre-commit` até que todos os hooks retornem `Passed`.
