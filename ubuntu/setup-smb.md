# setup-smb.sh — Compartilhamento SMB no Ubuntu

## Descrição
Script interativo para configurar rapidamente um compartilhamento de arquivos via Samba (SMB) no Ubuntu, permitindo que diretórios do Linux sejam acessados por máquinas Windows na rede.

- Verifica e instala dependências (`samba`, `smbclient`)
- Solicita diretório, nome do compartilhamento e usuário de acesso
- Cria usuário de sistema/Samba se necessário
- Configura permissões e adiciona entrada ao `smb.conf`
- Reinicia o serviço Samba
- Exibe mensagens coloridas, com emojis e instruções claras

---

## Como usar

```bash
sudo bash setup-smb.sh
```

> **Atenção:** O script deve ser executado como root (use `sudo`).

---

## Passos do Script

1. **Verificação de dependências**
   - Instala `samba` e `smbclient` se necessário.
2. **Solicitação de informações**
   - Caminho do diretório a ser compartilhado (cria se não existir)
   - Nome do compartilhamento
   - Nome do usuário de acesso (cria se não existir)
   - Senha do usuário Samba
3. **Configuração**
   - Permissões do diretório ajustadas
   - Backup automático do `/etc/samba/smb.conf`
   - Nova entrada adicionada ao `smb.conf`
4. **Finalização**
   - Reinicia o serviço `smbd`
   - Exibe instruções para acessar o compartilhamento via Windows

---

## Exemplo de uso

```
Digite o caminho ABSOLUTO do diretório a ser compartilhado (ex: /srv/compartilhado): /srv/compartilhado
Digite o NOME do compartilhamento (ex: arquivos): arquivos
Digite o NOME do usuário para acesso ao compartilhamento (ex: smbuser): smbuser
Defina a senha para o usuário Samba (será usada para acessar o compartilhamento na rede):
```

---

## Acesso via Windows

- No Windows Explorer, acesse:
  ```
  \\IP_DO_UBUNTU\NOME_DO_COMPARTILHAMENTO
  ```
- Use o usuário e senha definidos no script.

---

## Dicas e Observações

- Se necessário, libere as portas 445 e 139 no firewall (`ufw`).
- Para desfazer, remova a entrada do compartilhamento no `smb.conf` e reinicie o Samba.
- O script faz backup automático do `smb.conf` antes de alterar.

---

## Requisitos
- Ubuntu (testado em 20.04+)
- Permissão de root

---

## Autor
- devopsvanilla — 2026
