# Criação de usuário de discovery para auditoria AWS

⏱️ Tempo de leitura: ~8 minutos

## Propósito

Este material cria um usuário IAM chamado `devopsvanilla` com foco em:

- auditar configurações e provisionamento dos recursos da conta AWS;
- inventariar serviços, topologia, proteções e configurações de segurança;
- visualizar custos, faturamento e dados consolidados de billing;
- acessar a conta pela interface web do console AWS e também pela AWS CLI.

O perfil foi desenhado para **observabilidade administrativa** e **inventário**, sem permitir operação, alterações administrativas de IAM nem acesso ao conteúdo armazenado pelos workloads do cliente.

## Permissões concedidas

O manifesto entrega um usuário com:

- policy gerenciada AWS `ReadOnlyAccess` para leitura ampla de configurações e inventário;
- permissões complementares de leitura para:
  - **AWS Organizations**;
  - **IAM e segurança** (`IAM`, `Access Analyzer`, `CloudTrail`, `AWS Config`, `GuardDuty`, `Security Hub`, `Inspector`, `KMS` em modo descritivo);
  - **Billing e custos** (`Billing`, `Cost Explorer`, `Budgets`, `CUR`, `Pricing`, `Invoicing`, `Payments`, `Tax`, `Free Tier`);
- acesso ao **AWS Management Console** via senha inicial definida no deploy;
- acesso programático via **AWS CLI** com `AccessKeyId` e `SecretAccessKey`.

### Restrições aplicadas

Também são aplicados bloqueios explícitos para reduzir risco de exposição de dados:

- não pode criar, alterar ou remover usuários, policies, roles ou credenciais IAM;
- não pode criar/remover access key, alterar login profile ou administrar MFA por conta própria;
- não pode abrir sessão remota em instâncias por `SSM Session Manager` ou `EC2 Instance Connect`;
- não pode ler segredos do `Secrets Manager` ou valores do `Parameter Store`;
- não pode consultar dados de bancos via `RDS Data API`, `Redshift Data API`, `DynamoDB`, `Athena` ou serviços similares;
- não pode ler objetos de `S3`, listar chaves de objetos em buckets nem acessar blocos de snapshots EBS;
- não pode invocar funções `Lambda`, modelos `Bedrock` ou endpoints de inferência do `SageMaker`;
- não pode ler eventos de log detalhados do `CloudWatch Logs`.

## Como executar

> 📂 **Estrutura do Projeto**: esta solução está em `clouds/aws/create-discovery-user/`. Execute os passos a partir desse diretório para evitar confusão.

### 1. Pre-requisitos

Antes de iniciar, o analista deve ter:

- acesso a uma conta AWS com permissão para criar usuário IAM, login profile, access key e managed policies ou `AWS CLI` instalada e autenticada com uma identidade administrativa;
- permissão para abrir o **CloudFormation** no console ou usar a CLI;
- confirmação de que o recurso **IAM access to Billing** está habilitado na conta, caso o usuário precise ver faturamento no console.

### 2. Faça o download do manifesto CloudFormation para o seu computador

- Faça o download do [manifesto CloudFormation](https://raw.githubusercontent.com/devopsvanilla/.BatOps/refs/heads/main/clouds/setup-gcloud.sh) no seu computador em arquivo nomeado como *devopsvanilla-create-discovery-user.yaml*

### 3. Escolher a forma de implantação

Você pode implantar de duas maneiras:

- **Console AWS**: melhor para quem está começando;
- **AWS CLI**: melhor para automação e repetibilidade.

### 4. Implantação pelo Console AWS

1. Abra o console AWS com uma conta administrativa.
2. Pesquise por **CloudFormation**.
3. Clique em **Create stack** > **With new resources (standard)**.
4. Em **Specify template**, escolha **Upload a template file**.
5. Envie o arquivo `devopsvanilla-create-discovery-user.yaml` salvo no seu computador.
6. Clique em **Next**.
7. Em **Stack name**, informe `devopsvanilla-discovery-user` (recomendado).
8. Preencha os parâmetros:
   - `UserName`: mantenha `devopsvanilla`;
   - `UserEmail`: mantenha `devopsvanilla@outlook.com` ou ajuste se necessário;
   - `ConsolePassword`: defina uma senha inicial forte;
   - `RequirePasswordReset`: recomenda-se `true`;
   - `CreateProgrammaticAccess`: recomenda-se `true`.
9. Clique em **Next**.
10. Em **Configure stack options**, pode seguir com os padrões.
11. Clique em **Next** novamente.
12. Revise as informações.
13. Marque a confirmação de que o CloudFormation criará recursos IAM.
14. Clique em **Submit**.
15. Aguarde o status `CREATE_COMPLETE`.

### 5. Implantação pela AWS CLI

Execute o deploy com uma identidade administrativa já autenticada:

```bash
aws cloudformation deploy \
  --stack-name devopsvanilla-discovery-user \
  --template-file devopsvanilla-create-discovery-user.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    RecommendedStackName=devopsvanilla-discovery-user \
    UserName=devopsvanilla \
    UserEmail=devopsvanilla@outlook.com \
    ConsolePassword='Troque-Essa-Senha-Agora-123!' \
    RequirePasswordReset=true \
    CreateProgrammaticAccess=true
```

### 6. Capturar as saídas da stack

Se o deploy foi feito por CLI, obtenha os outputs assim:

```bash
aws cloudformation describe-stacks \
  --stack-name devopsvanilla-discovery-user \
  --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
  --output table
```

### 7. Padrões recomendados e comunicação de exceções

Para padronização operacional, recomenda-se manter estes valores:

- nome da stack: `devopsvanilla-discovery-user`;
- `RecommendedStackName=devopsvanilla-discovery-user`;
- `UserName=devopsvanilla`;
- `UserEmail=devopsvanilla@outlook.com`;
- `RequirePasswordReset=true`;
- `CreateProgrammaticAccess=true`.

Se qualquer um desses valores for alterado, a mudança deve ser comunicada formalmente ao time responsável pela auditoria (incluindo valor antigo, valor novo, justificativa e data da alteração).

## Senha inicial: como funciona

A senha inicial **sempre** é definida por quem executa o deploy (campo `ConsolePassword`).

Se `RequirePasswordReset=true` (recomendado), o usuário será obrigado a trocar a senha no primeiro login.

### Como o usuário troca a senha no primeiro acesso (console AWS)

1. Acesse a URL de login do console (`ConsoleLoginUrl`).
2. Informe o usuário criado (padrão: `devopsvanilla`).
3. Digite a senha inicial fornecida pelo analista.
4. O console exibirá a tela obrigatória de troca de senha.
5. Informe a senha antiga (inicial) e a nova senha.
6. Conclua a alteração e faça login novamente.
7. Com a nova senha, execute os testes de acesso antes da liberação final da conta.

> ✅ Isso permite testar os acessos normalmente antes de entregar a conta, sem precisar redefinir a senha por fora do fluxo do console.

## Como verificar a implantação

Depois da criação, valide os pontos abaixo.

### Verificação no CloudFormation

- a stack deve estar com status `CREATE_COMPLETE`;
- não deve haver eventos de erro ou rollback;
- os outputs devem exibir pelo menos:
  - `UserName`;
  - `UserArn`;
  - `ConsoleLoginUrl`;
  - `AccessKeyId` e `SecretAccessKey` (se `CreateProgrammaticAccess=true`).

### Verificação no IAM

No console AWS:

1. Abra **IAM**.
2. Acesse **Users**.
3. Confirme que o usuário definido no parâmetro `UserName` existe (padrão: `devopsvanilla`).
4. Abra o usuário e valide:
   - existe acesso ao console;
   - existe ao menos uma access key ativa, se solicitado;
   - a policy AWS `ReadOnlyAccess` está anexada;
   - existem as policies gerenciadas criadas pela stack para complemento de leitura e deny explícito.

### Verificação funcional no console

Com as credenciais do novo usuário:

1. Acesse a URL do output `ConsoleLoginUrl`.
2. Entre com o usuário definido no parâmetro `UserName` (padrão: `devopsvanilla`) e a senha inicial.
3. Confirme que o usuário consegue:
   - abrir `EC2`, `VPC`, `RDS`, `S3`, `Lambda`, `CloudTrail`, `Config`, `GuardDuty`, `Security Hub`, `Organizations` e `Billing`;
   - listar recursos e visualizar configurações.
4. Confirme também que o usuário **não** consegue:
   - baixar objetos de um bucket S3;
   - abrir sessão via `Session Manager`;
   - visualizar um segredo do `Secrets Manager`;
   - criar nova access key ou alterar login profile/MFA sem autorização.

### Verificação funcional na AWS CLI

Configure a CLI com a access key entregue e valide:

```bash
aws sts get-caller-identity
aws ec2 describe-regions
aws organizations describe-organization
aws ce get-cost-and-usage \
  --time-period Start=2026-07-01,End=2026-07-31 \
  --granularity MONTHLY \
  --metrics UnblendedCost
```

Depois, teste um acesso que deve falhar, por exemplo:

```bash
aws s3 cp s3://NOME-DO-BUCKET/algum-arquivo.txt -
```

O comportamento esperado é receber erro de `AccessDenied`.

## Dados a serem fornecidos após a execução

Ao final da implantação, o analista deve entregar **somente por canal seguro** os seguintes dados:

- `Account ID` da conta AWS onde o usuário foi criado;
- `UserName` efetivo (padrão: `devopsvanilla`);
- URL de login do console (`ConsoleLoginUrl`);
- senha inicial definida no deploy;
- `AccessKeyId`;
- `SecretAccessKey` (lembrando que ela aparece apenas na criação da stack);
- confirmação se `RequirePasswordReset` foi configurado como `true` ou `false`;
- confirmação se a visualização de billing para usuários IAM está habilitada na conta;
- nome da stack criada no CloudFormation;
- confirmação se os valores padrão foram mantidos; caso não, listar todas as alterações aplicadas;
- data e hora da implantação.

> 🔐 **Boas práticas**:
>
> - nunca envie credenciais por e-mail sem criptografia;
> - prefira cofre de senhas, canal corporativo seguro ou compartilhamento temporário controlado;
> - após a entrega, registre internamente quem recebeu as credenciais e quando.
