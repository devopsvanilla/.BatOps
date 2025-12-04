# Quick Start Guide

## 🚀 Início Rápido - Contexto Local

```bash
# 1. Criar arquivo .env a partir do exemplo
cp .env-sample .env

# 2. Editar senhas no .env
nano .env  # ou seu editor preferido

# 3. Executar o script
./up.sh
```

## 🌐 Início Rápido - Contexto Remoto (SSH)

```bash
# 1. Criar arquivo .env a partir do exemplo
cp .env-sample .env

# 2. Editar senhas no .env
nano .env

# 3. Configurar contexto Docker remoto
docker context create meu-servidor \
  --docker "host=ssh://usuario@ip-do-servidor"

# 4. Ativar o contexto remoto
docker context use meu-servidor

# 5. Executar o script
./up.sh

# O script irá sincronizar automaticamente os arquivos
# e executar no servidor remoto!
```

### O que o script faz automaticamente

- Detecta e, se necessário, troca o contexto Docker ativo (local ou remoto).
- Lista as redes disponíveis no contexto, permitindo escolher ou criar na hora.
- Cria/ajusta os volumes externos exigidos e aplica permissões compatíveis com o usuário `mssql` (10001).
- Sincroniza `.env`, `docker-compose.yml` e demais arquivos com o host remoto quando aplicável.
- Executa `docker compose up -d` no local correto e aguarda os health checks antes de mostrar as URLs de acesso.

## 🧪 Validar Configuração

```bash
# Executar teste de pré-requisitos
./test-setup.sh
```

## 📚 Documentação Completa

- **[README.md](README.md)** - Documentação completa do projeto
- **[REMOTE-SETUP.md](REMOTE-SETUP.md)** - Guia detalhado para uso remoto

## 🔑 Acesso Padrão

Após executar `./up.sh` com sucesso:

### Local

- **SQLPad:** [http://localhost:3000](http://localhost:3000)
- **SQL Server:** `localhost:1433`

### Remoto

- **SQLPad:** [http://IP-DO-SERVIDOR:3000](http://IP-DO-SERVIDOR:3000)
- **SQL Server:** `IP-DO-SERVIDOR:1433`

**Credenciais padrão:**

- SQLPad: `admin@sqlpad.com` / (senha do .env)
- SQL Server: `sa` / (senha do .env)

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
