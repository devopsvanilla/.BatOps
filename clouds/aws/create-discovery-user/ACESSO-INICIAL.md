# Acesso inicial da conta de discovery AWS

⏱️ Tempo de leitura: ~5 minutos

Este guia e para a pessoa que vai **receber** a conta `devopsvanilla` depois que ela for criada.

## Objetivo

Usar a conta de discovery para:

- acessar o console AWS;
- configurar a AWS CLI;
- validar que as permissoes de auditoria estao funcionando;
- entender rapidamente quais acessos foram bloqueados por seguranca.

## O que voce deve receber

Antes de comecar, solicite ao analista os itens abaixo:

- `Account ID` da conta AWS;
- URL de login do console AWS;
- usuario `devopsvanilla`;
- senha inicial;
- `AccessKeyId`;
- `SecretAccessKey`;
- confirmacao se sera obrigatorio trocar a senha no primeiro login.

## Passo a passo para acessar o console AWS

1. Abra a URL de login enviada pelo analista.
2. Informe o usuario `devopsvanilla`.
3. Digite a senha inicial.
4. Se o ambiente exigir troca de senha no primeiro acesso, siga a etapa apresentada na tela.
5. Apos entrar, valide rapidamente se os menus abaixo abrem sem erro:
   - `Billing and Cost Management`;
   - `Organizations`;
   - `IAM`;
   - `CloudTrail`;
   - `AWS Config`;
   - `GuardDuty`;
   - `Security Hub`;
   - `EC2`;
   - `RDS`;
   - `S3`.

## Passo a passo para configurar a AWS CLI

### Linux, macOS ou WSL

```bash
aws configure
```

Quando a CLI solicitar, informe:

- `AWS Access Key ID`: valor recebido do analista;
- `AWS Secret Access Key`: valor recebido do analista;
- `Default region name`: use a regiao principal da conta, por exemplo `us-east-1`;
- `Default output format`: recomenda-se `json`.

### Validar a identidade configurada

```bash
aws sts get-caller-identity
```

O comando deve retornar o ARN do usuario IAM `devopsvanilla`.

## Testes recomendados

### Testes que devem funcionar

```bash
aws ec2 describe-regions
aws iam get-account-summary
aws organizations describe-organization
aws ce get-cost-and-usage \
  --time-period Start=2026-07-01,End=2026-07-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost
```

### Testes que devem falhar

Os exemplos abaixo devem retornar `AccessDenied` ou erro equivalente:

```bash
aws secretsmanager get-secret-value --secret-id exemplo
aws ssm start-session --target i-1234567890abcdef0
aws s3 cp s3://bucket-exemplo/arquivo.txt -
```

## Limitações esperadas

Esta conta foi criada para auditoria e inventario. Portanto, e normal que voce **nao** consiga:

- baixar arquivos de buckets S3;
- ler segredos do Secrets Manager;
- abrir sessao em servidores;
- rodar consultas em bases de dados ou servicos analiticos;
- criar novas chaves, alterar login profile ou administrar MFA por conta propria;
- criar novos usuarios, roles ou policies IAM.

## O que fazer em caso de erro

Se algum acesso de leitura importante falhar:

1. capture o nome do servico e a acao executada;
2. registre a mensagem exata de erro;
3. informe se o problema ocorreu no console, na CLI ou em ambos;
4. envie o horario aproximado do teste e, se possivel, um print ou log curto.

Se um acesso a dados **funcionar** quando nao deveria, trate isso como ponto de seguranca e reporte imediatamente.
