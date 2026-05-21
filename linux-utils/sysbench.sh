#!/bin/bash

sudo apt update
sudo apt install -y sysbench

echo "===== TESTE DE CPU ====="
CPU_OUT=$(sysbench cpu run)
echo "$CPU_OUT"

echo -e "\n===== TESTE DE MEMÓRIA ====="
MEM_OUT=$(sysbench memory run)
echo "$MEM_OUT"

echo -e "\n===== TESTE DE THREADS ====="
THR_OUT=$(sysbench threads run)
echo "$THR_OUT"

echo -e "\n===== TESTE DE DISCO ====="
# Preparar arquivos de teste
sysbench fileio --file-total-size=100mb prepare

# Teste de leitura sequencial
echo "Executando leitura sequencial..."
DISK_SEQRD=$(sysbench fileio --file-total-size=100mb --file-test-mode=seqrd run)
echo "$DISK_SEQRD"

# Teste de escrita sequencial
echo -e "\nExecutando escrita sequencial..."
DISK_SEQWR=$(sysbench fileio --file-total-size=100mb --file-test-mode=seqwr run)
echo "$DISK_SEQWR"

# Teste de leitura aleatória
echo -e "\nExecutando leitura aleatória..."
DISK_RNDRD=$(sysbench fileio --file-total-size=100mb --file-test-mode=rndrd run)
echo "$DISK_RNDRD"

# Teste de escrita aleatória
echo -e "\nExecutando escrita aleatória..."
DISK_RNDWR=$(sysbench fileio --file-total-size=100mb --file-test-mode=rndwr run)
echo "$DISK_RNDWR"

# Limpar arquivos de teste
sysbench fileio cleanup

echo -e "\n=========================================================="
echo "          RELATÓRIO DO SISTEMA (FÁCIL ENTENDIMENTO)        "
echo "=========================================================="
echo "💻 PROCESSADOR (CPU):"
echo "   - Quantidade de Cores: $(nproc) cores"
echo "   - Desempenho Efetivo (Sysbench): $(echo "$CPU_OUT" | grep 'events per second:' | awk '{print $4}') eventos/seg"
echo ""
echo "🧠 MEMÓRIA RAM:"
echo "   - Capacidade Total: $(free -h | awk '/^Mem:/ {print $2}')"
echo "   - Velocidade Efetiva: $(echo "$MEM_OUT" | grep 'MiB transferred' | grep -o '([0-9.]* MiB/sec)' | tr -d '()')"
echo ""
echo "💾 DISCO (Armazenamento):"
echo "   - Velocidade de Leitura: $(echo "$DISK_SEQRD" | grep 'read, MiB/s:' | awk '{print $3}') MiB/s"
echo "   - Velocidade de Gravação: $(echo "$DISK_SEQWR" | grep 'written, MiB/s:' | awk '{print $3}') MiB/s"
echo "=========================================================="
