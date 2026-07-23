# Criação de usuário de discovery para auditoria AWS

⏱️ Tempo de execução: ~10 minutos

## Propósito

> Esse procedimento foi concebido exclusivamente para conceder acesso para o levantamento de ativos e configurações realizado por DevOps Vanilla. Ele poderá ser aproveitado para outras finalidades, porém tenha o cuidado de atualizar as informações de contato, acessos e identificadores para a sua necessidade

Este procedimento cria um usuário IAM chamado `devopsvanilla` com foco em:

- auditar configurações e provisionamento dos recursos da conta AWS;
- inventariar serviços, topologia, proteções e configurações de segurança;
- visualizar custos, faturamento e dados consolidados de billing;
- acessar a conta pela interface web do console AWS e também pela AWS CLI.

O perfil foi elaborado para **observabilidade administrativa** e **inventário**, sem permitir operação, alterações administrativas de IAM nem acesso ao conteúdo armazenado pelos workloads do cliente.

## Permissões concedidas

O manifesto cria um usuário com:

- Policy gerenciada AWS `ReadOnlyAccess` para leitura ampla de configurações e inventário;
- Policy gerenciada AWS `AWSBillingReadOnlyAccess` para acesso somente leitura ao console de Billing and Cost Management, acompanhando automaticamente as atualizações de permissões da AWS;
- Permissões complementares de leitura para:
  - **AWS Organizations**;
  - **IAM e segurança** (`IAM`, `Access Analyzer`, `CloudTrail`, `AWS Config`, `GuardDuty`, `Security Hub`, `Inspector`, `KMS` em modo descritivo);
  - **catálogo de preços** (`Pricing`);
- Acesso ao **AWS Management Console** via senha inicial definida no deploy;
- Possibilidade de acesso programático via **AWS CLI** após criação manual de `AccessKeyId` e `SecretAccessKey` para o usuário.

### Restrições aplicadas

Também são aplicados bloqueios explícitos para reduzir risco de exposição de dados:

- Não poderá criar, alterar ou remover usuários, policies, roles ou credenciais IAM;
- Não poderá criar/remover access key, alterar login profile ou administrar MFA por conta própria;
- Não poderá abrir sessão remota em instâncias por `SSM Session Manager` ou `EC2 Instance Connect`;
- Não poderá ler segredos do `Secrets Manager` ou valores do `Parameter Store`;
- Não poderá consultar dados de bancos via `RDS Data API`, `Redshift Data API`, `DynamoDB`, `Athena` ou serviços similares;
- Não poderá ler objetos de `S3`, listar chaves de objetos em buckets nem acessar blocos de snapshots EBS;
- Não poderá invocar funções `Lambda`, modelos `Bedrock` ou endpoints de inferência do `SageMaker`;
- Não poderá ler eventos de log detalhados do `CloudWatch Logs`.

## Como executar

### 1. Pre-requisitos

Antes de iniciar, o executor deste procedimento deve ter acesso a uma conta na AWS com permissão para:

- Criar usuários no IAM
- Permissões para acessar o **CloudFormation** no console da AWS.

> **Importante sobre Billing:** a AWS exige um passo adicional feito com o **usuário root da conta** para liberar o acesso de usuários IAM ao console de faturamento. Esse ajuste não é automatizável por este manifesto CloudFormation.

### 2. Faça o download do manifesto CloudFormation para o seu computador

- Faça o download do [manifesto CloudFormation](https://raw.githubusercontent.com/devopsvanilla/.BatOps/refs/heads/main/clouds/aws/create-discovery-user/devopsvanilla-create-discovery-user.yaml) no seu computador em arquivo nomeado como **devopsvanilla-create-discovery-user.yaml**

### 3. Implantação pelo Console AWS

1. Abra o console AWS com uma conta administrativa.
2. Pesquise por **CloudFormation**.
3. Clique em **Criar pilha**
4. Escolha **Escolher um modelo existente**, **Fazer upload de um arquivo de modelo** e clique em **Escolher arquivo**. Aponte para o arquivo **devopsvanilla-create-discovery-user.yaml** no local em que salvou no seu disco
5. Clique no botão **Próximo**
6. Envie o arquivo `devopsvanilla-create-discovery-user.yaml` salvo no seu computador.
7. Clique em **Next**.
8. Em **Nome da pilha**, informe `devopsvanilla-discovery-user` (recomendado).
9. Preencha os parâmetros:
   - `UserName`: mantenha `devopsvanilla`;
   - `UserEmail`: mantenha `devopsvanilla@outlook.com` ou ajuste se necessário;
   - `ConsolePassword`: defina uma senha inicial forte.
10. Clique em **Próximo**.
11. Em **Capacidades**, marque a opção: **Entendo que o AWS CloudFormation pode criar recursos do IAM com nomes personalizados**.
12. Clique em **Próximo** novamente.
13. Revise as informações.
14. Clique em **Enviar**.
15. Acesse a aba **Recursos** e aguarde o status `CREATE_COMPLETE`de todos os itens exibidos na lista. A página será atualizada automaticamente, mas se tiver a impressão que está demorando muito, force a atualização da página pelo navegador.
16. Acesse a aba **Saídas** e e copie para um Bloco de Notas o conteúdo da tabela.

### 4. Crie manualmente a access key para uso na AWS CLI

Como medida de segurança, este manifesto **não cria** `AccessKeyId` nem `SecretAccessKey` no CloudFormation.

1. Abra o serviço **IAM** no console AWS com uma conta administrativa.
2. Acesse **Usuários do IAM**.
3. Clique no usuário criado pela stack, `devopsvanilla`.
4. Abra a aba **Credenciais de Segurança**.
5. Na seção **Chaves de acesso**, clique em **Criar chave de acesso**.
6. Escolha o caso de uso **Command Line Interface (CLI)**.
7. No fim da página, marque a opção **Compreendo a recomendação acima e quero prosseguir para criar uma chave de acesso**.
8. Clique no botão **Próximo**.
9. Clique no botão **Criar chave de acesso**.
10. Copie e armazene em um Bloco de notas imediatamente:
    - `Chave de acesso`
    - `Chave de acesso secreta`
11. Clique no botão Baixar arquivo .csv e selecione uma área no seu computador para salvá-lo

> A `Chave de acesso secreta` é exibida apenas no momento da criação. Depois disso, ela não poderá ser consultada novamente.

### 5. Habilite o acesso de usuários IAM ao Billing (obrigatório para o console de faturamento)

Sem esta etapa, o usuário criado verá a mensagem de falta de permissão no console de faturamento, mesmo com as policies corretas.

1. Entre na Console da AWS com o **usuário root** da conta caso a sua conta não seja (solicite ao seu intermediário de suporte técnico se for o caso).
2. Acesse a opção **Account**.
3. Role a página até a seção **Acesso do perfil e usuário do IAM a informações de faturamento**.
4. Clique em **Editar**.
5. Marque **Ativar acesso ao IAM**.
6. Clique em **Atualizar**.

> Depois disso, o usuário `devopsvanilla` passa a poder abrir as páginas de Billing and Cost Management compatíveis com a policy `AWSBillingReadOnlyAccess`.

### 6. Como verificar a implantação

Depois da criação, valide os pontos abaixo.

### Verificação funcional no console

Com as credenciais do novo usuário:

1. Acesse a URL do output `ConsoleLoginUrl`.
2. Entre com o usuário definido no parâmetro `UserName` (padrão: `devopsvanilla`) e a senha inicial.
3. Confirme que o usuário consegue:
   - abrir `EC2`, `VPC`, `RDS`, `S3`, `Lambda`, `CloudTrail`, `Config`, `GuardDuty`, `Security Hub`, `Organizations` e `Billing`;
   - listar recursos e visualizar configurações.
   - abrir a página inicial de `Billing and Cost Management` sem a mensagem `You need a new IAM permission to view the full list of recommended actions`.
4. Confirme também que o usuário **não** consegue:
   - baixar objetos de um bucket S3;
   - abrir sessão via `Session Manager`;
   - visualizar um segredo do `Secrets Manager`;
   - criar nova access key ou alterar login profile/MFA sem autorização.

## Envie o e-mail com os dados de acesso

* Salve o conteúdo das informações copiadas para o Bloco de Notas nos passos anteriores em um arquivo chamado acessos.txt no mesmo local em que salvou o arquivo da Chave de Acesso.
* Compacte o diretório com senha e envie-o para [sandro@devopsvanilla.com.br](mailto:sandro@devopsvanilla.com.br)
* A senha para descompactar o arquivo deverá ser enviada por WhatsApp para 11 98895-4887

## Problemas ou dúvidas?

Contatos:

- [sandro@devopsvanilla.com.br](sandro@devopsvanilla.com.br)
- WhatsApp (11) 98895-4887
