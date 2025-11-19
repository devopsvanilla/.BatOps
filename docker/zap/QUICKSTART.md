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

## Exemplo de Saída Esperada

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        OWASP ZAP Scanner - Execução Simplificada
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ URL válida: https://finops-hom.sondahybrid.com

📦 Escolha a imagem do OWASP ZAP
...
2) zaproxy/zap-stable (Docker Hub, estável - recomendado)
...

ℹ️  Pulando verificação/instalação de dependências
🔗 Mapeamento DNS detectado: finops-hom.sondahybrid.com -> 127.0.0.1
📦 Usando imagem: zaproxy/zap-stable
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
