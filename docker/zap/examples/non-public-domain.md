# Exemplo: Scan de Domínios Não Públicos

Este guia demonstra como executar o ZAP Scanner em domínios que **não estão no DNS público**, como ambientes de homologação, desenvolvimento ou infraestrutura interna.

## Cenário

Você precisa escanear `finops-hom.sondahybrid.com` que:
- ✅ Está acessível via rede (IP: `192.168.1.100`)
- ❌ Não está registrado no DNS público
- 🔧 Precisa de resolução via `/etc/hosts`

## Passo a Passo

### 1. Configure o /etc/hosts do Servidor

```bash
# Adicione a entrada DNS local
echo "192.168.1.100 finops-hom.sondahybrid.com" | sudo tee -a /etc/hosts

# Verifique se foi adicionado
grep finops-hom.sondahybrid.com /etc/hosts

# Teste a resolução
ping -c2 finops-hom.sondahybrid.com

# Teste conectividade HTTP/HTTPS
curl -I https://finops-hom.sondahybrid.com
```

**Saída esperada do ping:**
```
PING finops-hom.sondahybrid.com (192.168.1.100) 56(84) bytes of data.
64 bytes from finops-hom.sondahybrid.com (192.168.1.100): icmp_seq=1 ttl=64 time=0.345 ms
```

### 2. Execute o Scanner

```bash
cd /caminho/para/.BatOps/docker/zap

# Modo interativo (recomendado para primeira execução)
./run-zap-scanner.sh

# OU modo não-interativo com URL como argumento
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

### 3. O que acontece internamente

O script detecta automaticamente a entrada do `/etc/hosts`:

```bash
🔗 Mapeamento DNS detectado: finops-hom.sondahybrid.com -> 192.168.1.100
```

E executa o container ZAP com:
```bash
docker run --rm \
  --add-host=finops-hom.sondahybrid.com:192.168.1.100 \
  -v /etc/hosts:/etc/hosts:ro \
  ... \
  zaproxy/zap-stable
```

### 4. Verifique os Resultados

```bash
# Liste os arquivos gerados
ls -lht zap-results/ | head -5

# Abra o relatório HTML
xdg-open zap-results/finops-hom.sondahybrid.com-*.html
```

## Múltiplos Domínios no Mesmo IP

Se você tem vários domínios apontando para o mesmo servidor (virtual hosts):

```bash
# /etc/hosts
192.168.1.100 finops-hom.sondahybrid.com
192.168.1.100 api-hom.sondahybrid.com
192.168.1.100 admin-hom.sondahybrid.com
```

Execute um scan por vez:

```bash
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
./run-zap-scanner.sh https://api-hom.sondahybrid.com
./run-zap-scanner.sh https://admin-hom.sondahybrid.com
```

## Subdomínios com Wildcards

Para domínios internos com wildcards (ex: `*.interno.empresa.com`):

```bash
# /etc/hosts
10.0.1.50 app1.interno.empresa.com
10.0.1.50 app2.interno.empresa.com
10.0.1.51 api.interno.empresa.com
```

Execute scans individuais para cada subdomínio.

## Troubleshooting Específico

### Container não resolve o domínio

**Sintoma:**
```
Name or service not known
```

**Verificações:**

1. Confirme que o host resolve:
```bash
# No servidor (fora do container)
nslookup finops-hom.sondahybrid.com
# OU
getent hosts finops-hom.sondahybrid.com
```

2. Verifique formato do /etc/hosts:
```bash
# CORRETO ✅
192.168.1.100 finops-hom.sondahybrid.com

# INCORRETO ❌ (comentário impede parsing)
#192.168.1.100 finops-hom.sondahybrid.com
```

3. Verifique permissões:
```bash
ls -l /etc/hosts
# Deve ser legível: -rw-r--r--
```

### Certificado SSL autenticado inválido

**Sintoma:**
```
SSL certificate problem: self signed certificate
```

**Solução:** Use HTTP em vez de HTTPS para ambientes de desenvolvimento:

```bash
./run-zap-scanner.sh http://finops-hom.sondahybrid.com
```

**OU** configure o ZAP para aceitar certificados inválidos (não recomendado para produção):

```bash
# Será adicionado em versão futura
# Por ora, use HTTP para ambientes de dev/homologação
```

### Conexão recusada

**Sintoma:**
```
Connection refused
```

**Verificações:**

1. Servidor está respondendo:
```bash
# Teste com curl do host
curl -v http://finops-hom.sondahybrid.com

# Verifique a porta
nc -zv 192.168.1.100 80
nc -zv 192.168.1.100 443
```

2. Firewall permite conexões:
```bash
# No servidor alvo
sudo iptables -L -n | grep -E '80|443'

# OU
sudo firewall-cmd --list-all
```

## Integração com CI/CD

### GitLab CI

```yaml
zap-scan-staging:
  stage: security
  image: docker:latest
  services:
    - docker:dind
  before_script:
    # Adiciona entrada DNS
    - echo "10.0.1.100 staging.internal.company" >> /etc/hosts
  script:
    - cd docker/zap
    - ZAP_IMAGE=zaproxy/zap-stable ./run-zap-scanner.sh https://staging.internal.company
  artifacts:
    paths:
      - docker/zap/zap-results/
    expire_in: 7 days
  only:
    - merge_requests
```

### GitHub Actions

```yaml
name: Security Scan (Staging)

on:
  pull_request:
    branches: [main, develop]

jobs:
  zap-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Add DNS entry
        run: |
          echo "10.0.1.100 staging.internal.company" | sudo tee -a /etc/hosts

      - name: Run ZAP Scanner
        run: |
          cd docker/zap
          ZAP_IMAGE=zaproxy/zap-stable ./run-zap-scanner.sh https://staging.internal.company

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: zap-results
          path: docker/zap/zap-results/
```

## Boas Práticas

1. **Documente os IPs**: Mantenha um arquivo `hosts-mapping.txt` versionado:
   ```
   # Ambientes de Homologação
   192.168.1.100 finops-hom.sondahybrid.com
   192.168.1.101 api-hom.sondahybrid.com

   # Ambientes de Desenvolvimento
   10.0.1.50 finops-dev.sondahybrid.com
   ```

2. **Automatize a configuração**:
   ```bash
   # Script de setup
   cat hosts-mapping.txt | sudo tee -a /etc/hosts
   ```

3. **Limpe entradas obsoletas**:
   ```bash
   # Remove entradas antigas antes de adicionar novas
   sudo sed -i '/sondahybrid.com/d' /etc/hosts
   cat hosts-mapping.txt | sudo tee -a /etc/hosts
   ```

4. **Use VPN para acessar redes internas**:
   ```bash
   # Conecte à VPN corporativa primeiro
   sudo openvpn --config company-vpn.ovpn

   # Depois execute o scan
   ./run-zap-scanner.sh https://internal-app.company.local
   ```

## Resumo

✅ Configure `/etc/hosts` no servidor executor
✅ Verifique conectividade com `ping` e `curl`
✅ Execute o script (detecta automaticamente as entradas)
✅ Revise os resultados em `zap-results/`

Para mais informações sobre resolução de problemas, consulte [TROUBLESHOOTING.md](../TROUBLESHOOTING.md).
