# Proyecto AWS CloudFormation - Infraestructura con ALB y Auto Scaling

Este proyecto despliega una infraestructura completa y altamente disponible en AWS utilizando CloudFormation. La infraestructura incluye:

- **Application Load Balancer (ALB)** para distribución de tráfico
- **Auto Scaling Group** para escalado automático
- **Launch Template** para configuración estandarizada de instancias
- **Instancias EC2** con servidor web Apache y PHP
- **Security Groups** configurados siguiendo mejores prácticas
- **Roles IAM** con permisos mínimos necesarios

---

## 📋 Tabla de Contenidos

- [Prerrequisitos](#prerrequisitos)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Configuración Inicial](#configuración-inicial)
- [Guía Paso a Paso](#guía-paso-a-paso)
- [Scripts Disponibles](#scripts-disponibles)
- [Variables de Entorno](#variables-de-entorno)
- [Ejemplos de Uso](#ejemplos-de-uso)
- [Troubleshooting](#troubleshooting)
- [Documentación Adicional](#documentación-adicional)

---

## 🔧 Prerrequisitos

Antes de comenzar, asegúrate de tener instalado y configurado lo siguiente:

### 1. AWS CLI

Instala AWS CLI v2 siguiendo las [instrucciones oficiales](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html).

Verifica la instalación:
```bash
aws --version
```

### 2. Configurar Credenciales AWS

Configura tus credenciales de AWS usando uno de estos métodos:

**Opción A: Usando `aws configure`**
```bash
aws configure
# Ingresa tu Access Key ID, Secret Access Key, región por defecto y formato de salida
```

**Opción B: Usando perfiles**
```bash
aws configure --profile mi-perfil
```

### 3. Python 3

El script `create_ssm_params.py` requiere Python 3.

Verifica la instalación:
```bash
python3 --version
```

### 4. Permisos IAM Requeridos

Asegúrate de tener permisos suficientes para:
- Crear/actualizar/eliminar stacks de CloudFormation
- Crear recursos EC2 (instancias, Security Groups, Launch Templates, Auto Scaling Groups)
- Crear Application Load Balancers
- Crear roles y políticas IAM
- Crear y leer parámetros en SSM Parameter Store

### 5. Recursos AWS Existentes

La plantilla requiere los siguientes recursos que deben existir previamente:
- **VPC**: ID de la VPC donde se desplegará la infraestructura
- **Subnets**: Al menos 2 subredes públicas en diferentes Availability Zones
- **Security Group**: Un Security Group por defecto (opcional, se puede crear uno nuevo)

---

## 📁 Estructura del Proyecto

```
aws-arquitecture/
│
├── infra.yml                      # Plantilla CloudFormation principal
├── README.md                      # Este archivo
├── info.md                        # Documentación detallada de la infraestructura
│
└── scripts/
    ├── deploy.sh                  # Script para crear/actualizar el stack
    ├── delete.sh                  # Script para eliminar el stack
    └── create_ssm_params.py       # Script para crear parámetros en SSM Parameter Store
```

---

## 🚀 Configuración Inicial

### Paso 1: Clonar o Descargar el Proyecto

```bash
# Si estás usando git
git clone <repository-url>
cd aws-arquitecture

# O simplemente descarga el proyecto y navega al directorio
cd aws-arquitecture
```

### Paso 2: Verificar Archivos

Asegúrate de que todos los archivos estén presentes:

```bash
ls -la infra.yml scripts/
```

### Paso 3: Hacer Ejecutables los Scripts

```bash
chmod +x scripts/deploy.sh scripts/delete.sh
```

---

## 📖 Guía Paso a Paso

### Opción A: Despliegue Rápido (Recomendado)

Esta opción usa valores por defecto y no requiere configuración previa de SSM Parameter Store.

#### Paso 1: Verificar Valores por Defecto

Revisa los valores por defecto en `infra.yml` y asegúrate de que sean correctos para tu cuenta de AWS. Los valores principales son:

- **VpcId**: `vpc-04550a0fafacf51cb`
- **Subnet1**: `subnet-015d5b709ea188f60`
- **Subnet2**: `subnet-0d15ae4702750cd95`
- **SecurityGroupId**: `sg-07b2016a9c30fe9ca`

> ⚠️ **Importante**: Asegúrate de actualizar estos valores con los IDs reales de tu cuenta AWS.

#### Paso 2: Configurar SubnetId (Requerido)

El parámetro `SubnetId` no tiene valor por defecto. Tienes dos opciones:

**Opción A: Usar una de las subredes existentes**
```bash
# El script usará Subnet1 como fallback automáticamente
./scripts/deploy.sh
```

**Opción B: Especificar SubnetId manualmente**
```bash
SUBNET_ID=subnet-015d5b709ea188f60 ./scripts/deploy.sh
```

#### Paso 3: Desplegar el Stack

```bash
./scripts/deploy.sh
```

El script:
1. Obtendrá parámetros de SSM Parameter Store (si existen)
2. Usará valores por defecto si no están en SSM
3. Mostrará la configuración que se usará
4. Creará o actualizará el stack automáticamente

#### Paso 4: Monitorear el Despliegue

```bash
# Monitorear en tiempo real
aws cloudformation describe-stacks \
  --stack-name santiago-stack \
  --region us-east-1 \
  --profile default

# O esperar hasta que termine
aws cloudformation wait stack-create-complete \
  --stack-name santiago-stack \
  --region us-east-1 \
  --profile default
```

#### Paso 5: Obtener Outputs del Stack

Una vez completado, obtén el DNS name del ALB:

```bash
aws cloudformation describe-stacks \
  --stack-name santiago-stack \
  --region us-east-1 \
  --profile default \
  --query 'Stacks[0].Outputs[?OutputKey==`AlbDNSName`].OutputValue' \
  --output text
```

Accede a la aplicación web usando ese DNS name:
```
http://<alb-dns-name>
```

---

### Opción B: Despliegue con SSM Parameter Store (Avanzado)

Esta opción permite centralizar la configuración usando AWS Systems Manager Parameter Store.

#### Paso 1: Crear Parámetros en SSM Parameter Store

```bash
python3 scripts/create_ssm_params.py \
  --template infra.yml \
  --prefix /santiago \
  --region us-east-1 \
  --profile default
```

Este script creará parámetros SSM para todos los valores por defecto en `infra.yml`.

#### Paso 2: Actualizar Parámetros Personalizados (Opcional)

Si necesitas cambiar algunos valores, actualízalos en SSM:

```bash
# Ejemplo: Actualizar VpcId
aws ssm put-parameter \
  --name /santiago/VpcId \
  --value vpc-tu-vpc-id \
  --type String \
  --overwrite \
  --region us-east-1 \
  --profile default

# Ejemplo: Actualizar SubnetId
aws ssm put-parameter \
  --name /santiago/SubnetId \
  --value subnet-tu-subnet-id \
  --type String \
  --overwrite \
  --region us-east-1 \
  --profile default
```

#### Paso 3: Desplegar el Stack

```bash
./scripts/deploy.sh
```

El script automáticamente usará los valores de SSM Parameter Store.

---

## 📜 Scripts Disponibles

### 1. `scripts/deploy.sh`

**Propósito**: Crear o actualizar el stack de CloudFormation.

**Uso básico**:
```bash
./scripts/deploy.sh
```

**Uso avanzado**:
```bash
STACK_NAME=mi-stack \
SSM_PREFIX=/mi-proyecto \
REGION=us-west-2 \
PROFILE=mi-perfil \
./scripts/deploy.sh
```

**Características**:
- ✅ Detecta automáticamente si el stack existe (crea o actualiza)
- ✅ Obtiene parámetros de SSM Parameter Store
- ✅ Usa valores por defecto si no están en SSM
- ✅ Muestra configuración antes de ejecutar
- ✅ Validaciones automáticas

---

### 2. `scripts/delete.sh`

**Propósito**: Eliminar el stack de CloudFormation y todos sus recursos.

**Uso básico**:
```bash
./scripts/delete.sh
```

**Uso avanzado**:
```bash
STACK_NAME=mi-stack \
REGION=us-west-2 \
PROFILE=mi-perfil \
./scripts/delete.sh
```

**Características**:
- ✅ Solicita confirmación antes de eliminar
- ✅ Muestra información del stack antes de eliminar
- ✅ Espera automáticamente hasta que la eliminación termine
- ✅ Maneja errores apropiadamente

---

### 3. `scripts/create_ssm_params.py`

**Propósito**: Crear parámetros en SSM Parameter Store basados en los valores por defecto de `infra.yml`.

**Uso básico**:
```bash
python3 scripts/create_ssm_params.py
```

**Uso avanzado**:
```bash
python3 scripts/create_ssm_params.py \
  --template infra.yml \
  --prefix /santiago \
  --region us-east-1 \
  --profile default
```

**Parámetros**:
- `--template`: Archivo de template (default: `infra.yml`)
- `--prefix`: Prefijo para parámetros SSM (default: `/santiago`)
- `--region`: Región de AWS (default: `us-east-1`)
- `--profile`: Perfil de AWS CLI (default: `default`)

**Características**:
- ✅ Crea parámetros solo para valores que tienen `Default` en el template
- ✅ Omite parámetros sin valor por defecto (como `SubnetId`)
- ✅ Permite sobrescribir parámetros existentes

---

## 🔐 Variables de Entorno

Puedes personalizar el comportamiento de los scripts usando variables de entorno:

### Variables para `deploy.sh`:

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `STACK_NAME` | Nombre del stack de CloudFormation | `santiago-stack` |
| `TEMPLATE_FILE` | Archivo de template | `infra.yml` |
| `REGION` | Región de AWS | `us-east-1` |
| `PROFILE` | Perfil de AWS CLI | `default` |
| `SSM_PREFIX` | Prefijo para SSM Parameter Store | `/santiago` |
| `SUBNET_ID` | SubnetId si no está en SSM | (usa Subnet1 como fallback) |

### Variables para `delete.sh`:

| Variable | Descripción | Valor por Defecto |
|----------|-------------|-------------------|
| `STACK_NAME` | Nombre del stack a eliminar | `santiago-stack` |
| `REGION` | Región de AWS | `us-east-1` |
| `PROFILE` | Perfil de AWS CLI | `default` |

### Ejemplo de Uso:

```bash
# Establecer variables temporalmente
export STACK_NAME=mi-proyecto-stack
export REGION=us-west-2
export PROFILE=produccion

# Ejecutar script
./scripts/deploy.sh

# O en una sola línea
STACK_NAME=mi-stack REGION=us-west-2 ./scripts/deploy.sh
```

---

## 💡 Ejemplos de Uso

### Ejemplo 1: Despliegue Inicial

```bash
# 1. Verificar configuración
cat infra.yml | grep -A 2 "Default:"

# 2. Asegurarse de que SubnetId esté configurado
export SUBNET_ID=subnet-015d5b709ea188f60

# 3. Desplegar
./scripts/deploy.sh

# 4. Monitorear
aws cloudformation describe-stacks \
  --stack-name santiago-stack \
  --query 'Stacks[0].StackStatus'
```

### Ejemplo 2: Actualizar Stack con Nuevos Parámetros

```bash
# 1. Actualizar parámetros en SSM
aws ssm put-parameter \
  --name /santiago/MaxSize \
  --value "3" \
  --type String \
  --overwrite

aws ssm put-parameter \
  --name /santiago/DesiredCapacity \
  --value "2" \
  --type String \
  --overwrite

# 2. Actualizar stack
./scripts/deploy.sh
```

### Ejemplo 3: Desplegar en Diferente Región

```bash
# Desplegar en us-west-2
STACK_NAME=mi-stack-west \
REGION=us-west-2 \
PROFILE=default \
./scripts/deploy.sh
```

### Ejemplo 4: Eliminar Stack

```bash
# Eliminar stack
./scripts/delete.sh

# O con confirmación automática (no recomendado en producción)
echo "yes" | ./scripts/delete.sh
```

### Ejemplo 5: Crear Parámetros SSM y Desplegar

```bash
# 1. Crear parámetros SSM
python3 scripts/create_ssm_params.py \
  --prefix /santiago \
  --region us-east-1

# 2. Actualizar algún parámetro personalizado
aws ssm put-parameter \
  --name /santiago/InstanceType \
  --value "t3.small" \
  --type String \
  --overwrite

# 3. Desplegar usando parámetros de SSM
./scripts/deploy.sh
```

---

## 🔍 Troubleshooting

### Problema: "SubnetId no está configurado"

**Solución**:
```bash
# Opción 1: Especificar como variable de entorno
SUBNET_ID=subnet-xxxxx ./scripts/deploy.sh

# Opción 2: Crear en SSM Parameter Store
aws ssm put-parameter \
  --name /santiago/SubnetId \
  --value subnet-xxxxx \
  --type String
```

### Problema: "Stack creation/update failed"

**Solución**:
```bash
# Ver eventos del stack para diagnosticar
aws cloudformation describe-stack-events \
  --stack-name santiago-stack \
  --region us-east-1 \
  --max-items 20 \
  --query 'StackEvents[*].[Timestamp,ResourceStatus,ResourceType,LogicalResourceId,ResourceStatusReason]' \
  --output table
```

### Problema: "Template validation error"

**Solución**:
```bash
# Validar template antes de desplegar
aws cloudformation validate-template \
  --template-body file://infra.yml \
  --region us-east-1
```

### Problema: "No se pueden crear recursos IAM"

**Solución**:
- Verifica que tengas permisos IAM suficientes
- Asegúrate de usar `--capabilities CAPABILITY_IAM` (ya incluido en el script)

### Problema: "VPC o Subnets no existen"

**Solución**:
- Verifica que los IDs de VPC y Subnets existan en tu cuenta AWS
- Actualiza los valores en `infra.yml` o en SSM Parameter Store

### Problema: "Stack en estado DELETE_FAILED"

**Solución**:
```bash
# Ver qué recursos no se pudieron eliminar
aws cloudformation describe-stack-events \
  --stack-name santiago-stack \
  --query 'StackEvents[?ResourceStatus==`DELETE_FAILED`]' \
  --output table

# Eliminar recursos manualmente si es necesario
# Luego eliminar el stack manualmente desde la consola AWS
```

---

## 📚 Documentación Adicional

Para información detallada sobre la infraestructura desplegada, consulta:

- **[info.md](info.md)**: Documentación completa sobre todos los componentes de la infraestructura, incluyendo:
  - Componentes desplegados
  - Recursos creados (IAM, EC2, ALB, Security Groups, etc.)
  - Arquitectura de seguridad
  - Flujo de tráfico
  - Configuración de alta disponibilidad

---

## 🎯 Flujo de Trabajo Recomendado

### Para Desarrollo/Testing:

```bash
# 1. Configurar SubnetId
export SUBNET_ID=subnet-tu-subnet-id

# 2. Desplegar
./scripts/deploy.sh

# 3. Probar la aplicación
# Obtener DNS del ALB y acceder en el navegador

# 4. Eliminar cuando termines
./scripts/delete.sh
```

### Para Producción:

```bash
# 1. Crear parámetros SSM
python3 scripts/create_ssm_params.py --prefix /produccion

# 2. Actualizar valores de producción en SSM
aws ssm put-parameter --name /produccion/MaxSize --value "5" --type String --overwrite
aws ssm put-parameter --name /produccion/DesiredCapacity --value "3" --type String --overwrite
# ... más parámetros según sea necesario

# 3. Desplegar con prefijo de producción
STACK_NAME=produccion-stack \
SSM_PREFIX=/produccion \
./scripts/deploy.sh

# 4. Monitorear y verificar
aws cloudformation describe-stacks --stack-name produccion-stack
```

---

## 📝 Notas Importantes

1. **Costo**: Este proyecto crea recursos que generan costos en AWS. Asegúrate de eliminar el stack cuando no lo necesites.

2. **Región**: Todos los recursos se crean en la región especificada. Asegúrate de usar la misma región para todos los comandos.

3. **SubnetId**: Este parámetro es requerido y no tiene valor por defecto. El script intentará usar `Subnet1` como fallback.

4. **Permisos IAM**: El stack crea roles IAM. Asegúrate de tener permisos para crear recursos IAM.

5. **Valores por Defecto**: Revisa y actualiza los valores por defecto en `infra.yml` antes del primer despliegue.

---

## 🤝 Contribuciones

Si encuentras algún problema o tienes sugerencias, por favor:

1. Revisa la documentación en `info.md`
2. Verifica los logs de CloudFormation
3. Consulta la sección de Troubleshooting

---

## 🔗 Referencias

- [Documentación AWS CloudFormation](https://docs.aws.amazon.com/cloudformation/)
- [Documentación AWS Systems Manager Parameter Store](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html)
- [Documentación AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/)
