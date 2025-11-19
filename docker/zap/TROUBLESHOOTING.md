# Troubleshooting - OWASP ZAP Scanner

## Problemas Corrigidos

### 1. Erro: "docker: invalid reference format"

**Sintoma:**
```
docker: invalid reference format
Run 'docker run --help' for more information
```

**Causa:**
Problema na construção do comando Docker quando variáveis de ambiente estão vazias ou mal formatadas.

**Solução Implementada:**
O script agora verifica se há entradas no `/etc/hosts` antes de construir o comando Docker, evitando sintaxe inválida.

**Se você vê este erro:**
1. Verifique se o domínio precisa de entrada no `/etc/hosts`
2. Adicione a entrada se necessário:
   ```bash
   echo "192.168.1.100 finops-hom.sondahybrid.com" | sudo tee -a /etc/hosts
   ```
3. Execute o script novamente

### 2. Erro de DNS: "Name or service not known"

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
2025-11-19 03:04:11,748 Unable to copy yaml file to /zap/wrk/zap.yaml [Errno 13] Permission denied: '/zap/wrk/zap.yaml'
```

**Causa:**
O container ZAP roda com usuário `zap` (UID 1000) e não tem permissão de escrita no diretório montado `zap-results/` (mapeado para `/zap/wrk` dentro do container).

**Solução Implementada (v202511190304+):**
1. O script agora executa `chmod 777` no diretório `zap-results/` antes do scan
2. Ajusta permissões de arquivos e diretórios existentes automaticamente
3. Usa `-u zap` explicitamente no comando Docker
4. Monta volumes com modo `rw` (read-write)

**Solução Manual (se o erro persistir):**
```bash
# Ajuste permissões do diretório
chmod 777 ./zap-results/

# Se houver arquivos com permissões restritas
find ./zap-results -type f -exec chmod 666 {} \;
find ./zap-results -type d -exec chmod 777 {} \;

# Execute o scan novamente
./run-zap-scanner.sh https://finops-hom.sondahybrid.com
```

**Nota:** O aviso sobre permissão não impede a geração do relatório. O scan continua e o relatório HTML é criado normalmente, apenas o arquivo interno `zap.yaml` não é copiado (não afeta o resultado final).

### 3. Erro de DNS: "Name or service not known"
