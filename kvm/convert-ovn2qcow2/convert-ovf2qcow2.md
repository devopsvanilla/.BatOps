# Conversão OVF/OVA para KVM (qcow2)

<a name="objetivo"></a>
## 🎯 Objetivo
Este script foi projetado para localizar imagens de máquinas virtuais exportadas no formato OVF ou OVA (criadas pelo VMware ESXi) e convertê-las para o ambiente virtualizador KVM no formato nativo `qcow2`. Desenvolvido com foco no **Ubuntu**, o script automatiza o download remoto de dependências, mapeia os discos originais para o nome do arquivo da imagem e lê arquivos de manifesto (`.mf`) para garantir e checar assinaturas criptográficas dos componentes do diretório (vmdk e metadados) prevenindo de ler ou converter dados corrompidos. Traz consigo feedbacks visuais ricos, além de modo simulação (dry-run).

---

## 📝 Índice
- [Conversão OVF/OVA para KVM (qcow2)](#conversão-ovfova-para-kvm-qcow2)
  - [🎯 Objetivo](#-objetivo)
  - [📝 Índice](#-índice)
  - [🧰 O que faz o `virt-v2v` e por que foi escolhido?](#-o-que-faz-o-virt-v2v-e-por-que-foi-escolhido)
  - [🛠️ Dependências Utilizadas na Conversão](#️-dependências-utilizadas-na-conversão)
  - [💻 Como Executar](#-como-executar)
  - [✅ Guia de Verificação das Imagens Exportadas](#-guia-de-verificação-das-imagens-exportadas)
    - [Na Origem (Pré-Conversão)](#na-origem-pré-conversão)
    - [No Destino (Pós-Conversão - Dentro do target-dir KVM)](#no-destino-pós-conversão---dentro-do-target-dir-kvm)
  - [🐛 Guia de Resolução de Erros Comuns](#-guia-de-resolução-de-erros-comuns)
  - [⚖️ Distribuição e Isenção de Responsabilidade](#️-distribuição-e-isenção-de-responsabilidade)

<br/>

<a name="virt-v2v"></a>
## 🧰 O que faz o `virt-v2v` e por que foi escolhido?
O **virt-v2v** é a ramificação mais estável da família _libguestfs_. Bem diferente de ferramentas simples ou conversões puras e cegas de "caixa d'água" (`qemu-img convert`), o `virt-v2v` altera as vísceras da Máquina Virtual Hóspede:
- Ele injeta controladores padrão de alto rendimento no kernel do SO da imagem convertida (como o pacote moderno *VirtIO* de storage e network).
- Remove ou desabilita automaticamente as velhas "VMware Tools", varrendo os arquivos.
- Gera um "Hardware Template" (`.xml`) compatível com `libvirt` mapeando os slots antigos corretamente.
Essa manipulação da VFS da máquina evita que sistemas operacionais Windows caiam em Blue-Screens INACCESSIBLE_BOOT_DEVICE ou Kernels de base Linux demorem a dar *mount* no seu sistema de disco emulando uma SCSI tradicional da LSI SAS no VMWARE.

<br/>

<a name="dependencias"></a>
## 🛠️ Dependências Utilizadas na Conversão
O script fará o *check* de ambiente. Estes pacotes serão resolvidos se o script confirmar a requisição e chamará o gerenciador padrão do Ubuntu (`apt-get`) para baixá-los:
- **`virt-v2v`**: Mecanismo principal de conversão VFS da hospedagem VM.
- **`libguestfs-tools`**: Conjunto de bibliotecas utilizadas para montar temporariamente e espiá-los (supermin boot appliances).
- **`qemu-utils`**: Proporciona o sub-pacote `qemu-img`, que confere a consistência do arquivo criado logo após os passos da ferramenta central.

<br/>

<a name="como-executar"></a>
## 💻 Como Executar

No seu terminal Linux no ambiente que possui privilégio (KVM Server Ubuntu):
```bash
# Ofereça a permissão de Execução ao arquivo shell principal:
chmod +x convert-ovf2qcow2.sh
```

**Uso padrão:** Executa a varredura no `./ovf-images` adicionando as imagens convertidas em `./qcow2-images`.
```bash
./convert-ovf2qcow2.sh
```

**Uso com Mapeamento Adaptável:** Se a pasta de seus dumps estiver distantes, as variáveis podem ser chamadas em cadeia para alterar a origem e destino da execução KVM atual do servidor. Veja também que usamos neste cenário a opção simulação seca `--dry-run`:
```bash
./convert-ovf2qcow2.sh --source-dir /opt/KVM/exports --target-dir /var/lib/libvirt/images --dry-run
```

**Parâmetros suportados no Help:**
- `--source-dir DIR`: Indica o local onde as imagens que serão convertidas estão localizadas.
- `--target-dir DIR`: Indica o local onde as imagens convertidas (vmdk e xml embutido) devem ser gravadas.
- `--format FMT`: (padrão `qcow2`).
- `--dry-run`: Impede execução do núcleo da ferramenta, apenas lê a hierarquia para prever conflitos de diretórios e faltas de imagem.
- `--help`: Emite as listagens de parâmetros via prompt.

<br/>

<a name="guia-verificacao"></a>
## ✅ Guia de Verificação das Imagens Exportadas
Logo na finalização do script o terminal demonstrará no prompt o resumo:

### Na Origem (Pré-Conversão)
O Script por via de regra testa os blocos contitucionais se uma variação original da VMware do arquivo de integridade (`.mf`) atende pela leitura SHA-1 ou SHA-256 e se o que ali assina reflete o mesmo binário do seu bloco VMDK de dados.

### No Destino (Pós-Conversão - Dentro do target-dir KVM)
Verifique via arquivo e utilitário se o script não logou erros amarelos no comando de imagem do KVM. Você deve possuir:
- Um arquivo para as VMs convertidas com XML final e suas definições (`NomeDaVmBase.xml`)
- E atestadas suas bases de expansão virtual no formato raw/qcow nomeada geralmente para algo como `NomeDaVm-sda`. Se for adicionar aos WebGui como Cockpit OpenStack e Proxmox, desabilite no Hardware criado o seu principal Boot order originário em branco e atache explicitamente com um drive interface de Bus "SCSI VirtIO".

<br/>

<a name="resolucao-erros"></a>
## 🐛 Guia de Resolução de Erros Comuns
- **`libguestfs: error: cannot find any suitable libguestfs supermin`**, local ou restrito falhando.
  *Correção:* Garanta que o kernel Ubuntu local permita a chamada isolada por permissão do pacote supermin. Geralmente resolvida com variáveis de ambiente nativas injetadas internamente como o comando pre-instalado já incluso no source executado `export LIBGUESTFS_BACKEND=direct`.
- **Nenhum arquivo lido da pasta e terminando com [Avisos]**
  *Correção:* Tenha certeza que as chamadas das imagens carreguem sufixo extensional do formato VMware (são elas: `.ova` ou as tradicionais desempacotadas `.ovf`). O pacote não processa os metadados apenas lendo a base binária (`.vmdk` sem a raiz OVF apontadas).
- **Sem permissões para instalação e execução do APT Package Manager**
  *Correção:* Confirme que a conta do sistema rodando a sessão SSH possua sudoer root sem quebras do Sudo timeout e/ou forneça confirmação da credencial na tela no prompt da simulação de confirmação do Y/n.
- **Falha de Integridade nos arquivos no painel inicial do loop**
  *Correção:* Você obteve interrupção ou queda temporária dos sFTP ao puxar o vMDk massivo, consequentemente a falha não reflete do seu Hash MF. Volte ao repositório Storage Datastore do ESXi da VMware original e baixe-a (Export) limpa mais uma vez para a plataforma do Ubuntu KVM.

<br/>

<a name="isencao"></a>
## ⚖️ Distribuição e Isenção de Responsabilidade
> [!WARNING]
> Esse projeto e ferramentas de script Bash atrelados são fornecidos *"As is"*. Este modelo ou documentativo isenta garantias plenas, expressas ou não intencionais não garantindo suporte por vias de indisponibilidades técnicas. Erros críticos na camada de leitura/escrita libguest podem inutilizar partições da máquina convertida em raros OS descontinuados ou criptografados na fonte de Hardware (vTPM/Luks). Realize todos os testes de validação no Hypervisor local-remoto com os Backups Originais do VMware garantidos imutáveis em Datastores protegidos e não dependentes. Toda execução ocorre como risco deliberado do administrador e autor que gerou a invocação.
