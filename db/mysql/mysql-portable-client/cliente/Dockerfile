# cliente/Dockerfile
FROM ubuntu:22.04.5

# Não instalamos pacotes de runtime aqui.
# O container usará apenas o que está na pasta 'mysql-portable'

WORKDIR /opt/mysql-app
COPY . .

# Garante que tudo tenha permissão de execução
RUN chmod +x mysql run.sh

# Mantém o container vivo para o teste
CMD ["tail", "-f", "/dev/null"]
