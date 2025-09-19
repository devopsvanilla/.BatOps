# install-morpheus-phpmysqladmin.sh

## 📝 Descrição

Script Bash para instalação e configuração automática do **phpMyAdmin** como interface web para gerenciar o banco de dados MySQL embedded do **Morpheus Data Enterprise**. Permite acesso seguro ao banco de dados via interface web amigável com opções de autenticação dupla e configuração personalizada de portas.

***

## ⚙️ Funcionalidades

- **Configuração automática do MySQL embedded** do Morpheus para aceitar conexões externas
- **Instalação do Docker** (se não estiver presente no sistema)
- **Deploy de phpMyAdmin** via Docker Compose com configurações otimizadas
- **Extração automática da senha** do MySQL root do arquivo de secrets do Morpheus
- **Configuração de autenticação HTTP dupla** (opcional) usando ferramentas nativas
- **Detecção automática de IP** do host para configuração de rede
- **Testes de conectividade** automáticos pós-instalação
- **Validação de portas** e configurações de segurança

***

## 🛠 O que será instalado

### Componentes Docker
- **phpMyAdmin** (imagem oficial `phpmyadmin/phpmyadmin:latest`)
- **Docker Engine** e **Docker Compose** (se não estiverem instalados)

### Configurações criadas
- **Arquivo `.env`** com variáveis de ambiente
- **Arquivo `.htpasswd`** para autenticação HTTP (se habilitada)
- **Arquivo `apache-security.conf`** para configuração de segurança
- **Volume persistente** para sessões do phpMyAdmin

### Modificações no MySQL
- **Criação de usuários** MySQL para conexões externas
- **Configuração de permissões** para acesso remoto ao banco
- **Habilitação de bind-address** para aceitar conexões de outros IPs

***

## 🔒 Recomendações de Segurança

### ⚠️ Obrigatórias
1. **Execute sempre com sudo** - O script precisa acessar arquivos protegidos do Morpheus
2. **Habilite autenticação HTTP dupla** - Adiciona uma camada extra de segurança
3. **Configure firewall** para limitar acesso à porta do phpMyAdmin apenas para IPs autorizados
4. **Use portas não-padrão** - Evite usar a porta 80 ou outras comuns

### 🛡️ Recomendadas
1. **Configure SSL/TLS** - Use proxy reverso com certificados para HTTPS
2. **Monitore logs de acesso** - Acompanhe tentativas de login suspeitas
3. **Implemente IP whitelisting** - Limite acesso apenas para redes confiáveis
4. **Faça backup das configurações** - Mantenha cópias dos arquivos `.env` e de autenticação

### 🔐 Autenticação Dupla
Quando habilitada, o acesso requer:
1. **1ª Camada**: Autenticação HTTP Basic (usuário/senha HTTP)
2. **2ª Camada**: Autenticação MySQL (usuário/senha do banco)

***

## 🚀 Como Instalar

### 1. Pré-requisitos
- **Morpheus Data Enterprise** instalado e funcionando
- **Acesso root/sudo** no servidor
- **Arquivo de secrets** do Morpheus presente em `/etc/morpheus/morpheus-secrets.json`

### 2. Prepare os arquivos
```bash
# Navegue para o diretório morpheus-phpmysql
cd /caminho/para/morpheus-phpmysql

# Verifique se os arquivos estão presentes
ls -la
# Deve conter: install-morpheus-phpmysqladmin.sh e docker-compose.yml
```

### 3. Torne o script executável
```bash
chmod +x install-morpheus-phpmysqladmin.sh
```

### 4. Execute a instalação
```bash
sudo ./install-morpheus-phpmysqladmin.sh
```

### 5. Configure durante a execução
O script solicitará:

1. **Porta do MySQL** (padrão: 3306)
   ```
   Em que porta o MySQL do Morpheus está exposto?
   Digite a porta (default: 3306): 
   ```

2. **Porta do phpMyAdmin** (padrão: 8306)
   ```
   Em que porta deseja expor o phpMyAdmin?
   Digite a porta (default: 8306): 
   ```

3. **Usuário MySQL** (padrão: root)
   ```
   Qual usuário MySQL deseja usar para o phpMyAdmin?
   Digite o usuário (default: root): 
   ```

4. **Autenticação HTTP dupla** (padrão: Não)
   ```
   Deseja ativar autenticação HTTP dupla para phpMyAdmin? [s/N]:
   ```

   Se escolher **sim**:
   ```
   Digite o usuário para autenticação HTTP:
   Usuário HTTP (default: admin): 
   
   Digite a senha para autenticação HTTP:
   Senha HTTP: [senha oculta]
   ```

***

## 🌐 Como Acessar

### Acesso Básico (sem autenticação HTTP)
1. Abra o navegador web
2. Acesse: `http://[IP-DO-SERVIDOR]:[PORTA-CONFIGURADA]`
3. Faça login com:
   - **Servidor**: deixe em branco (localhost)
   - **Usuário**: usuário MySQL configurado (padrão: root)
   - **Senha**: extraída automaticamente do Morpheus

**Exemplo:**
```
URL: http://192.168.1.100:8306
Usuário: root
Senha: [extraída automaticamente do morpheus-secrets.json]
```

### Acesso com Autenticação Dupla
1. Abra o navegador web
2. Acesse: `http://[IP-DO-SERVIDOR]:[PORTA-CONFIGURADA]`
3. **1ª Camada** - Digite credenciais HTTP:
   - Usuário HTTP: conforme configurado
   - Senha HTTP: conforme configurado
4. **2ª Camada** - Digite credenciais MySQL:
   - **Servidor**: deixe em branco
   - **Usuário**: usuário MySQL configurado
   - **Senha**: extraída automaticamente do Morpheus

***

## 🔧 Comandos Úteis

### Gerenciar o Container
```bash
# Ver logs em tempo real
docker compose logs -f

# Verificar status e porta
docker compose ps
docker port morpheus-phpmyadmin

# Parar o serviço
docker compose down

# Reiniciar o serviço
docker compose restart

# Recriar completamente
docker compose down
docker compose up -d --force-recreate
```

### Verificar Configurações
```bash
# Ver variáveis de ambiente ativas
cat .env

# Verificar arquivos de autenticação (se habilitada)
ls -la .htpasswd apache-security.conf

# Testar conectividade MySQL
docker exec morpheus-phpmyadmin mysql -h [IP-HOST] -P [PORTA-MYSQL] -u [USUARIO] -p
```

### Debug e Troubleshooting
```bash
# Logs detalhados do container
docker logs morpheus-phpmyadmin

# Verificar se a porta está sendo usada
netstat -tulpn | grep :[PORTA-PHPMYADMIN]

# Testar acesso HTTP básico
curl -I http://[IP-HOST]:[PORTA-PHPMYADMIN]

# Verificar conexão MySQL externa
/opt/morpheus/embedded/mysql/bin/mysql -h [IP-HOST] -P [PORTA-MYSQL] -u [USUARIO] -p
```

***

## ⚠️ Importantes Observações

### Modificações no Sistema
- **MySQL embedded reconfigurado** para aceitar conexões externas
- **Usuários MySQL criados** para acesso remoto (root@IP, root@hostname, root@%)
- **Docker instalado** automaticamente se não estiver presente
- **Nenhum software adicional** é instalado no servidor host

### Arquivos Criados
- `.env` - Variáveis de ambiente do Docker Compose
- `.htpasswd` - Senhas HTTP (se autenticação dupla habilitada)
- `apache-security.conf` - Configuração de segurança Apache

### Portas Utilizadas
- **Porta MySQL**: Configurável (padrão: 3306)
- **Porta phpMyAdmin**: Configurável (padrão: 8306)
- Validação automática de faixa de portas (1024-65535)

### Autenticação e Senhas
- **Senha MySQL**: Extraída automaticamente de `/etc/morpheus/morpheus-secrets.json`
- **Senha HTTP**: Definida pelo usuário (se autenticação dupla habilitada)
- **Hash de senha**: Gerado usando `openssl` nativo do sistema

***

## 🔄 Implantação Manual (Alternativa)

Se preferir executar manualmente após a configuração do script:

```bash
# 1. Exporte as variáveis necessárias
export PASS_MYSQL=$(sudo sed -n 's/.*"root_password" *: *"\([^"]*\)".*/\1/p' /etc/morpheus/morpheus-secrets.json)
export PMA_PORT=8306
export PMA_USER=root
export MYSQL_PORT=3306
export HOST_IP=192.168.1.100
export ENABLE_HTTP_AUTH=false

# 2. Execute o Docker Compose
docker compose up -d
```

***

## 📚 Referências

- **Morpheus Data Enterprise**: [Documentação Oficial](https://docs.morpheusdata.com/)
- **phpMyAdmin Docker**: [Docker Hub](https://hub.docker.com/r/phpmyadmin/phpmyadmin/)
- **Docker Compose**: [Documentação](https://docs.docker.com/compose/)
- **MySQL 8.0**: [Documentação de Segurança](https://dev.mysql.com/doc/refman/8.0/en/security.html)

***

**Criado por DevOps Vanilla, 2025**
<span style="display:none">[^1][^2][^3][^4][^5]</span>

<div style="text-align: center">⁂</div>

[^1]: https://docs.morpheusdata.com/en/latest/infrastructure/databases/databases.html
[^2]: https://docs.docker.com/compose/compose-file/
[^3]: https://docs.phpmyadmin.net/en/latest/setup.html
[^4]: https://dev.mysql.com/doc/refman/8.0/en/access-control.html
[^5]: https://httpd.apache.org/docs/2.4/howto/auth.html