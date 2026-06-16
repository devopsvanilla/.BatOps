FROM ubuntu:22.04

# Dependências
RUN apt-get update && apt-get install -y curl wget gnupg

# Instalar Ollama
RUN curl -fsSL https://ollama.com/download/Ollama-linux-amd64.tgz | tar -xz -C /usr/local/bin

# Expor API
EXPOSE 11434

CMD ["ollama", "serve"]
