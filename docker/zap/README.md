# Scanner de Baseline com OWASP ZAP em Docker - zap-scanner

Esta página documenta a execução containerizada do **zap-scanner**, automação feita em Bash e Docker que executa um scan de baseline (passivo) com o OWASP ZAP em uma URL alvo, gerando um relatório HTML e PDF em `zap-results/`.

![ZAP Scan Report](../../_images/check-zap-cve.jpeg)

## 🛡️ Por que usar esta abordagem?

### Vantagens de Segurança e Isolamento

Esta solução oferece **execução isolada via containers Docker** com detecção automática de configurações DNS locais:

- **🔒 Isolamento de segurança**: O ZAP roda em container separado, protegendo o sistema host
- **🌐 Suporte a DNS local**: Detecta automaticamente entradas do `/etc/hosts` e propaga para o container
- **🏝️ Ambiente efêmero**: Container é destruído após cada scan, sem deixar rastros
- **📦 Reprodutibilidade**: Mesma imagem, mesmo ambiente, mesmos resultados
- **🚀 Deploy rápido**: Pronto para uso em segundos, sem configuração manual
- **♻️ Cleanup automático**: Container removido automaticamente com `--rm`
- **🔧 Flexibilidade**: Suporta domínios públicos e privados (via /etc/hosts)

### Casos de uso ideais

- Pipelines de CI/CD (GitHub Actions, GitLab CI, Jenkins)
- Ambientes de produção onde não se pode instalar ferramentas diretamente
- Equipes de segurança que precisam executar scans em diferentes ambientes
- Desenvolvimento local sem "poluir" o sistema com dependências de ferramentas de teste

## Visão geral

**O que é executado:**

- Validação da URL no formato `http(s)://<fqdn>` (pode conter caminho)
- Seleção automática ou manual da imagem Docker do ZAP (GHCR ou Docker Hub)
- Execução do ZAP Baseline (passivo, sem ataques ativos) dentro de um container Docker
- Geração de relatórios em `zap-results/<fqdn>-<YYYYMMDDHHMM>.html` e `.pdf`

**Requisitos:**

- Docker instalado e em execução
- Permissões para executar Docker (usuário no grupo docker)


## Sobre OWASP ZAP e reputação para essa atividade

O OWASP ZAP (Zed Attack Proxy) é um projeto da OWASP, gratuito e de código aberto, amplamente reconhecido e utilizado para testes de segurança de aplicações web. É um dos scanners mais populares para análise automática, especialmente adequado para pipelines CI/CD e verificações de baseline.

Para esta atividade, usamos o modo Baseline do ZAP:

- Seguro para executar em ambientes de produção (não faz ataques ativos)
- Executa varredura passiva em requisições HTTP(S)
- Ajuda a encontrar problemas comuns de configuração e segurança sem causar interrupções

Observação: um scan passivo não substitui um teste de intrusão completo. Para análises profundas, é recomendado utilizar scans ativos e outras técnicas, em um ambiente controlado.


## O que é testado no Baseline

O ZAP Baseline é focado em detecção passiva. Exemplos de itens verificados:

- Cabeçalhos de segurança ausentes ou mal configurados (ex.: `Content-Security-Policy`, `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security`)
- Cookies sem `Secure`/`HttpOnly`/`SameSite`
- Possíveis vazamentos de informação em páginas/headers
- Recursos acessíveis sem HTTPS
- Itens detectáveis sem enviar payloads maliciosos

Por padrão, o baseline realiza um spider leve para descobrir páginas e, então, aplica regras passivas sobre as respostas. Não há exploração ativa.


## 🚀 Como usar

### Modo Recomendado: Script Wrapper Interativo

Execute o script que guia você por todas as opções:

```bash
./run-zap-scanner.sh
```

**OU** passe a URL como argumento para modo semi-interativo:

```bash
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

O script irá:
- ✅ Verificar se Docker está instalado e rodando
- 🎯 Validar a URL alvo
- 🔗 Detectar automaticamente entradas do `/etc/hosts` para domínios não públicos
- 📦 Permitir escolher a imagem ZAP (GHCR ou Docker Hub)
- ⚠️ Alertar sobre scans em produção e pedir confirmação
- 📝 Solicitar número de ticket/chamado (se produção)
- 🚀 Executar o scan e exibir resultados

### Modo Direto: Script check-zap-cve.sh

Para uso avançado ou automação, chame diretamente:

```bash
# Com seleção de imagem interativa
./check-zap-cve.sh https://seu-site.com

# Com imagem pré-definida
ZAP_IMAGE=zaproxy/zap-stable ./check-zap-cve.sh https://seu-site.com

# Modo simulação (rápido, para testes)
ZAP_IMAGE=DRY_RUN ./check-zap-cve.sh https://seu-site.com
```

## ⚙️ Configuração

### Variáveis de Ambiente

- `SKIP_DEPENDENCY_CHECK=1` - Pula verificação de dependências (já instaladas no container)
- `NO_PROMPT=1` - Executa em modo não interativo (não pergunta a imagem)
- `ZAP_IMAGE=ghcr.io/zaproxy/zaproxy:stable` - Define explicitamente a imagem do ZAP a ser utilizada
- `ZAP_IMAGE=DRY_RUN` - Executa em modo simulado (gera relatório fictício rapidamente)

### Opções de execução e imagens ZAP

Em ambientes não interativos (como containers ou CI), o script usará automaticamente `ghcr.io/zaproxy/zaproxy:stable`.

Para alterar a imagem, use a variável `ZAP_IMAGE`:

```bash
docker run --rm \
  -e ZAP_IMAGE=zaproxy/zap-stable \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/zap-results:/app/zap-results \
  --privileged \
  zap-scanner https://seu-site.com
```

**Imagens disponíveis:**

1. `ghcr.io/zaproxy/zaproxy:stable` (GHCR, mais recente)
2. `zaproxy/zap-stable` (Docker Hub, estável)
3. `zaproxy/zap-weekly` (Docker Hub, semanal)
4. `DRY_RUN` (simulação sem Docker - para validação rápida)


## 📊 Resultados

Os relatórios são salvos no diretório `zap-results/` com os seguintes formatos:

- `<dominio>-<timestamp>.html` - Relatório HTML detalhado
- `<dominio>-<timestamp>.pdf` - Relatório PDF (wkhtmltopdf incluído no container)
- `<dominio>-<timestamp>.log` - Log completo da execução

**Visualizar relatórios:**

```bash
# Listar relatórios gerados
ls -la zap-results/

# Abrir relatório HTML (Linux)
xdg-open zap-results/example.com-YYYYMMDDHHMM.html

# Abrir relatório PDF
xdg-open zap-results/example.com-YYYYMMDDHHMM.pdf
```


## 🔧 Troubleshooting

> **📖 Documentação Completa:** Consulte [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) para guia detalhado de resolução de problemas.

### Problemas Comuns

#### ❌ Erro: "Name or service not known"

**Sintoma:**
```
finops-hom.sondahybrid.com: Name or service not known
```

**Causa:** O domínio não está no DNS público e o container não consegue resolvê-lo.

**Solução:** Configure o `/etc/hosts` do servidor:

```bash
# Adicione o mapeamento DNS no host
echo "192.168.1.100 finops-hom.sondahybrid.com" | sudo tee -a /etc/hosts

# Verifique a resolução
ping -c1 finops-hom.sondahybrid.com

# Execute o scan - o script detectará automaticamente a entrada
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

O script agora **detecta automaticamente** entradas do `/etc/hosts` e as propaga para o container ZAP usando `--add-host`.

#### ❌ Erro: "Permission denied: '/zap/wrk/zap.yaml'"

**Sintoma:**
```
Unable to copy yaml file to /zap/wrk/zap.yaml [Errno 13] Permission denied
```

**Causa:** Conflito de permissões entre usuário do container e volume montado.

**Solução:** O script agora corrige automaticamente as permissões do diretório `zap-results/` antes de executar. Se persistir:

```bash
# Manual fix
chmod 777 ./zap-results/
```

#### Permissão negada ao Docker socket

Se você receber erro de permissão:

```bash
sudo chmod 666 /var/run/docker.sock
# ou
sudo usermod -aG docker $USER
newgrp docker
```

#### Erro ao acessar GHCR

**Sintoma:** `OpenSSL SSL_connect: SSL_ERROR_SYSCALL` ou `EOF`

**Causa:** Firewall/proxy corporativo bloqueando `ghcr.io`

**Solução rápida:** Use Docker Hub com `ZAP_IMAGE=zaproxy/zap-stable`

```bash
ZAP_IMAGE=zaproxy/zap-stable ./run-zap-scanner.sh https://seu-site.com
```

**Solução estrutural:** Configure proxy no daemon Docker (`/etc/systemd/system/docker.service.d/proxy.conf`):

```ini
[Service]
Environment="HTTP_PROXY=http://proxy.corp:8080"
Environment="HTTPS_PROXY=http://proxy.corp:8080"
Environment="NO_PROXY=localhost,127.0.0.1,::1,.local,.corp,.internal,registry-1.docker.io,ghcr.io"
```

Em seguida:

```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
docker info | grep -i proxy -A2
```

#### Container não consegue acessar internet

Verifique configurações de rede:

```bash
docker network ls
docker network inspect bridge
```

#### Rate limit no Docker Hub (erro 429)

**Sintoma:** Pulls falham por limite de requisições anônimas

**Solução:** Fazer login no Docker Hub

```bash
docker login
```

#### PDF não é gerado

O wkhtmltopdf está incluído no container e usa `xvfb` para display virtual. Se o PDF não for gerado, verifique os logs do container.

#### Build falha ou imagem não encontrada

Certifique-se de estar no diretório correto:

```bash
cd /caminho/para/.BatOps/docker/zap
docker build -t zap-scanner .
```

## 📝 Notas técnicas

- O container usa Docker-in-Docker (DinD) para executar as imagens ZAP
- Requer modo privilegiado para montar o socket do Docker
- Resultados são persistidos no volume montado
- O ambiente é efêmero e destruído após execução com `--rm`
- O modo Baseline do ZAP é uma excelente verificação inicial e de monitoramento contínuo
- Para cobertura mais profunda, combine com scans ativos, SAST/DAST adicionais e revisões manuais
- Use `ZAP_IMAGE=DRY_RUN` para validar a integração (CI/CD) sem dependências de rede


## 🔒 Segurança

Este container executa em modo privilegiado e tem acesso ao socket do Docker. Use apenas em ambientes de desenvolvimento/teste confiáveis.

### ⚠️ AVISO IMPORTANTE: Scans em Ambientes de Produção

**Executar scans de segurança em ambientes de produção pode gerar alertas críticos de intrusão!**

Ambientes produtivos, especialmente aqueles hospedados em **nuvens públicas** (AWS, Azure, GCP) e com **CDN** (CloudFlare, Akamai, Fastly), normalmente possuem:

- 🚨 **WAF (Web Application Firewall)** - Detecta e bloqueia padrões de ataque
- 🔍 **IDS/IPS (Intrusion Detection/Prevention Systems)** - Identifica comportamentos suspeitos
- 📊 **SIEM (Security Information and Event Management)** - Correlaciona eventos de segurança
- 🛡️ **DDoS Protection** - Pode interpretar o scan como ataque distribuído
- 📧 **Alertas automáticos** - Equipes de segurança e NOC serão notificados

#### Consequências de scans não autorizados

- ⛔ **Bloqueio de IP** temporário ou permanente
- 🚫 **Rate limiting** aplicado pela CDN
- 📞 **Escalação para times de segurança** e resposta a incidentes
- 📋 **Abertura de tickets** de investigação de incidentes
- ⚖️ **Possíveis implicações legais** em ambientes corporativos

#### ✅ Boas práticas para scans em produção

1. **Obtenha autorização formal** dos times de Segurança da Informação e Monitoramento
2. **Agende uma janela de teste** com antecedência
3. **Solicite whitelist do IP** de origem nos sistemas de segurança
4. **Informe o NOC/SOC** sobre o horário e escopo do teste
5. **Documente** o teste com número de chamado/ticket
6. **Use ambientes de staging/homologação** quando possível
7. **Configure alertas** como "esperados" no SIEM durante o período do teste

#### Recomendação

Para scans de rotina, sempre prefira executar em:

- 🧪 Ambientes de **desenvolvimento/staging**
- 🏠 Infraestrutura **on-premises** controlada
- 🔒 Ambientes **isolados** sem CDN/WAF ativo
- 📝 Com **aprovação documentada** quando absolutamente necessário em produção

## Agradecimentos

Este projeto utiliza as seguintes ferramentas e dependências:

- **[OWASP ZAP (Zed Attack Proxy)](https://www.zaproxy.org/)** - Scanner de segurança de aplicações web, open source e mantido pela OWASP
  - Imagens Docker: `ghcr.io/zaproxy/zaproxy:stable`, `zaproxy/zap-stable`, `zaproxy/zap-weekly`
  - Licença: Apache License 2.0

- **[Docker](https://www.docker.com/)** - Plataforma de containerização utilizada para executar o ZAP de forma isolada e portável
  - Licença: Apache License 2.0

- **[wkhtmltopdf](https://wkhtmltopdf.org/)** - Ferramenta de conversão de HTML para PDF usando o engine de renderização Qt WebKit
  - Licença: LGPLv3

Agradecemos também à comunidade OWASP e aos mantenedores de todas essas ferramentas pelo trabalho contínuo em tornar a segurança de aplicações mais acessível.

---

Este script faz parte do **[.BatOps](https://github.com/devopsvanilla/.BatOps)** - Uma coleção de scripts utilitários para DevOps e automação.
