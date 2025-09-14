# Script: create-proxmox-vm.sh

## Descrição

Este script automatiza a criação de uma máquina virtual (VM) no Proxmox utilizando uma imagem cloud do Ubuntu 24.04 (Noble). Ele permite personalizar diversos parâmetros da VM via prompts interativos, facilitando a configuração conforme o ambiente desejado.

## O que o script faz

- Solicita ao usuário os principais parâmetros da VM (nome, IP, gateway, DNS, storage, bridge, memória, CPU, disco, usuário, senha, etc.).
- Baixa a imagem cloud do Ubuntu se necessário.
- Cria a VM no Proxmox com as configurações informadas.
- Configura disco, rede, cloud-init, usuário e senha.
- Gera um arquivo customizado para habilitar autenticação SSH por senha.
- Habilita o QEMU Guest Agent.
- Pergunta se deseja iniciar a VM após a criação.
- Opcionalmente remove a imagem cloud baixada.

## Pré-requisitos

- Proxmox instalado e configurado.
- Permissão de root para executar o script.
- Ferramentas necessárias instaladas no host Proxmox:
  - `qm` (Proxmox CLI)
  - `wget`
  - `awk`, `grep`, `cat`, `openssl`
- A pasta `/var/lib/vz/snippets/` deve existir e estar acessível.

## Como usar

1. Faça login no host Proxmox como root.
2. Copie o script para o servidor.
3. Torne o script executável:
   ```bash
   chmod +x create-proxmox-vm.sh
   ```
4. Execute o script informando o nome da VM e o IP estático desejado:
   ```bash
   ./create-proxmox-vm.sh <nome_vm> <ip_static>
   ```
   Exemplo:
   ```bash
   ./create-proxmox-vm.sh minha-vm 192.168.1.100
   ```

5. Responda aos prompts para personalizar os parâmetros da VM ou pressione Enter para aceitar os valores padrão.

6. Ao final, escolha se deseja iniciar a VM imediatamente e se deseja remover a imagem cloud baixada.

## Observações

- O script valida se o nome da VM já existe e se o IP informado é válido.
- O usuário e senha definidos serão utilizados para acesso SSH à VM.
- O script gera um arquivo cloud-init customizado para garantir que o SSH por senha esteja habilitado.
- Os valores padrão podem ser alterados facilmente no início do script.
