# Troubleshooting - OWASP ZAP Scanner

## Problemas Corrigidos

### 1. Erro de DNS: "Name or service not known"

**Sintoma:**
```
Job spider failed to access URL https://finops-hom.sondahybrid.com check that it is valid : finops-hom.sondahybrid.com: Name or service not known
```

**Causa:**
O container ZAP não consegue resolver o domínio porque o arquivo `/etc/hosts` do host não é automaticamente propagado para dentro do container.

**Solução Implementada:**
1. O script agora lê o `/etc/hosts` do host
2. Extrai entradas relacionadas ao domínio alvo
3. Usa `--add-host` para propagar essas entradas ao container ZAP
4. Monta o `/etc/hosts` do host como volume read-only

**Exemplo de uso:**

Se seu `/etc/hosts` tem:
```
192.168.1.100 finops-hom.sondahybrid.com
```

O script automaticamente adiciona `--add-host=finops-hom.sondahybrid.com:192.168.1.100` ao comando Docker.

### 2. Erro de Permissão: "Permission denied: '/zap/wrk/zap.yaml'"

**Sintoma:**
```
2025-11-19 00:18:09,587 Unable to copy yaml file to /zap/wrk/zap.yaml [Errno 13] Permission denied: '/zap/wrk/zap.yaml'
```

**Causa:**
Conflito de permissões entre o usuário do container (`zap`) e o volume montado.

**Solução Implementada:**
1. Garante permissões `777` no diretório de resultados antes de executar
2. Usa `-u zap` explicitamente no comando Docker
3. Monta volumes com modo `rw` (read-write)

## Uso Atualizado

### Modo Interativo
```bash
./run-zap-scanner.sh
```

### Modo Não-Interativo (com argumento)
```bash
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

### Variáveis de Ambiente Suportadas

```bash
# Escolher imagem específica
ZAP_IMAGE=zaproxy/zap-stable ./run-zap-scanner.sh https://exemplo.com

# Modo simulação (sem scan real)
ZAP_IMAGE=DRY_RUN ./run-zap-scanner.sh https://exemplo.com
```

## Requisitos para Domínios Não Públicos

Se o domínio **não está no DNS público**, configure o `/etc/hosts` do servidor:

```bash
# Adicione a entrada no /etc/hosts do host
echo "192.168.1.100 finops-hom.sondahybrid.com" | sudo tee -a /etc/hosts

# Verifique a resolução
ping -c1 finops-hom.sondahybrid.com

# Execute o scan
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

O script detectará automaticamente essa entrada e a propagará para o container ZAP.

## Verificações Pré-Execução

Antes de executar o scan, verifique:

```bash
# 1. Docker está rodando
docker ps

# 2. Conectividade com a URL (do host)
curl -I https://finops-hom.sondahybrid.com

# 3. Entrada no /etc/hosts (se necessário)
grep finops-hom.sondahybrid.com /etc/hosts

# 4. Permissões do diretório de resultados
ls -ld ./zap-results/
```

## Exit Codes do ZAP

| Código | Significado |
|--------|-------------|
| 0      | Sucesso - nenhuma vulnerabilidade crítica |
| 1      | Warnings - vulnerabilidades de baixo risco |
| 2      | Alertas - vulnerabilidades médias |
| 3      | Falha fatal - scan não completou |
| 4      | Erro de geração de relatório |

## Logs e Debugging

Os logs são salvos em `zap-results/<dominio>-<timestamp>.log`:

```bash
# Ver último log
ls -lt zap-results/*.log | head -1

# Seguir log em tempo real (em outra sessão)
tail -f zap-results/*.log
```

## Alternativas para Ambientes Restritos

Se o acesso a `ghcr.io` está bloqueado:

```bash
# Use Docker Hub em vez de GHCR
ZAP_IMAGE=zaproxy/zap-stable ./run-zap-scanner.sh https://exemplo.com
```

Se está atrás de proxy corporativo:

```bash
# Configure proxy para Docker
export HTTP_PROXY=http://proxy.empresa.com:8080
export HTTPS_PROXY=http://proxy.empresa.com:8080

# Execute o scan
./run-zap-scanner.sh https://exemplo.com
```

## Suporte

Para problemas não cobertos aqui:
1. Verifique os logs em `zap-results/*.log`
2. Execute com `set -x` para debug: `bash -x ./run-zap-scanner.sh`
3. Verifique a documentação oficial do ZAP: https://www.zaproxy.org/docs/
