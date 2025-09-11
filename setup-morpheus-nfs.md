# setup-morpheus-nfs.sh

## 📝 Descrição

Script Bash para instalação e configuração automática do servidor NFS para armazenamento local do **Morpheus Data Enterprise**. Permite parametrização do diretório exportado e da sub-rede autorizada. Realiza testes automáticos de exportação e montagem para garantir a correta funcionalidade.

***

## ⚙️ Funcionalidades

- Instala dependências: `rpcbind` e `nfs-kernel-server`
- Cria e configura o diretório de exportação NFS
- Atualiza o arquivo `/etc/exports` com permissões adequadas
- Reinicia e habilita os serviços necessários
- Efetua testes pós-instalação:
    - Verifica exportação ativa
    - Testa montagem NFS local
    - Faz teste de escrita no storage
- Exibe mensagens coloridas e emojis durante o progresso

***

## 🚀 Como Utilizar

### Torne o script executável

```bash
chmod +x setup-morpheus-nfs.sh
```


### Execute com os parâmetros desejados

```bash
sudo ./setup-morpheus-nfs.sh
sudo ./setup-morpheus-nfs.sh --directory /meu/diretorio --subnet 10.0.0.0/24
```


### Visualize a ajuda

```bash
./setup-morpheus-nfs.sh --help
```


***

## 🔑 Parâmetros

- `--directory <path>`: Diretório a ser exportado via NFS (padrão `/opt/morpheus/storage/virtual-images`)
- `--subnet <cidr>`: Sub-rede autorizada para acesso NFS (padrão `192.168.0.0/24`)

***

## ✅ Testes Automáticos

Após configurar:

- Verifica que a exportação NFS está ativa
- Realiza montagem NFS local via `localhost`
- Testa escrita e permissões no diretório exportado
- Remove arquivos e diretórios temporários criados pelos testes

***

## 📋 Procedimento Pós-Instalação

1. Realize um teste de montagem NFS em outro servidor (cliente Morpheus):

```bash
sudo mount -t nfs -o vers=3 <IP-DO-SERVIDOR>:/opt/morpheus/storage/virtual-images /tmp/test
```

2. Se funcionar corretamente:
    - Configure o storage como NFS file share dentro do Morpheus Data Enterprise
    - Use o IP do servidor, diretório e versão configurados no script

***

## 💡 Observações

- Este script deve ser executado com permissões de superusuário (sudo)
- Utilize os parâmetros conforme seu ambiente de rede e armazenamento
- Confirme se não existe nenhuma política de segurança ou firewall bloqueando o acesso ao NFS

***

## 🛠 Exemplos Úteis

```bash
# Instalação padrão
sudo ./setup-morpheus-nfs.sh

# Customizando diretório e sub-rede
sudo ./setup-morpheus-nfs.sh --directory /srv/morpheus/images --subnet 10.0.2.0/24
```


***

## 📚 Referências

- Documentação oficial Morpheus Data: [https://docs.morpheusdata.com/en/8.0.6/infrastructure/storage/storage.html](https://docs.morpheusdata.com/en/8.0.6/infrastructure/storage/storage.html)
- Documentação NFS Ubuntu: https://help.ubuntu.com/community/SettingUpNFSHowTo

***

**Criado por DevOps Vanilla, 2025**
<span style="display:none">[^1][^2][^3][^4][^5][^6][^7]</span>

<div style="text-align: center">⁂</div>

[^1]: https://stackoverflow.com/questions/20303826/how-to-highlight-bash-shell-commands-in-markdown

[^2]: https://github.com/ralish/bash-script-template

[^3]: https://design2seo.com/blog/web-development/11ty/markdown-template-with-shell-script/

[^4]: https://dev.to/wancat/mdsh-run-shell-scripts-in-markdown-templates-1o7o

[^5]: https://bashly.dev/advanced/rendering/

[^6]: https://betterdev.blog/minimal-safe-bash-script-template/

[^7]: https://gitlab.com/the-common/bash-script-templates

