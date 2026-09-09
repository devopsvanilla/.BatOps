# PFX Extractor for Nginx 🔐

Utilitário em Bash para extrair chaves privadas, certificados de domínio e cadeias intermediárias (CA) de arquivos **PFX / P12 (PKCS#12)**, gerando automaticamente os arquivos formatados e organizados para configuração de SSL/TLS no **Nginx**.

---

## 📑 Sumário

- [Propósito](#-propósito)
- [O que é um arquivo .pfx / .p12?](#-o-que-é-um-arquivo-pfx--p12)
- [Por que o Nginx não aceita .pfx diretamente?](#-por-que-o-nginx-não-aceita-pfx-diretamente)
- [Estrutura dos Arquivos Gerados](#-estrutura-dos-arquivos-gerados)
- [Pré-requisitos](#-pré-requisitos)
- [Como Executar](#-como-executar)
  - [1. Permissão de execução](#1-tornar-o-script-executável)
  - [2. Modo Interativo](#2-modo-interativo-recomendado-para-uso-rápido)
  - [3. Modo por Linha de Comando (CLI / Flags)](#3-modo-via-linha-de-comando-flags)
- [Configuração no Nginx](#-configuração-no-nginx)
- [Guia de Problemas Comuns (Troubleshooting)](#-guia-de-problemas-comuns-troubleshooting)
  - [1. Erro de cifra legada no OpenSSL 3 (digital envelope routines::unsupported)](#1-erro-de-cifra-legada-no-openssl-3-digital-envelope-routinesunsupported)
  - [2. Erro de senha incorreta (MAC verify error)](#2-erro-de-senha-incorreta-mac-verify-error)
  - [3. Incompatibilidade entre Chave e Certificado (key values mismatch)](#3-incompatibilidade-entre-chave-e-certificado-key-values-mismatch)
  - [4. Cadeia intermediária incompleta (Navegador acusa certificado não confiável)](#4-cadeia-intermediária-incompleta-navegador-acusa-certificado-não-confiável)
  - [5. Permissão negada no Nginx (Permission denied)](#5-permissão-negada-no-nginx-permission-denied)
  - [6. Nginx pedindo senha ao iniciar ou recarregar](#6-nginx-pedindo-senha-ao-iniciar-ou-recarregar)
  - [7. Certificado expirado ou fora do período de validade](#7-certificado-expirado-ou-fora-do-período-de-validade)
- [Comandos Úteis de Verificação Manual](#-comandos-úteis-de-verificação-manual)

---

## 🎯 Propósito

Em ambientes corporativos e servidores Windows (IIS, Active Directory Certificate Services - AD CS), é muito comum receber certificados SSL/TLS empacotados na extensão `.pfx` (ou `.p12`).

No entanto, o servidor web **Nginx** opera de forma diferente: ele exige arquivos PEM planos separados (a chave privada em formato `.key` e o certificado em formato `.crt` ou `.pem`, contendo a cadeia completa de autoridades certificadoras).

Este script automatiza 100% esse processo:
1. Extrai a chave privada de forma descriptografada (`-nodes`), evitando que o Nginx trave pedindo senha ao reiniciar.
2. Extrai o certificado do servidor (leaf) e os certificados intermediários da Autoridade Certificadora (CA chain).
3. Concatena os certificados na ordem estrita exigida pelo Nginx (`fullchain.crt`: leaf primeiro, seguido das intermediárias).
4. Suporta detecção e contorno automático das cifras legadas (RC2/3DES) do **OpenSSL 3.0+** (comuns em exportações do Windows/IIS).
5. Valida a integridade criptográfica (garante que a chave privada realmente pertence àquele certificado).
6. Gera metadados detalhados de validade e um exemplo de configuração pronto para o Nginx.

---

## 📦 O que é um arquivo .pfx / .p12?

Um arquivo `.pfx` (Personal Information Exchange) ou `.p12` é um formato de arquivo binário definido pelo padrão **PKCS#12** (Public-Key Cryptography Standards #12).

Ao contrário de formatos comuns como `.crt`, `.cer` ou `.pem` (que contêm apenas certificados públicos em texto Base64), o `.pfx` é um **arquivo contêiner criptografado** protegido por senha que armazena em um único pacote:
- A **Chave Privada** (*Private Key*);
- O **Certificado do Servidor** (*Leaf Certificate* / *End-entity Certificate*);
- Os **Certificados Intermediários** das Autoridades Certificadoras (*Intermediate CAs*);
- Opcionalmente, o certificado da **Autoridade Raiz** (*Root CA*).

Ele é o formato padrão de exportação e importação no ecossistema Microsoft Windows, IIS, Azure e Java KeyStores convertidas.

---

## ⚡ Por que o Nginx não aceita .pfx diretamente?

O Nginx utiliza a biblioteca OpenSSL para terminação TLS, mas foi projetado para ler certificados e chaves a partir de arquivos texto codificados em **PEM** (Privacy-Enhanced Mail, delimitados por blocos textuais Base64 de certificado e chave privada).

Além disso:
1. **Separação de Privilégios**: Em sistemas Linux/Unix, a chave privada (`.key`) deve possuir permissão restrita de leitura (ex: `chmod 600`), enquanto o certificado público (`.crt`) pode ter leitura ampla (`chmod 644`).
2. **Sem interação no Boot**: O Nginx executa como um serviço de sistema (*daemon* em segundo plano via `systemd`). Se a chave privada requerer senha interativa toda vez que o processo reiniciar, o servidor travará na inicialização esperando um operador digitar a senha no terminal.
3. **Cadeia em Bundle**: O protocolo TLS exige que o servidor envie a cadeia de certificação para os clientes. O Nginx faz isso lendo um único arquivo unificado (`fullchain.crt`), onde a ordem dos certificados importa criticamente.

---

## 📂 Estrutura dos Arquivos Gerados

Ao executar o script, os seguintes arquivos são criados no diretório de saída:

| Arquivo | Descrição | Permissão | Diretiva Nginx |
| :--- | :--- | :---: | :--- |
| **`privkey.key`** | Chave privada desprotegida (sem passphrase) | `0600` (`-rw-------`) | `ssl_certificate_key` |
| **`fullchain.crt`** | **Certificado completo** (Leaf + Intermediárias) | `0644` (`-rw-r--r--`) | `ssl_certificate` ⭐ *(Utilize este!)* |
| **`cert.crt`** | Apenas o certificado do servidor (leaf) | `0644` (`-rw-r--r--`) | Referência / Backup |
| **`chain.crt`** | Apenas a(s) autoridade(s) certificadora(s) intermediária(s) | `0644` (`-rw-r--r--`) | `ssl_trusted_certificate` (OCSP) |
| **`cert-info.txt`** | Relatório com Domínio, Emissor, SANs e Validade | `0644` (`-rw-r--r--`) | Consulta humana |
| **`nginx-ssl-sample.conf`** | Bloco `server {}` de exemplo com boas práticas modernas | `0644` (`-rw-r--r--`) | Modelo de configuração |

---

## 🛠️ Pré-requisitos

O script depende de ferramentas padrão presentes em qualquer distribuição Linux moderna (Ubuntu, Debian, CentOS, AlmaLinux, Rocky Linux, WSL2):

- **Bash** (versão 4+)
- **OpenSSL** (versão 1.1.1 ou 3.x)

Para instalar no Ubuntu/Debian caso necessário:
```bash
sudo apt update && sudo apt install -y openssl
```

---

## 🚀 Como Executar

### 1. Tornar o script executável

Navegue até a pasta do utilitário e dê permissão de execução:

```bash
chmod +x extract-pfx.sh
```

---

### 2. Modo Interativo (Recomendado para uso rápido)

Basta rodar o script sem parâmetros. Ele solicitará o caminho do arquivo e a senha de forma segura (a digitação da senha fica oculta no terminal):

```bash
./extract-pfx.sh
```

Exemplo de execução interativa:
```text
Digite o caminho para o arquivo .pfx ou .p12:
> /home/devopsvanilla/certs/meusite.pfx
Digite a senha do arquivo PFX (deixe em branco se não houver senha):
> ********

==> Validando arquivo e senha do PFX...
[INFO] PFX acessível usando provedores padrão do OpenSSL.
[INFO] Diretório de saída: /home/devopsvanilla/.batops/certs/pfx-extractor/extracted_meusite

==> 1/4 Extraindo Chave Privada (descriptografada para Nginx)...
[SUCESSO] Chave privada extraída com sucesso: .../privkey.key (chmod 600)

==> 2/4 Extraindo Certificado do Servidor (Leaf)...
[SUCESSO] Certificado do servidor extraído: .../cert.crt

==> 3/4 Extraindo Cadeia de Certificados Intermediários (CA Chain)...
[SUCESSO] Cadeia de CA extraída: .../chain.crt

==> 4/4 Montando arquivo fullchain.crt para o Nginx...
[INFO] Combinando certificado do domínio + certificados intermediários em fullchain.crt.
[SUCESSO] Arquivo fullchain gerado com sucesso: .../fullchain.crt

==> Verificando correspondência entre chave privada e certificado...
[SUCESSO] Chave privada e Certificado CORRESPONDEM perfeitamente!
```

---

### 3. Modo via Linha de Comando (Flags)

Você pode passar todos os argumentos diretamente, ideal para scripts automatizados ou pipelines CI/CD:

```bash
./extract-pfx.sh [OPÇÕES]
```

#### Opções disponíveis
| Flag | Descrição |
| :--- | :--- |
| `-f, --file <caminho>` | Caminho do arquivo `.pfx` ou `.p12`. |
| `-o, --output <dir>` | Diretório de destino dos arquivos (padrão: `./extracted_<nome_do_arquivo>`). |
| `-p, --password <senha>` | Senha do PFX (se omitida, será solicitada de forma segura sem eco no terminal). |
| `--legacy` | Força o uso do provedor de algoritmos legados do OpenSSL 3.x (`-legacy`). |
| `-h, --help` | Exibe a mensagem de ajuda com exemplos. |

#### Exemplos práticos

**Exemplo A: Informando arquivo e pasta de destino:**
```bash
./extract-pfx.sh -f certificado.pfx -o /etc/nginx/ssl/meudominio
```

**Exemplo B: Informando a senha via linha de comando:**
```bash
./extract-pfx.sh -f certificado.pfx -o ./ssl_saida -p "MinhaSenhaSuperSecreta"
```

**Exemplo C: Forçando o modo legado (se exportado de Windows Server antigo):**
```bash
./extract-pfx.sh -f iis-export.pfx --legacy
```

---

## 🌐 Configuração no Nginx

Após a extração, siga os passos abaixo para configurar o Nginx:

### 1. Mover os arquivos para o diretório SSL padrão

Geralmente em `/etc/nginx/ssl/<seu-dominio>/`:

```bash
sudo mkdir -p /etc/nginx/ssl/meudominio
sudo cp extracted_meusite/fullchain.crt /etc/nginx/ssl/meudominio/
sudo cp extracted_meusite/privkey.key /etc/nginx/ssl/meudominio/
sudo chmod 600 /etc/nginx/ssl/meudominio/privkey.key
sudo chmod 644 /etc/nginx/ssl/meudominio/fullchain.crt
```

### 2. Configurar o VirtualHost no Nginx

Edite seu arquivo de configuração (ex: `/etc/nginx/conf.d/meudominio.conf` ou `/etc/nginx/sites-available/meudominio`):

```nginx
server {
    listen 80;
    listen [::]:80;
    server_name meudominio.com.br www.meudominio.com.br;

    # Redirecionamento HTTP para HTTPS
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name meudominio.com.br www.meudominio.com.br;

    # Certificados extraídos pelo script
    ssl_certificate         /etc/nginx/ssl/meudominio/fullchain.crt;
    ssl_certificate_key     /etc/nginx/ssl/meudominio/privkey.key;

    # Protocolos e Cifras Modernas e Seguras
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # Otimização de Sessão SSL
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:10m;
    ssl_session_tickets off;

    # Cabeçalhos de Segurança Recomendados
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    location / {
        root /var/www/meudominio;
        index index.html;
    }
}
```

### 3. Testar a sintaxe e recarregar o Nginx

```bash
# Valida a sintaxe dos arquivos de configuração
sudo nginx -t

# Se o teste retornar 'successful', recarregue sem derrubar conexões ativas:
sudo systemctl reload nginx
```

---

## 🩺 Guia de Problemas Comuns (Troubleshooting)

### 1. Erro de cifra legada no OpenSSL 3 (`digital envelope routines::unsupported`)

* **Sintoma:** Ao tentar extrair em distribuições recentes (Ubuntu 22.04, Ubuntu 24.04, Debian 12) aparece a mensagem:
  ```text
  00109D94557F0000:error:0308010C:digital envelope routines:inner_evp_generic_fetch:unsupported:../crypto/evp/evp_fetch.c:349:Global default library context, Algorithm (RC2-40-CBC : 0), Properties ()
  ```
* **Causa:** O Windows Server / IIS tradicionalmente exporta arquivos PFX usando algoritmos de criptografia antigos como `RC2-40-CBC` ou `3DES`. O OpenSSL 3 desativou essas cifras fracas por padrão no provedor padrão.
* **Solução:**
  - O script `extract-pfx.sh` **detecta isso automaticamente** e aplica o parâmetro `-legacy` para ler o arquivo sem você precisar fazer nada.
  - Caso execute manualmente via OpenSSL, passe a flag `-legacy`:
    ```bash
    openssl pkcs12 -in certificado.pfx -nocerts -nodes -legacy -out privkey.key
    ```

---

### 2. Erro de senha incorreta (`MAC verify error`)

* **Sintoma:** O comando falha com:
  ```text
  Mac verify error: invalid password?
  ```
* **Causa:** A senha informada difere da senha definida quando o PFX foi exportado.
* **Solução:**
  - Certifique-se de que não há espaços extras copiados antes ou depois da senha.
  - Se a senha contiver caracteres especiais como `$`, `!`, `\` ou aspas, utilize o modo interativo (onde a senha é lida via `read -s`) em vez de passá-la pela flag `-p "..."` no terminal, para evitar interpolação do Bash.

---

### 3. Incompatibilidade entre Chave e Certificado (`key values mismatch`)

* **Sintoma:** Ao iniciar o Nginx (`nginx -t`), ocorre o erro:
  ```text
  nginx: [emerg] SSL_CTX_use_PrivateKey_file(".../privkey.key") failed (SSL: error:0B080074:x509 certificate routines:X509_check_private_key:key values mismatch)
  ```
* **Causa:** O certificado (`cert.crt`/`fullchain.crt`) e a chave privada (`privkey.key`) não pertencem ao mesmo par de chaves.
* **Solução:**
  - O script `extract-pfx.sh` faz essa verificação automaticamente antes de finalizar. Se ele der sucesso, esse erro **não ocorrerá**.
  - Para verificar manualmente se o par confere, compare o hash da chave pública:
    ```bash
    openssl x509 -in cert.crt -noout -pubkey | openssl sha256
    openssl pkey -in privkey.key -pubout | openssl sha256
    ```
    Os dois hashes SHA256 **precisam ser exatamente iguais**.

---

### 4. Cadeia intermediária incompleta (Navegador acusa certificado não confiável)

* **Sintoma:** O site funciona no Google Chrome no desktop, mas em celulares (Android/iOS) ou ferramentas como `curl`/APIs externas ocorre o erro:
  ```text
  curl: (60) SSL certificate problem: unable to get local issuer certificate
  ```
  Ou alertas de segurança informando que o emissor é desconhecido.
* **Causa:** Você apontou `ssl_certificate` para o arquivo `cert.crt` (apenas o certificado de ponta) em vez do `fullchain.crt`. O navegador cliente não possui o certificado intermediário no cache local e não consegue validar a cadeia até a Autoridade Raiz.
* **Solução:**
  - No arquivo de configuração do Nginx, sempre aponte:
    ```nginx
    ssl_certificate /etc/nginx/ssl/meudominio/fullchain.crt;
    ```
  - **Atenção à ordem no arquivo:** O certificado do domínio deve vir primeiro, e os certificados das intermediárias devem vir abaixo dele. O script já organiza nessa ordem exata.

---

### 5. Permissão negada no Nginx (`Permission denied`)

* **Sintoma:** O Nginx falha ao carregar a chave privada com:
  ```text
  nginx: [emerg] cannot load certificate key ".../privkey.key": BIO_new_file() failed (SSL: error:0200100D:system library:fopen:Permission denied)
  ```
* **Causa:** O usuário com o qual o processo worker do Nginx roda (geralmente `www-data` ou `nginx`) ou o processo mestre (root) não tem permissão de leitura no arquivo ou na pasta onde ele reside.
* **Solução:**
  - Garanta que o usuário `root` ou o grupo do Nginx possa ler o arquivo:
    ```bash
    sudo chown root:www-data /etc/nginx/ssl/meudominio/privkey.key
    sudo chmod 640 /etc/nginx/ssl/meudominio/privkey.key
    ```
  - Verifique também se as pastas pai têm permissão de execução/travessia (`chmod +x`).

---

### 6. Nginx pedindo senha ao iniciar ou recarregar

* **Sintoma:** Ao rodar `sudo systemctl start nginx` ou `nginx -t`, o terminal fica preso exibindo:
  ```text
  Enter PEM pass phrase:
  ```
* **Causa:** A chave privada foi exportada com criptografia (com passphrase).
* **Solução:**
  - O script já extrai a chave com a flag `-nodes` (no-DES), gerando a chave descriptografada propositalmente para o Nginx.
  - Se você tiver uma chave criptografada antiga e quiser remover a senha:
    ```bash
    openssl rsa -in chave_com_senha.key -out chave_sem_senha.key
    ```

---

### 7. Certificado expirado ou fora do período de validade

* **Sintoma:** O navegador exibe `NET::ERR_CERT_DATE_INVALID`.
* **Causa:** O certificado ainda não iniciou sua validade ou já passou da data de término (*Not After*).
* **Solução:**
  - Verifique as datas exatas no arquivo `cert-info.txt` gerado pelo script ou execute:
    ```bash
    openssl x509 -in cert.crt -noout -dates
    ```
  - Se estiver expirado, solicite uma nova emissão/renovação do certificado à sua Autoridade Certificadora.

---

## 🔍 Comandos Úteis de Verificação Manual

Aqui estão comandos rápidos para consultar ou depurar seus certificados:

```bash
# 1. Ver informações gerais do certificado (Subject, Issuer, Validade):
openssl x509 -in cert.crt -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:"

# 2. Verificar se o certificado expirou:
openssl x509 -in cert.crt -noout -checkend 0

# 3. Testar a integridade da chave privada:
openssl rsa -in privkey.key -check

# 4. Inspecionar o arquivo PFX original sem extrair:
openssl pkcs12 -info -in certificado.pfx -noout

# 5. Testar a conexão SSL remota do Nginx após publicado:
openssl s_client -connect seudominio.com.br:443 -servername seudominio.com.br
```

---

*Desenvolvido com foco em automação, confiabilidade e segurança para ambientes DevOps.*
