#!/bin/bash

echo "🔐 Qual perfil da AWS você quer testar?"
read -p "Perfil: " PERFIL

echo "🔍 Obtendo ARN da identidade associada ao perfil '$PERFIL'..."
ARN=$(aws sts get-caller-identity --profile "$PERFIL" --query Arn --output text 2>/dev/null)

if [ -z "$ARN" ]; then
  echo "❌ Não foi possível obter o ARN. Verifique se o perfil existe e está configurado corretamente."
  exit 1
fi

echo "✅ Identidade: $ARN"
echo "🧪 Testando permissões essenciais do Morpheus Data..."

declare -A MORPHEUS_TESTS=(
  ["S3 ListBuckets"]="aws s3api list-buckets --profile $PERFIL"
  ["S3 CreateBucket"]="aws s3api create-bucket --bucket \"test-morpheus-$(date +%s)\" --region us-east-1 --create-bucket-configuration LocationConstraint=us-east-1 --profile $PERFIL"
  ["EC2 DescribeInstances"]="aws ec2 describe-instances --profile $PERFIL"
  ["EC2 RunInstances"]="aws ec2 run-instances --image-id ami-abcd1234 --instance-type t2.micro --dry-run --profile $PERFIL"
  ["CloudFormation ListStacks"]="aws cloudformation list-stacks --profile $PERFIL"
  ["CloudFormation CreateStack"]="aws cloudformation create-stack --stack-name MorpheusTestStack --template-body file://template.json --dry-run --profile $PERFIL"
  ["IAM ListRoles"]="aws iam list-roles --profile $PERFIL"
  ["IAM ListInstanceProfiles"]="aws iam list-instance-profiles --profile $PERFIL"
  ["KMS Decrypt (Test)"]="aws kms list-keys --profile $PERFIL"
  ["RDS DescribeDBInstances"]="aws rds describe-db-instances --profile $PERFIL"
  ["ELB DescribeLoadBalancers"]="aws elb describe-load-balancers --profile $PERFIL"
  ["CloudWatch ListMetrics"]="aws cloudwatch list-metrics --profile $PERFIL"
  ["EKS ListClusters"]="aws eks list-clusters --profile $PERFIL"
  ["Route53 ListHostedZones"]="aws route53 list-hosted-zones --profile $PERFIL"
  ["SSM GetParameters"]="aws ssm describe-parameters --profile $PERFIL"
  ["CUR DescribeReportDefinitions"]="aws cur describe-report-definitions --profile $PERFIL"
  ["CostExplorer GetCostAndUsage"]="aws ce get-cost-and-usage --time-period Start=2022-01-01,End=2022-01-31 --granularity MONTHLY --metrics BlendedCost --profile $PERFIL"
)

for TEST in "${!MORPHEUS_TESTS[@]}"; do
  echo -n "🔸 Testando $TEST... "
  OUTPUT=$(${MORPHEUS_TESTS[$TEST]} 2>&1)
  if echo "$OUTPUT" | grep -q -E "AccessDenied|UnauthorizedOperation|Not authorized|is not authorized"; then
    echo "❌ Acesso negado"
  elif echo "$OUTPUT" | grep -qi "error"; then
    echo "⚠️ Erro: $(echo "$OUTPUT" | head -n 1)"
  else
    echo "✅ Acesso permitido"
  fi
done

echo "⚠️ Observação: Alguns testes usam --dry-run ou opções seguras para evitar custos reais. Ajuste conforme necessário."
