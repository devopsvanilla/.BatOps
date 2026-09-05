# 🤖 RTK CLI — Instalação Segura

Solução BatOps para instalação segura e sempre atualizada do [RTK (Rust Token Killer)](https://github.com/rtk-ai/rtk) — um proxy de CLI em Rust que reduz em até 90% a saída de comandos bash lidos por agentes de IA (Claude Code, GitHub Copilot, Cursor, Gemini CLI, etc.), economizando tokens e acelerando respostas.

---

## 🎯 Propósito

O script `install-rtk.sh` automatiza a instalação do RTK seguindo práticas de segurança que o método oficial rápido (`curl | sh`) **não** oferece:

| Prática | `curl \| sh` oficial | Este script |
|---|---|---|
| Execução de código remoto não auditado | ⚠️ Sim | ❌ Não — baixa apenas o binário |
| Verificação de integridade SHA-256 | ❌ Não garantida | ✅ Obrigatória antes de instalar |
| Checksum contra fonte oficial | — | ✅ `checksums.txt` do release |
| TLS forçado (HTTPS/TLS 1.2+) | Parcial | ✅ Sim |
| Detecção automática de versão mais recente | ✅ | ✅ Via API do GitHub |
| Sem necessidade de root/sudo | ✅ | ✅ Instala em `~/.local/bin` |
| Idempotente (pula se já atualizado) | ❌ | ✅ Sim |

---

## 🚀 Como Executar

```bash
chmod +x install-rtk.sh

# Instala a versão mais recente (recomendado)
./install-rtk.sh

# Instala uma versão específica
./install-rtk.sh v0.48.0
```

Após a instalação, integre o RTK ao seu agente de IA:

```bash
rtk init -g              # Claude Code / GitHub Copilot (padrão)
rtk init -g --copilot    # GitHub Copilot no VS Code
rtk init -g --gemini     # Gemini CLI
rtk init -g --codex      # Codex (OpenAI)
```

### 🤖 GitHub Copilot (VS Code)

Integração **global** com hook de reescrita transparente — os comandos bash são automaticamente convertidos para `rtk` antes da execução:

```bash
rtk init -g --copilot
```

Após rodar o comando, **reinicie o VS Code** para o hook entrar em vigor. A partir daí, comandos como `git status` executados pelo agente são reescritos para `rtk git status` de forma transparente.

### 🐜 Google Antigravity

Integração **por projeto** (project-scoped) — o RTK cria regras no repositório instruindo o agente a usar `rtk`:

```bash
cd /caminho/do/seu/projeto
rtk init --agent antigravity
```

Isso gera o arquivo `.agents/rules/antigravity-rtk-rules.md` dentro do projeto. Observações importantes:

- Execute o comando **dentro de cada repositório** onde quiser a otimização (não é global).
- O arquivo de regras **deve ser commitado** no Git para que outros desenvolvedores e sessões futuras do agente herdem a configuração.
- Diferente do Copilot, não há hook transparente: o agente é instruído via regras a chamar `rtk` explicitamente.

Verifique se está tudo certo:

```bash
rtk --version     # deve exibir a versão instalada
rtk gain          # painel de economia de tokens
rtk init --show   # mostra hooks e agentes configurados
```

> ⚠️ **Colisão de nome**: existe outro projeto chamado `rtk` (Rust Type Kit) no crates.io. Se `rtk gain` falhar, você tem o pacote errado — reinstale com este script.

---

## 🛡️ Dicas de Segurança

### Ao instalar/atualizar

- **Sempre use este script** (ou o Homebrew) em vez de `curl | sh` — a verificação de checksum SHA-256 garante que o binário não foi corrompido ou adulterado em trânsito.
- **Audite antes de executar**: o script é legível e comentado. Revise-o com `less install-rtk.sh` antes da primeira execução — bom hábito para qualquer script baixado.
- **Evite instalar como root**: o RTK é um binário de usuário único; `~/.local/bin` é o local correto. Executar instaladores como root amplifica o impacto de qualquer comprometimento da cadeia de suprimentos.
- **Fixe a versão em ambientes críticos**: em CI/CD ou máquinas de produção, passe a versão explicitamente (`./install-rtk.sh v0.48.0`) para garantir reprodutibilidade.

### Ao usar o RTK no dia a dia

- **O hook reescreve comandos bash automaticamente** — revise o que será interceptado em `rtk init --show` e exclua comandos sensíveis no `~/.config/rtk/config.toml`:

  ```toml
  [hooks]
  exclude_commands = ["curl", "playwright", "aws s3 cp"]
  ```

- **Saída completa em caso de falha**: quando um comando filtrado falha, o RTK salva a saída bruta em `~/.local/share/rtk/tee/`. Limpe esses logs periodicamente se trabalhar com dados sensíveis:

  ```bash
  rm -rf ~/.local/share/rtk/tee/*
  ```

- **Telemetria é opt-in**: o RTK pode coletar métricas anônimas de uso, mas **desabilitada por padrão**. Verifique e controle com:

  ```bash
  rtk telemetry status    # verifica o estado atual
  rtk telemetry disable   # revoga consentimento
  export RTK_TELEMETRY_DISABLED=1   # bloqueio total via ambiente
  ```

- **Mantenha o `rg` (ripgrep) instalado**: alguns filtros do RTK dependem dele. Instale com `sudo apt install ripgrep` (Ubuntu/Debian) para evitar avisos.

### Manutenção

- **Atualize regularmente**: rode `./install-rtk.sh` novamente — o script detecta automaticamente se há versão nova e só reinstala quando necessário.
- **Desinstalação limpa**:

  ```bash
  rtk init -g --uninstall   # remove hooks e configurações de agentes
  rm ~/.local/bin/rtk       # remove o binário
  ```

---

## 📚 Referências

- [Repositório oficial — rtk-ai/rtk](https://github.com/rtk-ai/rtk)
- [Guia de instalação (INSTALL.md)](https://github.com/rtk-ai/rtk/blob/develop/INSTALL.md)
- [Documentação completa](https://www.rtk-ai.app/guide)
- [Política de segurança](https://github.com/rtk-ai/rtk/blob/develop/SECURITY.md)
- [Como funcionam as economias de tokens](https://github.com/rtk-ai/rtk/blob/develop/docs/guide/resources/savings-explained.md)
