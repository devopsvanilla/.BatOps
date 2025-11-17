FROM ubuntu:22.04

# Evita prompts interativos durante instalação
ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    wkhtmltopdf \
    xvfb \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Cria diretório de trabalho
WORKDIR /app

# Copia o script para o container
COPY check-zap-cve.sh /app/check-zap-cve.sh

# Cria diretório para resultados
RUN mkdir -p /app/zap-results

# Torna o script executável
RUN chmod +x /app/check-zap-cve.sh

# Define variáveis de ambiente para evitar instalação interativa
ENV SKIP_DEPENDENCY_CHECK=1

# Volume para armazenar resultados
VOLUME ["/app/zap-results"]

# Entrypoint para executar o script
ENTRYPOINT ["/app/check-zap-cve.sh"]

# Argumento padrão (pode ser sobrescrito)
CMD ["https://example.com"]
