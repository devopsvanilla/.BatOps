# 🦇 BatOps 🚀

[![CI — Lint, Segurança e SCA](https://github.com/devopsvanilla/.batops/actions/workflows/ci.yml/badge.svg)](https://github.com/devopsvanilla/.batops/actions/workflows/ci.yml)
[![Release](https://github.com/devopsvanilla/.batops/actions/workflows/release.yml/badge.svg)](https://github.com/devopsvanilla/.batops/actions/workflows/release.yml)
[![License](https://img.shields.io/github/license/devopsvanilla/.batops)](LICENSE)

**O Cinturão de Utilidades do Guardião DevOps**


> Enquanto um cinturão de ferramentas DevOps representa um conjunto técnico de soluções, o cinturão de utilidades simboliza a postura estratégica e multifuncional do verdadeiro guardião da cultura DevOps — alguém que não apenas executa, mas protege, promove e adapta práticas que sustentam a colaboração, a automação e a entrega contínua.

**BatOps** é um repositório de scripts, automações e guias para ambientes DevOps e SRE. Reúne soluções para gerenciamento de infraestrutura, containers, virtualização, diagnóstico e configuração de sistemas.

---

## 📋 Índice de Soluções

### 🐳 Docker

| Solução | Descrição |
|---|---|
| [docker-context.sh](docker/docker-context.sh) | Gerenciamento de contextos Docker |
| [docker-ps-all.sh](docker/docker-ps-all.sh) | Listagem detalhada de containers |
| [docker-reset.sh](docker/docker-reset.sh) | Reset completo do ambiente Docker ([docs](docker/docker-reset.md)) |
| [install-docker-remote.sh](docker/install-docker-remote.sh) | Instalação do Docker para acesso remoto ([docs](docker/docker-remote.md)) |
| [setup-docker-remote.sh](docker/setup-docker-remote.sh) | Configuração de acesso remoto ao Docker |

#### Docker Compose — Stacks

| Solução | Descrição |
|---|---|
| [metabase+pgsql](docker/metabase+pgsql/) | Metabase com PostgreSQL |
| [mssql+sqlpad](docker/mssql+sqlpad/) | SQL Server com SQLPad |
| [mysql+pma](docker/mysql+pma/) | MySQL com phpMyAdmin |
| [n8n](docker/n8n/) | Plataforma de automação N8N |
| [openldap+phpLDAPadmin](docker/openldap+phpLDAPadmin/) | OpenLDAP com phpLDAPadmin |
| [portainer](docker/portainer/) | Portainer — gerenciamento de containers |
| [zap](docker/zap/) | OWASP ZAP — análise de segurança |

---

### ☸️ Kubernetes

| Solução | Descrição |
|---|---|
| [kubeadm](k8s/kubeadm/) | Instalação e configuração de cluster com kubeadm |
| [nginx-nodeport-deployment](k8s/nginx-nodeport-deployment/) | Deploy de Nginx com NodePort no K8s ([docs](k8s/nginx-nodeport-deployment/README.md)) |

#### Guias Kubernetes

| Guia | Descrição |
|---|---|
| [GetClusterAdmin.md](guides/k8s/GetClusterAdmin.md) | Obter acesso de admin ao cluster |
| [checkNetworkConnectivity.md](guides/k8s/checkNetworkConnectivity.md) | Verificação de conectividade de rede |
| [kubeAPITroughControlplane.md](guides/k8s/kubeAPITroughControlplane.md) | Acesso à API via control plane |

---

### 🖥️ Virtualização

| Solução | Descrição |
|---|---|
| [create-proxmox-vm.sh](proxmox/create-proxmox-vm.sh) | Criação de VMs no Proxmox ([docs](proxmox/README.md)) |
| [create-haos-vm.sh](proxmox/create-haos-vm.sh) | Criação de VM para Home Assistant OS |
| [convert-ovn2qcow2](kvm/convert-ovn2qcow2/) | Conversão de imagens OVN para QCOW2 |

---

### 🔍 Diagnóstico e Monitoramento

| Solução | Descrição |
|---|---|
| [list-ports-and-firewall.sh](network-diagnostics/list-ports-and-firewall.sh) | Listagem de portas e regras de firewall ([docs](network-diagnostics/README.md)) |
| [list-ports-simple.sh](network-diagnostics/list-ports-simple.sh) | Listagem simplificada de portas |
| [audit-site-simple.sh](network-diagnostics/audit-site-simple.sh) | Auditoria simples de sites |
| [get-linux-version.sh](linux-utils/get-linux-version.sh) | Identificação da versão do Linux |
| [get-proxmox-cloudinit-diagnostics.sh](proxmox/get-proxmox-cloudinit-diagnostics.sh) | Diagnóstico de Cloud-Init no Proxmox |
| [get-ssh-diagnostics.sh](network-diagnostics/get-ssh-diagnostics.sh) | Diagnóstico de configuração SSH |

---

### 🏗️ Morpheus

| Solução | Descrição |
|---|---|
| [phpmysql](docker/phpmysql/) | Instalação do phpMyAdmin para Morpheus ([docs](docker/phpmysql/README.md)) |
| [set-morpheus-logback.sh](morpheus/set-morpheus-logback.sh) | Configuração de logback do Morpheus |
| [setup-morpheus-nfs.sh](morpheus/setup-morpheus-nfs.sh) | Configuração de NFS para Morpheus ([docs](morpheus/SETUP-NFS.md)) |
| [delete-morpheus-logs.sh](morpheus/delete-morpheus-logs.sh) | Limpeza de logs do Morpheus |
| [list-morpheus-aws-permissions.sh](morpheus/list-morpheus-aws-permissions.sh) | Listagem de permissões AWS do Morpheus |

---

### 🐧 Ubuntu / Linux

| Solução | Descrição |
|---|---|
| [find-dir-term.sh](ubuntu/find-dir-term.sh) | Busca de diretórios por termo |
| [install-startship.sh](ubuntu/install-startship.sh) | Instalação do Starship prompt |
| [setup-logitech-mxkeys.sh](ubuntu/setup-logitech-mxkeys.sh) | Configuração do teclado Logitech MX Keys |
| [setup-smb.sh](ubuntu/setup-smb.sh) | Configuração de compartilhamento SMB ([docs](ubuntu/setup-smb.md)) |

---

### 🛠️ Ferramentas de Desenvolvimento

| Solução | Descrição |
|---|---|
| [code-server/update-code.sh](code-server/update-code.sh) | Atualização do code-server |
| [vscode/reset-copilot.sh](vscode/reset-copilot.sh) | Reset do GitHub Copilot no VSCode |
| [git/cd-git-root.sh](git/cd-git-root.sh) | Navegação para a raiz do repositório Git |
| [git-resetall.sh](git/git-resetall.sh) | Reset completo de repositório Git |
| [gravar-terminal.sh](linux-utils/gravar-terminal.sh) | Gravação de sessão de terminal |

---

### 🤖 IA e LLMs

| Solução | Descrição |
|---|---|
| [LM-Audit-Dashboard-GUI.ps1](lmstudio/appsec/LM-Audit-Dashboard-GUI.ps1) | Dashboard de auditoria AppSec com LM Studio |

---

### 🧪 Testes e Validações

| Solução | Descrição |
|---|---|
| [check-email-dns.sh](tests/check-email-dns.sh) | Verificação de DNS de e-mail |
| [spamhaus-check.sh](tests/spamhaus-check.sh) | Verificação de blacklist Spamhaus |
| [test-internet-speed.sh](tests/test-internet-speed.sh) | Teste de velocidade de internet ([docs](tests/test-internet-speed.md)) |
| [publish-helloworld.sh](tests/publish-helloworld.sh) | Publicação de Hello World para testes |

---

### 🪟 Windows / PowerShell

| Solução | Descrição |
|---|---|
| [Compact-WSL.ps1](windows/Compact-WSL.ps1) | Compactação de disco WSL |
| [Reset-GitHubCopilotVSCode.ps1](windows/Reset-GitHubCopilotVSCode.ps1) | Reset do GitHub Copilot no VSCode (PowerShell) |

---

## 🚀 Como Utilizar

### Pré-requisitos

- Git instalado
- Bash 4.0+ (para scripts Linux)
- PowerShell 5.1+ (para scripts Windows)
- Ferramentas específicas de cada solução (consulte a documentação individual)

### Clonando o Repositório

```bash
git clone https://github.com/devopsvanilla/batops.git
cd batops
```

### Utilizando uma Solução

1. Navegue até a solução desejada no [índice acima](#-índice-de-soluções)
2. Leia a documentação específica da solução (README.md ou arquivo `.md` correspondente)
3. Verifique os pré-requisitos e dependências
4. Execute o script conforme as instruções

```bash
# Exemplo: Executar o diagnóstico de portas e firewall
chmod +x network-diagnostics/list-ports-and-firewall.sh
./network-diagnostics/list-ports-and-firewall.sh
```

> **Nota:** Alguns scripts podem requerer permissões elevadas (`sudo`). Consulte a documentação de cada solução.

---

## 📖 Documentação

| Documento | Descrição |
|---|---|
| [CONTRIBUTING.md](CONTRIBUTING.md) | Como contribuir para o projeto |
| [THIRDPARTY.md](THIRDPARTY.md) | Soluções de terceiros utilizadas |
| [LICENSE](LICENSE) | Licença MIT |

---

## 📄 Licença

Este projeto está licenciado sob a [Licença MIT](LICENSE).

---

## 🤝 Contribuindo

Contribuições são bem-vindas! Consulte o [CONTRIBUTING.md](CONTRIBUTING.md) para detalhes sobre o processo de contribuição, padrão de commits e fluxo de pull requests.
