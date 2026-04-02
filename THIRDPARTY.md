# Soluções de Terceiros — BatOps

Lista de todas as dependências, bibliotecas, ferramentas e soluções de terceiros utilizadas no projeto.

---

## Ferramentas de Infraestrutura

| Solução | Licença | Uso no Projeto | Link |
|---|---|---|---|
| Docker | Apache 2.0 | Containerização de aplicações e stacks | [docker.com](https://www.docker.com/) |
| Docker Compose | Apache 2.0 | Orquestração de stacks multi-container | [docs.docker.com/compose](https://docs.docker.com/compose/) |
| Kubernetes | Apache 2.0 | Orquestração de containers em cluster | [kubernetes.io](https://kubernetes.io/) |
| kubeadm | Apache 2.0 | Instalação e configuração de clusters K8s | [kubernetes.io/docs/setup](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) |
| Flannel | Apache 2.0 | Plugin de rede CNI para Kubernetes | [github.com/flannel-io/flannel](https://github.com/flannel-io/flannel) |
| Proxmox VE | AGPL v3 | Plataforma de virtualização para criação de VMs | [proxmox.com](https://www.proxmox.com/) |
| QEMU/KVM | GPL v2 | Hypervisor para virtualização | [qemu.org](https://www.qemu.org/) |
| qemu-utils | GPL v2 | Utilitários de disco (qemu-img) para KVM/Proxmox | [qemu.org](https://www.qemu.org/) |
| virt-v2v | GPL v2+ | Conversão e injeção de drivers em VMs (Libguestfs) | [libguestfs.org](https://libguestfs.org/virt-v2v.1.html) |
| ntfs-3g | GPL v2+ | Suporte NTFS para injeção de drivers em Windows | [tuxera.com](https://github.com/tuxera/ntfs-3g) |

## Stacks Docker Compose

| Solução | Licença | Uso no Projeto | Link |
|---|---|---|---|
| Portainer CE | Zlib | Gerenciamento visual de containers Docker | [portainer.io](https://www.portainer.io/) |
| N8N | Sustainable Use | Plataforma de automação de workflows | [n8n.io](https://n8n.io/) |
| Metabase | AGPL v3 | Business intelligence e dashboards | [metabase.com](https://www.metabase.com/) |
| PostgreSQL | PostgreSQL License | Banco de dados relacional (stack Metabase) | [postgresql.org](https://www.postgresql.org/) |
| MySQL | GPL v2 | Banco de dados relacional | [mysql.com](https://www.mysql.com/) |
| phpMyAdmin | GPL v2 | Administração web do MySQL | [phpmyadmin.net](https://www.phpmyadmin.net/) |
| SQL Server | Comercial (Microsoft) | Banco de dados relacional | [microsoft.com/sql-server](https://www.microsoft.com/sql-server) |
| SQLPad | MIT | Interface web para consultas SQL | [github.com/sqlpad/sqlpad](https://github.com/sqlpad/sqlpad) |
| OpenLDAP | OpenLDAP Public License | Servidor de diretório LDAP | [openldap.org](https://www.openldap.org/) |
| phpLDAPadmin | GPL v2 | Administração web do OpenLDAP | [github.com/leenooks/phpLDAPadmin](https://github.com/leenooks/phpLDAPadmin) |
| OWASP ZAP | Apache 2.0 | Scanner de segurança de aplicações web | [zaproxy.org](https://www.zaproxy.org/) |

## Ferramentas de Desenvolvimento e Diagnóstico

| Solução | Licença | Uso no Projeto | Link |
|---|---|---|---|
| ShellCheck | GPL v3 | Análise estática de scripts Bash | [shellcheck.net](https://www.shellcheck.net/) |
| Nmap | Nmap Public Source License | Scan de portas e vulnerabilidades | [nmap.org](https://nmap.org/) |
| OpenSSL | Apache 2.0 | Verificação de certificados SSL | [openssl.org](https://www.openssl.org/) |
| Starship | ISC | Prompt personalizado para terminal | [starship.rs](https://starship.rs/) |
| code-server | MIT | VS Code no navegador | [github.com/coder/code-server](https://github.com/coder/code-server) |
| VMware OVF Tool | Comercial (VMware) | Conversão de imagens OVF/VMDK | [vmware.com](https://www.vmware.com/) |
| asciinema | GPL v3 | Gravação e compartilhamento de sessões de terminal | [asciinema.org](https://asciinema.org/) |
| rpcbind | BSD | Mapeador de portas RPC para serviços NFS | [linux-nfs.org](http://linux-nfs.org/) |
| nfs-kernel-server | GPL v2 | Servidor NFS nativo do Kernel Linux | [linux-nfs.org](http://linux-nfs.org/) |

## CI/CD e Automação

| Solução | Licença | Uso no Projeto | Link |
|---|---|---|---|
| GitHub Actions | Comercial (GitHub) | Pipelines de CI/CD | [github.com/features/actions](https://github.com/features/actions) |
| Gitleaks | MIT | Detecção de segredos no código | [github.com/gitleaks/gitleaks](https://github.com/gitleaks/gitleaks) |
| Hadolint | GPL v3 | Lint de Dockerfiles | [github.com/hadolint/hadolint](https://github.com/hadolint/hadolint) |
| Trivy | Apache 2.0 | SCA e scan de vulnerabilidades | [github.com/aquasecurity/trivy](https://github.com/aquasecurity/trivy) |
| Release Please | Apache 2.0 | Release automatizado via Conventional Commits | [github.com/googleapis/release-please](https://github.com/googleapis/release-please) |
| pre-commit | MIT | Hooks de pré-commit | [pre-commit.com](https://pre-commit.com/) |

## Plataformas e Serviços

| Solução | Licença | Uso no Projeto | Link |
|---|---|---|---|
| Morpheus Data | Comercial | Plataforma de Cloud Management (CMP) | [morpheusdata.com](https://morpheusdata.com/) |
| LM Studio | Comercial | Execução local de modelos LLM | [lmstudio.ai](https://lmstudio.ai/) |
| Home Assistant OS | Apache 2.0 | Sistema operacional para automação residencial | [home-assistant.io](https://www.home-assistant.io/) |
