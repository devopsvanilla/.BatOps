# Instalação e configuração do Google Cloud SDK

Este guia mostra como usar o Google Cloud SDK após a instalação, com autenticação por conta de serviço.

## 1. Pré-requisitos

- Google Cloud SDK instalado
- `gcloud` disponível no `PATH`
- Arquivo de chave JSON da conta de serviço ou credenciais de usuário

## 2. Verificar instalação

```bash
gcloud version
```

Se estiver instalado, a versão do SDK será exibida.

## 3. Autenticação com conta de serviço

Se você tem um e-mail de conta de serviço e chave privada, salve o JSON da chave em um arquivo, por exemplo:

```bash
cat > /tmp/gcloud-sa.json <<'EOF'
{
  "type": "service_account",
  "project_id": "SEU_PROJECT_ID",
  "private_key_id": "XXXXXXXXXXXX",
  "private_key": "YOUR_PRIVATE_KEY_CONTENT_HERE",
  "client_email": "seu-email@seu-projeto.iam.gserviceaccount.com",
  "client_id": "12345678901234567890",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/seu-email%40seu-projeto.iam.gserviceaccount.com"
}
EOF
```

Ative a conta de serviço:

```bash
gcloud auth activate-service-account seu-email@seu-projeto.iam.gserviceaccount.com \
  --key-file=/tmp/gcloud-sa.json
```

## 4. Configurar o projeto padrão

```bash
gcloud config set project SEU_PROJECT_ID
```

Opcionalmente, defina região e zona padrão:

```bash
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a
```

## 5. Verificar autenticação e configurações

```bash
gcloud auth list
gcloud config list
gcloud projects list
```

## 6. Se for usuário normal (não conta de serviço)

Use:

```bash
gcloud auth login
```

Ou, em servidor sem navegador:

```bash
gcloud auth login --no-launch-browser
```

Se precisar de credenciais para bibliotecas Google em código:

```bash
gcloud auth application-default login
```

Ou, para conta de serviço:

```bash
gcloud auth application-default activate-service-account \
  --key-file=/tmp/gcloud-sa.json
```

## 7. Observações

- O `client_email` do JSON de conta de serviço deve ser o e-mail da conta de serviço.
- O `project_id` deve existir no Google Cloud.
- A conta precisa ter permissões IAM adequadas para a operação que você vai fazer.
