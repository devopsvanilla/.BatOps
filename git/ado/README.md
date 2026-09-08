# 🔧 Azure DevOps — Setup de Acesso Git — Soluções BatOps

Scripts (Bash + PowerShell) para instalar o Azure CLI e preparar o acesso de
contribuição (commits, PRs, clones) ao **Azure DevOps** a partir do terminal,
do **Visual Studio Code**, do **Antigravity** e do **Visual Studio 2022**, sem
quebrar o acesso já configurado ao **GitHub**.

---

## 📋 Scripts Disponíveis

| Script Bash | Script PowerShell | Descrição |
|---|---|---|
| `install-azcli.sh` | `Install-AZCLI.ps1` | Instala/valida o Azure CLI (`az`) e a extensão `azure-devops` |
| `configure-ado-access.sh` | `Configure-ADOAccess.ps1` | Configura o Git Credential Manager (GCM) com helpers **escopados** para `dev.azure.com` e `*.visualstudio.com`, e os defaults do `az devops` |
| `set-git-profile.sh` | `Set-GitProfile.ps1` | Garante que `user.name` e `user.email` globais do Git estejam configurados |
| `fix-github-ado-conflict.sh` | `Fix-GitHubADOConflict.ps1` | Diagnostica (e corrige com `--fix`/`-Fix`) conflitos entre o helper de credencial do GitHub CLI e helpers genéricos que possam interceptar essas credenciais |

Convenção de nomes: **(ação)-(contexto)**, ex.: `install-azcli.sh` / `Install-AZCLI.ps1`.

---

## 🚀 Como Utilizar

Execute na ordem sugerida abaixo. Os scripts são **idempotentes**: rodar
novamente não causa efeitos colaterais indesejados.

### Linux/WSL (Bash)

```bash
cd git/ado
chmod +x *.sh

./install-azcli.sh                 # 1. Instala/valida az CLI + extensão azure-devops
./set-git-profile.sh               # 2. Garante nome/e-mail do Git
./configure-ado-access.sh          # 3. Configura acesso Git ao Azure DevOps
./fix-github-ado-conflict.sh       # 4. Verifica se o acesso ao GitHub não foi afetado
```

### Windows (PowerShell / pwsh)

```powershell
cd git\ado

./Install-AZCLI.ps1                # 1. Instala/valida az CLI + extensão azure-devops
./Set-GitProfile.ps1               # 2. Garante nome/e-mail do Git
./Configure-ADOAccess.ps1          # 3. Configura acesso Git ao Azure DevOps
./Fix-GitHubADOConflict.ps1        # 4. Verifica se o acesso ao GitHub não foi afetado
```

> ⚠️ **Erro comum:** `... não está assinado digitalmente. Não é possível
> executar este script no sistema atual` (`UnauthorizedAccess`). Isso é a
> Execution Policy do Windows bloqueando scripts não assinados.
>
> Primeiro, diagnostique **qual escopo** está bloqueando (rodar
> `Set-ExecutionPolicy -Scope CurrentUser` sozinho não resolve se houver uma
> política mais restritiva em `MachinePolicy`/`UserPolicy`, definida por GPO
> corporativa — comum em máquinas de empresa):
>
> ```powershell
> Get-ExecutionPolicy -List
> ```
>
> - Se `MachinePolicy` ou `UserPolicy` aparecerem com um valor diferente de
>   `Undefined` (ex.: `Restricted`/`AllSigned`), essa política vem de GPO e
>   **não pode ser sobrescrita** por `Set-ExecutionPolicy -Scope CurrentUser`.
>   Nesse caso, use a Opção B (ou peça ao time de TI para liberar `RemoteSigned`
>   no GPO).
> - Rodar o script a partir de um caminho UNC do WSL
>   (`\\wsl.localhost\...`) também pode ser tratado como origem não confiável
>   mesmo com `RemoteSigned`. Se a Opção A não resolver, use a Opção B ou copie
>   os scripts para uma pasta local do Windows antes de executar.
>
> ```powershell
> # Opção A - permanente para o usuário atual (funciona se não houver GPO)
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
>
> # Opção B - apenas para esta execução, sem alterar a política global
> # (funciona mesmo com GPO restritiva ou caminho UNC do WSL)
> powershell -ExecutionPolicy Bypass -File .\Install-AZCLI.ps1
>
> # Opção C - se o arquivo veio de outro local e ficou marcado como bloqueado
> Unblock-File .\Install-AZCLI.ps1
> ```

---

## 🛠️ Detalhes e Requisitos

### Por que helpers "escopados"?

O Git permite configurar `credential.helper` **por host** (ex.:
`credential.https://dev.azure.com.helper`). Este pacote de scripts **nunca**
define um `credential.helper` global genérico, para não interferir no helper
já usado pelo `gh` (GitHub CLI), que costuma ser escopado para
`github.com`/`gist.github.com`. O `configure-ado-access.sh` /
`Configure-ADOAccess.ps1` escopam explicitamente o **Git Credential Manager
(GCM)** apenas para `dev.azure.com` e `*.visualstudio.com`.

### Mitigação de conflitos com o GitHub

`fix-github-ado-conflict.sh` / `Fix-GitHubADOConflict.ps1` procuram por
`credential.helper` **sem escopo de URL** na configuração global — esse tipo
de entrada é avaliado pelo Git para **qualquer** host, inclusive
`github.com`, e pode substituir/conflitar com o helper do `gh`. Sem a flag
`--fix`/`-Fix`, o script só diagnostica (somente leitura). Com a flag, ele
faz backup do `~/.gitconfig` (ou `.gitconfig` do usuário no Windows) antes de
remover o helper genérico e reafirmar os helpers escopados do GitHub (via
`gh auth setup-git`) e do Azure DevOps.

> ⚠️ Se você usa um `credential.helper` genérico para **outro** serviço (ex.:
> AWS CodeCommit), revise o diagnóstico antes de rodar com `--fix`/`-Fix`,
> pois a correção automática remove *todos* os helpers genéricos.

### Dependências

- `git`
- Azure CLI (`az`) — instalado pelo `install-azcli.sh` / `Install-AZCLI.ps1`
- Extensão `azure-devops` do `az` — instalada automaticamente
- Git Credential Manager (GCM) — já incluso no **Git for Windows**; no Linux,
  use `./configure-ado-access.sh --install-gcm` para instalar automaticamente,
  ou veja: <https://github.com/git-ecosystem/git-credential-manager/releases>
- GitHub CLI (`gh`), opcional, usado apenas para reafirmar o helper do GitHub
  durante a correção de conflitos

### Compatibilidade

Testado em **WSL2 (Ubuntu)** com Azure CLI acessado via interoperabilidade
com o Windows, e em **Windows (PowerShell/pwsh)** com Git for Windows e GCM
nativos. `install-azcli.sh` detecta esse cenário de interoperabilidade e
avisa; use `--force-native` para instalar uma cópia nativa do `az` no Linux.

Como **Visual Studio Code**, **Antigravity** (editor baseado em VS Code) e
**Visual Studio 2022** compartilham a mesma configuração global do Git
(`~/.gitconfig` no Linux/WSL ou `%USERPROFILE%\.gitconfig` no Windows), o
acesso configurado por estes scripts vale automaticamente para os três, sem
nenhum passo adicional dentro de cada IDE.

---

## 📚 Referências

- [Azure DevOps CLI](https://learn.microsoft.com/azure/devops/cli/)
- [Git Credential Manager](https://github.com/git-ecosystem/git-credential-manager)
- [Autenticação Git com Azure Repos](https://learn.microsoft.com/azure/devops/repos/git/set-up-credential-managers)
- [GitHub CLI](https://cli.github.com/)
