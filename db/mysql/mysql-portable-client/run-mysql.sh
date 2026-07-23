#!/bin/bash
# Define o caminho local das libs

LD_LIBRARY_PATH="$(dirname "$0")/lib":$LD_LIBRARY_PATH
export LD_LIBRARY_PATH
# Executa o binário
exec "$(dirname "$0")/mysql" "$@"
