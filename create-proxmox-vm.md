
# Script: create-proxmox-vm.sh

## Descrição

Script interativo para criar uma VM no Proxmox usando imagem cloud do Ubuntu 24.04 (Noble), com suporte completo a customização de rede, disco, usuário, senha, chave SSH, cloud-init e pós-instalação.

## Funcionalidades

- Solicita parâmetros essenciais da VM (nome, IP estático, gateway, DNS, netmask, storage, bridge, memória, cores, disco, usuário, senha, URL da imagem).
- Permite customizar todos os parâmetros via prompts, com valores padrão sugeridos.
- Valida se o script está sendo executado como root.
- Valida se o nome da VM já existe e se o IP informado é válido.
- Baixa a imagem cloud do Ubuntu se não existir em `/tmp`.
- Cria a VM base no Proxmox com as configurações informadas.
- Importa e configura o disco cloud-init, redimensiona o disco conforme solicitado.
- Configura rede, DNS, usuário, senha e SSH via cloud-init customizado.
- Suporte a autenticação SSH por senha e/ou chave pública:
   - Permite escolher entre autenticação apenas por senha ou adicionar chave SSH.
   - Gera arquivo cloud-init customizado para cada cenário.
- Habilita QEMU Guest Agent e configura display VGA padrão.
- Regenera configuração cloud-init após customização.
- Pergunta se deseja iniciar a VM após a criação e aguarda inicialização.
- Exibe resumo das configurações e instruções de acesso SSH.
- Opcionalmente remove a imagem cloud baixada após uso.

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
6. Escolha se deseja configurar autenticação SSH por senha ou adicionar chave pública.
7. Ao final, escolha se deseja iniciar a VM imediatamente e se deseja remover a imagem cloud baixada.

## Detalhes e opções

- O script valida o IP informado e verifica se o nome da VM já existe.
- Permite customizar todos os parâmetros relevantes para a VM.
- Suporte a configuração de usuário e senha, além de chave SSH opcional.
- Gera arquivo cloud-init customizado em `/var/lib/vz/snippets/<nome_vm>-user.yaml`.
- Habilita QEMU Guest Agent para integração avançada com Proxmox.
- Configura display VGA padrão (std).
- Exibe instruções de acesso SSH ao final:
   - Com senha: `ssh <usuario>@<ip>`
   - Com chave: `ssh -i <chave_privada> <usuario>@<ip>`
   - Usuário padrão `ubuntu` também é criado com mesma senha.
- Recomenda aguardar alguns minutos para o cloud-init finalizar antes de acessar a VM.

## Observações

- Os valores padrão podem ser alterados facilmente no início do script.
- O script é seguro, aborta em caso de erro ou conflito.
- O arquivo cloud-init gerado pode ser customizado conforme necessidade.
- Ideal para automação de ambientes de desenvolvimento, testes ou produção no Proxmox.

---
Última atualização: setembro/2025
