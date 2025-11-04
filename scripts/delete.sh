#!/bin/bash

# Script para eliminar el stack de CloudFormation y esperar hasta su eliminación completa
# Adaptado al proyecto actual con valores por defecto de "santiago"

set -e

STACK_NAME="${STACK_NAME:-santiago-stack}"
REGION="${REGION:-us-east-1}"
PROFILE="${PROFILE:-admin}"

echo "=========================================="
echo "Eliminación del Stack de CloudFormation"
echo "=========================================="
echo "Stack Name: $STACK_NAME"
echo "Region: $REGION"
echo "Profile: $PROFILE"
echo "=========================================="
echo ""

# Verificar si el stack existe
echo "Verificando si el stack $STACK_NAME existe..."
if ! aws cloudformation describe-stacks --stack-name $STACK_NAME --region $REGION --profile $PROFILE &>/dev/null; then
  echo "El stack $STACK_NAME no existe. Nada que eliminar."
  exit 0
fi

# Mostrar información del stack antes de eliminar
echo "Información del stack:"
aws cloudformation describe-stacks \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --query 'Stacks[0].[StackName,StackStatus,CreationTime]' \
  --output table \
  --no-cli-pager

echo ""
read -p "¿Estás seguro de que quieres eliminar el stack '$STACK_NAME'? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Eliminación cancelada."
  exit 0
fi

echo ""
echo "Solicitando eliminación del stack $STACK_NAME..."

aws cloudformation delete-stack \
  --stack-name $STACK_NAME \
  --region $REGION \
  --profile $PROFILE \
  --no-cli-pager

echo "✓ Solicitud de eliminación enviada."
echo ""
echo "Esperando a que el stack $STACK_NAME sea eliminado..."
echo "(Esto puede tomar varios minutos. Presiona Ctrl+C para cancelar y monitorear manualmente)"
echo ""

# Esperar hasta que el stack sea eliminado
while true; do
  STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --region $REGION \
    --profile $PROFILE \
    --query 'Stacks[0].StackStatus' \
    --output text 2>&1 || echo "DOES_NOT_EXIST")
  
  if [ "$STATUS" = "DOES_NOT_EXIST" ] || echo "$STATUS" | grep -q "does not exist"; then
    echo ""
    echo "✓ Stack $STACK_NAME eliminado correctamente."
    break
  elif [ "$STATUS" = "DELETE_IN_PROGRESS" ]; then
    echo "  Estado: DELETE_IN_PROGRESS - Eliminando recursos..."
    sleep 10
  elif [ "$STATUS" = "DELETE_FAILED" ]; then
    echo ""
    echo "✗ Error: La eliminación del stack falló."
    echo "Estado: $STATUS"
    echo ""
    echo "Para ver más detalles:"
    echo "  aws cloudformation describe-stack-events --stack-name $STACK_NAME --region $REGION --profile $PROFILE"
    exit 1
  else
    echo "  Estado: $STATUS"
    sleep 5
  fi
done

echo ""
echo "Eliminación completada exitosamente."
