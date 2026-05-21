#!/bin/bash

sudo apt update
sudo apt install sysbench

echo "===== TESTE DE CPU ====="
sysbench cpu run

echo -e "\n===== TESTE DE MEMÓRIA ====="
sysbench memory run

echo -e "\n===== TESTE DE THREADS ====="
sysbench threads run

echo -e "\n===== TESTE DE DISCO ====="
# Preparar arquivos de teste
sysbench fileio --file-total-size=100mb prepare

# Teste de leitura sequencial
sysbench fileio --file-total-size=100mb --file-test-mode=seqrd run

# Teste de escrita sequencial
sysbench fileio --file-total-size=100mb --file-test-mode=seqwr run

# Teste de leitura aleatória
sysbench fileio --file-total-size=100mb --file-test-mode=rndrd run

# Teste de escrita aleatória
sysbench fileio --file-total-size=100mb --file-test-mode=rndwr run

# Limpar arquivos de teste
sysbench fileio cleanup
