# Script de Listagem de Portas e Firewall - Ubuntu

## Descrição

O script `list-ports-and-firewall.sh` é uma ferramenta completa para monitorar portas em uso e configurações de firewall no Ubuntu. Ele fornece informações detalhadas sobre:

- **Portas em uso** (TCP e UDP)
- **ID do processo** (PID) que está usando cada porta
- **Caminho completo** do executável do processo
- **Status do firewall UFW**
- **Portas bloqueadas** e regras de firewall

## Características

### ✅ Funcionalidades Principais

- 🔍 **Listagem completa de portas**: TCP e UDP em uso
- 🆔 **Identificação de processos**: PID e caminho do executável
- 🔥 **Análise do firewall**: Status do UFW e regras configuradas
- 🚫 **Portas bloqueadas**: Identifica regras de DENY e DROP
- 📊 **Resumo estatístico**: Contadores e status geral
- 🎨 **Saída colorizada**: Interface visual clara e organizada

### 📋 Informações Coletadas

Para cada porta em uso, o script mostra:
- **Porta**: Número da porta
- **Protocolo**: TCP ou UDP
- **PID**: ID do processo
- **Caminho**: Localização completa do executável

Para o firewall:
- Status do UFW (ativo/inativo)
- Regras configuradas
- Políticas padrão
- Portas explicitamente bloqueadas

## Como Usar

### 💡 Execução Básica

```bash
# Execução normal (usuário comum)
./list-ports-and-firewall.sh
```

### 🔐 Execução com Privilégios

```bash
# Para informações completas do firewall
sudo ./list-ports-and-firewall.sh
```

### 📝 Salvando Resultado em Arquivo

```bash
# Salvar relatório em arquivo
./list-ports-and-firewall.sh > relatorio-portas.txt

# Salvar com timestamp
./list-ports-and-firewall.sh > "relatorio-$(date +%Y%m%d_%H%M%S).txt"
```

## Exemplo de Saída

```
================================================================
           RELATÓRIO DE PORTAS E FIREWALL - UBUNTU
================================================================

🔍 PORTAS EM USO NO SISTEMA
================================================================
PORTA    PROTOCOLO  PID        CAMINHO DO PROCESSO                      
------------------------------------------------------------------------
📡 Portas TCP:
22       tcp        1234       /usr/sbin/sshd
80       tcp        5678       /usr/sbin/nginx
443      tcp        5678       /usr/sbin/nginx
3306     tcp        9012       /usr/sbin/mysqld

📡 Portas UDP:
53       udp        3456       /usr/sbin/systemd-resolved
68       udp        7890       /sbin/dhclient

🔥 STATUS DO FIREWALL (UFW)
================================================================
📊 Status do UFW:
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)

📋 Regras do UFW (numeradas):
     To                         Action      From
     --                         ------      ----
[ 1] 22/tcp                     ALLOW IN    Anywhere
[ 2] 80/tcp                     ALLOW IN    Anywhere
[ 3] 443/tcp                    ALLOW IN    Anywhere

🚫 ANÁLISE DE PORTAS BLOQUEADAS
================================================================
🔍 Política padrão do UFW:
Default: deny (incoming), allow (outgoing), disabled (routed)

📊 RESUMO
================================================================
🔢 Total de portas TCP em uso: 15
🔢 Total de portas UDP em uso: 8
🔥 Status do UFW: active
```

## Requisitos

### 📦 Dependências

O script utiliza comandos padrão do Ubuntu:
- `netstat` (pacote net-tools)
- `ufw` (Ubuntu Firewall)
- `iptables`
- Comandos básicos: `awk`, `sed`, `grep`

### 🔧 Instalação de Dependências

```bash
# Instalar net-tools se necessário
sudo apt update
sudo apt install net-tools

# UFW já vem instalado no Ubuntu por padrão
# Se não estiver instalado:
sudo apt install ufw
```

## Permissões

### 👤 Usuário Comum
- ✅ Lista portas em uso
- ✅ Mostra PIDs e caminhos de processos próprios
- ⚠️ Informações limitadas do firewall

### 🔐 Root/Sudo
- ✅ Informações completas de todos os processos
- ✅ Status completo do firewall UFW
- ✅ Regras do iptables
- ✅ Políticas padrão

## Casos de Uso

### 🔍 Diagnóstico de Segurança
```bash
# Verificar quais portas estão abertas
sudo ./list-ports-and-firewall.sh | grep -E "PORTA|tcp|udp"
```

### 📊 Auditoria de Serviços
```bash
# Identificar processos usando portas específicas
sudo ./list-ports-and-firewall.sh | grep ":80\|:443\|:22"
```

### 🔥 Verificação de Firewall
```bash
# Focar apenas no firewall
sudo ./list-ports-and-firewall.sh | grep -A 20 "FIREWALL"
```

### 📈 Monitoramento
```bash
# Executar periodicamente
watch -n 30 'sudo ./list-ports-and-firewall.sh'
```

## Troubleshooting

### ❌ Problemas Comuns

1. **"netstat: command not found"**
   ```bash
   sudo apt install net-tools
   ```

2. **"Permission denied" para informações do firewall**
   ```bash
   sudo ./list-ports-and-firewall.sh
   ```

3. **Saída sem cores**
   - Verifique se o terminal suporta cores
   - Use `export TERM=xterm-256color`

## Personalização

O script pode ser facilmente modificado para:
- Filtrar portas específicas
- Adicionar mais informações de processo
- Integrar com sistemas de monitoramento
- Gerar relatórios em diferentes formatos

## Segurança

⚠️ **Aviso de Segurança**:
- O script mostra informações sensíveis do sistema
- Execute apenas em sistemas que você administra
- Não compartilhe a saída sem revisar informações expostas

## Autor

**DevOps Vanilla** - Script para listagem de portas e firewall Ubuntu

## Licença

Este script é fornecido "como está" para fins educacionais e de administração de sistemas.