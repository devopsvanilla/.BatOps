#!/usr/bin/env bash
# TODO: Revisar e adicionar set -euo pipefail — Issue #1

# Verificar se o domínio foi fornecido
if [ -z "$1" ]; then
    echo "Uso: $0 <dominio>"
    echo "Exemplo: $0 devopsvanilla.com.br"
    echo "         $0 exemplo.com"
    echo "         $0 meudominio.org"
    exit 1
fi

DOMAIN="$1"
MAIL_HOST="mail.$DOMAIN"

# Obter IP do mail host para verificação PTR
SERVER_IP=$(dig A $MAIL_HOST +short)

echo "==============================================="
echo "   VERIFICAÇÃO DNS MAIL SERVER"
echo "   Domínio: $DOMAIN"
echo "   Mail Host: $MAIL_HOST"
echo "==============================================="
echo

# 1. Registro A
echo "✅ REGISTRO A (Mail Host):"
a_record=$(dig A $MAIL_HOST +short)
if [ -n "$a_record" ]; then
    echo "   $MAIL_HOST → $a_record"
else
    echo "   ❌ AUSENTE - Configurar: $MAIL_HOST → [SEU_IP]"
fi
echo

# 2. Registro PTR (se tiver IP)
if [ -n "$SERVER_IP" ]; then
    echo "⏳ REGISTRO PTR (Reverse DNS):"
    ptr_record=$(dig -x $SERVER_IP +short)
    if [ -n "$ptr_record" ]; then
        echo "   $SERVER_IP → $ptr_record"
        if [[ "$ptr_record" == *"$MAIL_HOST"* ]]; then
            echo "   ✅ PTR correto"
        else
            echo "   ⚠️  PTR não coincide - Solicitar ao provedor: $MAIL_HOST"
        fi
    else
        echo "   ❌ AUSENTE - Solicitar ao provedor: $SERVER_IP → $MAIL_HOST"
    fi
    echo
fi

# 3. Registro MX
echo "📬 REGISTRO MX:"
mx_record=$(dig MX $DOMAIN +short)
if [ -n "$mx_record" ]; then
    echo "   ✅ CONFIGURADO: $mx_record"
else
    echo "   ❌ AUSENTE"
    echo "   📝 CONFIGURAR: $DOMAIN IN MX 10 $MAIL_HOST"
fi
echo

# 4. Registro SPF
echo "🛡️  REGISTRO SPF:"
spf_record=$(dig TXT $DOMAIN +short | grep -i spf)
if [ -n "$spf_record" ]; then
    echo "   ✅ CONFIGURADO: $spf_record"
else
    echo "   ❌ AUSENTE"
    echo "   📝 CONFIGURAR: $DOMAIN IN TXT \"v=spf1 mx -all\""
fi
echo

# 5. Registro DKIM
echo "🔐 REGISTRO DKIM:"
dkim_record=$(dig TXT dkim._domainkey.$DOMAIN +short)
if [ -n "$dkim_record" ]; then
    echo "   ✅ CONFIGURADO NO DNS"
    echo "   Valor: ${dkim_record:0:50}..."
else
    echo "   ❌ AUSENTE NO DNS"
    echo "   📝 OBTER CHAVE: sudo amavisd-new showkeys"
    echo "   📝 CONFIGURAR: dkim._domainkey.$DOMAIN IN TXT \"v=DKIM1; p=...\""
fi
echo

# 6. Registro DMARC
echo "🚨 REGISTRO DMARC:"
dmarc_record=$(dig TXT _dmarc.$DOMAIN +short)
if [ -n "$dmarc_record" ]; then
    echo "   ✅ CONFIGURADO: $dmarc_record"
else
    echo "   ❌ AUSENTE"
    echo "   📝 CONFIGURAR: _dmarc.$DOMAIN IN TXT \"v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN\""
fi
echo

# 7. Teste de Conectividade (se tiver IP)
if [ -n "$SERVER_IP" ]; then
    echo "🌐 CONECTIVIDADE SMTP:"
    if timeout 5 bash -c "</dev/tcp/$MAIL_HOST/25" 2>/dev/null; then
        echo "   ✅ SMTP acessível na porta 25"
    else
        echo "   ❌ SMTP inacessível - Verificar firewall"
    fi
    echo
fi

# 8. Resumo
echo "==============================================="
echo "   RESUMO DOS REGISTROS"
echo "==============================================="
[ -n "$a_record" ] && echo "✅ A Record" || echo "❌ A Record"
[ -n "$ptr_record" ] && echo "✅ PTR Record" || echo "❌ PTR Record"
[ -n "$mx_record" ] && echo "✅ MX Record" || echo "❌ MX Record"
[ -n "$spf_record" ] && echo "✅ SPF Record" || echo "❌ SPF Record"
[ -n "$dkim_record" ] && echo "✅ DKIM Record" || echo "❌ DKIM Record"
[ -n "$dmarc_record" ] && echo "✅ DMARC Record" || echo "❌ DMARC Record"
echo "==============================================="
