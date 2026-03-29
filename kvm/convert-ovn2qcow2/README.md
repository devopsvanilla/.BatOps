# 🛠️ BConversor de imagens do VMware (ovf) para KVM (qcow2)

Este conjunto de ferramentas foi desenvolvido para automatizar e validar a migração de máquinas virtuais de ambientes **VMware (ESXi/vSphere)** para **KVM/Proxmox**, com suporte específico para execução em **Ubuntu** (Nativo ou WSL2).

O diferencial desta ferramenta é a injeção automática de drivers **VirtIO** e a reconstrução de metadados, garantindo que o Windows ou Linux de origem inicie corretamente no ambiente KVM.

---

## 📋 1. Requisitos de Execução

### Sistema Operacional Recomendado
* **Ubuntu 22.04 LTS ou 24.04 LTS** (Nativo ou em instância isolada).
* **WSL2 (Windows Subsystem for Linux)**: Requer que a Virtualização Aninhada (Nested Virtualization) esteja ativa na BIOS/UEFI e no Windows.

### Dependências Técnicas
O script `setup-tools.sh` instalará automaticamente:
* `virt-v2v`: Motor de conversão e injeção de drivers.
* `libguestfs-tools`: Manipulação de sistemas de arquivos internos da VM.
* `qemu-utils`: Conversão de formatos de disco rígido virtual.
* `libxml2-utils`: Extração de metadados de arquivos XML/OVF.

---

## 📂 2. Estrutura de Diretórios

O projeto utiliza a seguinte organização de pastas:

```text
.
├── setup-tools.sh          # [SCRIPT] Instalador de infraestrutura e dependências
├── validate-ovf.sh         # [SCRIPT] Diagnóstico detalhado de integridade (Detetive)
├── convert-ovf-qcow2.sh    # [SCRIPT] Processador de conversão e injeção VirtIO
├── README.md               # [DOC] Este guia de utilização
├── ovf-images/             # [ENTRADA] Coloque aqui suas pastas de OVF/VMDK originais
├── output/                 # [SAÍDA] Onde os arquivos .qcow2 finais serão gerados
├── work/                   # [TEMP] Espaço temporário para processamento de discos
└── conversion.log          # [LOG] Registro histórico de todas as conversões
```

---

## 💿 3. Requisitos das Imagens de Origem

Para evitar o erro de "No root device found", certifique-se de que:
1.  **VM Desligada**: A origem deve ter sido exportada com a VM em estado **Power Off**.
2.  **Arquivos Completos**:
    * **Formato StreamOptimized**: Um único arquivo `.vmdk` grande (GBs).
    * **Formato Monolithic Flat**: Um arquivo `.vmdk` pequeno (Descriptor) e um arquivo **`-flat.vmdk`** grande (Dados).
3.  **Localização**: Cada VM deve estar em sua própria subpasta dentro de `./ovf-images/`.

---

## 🚀 4. Guia de Execução (Sequência Obrigatória)

### Passo 1: Preparação do Sistema
Instale as ferramentas necessárias e configure as permissões de hardware.
```bash
sudo chmod +x *.sh
sudo ./setup-tools.sh
# Importante: Aplique os grupos de hardware sem reiniciar
newgrp kvm && newgrp libvirt
```

### Passo 2: Validação (O "Detetive")
Execute o validador para garantir que os arquivos não estão corrompidos ou incompletos.
```bash
./validate-ovf.sh
```

### Passo 3: Conversão Real
Se a validação retornar **OK**, inicie a conversão.
```bash
./convert-ovf-qcow2.sh
```

---

## 📊 5. Interpretando o Relatório de Validação

| Status | Significado | Ação Necessária |
| :--- | :--- | :--- |
| **OK (READY)** | Arquivo completo e pronto. | Seguir para a conversão. |
| **DUMMY_HEADER** | O VMDK tem apenas KBs; faltam os dados. | Exportar novamente do vSphere. |
| **MISSING -FLAT** | Identificado arquivo Descriptor, mas o binário de dados sumiu. | Localizar o arquivo `-flat.vmdk` na origem. |
| **CORRUPT_FILE** | O cabeçalho do disco está ilegível. | Verificar integridade do download/cópia. |

---

## 🛡️ 6. Segurança e Isolamento

> [!IMPORTANT]
> **ESTE SCRIPT NÃO DEVE SER EXECUTADO NO HOST DO KVM/PROXMOX.**
> Por razões de segurança e estabilidade, a execução deve ocorrer em uma máquina **Ubuntu** isolada ou ambiente **WSL2**. 
> O `virt-v2v` monta sistemas de arquivos temporários e instala drivers que podem conflitar com kernels de hipervisores em produção. Converta em ambiente de *staging* e mova apenas o `.qcow2` final para o host de produção.

---

## ⚠️ 7. Problemas Comuns

* **"No root device found"**: Quase sempre significa que o arquivo `.vmdk` não contém os dados reais do Windows (falta o `-flat` ou exportação corrompida).
* **Permission Denied em /dev/kvm**: Seu usuário não tem permissão de hardware. Certifique-se de ter rodado `setup-tools.sh` e o comando `newgrp`.
* **Erro de Socket Libvirt**: Os scripts usam o `LIBGUESTFS_BACKEND=direct` para evitar a necessidade de um serviço Libvirt rodando, mas isso requer suporte a KVM no kernel.

---

## ⚖️ 8. Nota de Isenção (Disclaimer)

**AVISO:** Estes scripts são fornecidos "como estão", sem garantias de qualquer tipo, expressas ou implícitas. A conversão de sistemas operacionais é um processo crítico que envolve riscos de perda de dados ou corrupção de boot. É de inteira responsabilidade do usuário garantir a existência de **backups verificados** antes de qualquer operação. O autor não se responsabiliza por danos resultantes do uso desta ferramenta.

---
**BatOps** - *Automation & Infrastructure Engineering*
