# 🛡️ Auditoria GitHub com Legitify — Soluções BatOps

Solução para auditar a postura de segurança da sua organização e repositórios
GitHub usando o [Legitify](https://github.com/Legit-Labs/legitify) (Legit Security),
gerando relatórios em **PDF** (além de JSON e texto) e permitindo execução
periódica via **cron** ou **GitHub Actions**.

O Legitify automatiza a verificação das recomendações da [OpenSSF SCM Best
Practices Guide](https://best.openssf.org/SCM-BestPractices/) para plataformas de
gerenciamento de código-fonte (SCM), além de más configurações e riscos de segurança em:
organização, GitHub Actions, membros/colaboradores, repositórios e grupos de runners.

---

## 📋 Arquivos da Solução

| Arquivo | Descrição |
|---|---|
| `install-legitify.sh` | Instala/atualiza o binário do Legitify (verifica versão e checksum, sem precisar de root) |
| `audit-github.sh` | Script principal: via prompts (ou variáveis de ambiente), executa a análise e gera relatório em PDF/JSON/TXT |
| `run-scheduled-audit.sh` | Wrapper não-interativo, para uso em `cron`, que carrega `.env` e chama `audit-github.sh --non-interactive` |
| `.env.example` | Modelo de variáveis de ambiente usado como fonte de valores padrão pela auditoria pontual e pela execução agendada via cron. Não é usado pelo GitHub Actions — copie para `.env` |
| `ignore-policies.example.txt` | Modelo de lista de políticas a ignorar na análise |
| `github-actions/legitify-audit.yml` | Template de workflow do GitHub Actions para auditoria periódica |

---

## ✅ Pré-requisitos

- Bash, `curl`, `tar`, `sha256sum` (para instalação do Legitify).
- Um **Personal Access Token (PAT) clássico** do GitHub (não é o "fine-grained
  personal access token" — o Legitify não suporta esse tipo).
  Crie em **GitHub → Settings → Developer settings → Personal access tokens →
  Tokens (classic) → Generate new token (classic)**
  ([guia oficial](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)).

  Na tela de criação, os escopos usados pelo Legitify aparecem **aninhados**
  dentro de grupos (marque apenas os itens abaixo, não é preciso marcar o item
  "pai" inteiro, exceto onde indicado):

  | Escopo a marcar | Onde encontrar na tela do GitHub |
  |---|---|
  | `repo` | Checkbox de topo "repo — Full control of private repositories" (já inclui `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`) |
  | `read:org` | Sub-item dentro do grupo `admin:org` / `write:org` / **`read:org`** |
  | `admin:org_hook` | Checkbox de topo "admin:org_hook — Full control of organization hooks" (não existe uma opção somente-leitura para esse escopo, é necessário marcar o escopo completo) |
  | `read:repo_hook` | Sub-item dentro do grupo `admin:repo_hook` / `write:repo_hook` / **`read:repo_hook`** |
  | `read:enterprise` | Sub-item dentro do grupo `admin:enterprise` / `manage_runners:enterprise` / `manage_billing:enterprise` / **`read:enterprise`** (só é necessário se for analisar um GitHub Enterprise Server via `--enterprise`) |

  > Fine-grained PATs não são suportados pelo Legitify.
  >
  > ⚠️ Ter a **GH CLI** (`gh`) instalada e autenticada **não substitui** o PAT: o
  > token gerado pelo `gh auth login` normalmente não possui os escopos `admin:org`,
  > `read:enterprise`, `admin:org_hook` e `read:repo_hook`, necessários para a análise
  > completa (organização, membros e actions). Com o token da `gh` você só obtém
  > políticas de repositório. O script `audit-github.sh` detecta a GH CLI e sugere o
  > token dela como valor padrão no prompt, mas o ideal é colar um PAT dedicado com
  > os escopos completos.
- Ser owner de ao menos uma organização (ou admin de repositório para análises limitadas a repositório).
- Para gerar o **PDF**: `pandoc` + um motor de renderização (`wkhtmltopdf`, `weasyprint`,
  `xelatex` ou `pdflatex`). Exemplo de instalação no Ubuntu/Debian:
  ```bash
  sudo apt-get update && sudo apt-get install -y pandoc wkhtmltopdf
  ```
  Se essas ferramentas não estiverem disponíveis, o script ainda gera os relatórios
  em texto (`.txt`) e JSON (`.json`), apenas pulando a etapa de PDF.

---

## 🚀 Como Executar uma Auditoria Pontual (via prompts)

```bash
cd security/legitify
chmod +x install-legitify.sh audit-github.sh
./audit-github.sh
```

O script irá:
1. Instalar o Legitify automaticamente, caso não esteja instalado ou esteja desatualizado.
2. Carregar valores padrão do arquivo `.env` (se existir — veja [Configurando o
   arquivo .env](#-configurando-o-arquivo-env)), sem exibi-los na tela.
3. Perguntar interativamente: **token do GitHub**, **organização(ões)** (opcional),
   **repositório(s)** específicos (opcional), se deve **incluir os repositórios
   pessoais do dono do PAT** (fora de organizações), **namespaces** a analisar
   (opcional) e **diretório de saída**. Se um valor já veio do `.env`, o prompt indica
   "[já definido no .env, ENTER para manter]" — basta apertar ENTER para reaproveitá-lo,
   ou digitar um novo valor para substituí-lo.
4. Se você responder "s" à pergunta sobre repositórios pessoais, o script consulta a
   API do GitHub (`GET /user/repos?affiliation=owner`) com o próprio PAT e adiciona
   automaticamente todos os repositórios não-arquivados do usuário dono do token à
   lista de repositórios analisados (paginando até esgotar os resultados).
5. Executar a análise do Legitify. O Legitify não permite combinar `--org` e `--repo`
   na mesma chamada, então o script roda **uma vez por escopo informado**
   (organização e/ou repositórios avulsos/pessoais) e combina o texto de todos os
   escopos em um único relatório — o JSON é mantido em um arquivo por escopo
   (ex.: `..._organizacao.json`, `..._repositorios.json`).
6. Converter o relatório em texto combinado em um **PDF** salvo em `./reports/` por
   padrão, com nome no formato `legitify-report-<organizacao>-<data-hora>.pdf`.

> 💡 Deixar organização e repositório em branco faz o Legitify analisar **todos** os
> recursos visíveis ao token (todas as orgs + repositórios pessoais), sem precisar
> responder "sim" à pergunta de repositórios pessoais — útil para uma varredura ampla,
> porém mais demorada.

> 💡 Se você colar a URL da organização por engano (ex.: `https://github.com/minha-org`),
> o script remove automaticamente o prefixo e usa apenas o slug (`minha-org`).

> ⚠️ Evite usar `export GITHUB_TOKEN=ghp_xxx` diretamente no shell antes de rodar o
> script — esse comando costuma ficar registrado no `~/.bash_history`. Prefira
> configurar o token uma única vez no arquivo `.env` (permissão `chmod 600`), que o
> script carrega automaticamente e nunca é exibido na tela nem versionado no git.

---

## 🧩 Configurando o arquivo `.env`

O arquivo `.env` é usado como fonte de valores padrão tanto pela **auditoria
pontual** (`audit-github.sh` interativo) quanto pela **execução agendada via cron**
(`run-scheduled-audit.sh`). Ele **não** é usado pelo GitHub Actions (que usa Secrets
do GitHub — veja a Opção B abaixo). Ordem de prioridade: variável já exportada
explicitamente no ambiente (ex.: por um CI) > valor do `.env` > sugestão da GH CLI
(somente para o token, com escopos limitados) > pergunta manual no prompt.

1. A partir do diretório `security/legitify`, copie o modelo:
   ```bash
   cp .env.example .env
   chmod 600 .env      # restringe a leitura do arquivo ao seu usuário
   ```
2. Edite o `.env` e preencha as variáveis:

   | Variável | Obrigatória | Preencha com |
   |---|---|---|
   | `GITHUB_TOKEN` | Sim | O PAT clássico criado conforme a seção [Pré-requisitos](#-pré-requisitos) |
   | `GITHUB_ORG` | Não | Organização(ões) GitHub a auditar, separadas por vírgula (ex.: `minha-org` ou `org1,org2`). Deixe em branco para auditar só repositórios pessoais ou tudo que o token enxergar |
   | `GITHUB_REPO` | Não | Repositório(s) específicos no formato `org/repo` ou `usuario/repo` (inclusive pessoais), separados por vírgula, para limitar a análise |
   | `LEGITIFY_INCLUDE_PERSONAL_REPOS` | Não | `1` ou `true` para incluir automaticamente todos os repositórios pessoais (fora de organizações) do usuário dono do PAT — usado principalmente na execução agendada, onde não há prompt |
   | `LEGITIFY_NAMESPACES` | Não | Subconjunto de namespaces a analisar: `organization,actions,member,repository,runner_group` (padrão: todos) |
   | `LEGITIFY_IGNORE_POLICIES_PATH` | Não | Caminho para um arquivo de políticas a ignorar (veja `ignore-policies.example.txt`) |
   | `LEGITIFY_OUTPUT_DIR` | Não | Diretório onde os relatórios `.pdf`/`.json`/`.txt` serão salvos (padrão: `./reports`) |

3. O arquivo `.env` já está coberto pelo `.gitignore` do repositório (`.env` e
   `.env.*`, exceto `.env.example`) — garanta que ele **nunca** seja commitado.

---

## ⏱️ Execução Periódica

### Opção A — Cron local

1. Configure o `.env` conforme a seção [Configurando o arquivo .env](#-configurando-o-arquivo-env) acima.
2. Agende no `crontab -e`, por exemplo para rodar toda segunda-feira às 08:00:
   ```
   0 8 * * 1 /caminho/completo/para/security/legitify/run-scheduled-audit.sh >> /caminho/completo/para/security/legitify/cron.log 2>&1
   ```
3. O wrapper carrega o `.env`, roda a auditoria em modo não-interativo e salva os
   relatórios em `LEGITIFY_OUTPUT_DIR` (padrão `./reports`).

> ⚠️ O arquivo `.env` contém um token sensível — garanta que ele **nunca** seja
> commitado e restrinja as permissões do arquivo (`chmod 600`).

### Opção B — GitHub Actions

No GitHub Actions **não se usa o arquivo `.env`**: o token fica armazenado como
um **Secret** gerenciado pelo próprio GitHub (criptografado em repouso, mascarado
nos logs, nunca exposto em texto plano). Siga os passos abaixo para configurar
isso de forma segura:

1. **Gere o PAT clássico** com os escopos descritos em [Pré-requisitos](#-pré-requisitos)
   e, se possível, defina uma **data de expiração** (ex.: 90 dias) para forçar rotação periódica.
2. **Cadastre o token como Secret**, preferindo o menor escopo de visibilidade possível:
   - *Um único repositório*: **Settings → Secrets and variables → Actions → New
     repository secret**, nome `PAT_FOR_LEGITIFY`.
   - *Vários repositórios da mesma organização* (recomendado quando a auditoria cobre
     toda a org): **Settings da organização → Secrets and variables → Actions → New
     organization secret**, nome `PAT_FOR_LEGITIFY`, e em "Repository access"
     selecione apenas os repositórios que devem executar o workflow (evite "All repositories").
3. Copie o template do workflow para o repositório onde a auditoria deve rodar:
   ```bash
   mkdir -p .github/workflows
   cp security/legitify/github-actions/legitify-audit.yml .github/workflows/legitify-audit.yml
   ```
4. Ajuste a variável `org_slug` no workflow para o nome da sua organização e, se desejar,
   o horário do `cron`. **Nunca** cole o token diretamente no YAML — ele deve ser sempre
   referenciado via `${{ secrets.PAT_FOR_LEGITIFY }}`.
5. (Recomendado) Proteja o workflow contra alterações não revisadas: exija Pull Request
   com review obrigatório para mudanças em `.github/workflows/` (branch protection rules),
   já que qualquer alteração nesse arquivo tem acesso ao secret.
6. (Opcional, para um controle extra) Vincule o job a um **Environment** do GitHub
   (Settings → Environments) com "Required reviewers", exigindo aprovação manual antes
   de cada execução agendada usar o secret.
7. Após configurar, dispare manualmente o workflow uma vez (`workflow_dispatch`) para
   validar antes de depender apenas do `schedule`.

O workflow, então:
   - Executa a [GitHub Action oficial do Legitify](https://github.com/marketplace/actions/legitify-analyze)
     e publica o resultado em formato **SARIF** como artefato (integrável com o
     GitHub Code Scanning).
   - Também executa `audit-github.sh --non-interactive` dentro do runner (recebendo o
     token via variável de ambiente `GITHUB_TOKEN`, vinda do secret — sem `.env`) para
     gerar o relatório em **PDF/JSON/TXT**, publicado como artefato adicional do workflow.
   - Pode ser disparado manualmente (`workflow_dispatch`) ou automaticamente pelo `schedule`.

---

## 🔒 Boas Práticas de Segurança

- Nunca commite tokens/PATs em texto plano — use secrets do GitHub Actions ou um
  arquivo `.env` local fora do controle de versão.
- Prefira PATs com o menor escopo necessário para o que for auditar (ex.: apenas
  `read:org` e `repo` se não for gerenciar hooks).
- Revise periodicamente e revogue PATs não utilizados.
- Os relatórios gerados podem conter informações sensíveis sobre a postura de
  segurança da organização — armazene-os em local de acesso restrito.

---

## 📚 Referências

- [Legitify — repositório oficial](https://github.com/Legit-Labs/legitify)
- [Legitify — documentação de políticas](https://legitify.dev/)
- [Legitify GitHub Action (marketplace)](https://github.com/marketplace/actions/legitify-analyze)
- [Criação de Personal Access Token no GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token)
