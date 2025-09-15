#!/bin/bash
echo "=== DIAGNÓSTICO SSH SENHA ==="
echo "1. Configuração SSH principal:"
sudo grep -n -E "PasswordAuthentication|PubkeyAuthentication|ssh_pwauth" /etc/ssh/sshd_config

echo -e "\n2. Arquivos cloud-init SSH:"
sudo ls -la /etc/ssh/sshd_config.d/
sudo cat /etc/ssh/sshd_config.d/* 2>/dev/null || echo "Nenhum arquivo encontrado"

echo -e "\n3. Configuração efetiva SSH:"
sudo sshd -T | grep -E -i "passwordauthentication|pubkeyauthentication|permitrootlogin"

echo -e "\n4. Usuários do sistema:"
getent passwd | grep -E "(1000|ubuntu|devops)"

echo -e "\n5. Cloud-init final:"
sudo cat /var/lib/cloud/instance/user-data.txt 2>/dev/null || echo "Arquivo não encontrado"
