# 🚀 Quickstart - OWASP ZAP Scanner

Guia rápido para executar o ZAP Scanner em domínios não públicos.

## Para o servidor `asmorpheusb`

Execute os comandos abaixo:

```bash
# 1. Navegue até o diretório do projeto
cd ~/.BatOps/docker/zap

# 2. Atualize o código do repositório
git pull

# 3. Verifique se o domínio está configurado no /etc/hosts
grep finops-hom.sondahybrid.com /etc/hosts

# Se não estiver, adicione (substitua o IP pelo correto):
# echo "192.168.1.100 finops-hom.sondahybrid.com" | sudo tee -a /etc/hosts

# 4. Execute o scan
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

## O que foi corrigido?

✅ **Arquitetura simplificada** - Removido container intermediário desnecessário
✅ **Detecção automática de DNS** - Lê `/etc/hosts` e propaga para container ZAP
✅ **Sem erro de sintaxe** - Correção do `docker: invalid reference format`
✅ **Performance melhorada** - Execução direta sem camadas extras
✅ **Modo Local/Dummy** - Suporte a URLs locais com `--network host`
✅ **Permissões corrigidas** - Ajuste automático de permissões em `zap-results/`

## ⚠️  Avisos Conhecidos (Podem ser Ignorados)

```text
2025-11-19 03:04:11,748 Unable to copy yaml file to /zap/wrk/zap.yaml [Errno 13] Permission denied: '/zap/wrk/zap.yaml'
```

**Impacto:** Nenhum - O relatório HTML é gerado corretamente.
**Causa:** Arquivo interno temporário do ZAP que não afeta o resultado.
**Status:** Corrigido automaticamente para novos scans (v202511190304+).

## 🌐 Modos de Acesso

### Internet Access

- URL acessível via DNS público ou internet
- Container ZAP usa rede bridge (padrão)
- Usa `--add-host` para resolução DNS customizada

### Local/Dummy Access ⭐ **NOVO**

- URL local (serviço rodando no host)
- Container ZAP usa `--network host`
- Acessa diretamente o `/etc/hosts` do host
- **Ideal para:** Serviços rodando em localhost, 127.0.0.1, ou IPs privados

## Exemplo de Saída Esperada

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        OWASP ZAP Scanner - Execução Simplificada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ URL válida: https://finops-hom.sondahybrid.com

🌐 Modo de acesso à URL
1) Internet Access (URL acessível via DNS público/internet)
2) Local/Dummy Access (URL local, usa /etc/hosts e rede do host)
Digite o número da opção [1-2]: 2
✅ Selecionado: Local/Dummy Access (network=host)

📦 Escolha a imagem do OWASP ZAP
...
2) zaproxy/zap-stable (Docker Hub, estável - recomendado)
...

ℹ️  Pulando verificação/instalação de dependências
🌐 Modo: Local/Dummy Access (usando rede do host)
🔍 Executando scan de segurança em: https://finops-hom.sondahybrid.com
```

## Troubleshooting

### Domínio ainda não resolve

```bash
# Verifique a entrada no /etc/hosts
cat /etc/hosts | grep finops-hom

# Teste resolução
ping -c2 finops-hom.sondahybrid.com

# Teste conectividade HTTP/HTTPS
curl -I https://finops-hom.sondahybrid.com
```

### Certificado SSL inválido

Para ambientes de desenvolvimento/homologação, use HTTP:

```bash
./run-zap-scanner.sh http://finops-hom.sondahybrid.com
```

### Docker não está rodando

```bash
sudo systemctl start docker
sudo systemctl status docker
```

## Mais Informações

- 📖 [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Guia completo de resolução de problemas
- 📚 [README.md](./README.md) - Documentação completa
- 💡 [examples/non-public-domain.md](./examples/non-public-domain.md) - Exemplo detalhado para domínios não públicos
