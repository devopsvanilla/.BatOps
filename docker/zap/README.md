# Scanner de Baseline com OWASP ZAP (`check-zap-cve.sh`)

Esta página documenta o script `check-zap-cve.sh`, que executa um scan de baseline (passivo) com o OWASP ZAP em uma URL alvo, gerando um relatório HTML (e opcionalmente PDF) em `zap-results/`.


## Visão geral

O script:
- Valida a URL no formato `http(s)://<fqdn>` (pode conter caminho)
- Pergunta qual imagem Docker do ZAP você deseja usar (GHCR ou Docker Hub) ou permite um modo de simulação (DRY_RUN)
- Executa o ZAP Baseline (passivo, sem ataques ativos) dentro de um container Docker
- Salva o relatório HTML em `docker/zap/zap-results/<fqdn>-<YYYYMMDDHHMM>.html`
- Se `wkhtmltopdf` estiver instalado, também gera um PDF com o mesmo nome

Requisitos:
- Docker instalado e em execução (daemon ativo)
- Acesso de rede ao registro de imagens escolhido (GHCR ou Docker Hub)
- `wkhtmltopdf` opcional para PDF


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


## Opções de execução apresentadas pelo script

Ao iniciar, você verá um menu interativo:

1) `ghcr.io/zaproxy/zaproxy:stable` (GHCR, mais recente)
2) `zaproxy/zap-stable` (Docker Hub, estável)
3) `zaproxy/zap-weekly` (Docker Hub, semanal)
4) `DRY_RUN` (simulação, sem Docker)

- Escolha 2 ou 3 para evitar GHCR, caso sua rede bloqueie `ghcr.io`.
- O modo `DRY_RUN` cria um HTML fictício para validar o fluxo sem precisar de Docker ou internet.

Variáveis reconhecidas:
- `DRY_RUN=1` — Se estiver definida, o script gera um relatório fictício, independentemente da imagem escolhida.

Saídas e códigos de retorno relevantes:
- `1` — Falta argumento de URL
- `2` — URL inválida
- `4` — Relatório HTML não foi gerado
- `10` — Opção de menu inválida


## Exemplos

- Execução normal (interativa), com geração de relatório em HTML (e PDF se `wkhtmltopdf` existir):
```bash
./check-zap-cve.sh https://example.com
```

- Se a rede bloquear GHCR, escolha a opção 2 (Docker Hub estável) quando o menu for exibido.

- Simular sem Docker/rede (DRY_RUN):
```bash
DRY_RUN=1 ./check-zap-cve.sh https://example.com
```

- Abrir relatório HTML gerado (Linux):
```bash
xdg-open ./zap-results/example.com-YYYYMMDDHHMM.html
```


## Solução de problemas comuns (Troubleshooting)

1) Erro ao acessar GHCR: `OpenSSL SSL_connect: SSL_ERROR_SYSCALL` ou `EOF`
- Causa provável: firewall/proxy corporativo interceptando/bloqueando TLS para `ghcr.io`
- Soluções rápidas:
  - Use Docker Hub: escolha a opção 2 (`zaproxy/zap-stable`) ou 3 (`zaproxy/zap-weekly`)
  - Verifique rede com:
    ```bash
    curl -v https://ghcr.io/v2/
    docker pull ghcr.io/zaproxy/zaproxy:stable
    ```
- Correções estruturais (no host):
  - Configurar proxy no daemon Docker (`/etc/systemd/system/docker.service.d/proxy.conf`):
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
  - Se houver inspeção TLS, confiar na CA corporativa no Docker para `ghcr.io`:
    ```bash
    sudo mkdir -p /etc/docker/certs.d/ghcr.io
    sudo cp /caminho/para/ca-corporativa.crt /etc/docker/certs.d/ghcr.io/ca.crt
    sudo systemctl restart docker
    docker pull ghcr.io/zaproxy/zaproxy:stable
    ```

2) `wkhtmltopdf` não instalado
- Sintoma: apenas HTML é gerado; mensagem avisa para instalar
- Solução:
  ```bash
  sudo apt install wkhtmltopdf
  ```

3) Docker não encontrado ou não está rodando
- Sintomas: `docker: command not found` ou falha em `docker info`
- Soluções:
  - Instalar Docker, iniciar serviço, e/ou verificar permissões
  - Em muitos casos:
    ```bash
    sudo systemctl status docker
    sudo systemctl start docker
    sudo usermod -aG docker "$USER"  # relogar após isso
    docker info
    ```

4) Rate limit no Docker Hub (erro 429)
- Sintoma: pulls falham por limite de requisições anônimas
- Solução: fazer login no Docker Hub
  ```bash
  docker login
  ```

5) "Relatório HTML não foi gerado"
- Verifique:
  - Permissões de escrita em `zap-results/`
  - Conectividade com a imagem escolhida (puxe manualmente)
  - Se a URL alvo está respondendo corretamente
  - Use `DRY_RUN=1` para validar se a pipeline local funciona


## Estrutura de saídas

- Diretório dos relatórios: `docker/zap/zap-results/`
- Padrão de nomes: `<fqdn>-<YYYYMMDDHHMM>.(html|pdf)`


## Notas finais

- O modo Baseline do ZAP é uma excelente verificação inicial e de monitoramento contínuo
- Para uma cobertura mais profunda, combine com scans ativos, SAST/DAST adicionais, e revisões manuais
- Use o DRY_RUN para validar a integração (CI/CD) sem dependências de rede
