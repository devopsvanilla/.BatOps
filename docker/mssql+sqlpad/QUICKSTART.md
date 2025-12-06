# Quick Start Guide

## 🚀 Início Rápido (qualquer contexto)

```bash
# 1. Criar arquivo .env a partir do exemplo
cp .env-sample .env

# 2. Editar senhas no .env
nano .env

# 3. (Opcional) configurar/selecionar contexto
docker context ls
docker context use <contexto>

# 4. Executar o script
./up.sh
```

O script mostra todos os contextos disponíveis, permite trocar o contexto padrão e executa o `docker compose` usando a flag `--context`, garantindo que tudo rode diretamente no Docker Engine selecionado (local ou remoto). Não há cópia de arquivos para hosts remotos, apenas comandos Docker via contexto.

## 🧪 Validar Configuração

```bash
# Executar teste de pré-requisitos
./test-setup.sh
```

## 📚 Documentação Completa

- **[README.md](README.md)** - Documentação completa do projeto
- **[REMOTE-SETUP.md](REMOTE-SETUP.md)** - Guia detalhado para uso remoto

## 🔑 Acesso Padrão

O resumo final do script informa URLs e host/porta conforme o contexto utilizado. Em contextos locais o endereço padrão continua sendo `http://localhost:3000` e `localhost:1433`. Em contextos remotos os endpoints seguem o host configurado para o contexto (ex.: `http://meu-servidor:3000`).

## ⚡ Comandos Úteis (após `./up.sh`)

> Estes comandos usam o contexto atualmente ativo. Se você já estiver em um contexto remoto, eles serão executados no servidor remoto.

```bash
# Ver logs
docker compose logs -f

# Parar containers
docker compose down

# Reiniciar serviços
docker compose restart

# Ver status / health
docker compose ps
```

## 🆘 Problemas?

```bash
# Verificar contexto atual
docker context show

# Voltar ao contexto local
docker context use default

# Recriar containers e volumes
docker compose down -v
./up.sh
```
