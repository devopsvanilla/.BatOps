#!/bin/bash
echo "=== DIAGNÓSTICO CLOUD-INIT VM COMPLETO ==="
echo "Data: $(date)"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime)"

echo -e "\n=== 1. STATUS BÁSICO ==="
echo "Cloud-init status:"
sudo cloud-init status --long

echo -e "\nDatasource:"
sudo cloud-id

echo -e "\n=== 2. SERVIÇOS CLOUD-INIT ==="
echo "Status dos serviços:"
sudo systemctl status cloud-init-local.service --no-pager -l
echo -e "\n---"
sudo systemctl status cloud-init.service --no-pager -l
echo -e "\n---"  
sudo systemctl status cloud-config.service --no-pager -l
echo -e "\n---"
sudo systemctl status cloud-final.service --no-pager -l

echo -e "\n=== 3. LOGS RECENTES ==="
echo "Logs cloud-init (últimos 20 minutos):"
sudo journalctl -u cloud-init-local -u cloud-init -u cloud-config -u cloud-final --since "20 minutes ago" --no-pager

echo -e "\n=== 4. ARQUIVOS DE LOG ==="
echo "Cloud-init log (últimas 50 linhas):"
sudo tail -n 50 /var/log/cloud-init.log 2>/dev/null || echo "Arquivo não encontrado"

echo -e "\nCloud-init output log (últimas 30 linhas):"
sudo tail -n 30 /var/log/cloud-init-output.log 2>/dev/null || echo "Arquivo não encontrado"

echo -e "\n=== 5. CONFIGURAÇÕES APLICADAS ==="
echo "Configuração cloud-init aplicada:"
sudo cloud-init query -a 2>/dev/null || echo "Não foi possível obter configurações"

echo -e "\n=== 6. DATASOURCE E INSTÂNCIA ==="
echo "Dados da instância:"
sudo cat /run/cloud-init/instance-data.json 2>/dev/null | jq . 2>/dev/null || sudo cat /run/cloud-init/instance-data.json 2>/dev/null || echo "Dados não disponíveis"

echo -e "\n=== 7. IDENTIFICAÇÃO DE DATASOURCE ==="
echo "Log ds-identify:"
sudo cat /run/cloud-init/ds-identify.log 2>/dev/null || echo "Log não encontrado"

echo -e "\n=== 8. REDE E SSH ==="
echo "Configuração de rede:"
ip addr show
echo -e "\nStatus SSH:"
sudo systemctl status ssh --no-pager || sudo systemctl status sshd --no-pager || echo "SSH não encontrado"

echo -e "\n=== 9. USUÁRIOS E AUTENTICAÇÃO ==="
echo "Usuários do sistema (filtrado):"
cat /etc/passwd | grep -E "(ubuntu|devops|1000|1001)" || echo "Usuários não encontrados"

echo -e "\nConfiguração SSH (PasswordAuthentication):"
sudo grep -n "PasswordAuthentication" /etc/ssh/sshd_config* 2>/dev/null || echo "Configuração não encontrada"

echo -e "\n=== 10. PROCESSOS BLOQUEANDO ==="
echo "Serviços aguardando:"
systemctl list-jobs --after 2>/dev/null || echo "Nenhum job pendente"

echo -e "\n=== 11. ERROS DO SISTEMA ==="
echo "Erros recentes do kernel:"
dmesg -T | grep -i -E "error|fatal|exception|warning" | tail -n 10 || echo "Nenhum erro encontrado"

echo -e "\nServiços falhados:"
systemctl --failed --no-pager || echo "Nenhum serviço falhado"

echo -e "\n=== 12. CLOUD-INIT MODULES ==="
echo "Módulos executados:"
sudo ls -la /var/lib/cloud/instance/sem/ 2>/dev/null || echo "Diretório não encontrado"

echo -e "\n=== DIAGNÓSTICO CONCLUÍDO ==="
