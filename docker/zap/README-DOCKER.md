# ZAP Security Scanner - Docker

Este diretório contém a configuração Docker para executar o script `check-zap-cve.sh` em um container.

## 📋 Pré-requisitos

- Docker instalado e rodando
- Permissões para executar Docker (usuário no grupo docker)

## 🚀 Como usar

### Opção 1: Docker Compose (Recomendado)

```bash
# Build da imagem
docker compose build

# Executar com URL padrão (configurada no docker-compose.yml)
docker compose up

# Executar com URL customizada
docker compose run --rm zap-scanner https://seu-site.com

# Ver logs e resultados
ls -la zap-results/
```

### Opção 2: Docker CLI

```bash
# Build da imagem
docker build -t zap-scanner .

# Executar o scanner
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd)/zap-results:/app/zap-results \
  --privileged \
  zap-scanner https://devopsvanilla.guru

# Ver resultados
ls -la zap-results/
```

## 📊 Resultados

Os relatórios são salvos no diretório `zap-results/` com os seguintes formatos:
- `<dominio>-<timestamp>.html` - Relatório HTML detalhado
- `<dominio>-<timestamp>.pdf` - Relatório PDF (se wkhtmltopdf estiver disponível)
- `<dominio>-<timestamp>.log` - Log completo da execução

## ⚙️ Configuração

### Variáveis de Ambiente

- `SKIP_DEPENDENCY_CHECK=1` - Pula verificação de dependências (já instaladas no container)

### Escolha da Imagem ZAP

Durante a execução, o script perguntará qual imagem ZAP usar:
1. `ghcr.io/zaproxy/zaproxy:stable` (GHCR, mais recente)
2. `zaproxy/zap-stable` (Docker Hub, estável)
3. `zaproxy/zap-weekly` (Docker Hub, semanal)
4. DRY_RUN (simulação sem Docker)

## 🔧 Troubleshooting

### Permissão negada ao Docker socket

Se você receber erro de permissão:
```bash
sudo chmod 666 /var/run/docker.sock
# ou
sudo usermod -aG docker $USER
newgrp docker
```

### Container não consegue acessar internet

Verifique configurações de rede:
```bash
docker network ls
docker network inspect bridge
```

### PDF não é gerado

O wkhtmltopdf está instalado, mas pode precisar do display virtual. O container usa `xvfb` para isso.

## 📝 Notas

- O container usa Docker-in-Docker (DinD) para executar as imagens ZAP
- Requer modo privilegiado para montar o socket do Docker
- Resultados são persistidos no volume montado
- O script original foi modificado para funcionar sem interação do usuário no container

## 🔒 Segurança

Este container executa em modo privilegiado e tem acesso ao socket do Docker. Use apenas em ambientes de desenvolvimento/teste confiáveis.
