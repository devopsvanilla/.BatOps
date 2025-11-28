#!/bin/bash

# Remove prefixo http:// ou https:// da entrada
DOMINIO=$(echo "$1" | sed -E 's#https?://##')

echo "======================================"
echo " Relatório de Segurança do Site"
echo " Domínio: $DOMINIO"
echo "======================================"
echo

# 1. WHOIS
echo "[WHOIS - Registro do Domínio]"
if command -v whois >/dev/null 2>&1; then
    whois $DOMINIO | grep -E 'Registrar|Registrant|Creation Date|Expiry Date'
else
    echo "⚠️ whois não está instalado. Instale com: sudo apt install whois"
fi
echo

# 2. DNS / Hospedagem
echo "[DNS - Servidores e IP]"
dig +short $DOMINIO
echo

# 3. Certificado SSL
echo "[Certificado SSL]"
echo | openssl s_client -connect $DOMINIO:443 -servername $DOMINIO 2>/dev/null | openssl x509 -noout -subject -issuer -dates
echo

# 4. Cabeçalhos HTTP
echo "[Cabeçalhos HTTP]"
curl -I -s https://$DOMINIO | grep -E 'HTTP|Server|Content-Security-Policy|Strict-Transport-Security'
echo

# 5. Scan de portas e vulnerabilidades básicas
echo "[Nmap - Portas e Vulnerabilidades]"
nmap -sV --script vuln -T4 $DOMINIO | grep -E 'open|VULNERABLE'
echo

echo "======================================"
echo " Análise resumida:"
echo " - WHOIS: informações de registro listadas acima"
echo " - DNS: IP e servidores resolvidos"
echo " - SSL: validade e emissor do certificado"
echo " - HTTP: políticas de segurança aplicadas"
echo " - Nmap: portas abertas e possíveis falhas"
echo "======================================"
echo

# Status simplificado
echo "[Status de Segurança]"
if curl -Is https://$DOMINIO | grep -q "200"; then
    echo "✅ Site responde em HTTPS"
else
    echo "⚠️ Problema ao acessar via HTTPS"
fi

if nmap -sV --script vuln -T4 $DOMINIO | grep -q "VULNERABLE"; then
    echo "❌ Vulnerabilidades detectadas"
else
    echo "✅ Nenhuma vulnerabilidade crítica detectada nos testes básicos"
fi
