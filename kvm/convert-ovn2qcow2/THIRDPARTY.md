# THIRDPARTY.md - BatOps OVF Converter

Este documento lista todas as dependências, bibliotecas e ferramentas de terceiros utilizadas neste projeto, conforme as diretrizes de governança BatOps.

| Solução | Licença | Versão (Mínima) | Link | Descrição |
| :--- | :--- | :--- | :--- | :--- |
| **virt-v2v** | GNU GPL v2+ | 2.0+ | [libguestfs.org](https://libguestfs.org/virt-v2v.1.html) | Ferramenta principal para conversão e injeção de drivers em VMs. |
| **rhsrvany** | GNU GPL v2+ | 1.1+ | [github.com/rwmjones/rhsrvany](https://github.com/rwmjones/rhsrvany) | Auxiliares para execução de scripts de primeiro boot no Windows. |
| **ntfs-3g** | GNU GPL v2+ | N/A | [tuxera.com](https://github.com/tuxera/ntfs-3g) | Suporte a leitura/escrita de arquivos NTFS (essencial para VMs Windows). |
| **qemu-utils** | GNU GPL v2 | N/A | [qemu.org](https://www.qemu.org/) | Utilitários para manipulação de imagens de disco (qemu-img). |
| **libxml2 (xmllint)** | MIT | N/A | [gnome.org/libxml2](https://gitlab.gnome.org/GNOME/libxml2) | Parser de XML utilizado para ler manifestos OVF. |
| **nbdkit** | GNU GPL v2+ | 1.30+ | [libguestfs.org](https://github.com/libguestfs/nbdkit) | Toolkit para exportação de dados de disco via Network Block Device. |
| **VirtIO Drivers** | Apache 2.0 / MIT | Latest | [github.com/virtio-win](https://github.com/virtio-win/virtio-win-pkg-scripts) | Drivers de alta performance para I/O no KVM. |

## Notas de Licenciamento
Todas as ferramentas listadas são de código aberto (FOSS). O uso comercial é permitido conforme as licenças GPL/MIT correspondentes, desde que respeitadas as cláusulas de atribuição e distribuição.
