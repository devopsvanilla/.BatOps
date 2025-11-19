#!/bin/bash
# Script de debug para identificar o problema do comando Docker

set -x  # Ativa modo debug

FQDN="finops-hom.sondahybrid.com"

echo "=== TESTE 1: Verificando /etc/hosts ==="
grep "$FQDN" /etc/hosts

echo -e "\n=== TESTE 2: Função get_host_entries ==="

get_host_entries() {
  local domain="$1"
  local entries=""
  local found=false
  
  if [ -f /etc/hosts ]; then
    while IFS= read -r line; do
      [[ "$line" =~ ^\s*# ]] && continue
      [[ -z "$line" ]] && continue
      
      if echo "$line" | grep -qw "$domain"; then
        local ip=$(echo "$line" | awk '{print $1}')
        local hostname=$(echo "$line" | awk '{print $2}')
        
        if [ -n "$ip" ] && [ -n "$hostname" ]; then
          entries="${entries} --add-host=${hostname}:${ip}"
          echo "Detectado: ${hostname} -> ${ip}"
          found=true
        fi
      fi
    done < /etc/hosts
  fi
  
  if [ "$found" = false ]; then
    echo "AVISO: Nenhuma entrada encontrada"
  fi
  
  echo "$entries"
}

HOST_ENTRIES=$(get_host_entries "$FQDN")

echo -e "\n=== TESTE 3: Valor da variável HOST_ENTRIES ==="
echo "HOST_ENTRIES='${HOST_ENTRIES}'"
echo "Tamanho: ${#HOST_ENTRIES}"

echo -e "\n=== TESTE 4: Teste condicional ==="
if [ -n "$HOST_ENTRIES" ]; then
    echo "Variável NÃO está vazia - executaria com --add-host"
else
    echo "Variável ESTÁ vazia - executaria sem --add-host"
fi

echo -e "\n=== TESTE 5: Comando Docker que seria executado ==="
if [ -n "$HOST_ENTRIES" ]; then
    echo "docker run --rm -v /tmp:/zap/wrk:rw -u zap $HOST_ENTRIES -t zaproxy/zap-stable zap-baseline.py -t https://$FQDN -r report.html"
else
    echo "docker run --rm -v /tmp:/zap/wrk:rw -u zap -t zaproxy/zap-stable zap-baseline.py -t https://$FQDN -r report.html"
fi

echo -e "\n=== TESTE 6: Executando comando real (sem scan, apenas --help) ==="
if [ -n "$HOST_ENTRIES" ]; then
    docker run --rm $HOST_ENTRIES zaproxy/zap-stable zap-baseline.py --help 2>&1 | head -5
else
    docker run --rm zaproxy/zap-stable zap-baseline.py --help 2>&1 | head -5
fi
