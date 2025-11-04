#!/bin/bash

# Script para crear o actualizar el stack de CloudFormation de forma parametrizada
# Adaptado al proyecto actual con valores por defecto de "santiago"

set -e

STACK_NAME="${STACK_NAME:-santiago-stack}"
TEMPLATE_FILE="${TEMPLATE_FILE:-infra.yml}"
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-admin}"
SSM_PREFIX="${SSM_PREFIX:-/santiago}"

# Parámetros hardcoded (se usan si SSM no devuelve valor)
# Valores por defecto basados en infra.yml actual
VPC_ID="vpc-04550a0fafacf51cb"
SUBNET_ID=""  # Sin valor por defecto en infra.yml - debe proporcionarse
INSTANCE_TYPE="t3.micro"
INSTANCE_NAME="santiago"
SECURITY_GROUP_ID="sg-07b2016a9c30fe9ca"
LAUNCH_TEMPLATE_NAME="lt-santiago"
AUTOSCALING_GROUP_NAME="asg-santiago"
SUBNET1="subnet-015d5b709ea188f60"
SUBNET2="subnet-0d15ae4702750cd95"
TAG_NAME="Web Server - Santiago"
LATEST_AMI_ID="ami-01ff0413d08899e5f"
MIN_SIZE="1"
DESIRED_CAPACITY="1"
MAX_SIZE="1"

# Helper para obtener parámetro de SSM o usar valor por defecto
get_ssm_or_default() {
  local name="$1"
  local fallback="$2"
  local val
  
  val=$(aws ssm get-parameter --name "$SSM_PREFIX/$name" --region $REGION --profile $PROFILE --query 'Parameter.Value' --output text 2>/dev/null || true)
  
  if [ -z "$val" ] || [ "$val" = "None" ]; then
    echo "$fallback"
  else
    echo "$val"
  fi
}

# Obtener valores de SSM (con fallbacks)
echo "Obteniendo parámetros de SSM Parameter Store (prefijo: $SSM_PREFIX)..."

VPC_ID=$(get_ssm_or_default VpcId "$VPC_ID")
INSTANCE_TYPE=$(get_ssm_or_default InstanceType "$INSTANCE_TYPE")
INSTANCE_NAME=$(get_ssm_or_default InstanceName "$INSTANCE_NAME")
SECURITY_GROUP_ID=$(get_ssm_or_default SecurityGroupId "$SECURITY_GROUP_ID")
LAUNCH_TEMPLATE_NAME=$(get_ssm_or_default LaunchTemplateName "$LAUNCH_TEMPLATE_NAME")
AUTOSCALING_GROUP_NAME=$(get_ssm_or_default AutoScalingGroupName "$AUTOSCALING_GROUP_NAME")
SUBNET1=$(get_ssm_or_default Subnet1 "$SUBNET1")
SUBNET2=$(get_ssm_or_default Subnet2 "$SUBNET2")
TAG_NAME=$(get_ssm_or_default TagName "$TAG_NAME")
LATEST_AMI_ID=$(get_ssm_or_default LatestAmiId "$LATEST_AMI_ID")
MIN_SIZE=$(get_ssm_or_default MinSize "$MIN_SIZE")
DESIRED_CAPACITY=$(get_ssm_or_default DesiredCapacity "$DESIRED_CAPACITY")
MAX_SIZE=$(get_ssm_or_default MaxSize "$MAX_SIZE")

# SubnetId: intentar obtener de SSM, si no está, usar Subnet1 como fallback
if [ -z "$SUBNET_ID" ]; then
  SUBNET_ID=$(get_ssm_or_default SubnetId "$SUBNET1")
fi

# Validar que SubnetId esté configurado
if [ -z "$SUBNET_ID" ]; then
  echo "Error: SubnetId no está configurado. Por favor:"
  echo "  1. Configura el parámetro SSM: $SSM_PREFIX/SubnetId"
  echo "  2. O establece SUBNET_ID como variable de entorno"
  echo "  3. O proporciona SubnetId como parámetro al script"
  exit 1
fi

# Mostrar valores que se usarán
echo ""
echo "=========================================="
echo "Configuración del despliegue"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Template File: $TEMPLATE_FILE"
echo "SSM Prefix: $SSM_PREFIX"
echo "Region: $REGION"
echo "Profile: $PROFILE"
echo ""
echo "Parámetros que se usarán:"
echo "  VpcId: $VPC_ID"
echo "  SubnetId: $SUBNET_ID"
echo "  InstanceType: $INSTANCE_TYPE"
echo "  InstanceName: $INSTANCE_NAME"
echo "  SecurityGroupId: $SECURITY_GROUP_ID"
echo "  LaunchTemplateName: $LAUNCH_TEMPLATE_NAME"
echo "  AutoScalingGroupName: $AUTOSCALING_GROUP_NAME"
echo "  Subnet1: $SUBNET1"
echo "  Subnet2: $SUBNET2"
echo "  TagName: $TAG_NAME"
echo "  LatestAmiId: $LATEST_AMI_ID"
echo "  MinSize: $MIN_SIZE"
echo "  MaxSize: $MAX_SIZE"
echo "  DesiredCapacity: $DESIRED_CAPACITY"
echo "=========================================="
echo ""

# Construir la cadena de parámetros para CloudFormation
PARAMETERS=(
  "ParameterKey=VpcId,ParameterValue=$VPC_ID"
  "ParameterKey=SubnetId,ParameterValue=$SUBNET_ID"
  "ParameterKey=InstanceType,ParameterValue=$INSTANCE_TYPE"
  "ParameterKey=InstanceName,ParameterValue=$INSTANCE_NAME"
  "ParameterKey=SecurityGroupId,ParameterValue=$SECURITY_GROUP_ID"
  "ParameterKey=LaunchTemplateName,ParameterValue=$LAUNCH_TEMPLATE_NAME"
  "ParameterKey=AutoScalingGroupName,ParameterValue=$AUTOSCALING_GROUP_NAME"
  "ParameterKey=Subnet1,ParameterValue=$SUBNET1"
  "ParameterKey=Subnet2,ParameterValue=$SUBNET2"
  "ParameterKey=TagName,ParameterValue=$TAG_NAME"
  "ParameterKey=LatestAmiId,ParameterValue=$LATEST_AMI_ID"
  "ParameterKey=MinSize,ParameterValue=$MIN_SIZE"
  "ParameterKey=MaxSize,ParameterValue=$MAX_SIZE"
  "ParameterKey=DesiredCapacity,ParameterValue=$DESIRED_CAPACITY"
)

# Verificar si el archivo de template existe
if [ ! -f "$TEMPLATE_FILE" ]; then
  echo "Error: El archivo de template '$TEMPLATE_FILE' no existe."
  echo "Por favor, asegúrate de estar en el directorio correcto."
  exit 1
fi

# Verificar si el stack existe
echo "Verificando si el stack $STACK_NAME existe..."
if aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --profile $PROFILE &>/dev/null; then
  echo "✓ El stack existe. Actualizando..."
  
  aws cloudformation update-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --profile $PROFILE \
    --parameters "${PARAMETERS[@]}" \
    --no-cli-pager
  
  echo ""
  echo "✓ Solicitud de actualización enviada."
  echo "Puedes monitorear el progreso con:"
  echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --profile $PROFILE"
  echo ""
  echo "O esperar hasta que termine con:"
  echo "  aws cloudformation wait stack-update-complete --stack-name $STACK_NAME --region $REGION --profile $PROFILE"
else
  echo "✓ El stack no existe. Creando nuevo stack..."
  
  aws cloudformation create-stack \
    --stack-name $STACK_NAME \
    --template-body file://$TEMPLATE_FILE \
    --capabilities CAPABILITY_IAM \
    --region $REGION \
    --profile $PROFILE \
    --parameters "${PARAMETERS[@]}" \
    --no-cli-pager
  
  echo ""
  echo "✓ Solicitud de creación enviada."
  echo "Puedes monitorear el progreso con:"
  echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --profile $PROFILE"
  echo ""
  echo "O esperar hasta que termine con:"
  echo "  aws cloudformation wait stack-create-complete --stack-name $STACK_NAME --region $REGION --profile $PROFILE"
fi
