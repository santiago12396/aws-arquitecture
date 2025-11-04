# Documentación de Infraestructura AWS CloudFormation

## Descripción General

Esta plantilla CloudFormation despliega una infraestructura completa y altamente disponible en AWS que incluye:

- **Application Load Balancer (ALB)** para distribución de tráfico
- **Auto Scaling Group** para escalado automático de instancias EC2
- **Launch Template** para configuración estandarizada de instancias
- **Instancia EC2** con servidor web Apache y PHP
- **Security Groups** con reglas de seguridad configuradas
- **Roles IAM** con permisos mínimos necesarios

La infraestructura está diseñada para soportar aplicaciones web con alta disponibilidad y escalabilidad automática.

---

## Componentes Desplegados

### 1. Parámetros Configurables (14 parámetros)

La plantilla acepta 14 parámetros personalizables:

| Parámetro | Tipo | Valor por Defecto | Descripción |
|-----------|------|-------------------|-------------|
| `LatestAmiId` | String | `ami-0341d95f75f311023` | ID de la AMI más reciente de Amazon Linux 2023 |
| `VpcId` | String | `vpc-077036bfcbb11d434` | ID de la VPC donde se desplegará la infraestructura |
| `SubnetId` | String | *(sin defecto)* | ID de la subred pública para la instancia EC2 directa |
| `InstanceType` | String | `t3.micro` | Tipo de instancia EC2 |
| `InstanceName` | String | `santiago` | Nombre de la instancia EC2 |
| `SecurityGroupId` | String | `sg-08fd9307f7c135213` | ID del Security Group por defecto |
| `LaunchTemplateName` | String | `lt-santiago` | Nombre del Launch Template |
| `AutoScalingGroupName` | String | `asg-santiago` | Nombre del Auto Scaling Group |
| `MinSize` | String | `1` | Tamaño mínimo del Auto Scaling Group |
| `MaxSize` | String | `1` | Tamaño máximo del Auto Scaling Group |
| `DesiredCapacity` | String | `1` | Capacidad deseada del Auto Scaling Group |
| `Subnet1` | String | `subnet-0768550a08edf7c74` | Primera subred pública (para ALB y ASG) |
| `Subnet2` | String | `subnet-021f2eade5dd37c7c` | Segunda subred pública (para ALB y ASG) |
| `TagName` | String | `Web Server - Santiago` | Valor de la etiqueta Name para recursos EC2 |

---

## Recursos Creados

### 2. Recursos IAM

#### **Ec2InstanceRole**
- **Tipo**: `AWS::IAM::Role`
- **Propósito**: Rol IAM para instancias EC2
- **Permisos**:
  - `AmazonSSMManagedInstanceCore`: Permite administración remota de instancias mediante AWS Systems Manager Session Manager
- **Trust Policy**: Permite que el servicio `ec2.amazonaws.com` asuma el rol

#### **Ec2InstanceProfile**
- **Tipo**: `AWS::IAM::InstanceProfile`
- **Propósito**: Perfil de instancia que asocia el rol IAM con las instancias EC2
- **Rol asociado**: `Ec2InstanceRole`

**Beneficios**:
- Permite conectarse a instancias EC2 sin necesidad de claves SSH
- Acceso mediante AWS Systems Manager Session Manager
- Seguridad mejorada al no exponer puerto SSH públicamente

---

### 3. Instancia EC2 Directa

#### **Ec2Instance**
- **Tipo**: `AWS::EC2::Instance`
- **Configuración**:
  - Tipo de instancia: Configurable (por defecto `t3.micro`)
  - AMI: Amazon Linux 2023
  - IP pública: Habilitada
  - Subnet: Configurable mediante parámetro `SubnetId`
  - Security Group: Usa el Security Group por defecto especificado

**UserData (Script de inicialización)**:
El script realiza las siguientes tareas automáticamente:
1. Actualiza el sistema: `yum update -y`
2. Instala Apache y PHP: `yum install -y httpd php`
3. Habilita y inicia el servicio HTTP: `systemctl enable httpd && systemctl start httpd`
4. Obtiene metadatos de la instancia (IP pública, IP privada, Availability Zone) usando IMDSv2
5. Crea una página PHP (`/var/www/html/index.php`) que muestra:
   - IP Pública de la instancia
   - IP Privada de la instancia
   - Zona de disponibilidad (AZ)

**Nota**: Esta instancia se crea independientemente del Auto Scaling Group para propósitos de demostración o desarrollo.

---

### 4. Launch Template

#### **Ec2LaunchTemplate**
- **Tipo**: `AWS::EC2::LaunchTemplate`
- **Nombre**: Configurable (por defecto `lt-santiago`)
- **Configuración**:
  - **AMI**: Amazon Linux 2023 (configurable)
  - **Instance Type**: Configurable (por defecto `t3.micro`)
  - **IAM Instance Profile**: Asociado al `Ec2InstanceProfile`
  - **Security Groups**:
    - Security Group por defecto (`SecurityGroupId`)
    - `InstanceSecurityGroup` (creado en esta plantilla)

**UserData**:
Incluye el mismo script de inicialización que la instancia EC2 directa:
- Instalación de Apache y PHP
- Configuración automática del servidor web
- Creación de página PHP con información de la instancia

**TagSpecifications**:
- Etiqueta `Name` con valor configurable (`TagName`)

**Propósito**: El Launch Template proporciona una plantilla reutilizable para crear instancias EC2 de manera consistente a través del Auto Scaling Group.

---

### 5. Security Groups

#### ¿Por qué se crean DOS Security Groups?

Se crean **dos Security Groups separados** siguiendo el principio de **"Defensa en Profundidad"** y **separación de responsabilidades**. Cada uno tiene un propósito específico y diferentes niveles de exposición:

1. **Separación de responsabilidades**: El ALB y las instancias EC2 tienen necesidades de seguridad diferentes
2. **Seguridad en capas**: Si un Security Group es comprometido, el otro sigue protegiendo
3. **Mejor control**: Permite aplicar reglas de seguridad más granulares y específicas
4. **Best Practice AWS**: Es la arquitectura recomendada por AWS para este tipo de infraestructura

---

#### **AlbSecurityGroup** (Security Group para el Application Load Balancer)

```yaml
AlbSecurityGroup:
  SecurityGroupIngress:
    - Puerto 80 (HTTP): Acceso desde cualquier IP (0.0.0.0/0)
```

**¿Dónde se aplica?**:
- Asociado al recurso `WebALB` (Application Load Balancer)

**¿Qué hace?**:
- **Permite que el ALB reciba tráfico HTTP desde internet** en el puerto 80
- Es la **primera capa de seguridad** - el punto de entrada público

**Reglas de entrada**:
- ✅ **Puerto 80 (HTTP)**: Desde cualquier IP de internet (`0.0.0.0/0`)
- ❌ No permite tráfico directo a las instancias EC2

**Propósito**:
- El ALB necesita ser accesible desde internet para recibir las peticiones HTTP
- Actúa como el único punto público de entrada

---

#### **InstanceSecurityGroup** (Security Group para las instancias EC2)

```yaml
InstanceSecurityGroup:
  SecurityGroupIngress:
    - Puerto 80 (HTTP): Solo desde AlbSecurityGroup (SourceSecurityGroupId)
    - Puerto 22 (SSH): Desde cualquier IP (0.0.0.0/0) - ⚠️ en producción restringir
```

**¿Dónde se aplica?**:
- Asociado a las instancias EC2 creadas por el Auto Scaling Group (vía Launch Template)
- También se puede aplicar a la instancia EC2 directa si se desea

**¿Qué hace?**:
- **Protege las instancias EC2** que ejecutan la aplicación
- Solo permite tráfico HTTP **desde el ALB**, NO directamente desde internet
- Permite acceso SSH para administración (en producción debería restringirse)

**Reglas de entrada**:
- ✅ **Puerto 80 (HTTP)**: **SOLO desde el ALB** usando `SourceSecurityGroupId: !Ref AlbSecurityGroup`
  - Esto significa que las instancias NO son accesibles directamente desde internet
  - Solo pueden recibir tráfico HTTP que viene del ALB
- ✅ **Puerto 22 (SSH)**: Desde cualquier IP (`0.0.0.0/0`)
  - ⚠️ **Nota de seguridad**: En producción deberías restringir esto a IPs específicas o usar solo SSM Session Manager

**Propósito**:
- Es la **segunda capa de seguridad** - protege las instancias de la aplicación
- Las instancias NO están expuestas directamente a internet para tráfico HTTP
- Solo el ALB puede comunicarse con las instancias en el puerto 80

---

#### Arquitectura de Seguridad - Flujo de Tráfico

```
┌─────────────────────────────────────────────────────────┐
│                      INTERNET                            │
│                    (Cualquier IP)                        │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ ✅ HTTP (puerto 80)
                        │ Permitido desde 0.0.0.0/0
                        ↓
┌─────────────────────────────────────────────────────────┐
│              AlbSecurityGroup                            │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Application Load Balancer (ALB)                 │   │
│  │  - DNS público                                    │   │
│  │  - Único punto de entrada público                │   │
│  └───────────────────────┬──────────────────────────┘   │
└──────────────────────────┼──────────────────────────────┘
                           │
                           │ ✅ HTTP (puerto 80)
                           │ SOLO desde AlbSecurityGroup
                           │ (SourceSecurityGroupId)
                           ↓
┌─────────────────────────────────────────────────────────┐
│           InstanceSecurityGroup                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Instancias EC2                                  │   │
│  │  - Apache + PHP                                  │   │
│  │  - NO accesibles directamente desde internet     │   │
│  │  - Solo reciben tráfico del ALB                  │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘

❌ BLOQUEADO: Tráfico HTTP directo desde internet a instancias
✅ PERMITIDO: Tráfico HTTP desde internet → ALB → Instancias
```

---

#### ¿Por qué esta arquitectura es más segura?

**Ventajas de usar dos Security Groups separados:**

1. **Aislamiento de la aplicación**:
   - Las instancias EC2 **NO tienen IPs públicas directas** para tráfico web
   - Si alguien intenta atacar las instancias directamente desde internet, el tráfico es **bloqueado**
   - Solo el ALB puede comunicarse con las instancias

2. **Defensa en profundidad**:
   - Si el `AlbSecurityGroup` tiene un problema, las instancias siguen protegidas
   - Si el `InstanceSecurityGroup` tiene un problema, el ALB actúa como barrera

3. **Control granular**:
   - Puedes cambiar las reglas del ALB sin afectar las instancias
   - Puedes cambiar las reglas de las instancias sin afectar el ALB
   - Cada Security Group tiene reglas específicas para su componente

4. **Facilita auditoría y cumplimiento**:
   - Fácil identificar qué recursos están expuestos públicamente
   - Las instancias no aparecen como accesibles desde internet

5. **Mejores prácticas AWS**:
   - Sigue las recomendaciones de AWS Well-Architected Framework
   - Arquitectura estándar para aplicaciones web escalables

---

#### Comparación: Un Security Group vs Dos Security Groups

| Aspecto | Un Security Group (❌ No recomendado) | Dos Security Groups (✅ Recomendado) |
|---------|--------------------------------------|--------------------------------------|
| **Exposición de instancias** | Instancias directamente expuestas a internet | Instancias aisladas, solo accesibles vía ALB |
| **Seguridad** | Una sola capa de protección | Defensa en profundidad (múltiples capas) |
| **Control** | Reglas mezcladas, difícil de mantener | Reglas separadas y específicas |
| **Ataques directos** | Instancias vulnerables a ataques directos | Instancias protegidas, solo ALB expuesto |
| **Flexibilidad** | Cambios afectan todo | Cambios independientes por componente |
| **Best Practice AWS** | ❌ No recomendado | ✅ Recomendado |

---

#### Resumen

**AlbSecurityGroup**:
- 🔓 **Abierto al público**: Recibe tráfico HTTP desde internet
- 🎯 **Aplicado a**: Application Load Balancer
- 🔒 **Función**: Primera barrera, punto de entrada público

**InstanceSecurityGroup**:
- 🔒 **Aislado**: Solo recibe tráfico del ALB
- 🎯 **Aplicado a**: Instancias EC2
- 🛡️ **Función**: Segunda barrera, protege la aplicación de acceso directo

**Resultado**: Las instancias están protegidas y solo accesibles a través del ALB, siguiendo el principio de seguridad en capas (Defense in Depth).

---

### 6. Application Load Balancer (ALB)

---

## ¿Qué es un Application Load Balancer (ALB)?

El **Application Load Balancer (ALB)** es un servicio de AWS que distribuye el tráfico de aplicaciones entre múltiples instancias EC2, contenedores o direcciones IP en una o más zonas de disponibilidad. Funciona en la capa 7 (aplicación) del modelo OSI, lo que significa que puede tomar decisiones de enrutamiento basadas en el contenido de la solicitud HTTP/HTTPS.

**Características principales**:
- Balanceo de carga a nivel de aplicación
- Alta disponibilidad y escalabilidad automática
- Health checks automáticos
- Routing basado en contenido (paths, hosts, headers)
- Terminación SSL/TLS

---

## Componentes necesarios para crear un ALB

Para crear un ALB funcional se necesitan **3 componentes principales**:

### 1️⃣ **Load Balancer (ALB)** - El componente principal
### 2️⃣ **Target Group** - Grupo de destinos que reciben el tráfico
### 3️⃣ **Listener** - Escucha las conexiones y enruta el tráfico

---

### 1️⃣ Load Balancer (WebALB)

```yaml
WebALB:
  Type: AWS::ElasticLoadBalancingV2::LoadBalancer
  Properties:
    Name: !Sub "alb-${AWS::StackName}"
    Scheme: internet-facing          # Accesible desde internet
    Subnets:
      - !Ref Subnet1                 # Mínimo 2 subredes en diferentes AZs
      - !Ref Subnet2
    SecurityGroups:
      - !Ref AlbSecurityGroup        # Security Group para el ALB
```

**¿Qué es?**
- Es el componente principal que recibe el tráfico desde internet
- Tiene un **DNS name único** que se usa para acceder a la aplicación
- Se despliega en múltiples zonas de disponibilidad para alta disponibilidad

**Configuración requerida**:
- ✅ **Scheme**: `internet-facing` (público) o `internal` (privado)
- ✅ **Subnets**: Mínimo 2 subredes en **diferentes Availability Zones** (AZs)
- ✅ **Security Groups**: Al menos un Security Group con reglas para el tráfico entrante

**Propósito**:
- Distribuye el tráfico HTTP/HTTPS entre múltiples instancias EC2
- Proporciona alta disponibilidad al distribuir instancias en múltiples AZs
- Actúa como punto de entrada único para la aplicación

**¿Qué recibe?**
- Tráfico HTTP/HTTPS desde internet
- Peticiones entrantes en el puerto configurado (en este caso, puerto 80)

**¿Qué hace?**
- Recibe las peticiones HTTP
- Las distribuye a las instancias saludables registradas en el Target Group
- Realiza health checks periódicos para verificar que las instancias estén saludables

---

### 2️⃣ Target Group (WebTargetGroup)

```yaml
WebTargetGroup:
  Type: AWS::ElasticLoadBalancingV2::TargetGroup
  Properties:
    Name: !Sub "tg-${AWS::StackName}"
    Port: 80
    Protocol: HTTP
    VpcId: !Ref VpcId
    TargetType: instance              # Tipo: instance, IP, o Lambda
    HealthCheckProtocol: HTTP
    HealthCheckPort: '80'
    HealthCheckPath: /
```

**¿Qué es?**
Un **Target Group** es un grupo lógico de recursos (instancias EC2, IPs, o funciones Lambda) que reciben el tráfico enrutado desde el Load Balancer. Es como una "lista de destinos" que el ALB puede usar para distribuir el tráfico.

**Configuración**:
- ✅ **Port**: Puerto en el que las instancias reciben el tráfico (80 para HTTP)
- ✅ **Protocol**: Protocolo usado (HTTP, HTTPS, TCP, TLS, UDP)
- ✅ **VpcId**: VPC donde se encuentran las instancias
- ✅ **TargetType**: Tipo de destino (`instance`, `ip`, o `lambda`)
- ✅ **Health Check**: Configuración para verificar la salud de las instancias

**Health Check**:
El Target Group realiza verificaciones periódicas para determinar si las instancias están saludables:
- **HealthCheckProtocol**: Protocolo usado (HTTP, HTTPS, TCP)
- **HealthCheckPort**: Puerto donde se verifica (80)
- **HealthCheckPath**: Ruta donde se verifica la salud (`/`)

**¿Qué hace?**
1. **Registra instancias**: Las instancias EC2 se registran automáticamente cuando se crean
2. **Verifica salud**: Realiza health checks periódicos en cada instancia
3. **Enruta tráfico**: Solo envía tráfico a instancias que están "saludables"
4. **Excluye instancias no saludables**: Si una instancia falla el health check, se excluye automáticamente del tráfico

**Estados de las instancias en el Target Group**:
- ✅ **Healthy**: La instancia responde correctamente a los health checks → Recibe tráfico
- ❌ **Unhealthy**: La instancia no responde a los health checks → NO recibe tráfico
- ⏳ **Initial**: Estado inicial mientras se realizan los primeros health checks

**Propósito**:
- Agrupa las instancias EC2 del Auto Scaling Group
- Define dónde y cómo se verifica la salud de las instancias
- Permite que el ALB sepa a qué instancias puede enviar tráfico

---

### 3️⃣ Listener (WebListener)

```yaml
WebListener:
  Type: AWS::ElasticLoadBalancingV2::Listener
  Properties:
    LoadBalancerArn: !Ref WebALB              # Referencia al ALB
    Port: 80
    Protocol: HTTP
    DefaultActions:
      - Type: forward                          # Acción: reenviar tráfico
        TargetGroupArn: !Ref WebTargetGroup    # Al Target Group
```

**¿Qué es?**
Un **Listener** es un proceso que verifica las solicitudes de conexión usando el protocolo y puerto que configuras. Es como el "portero" del ALB que decide qué hacer con cada petición que llega.

**Configuración requerida**:
- ✅ **LoadBalancerArn**: Referencia al ALB al que pertenece
- ✅ **Port**: Puerto en el que escucha (80 para HTTP, 443 para HTTPS)
- ✅ **Protocol**: Protocolo usado (HTTP, HTTPS, TCP, TLS, UDP)
- ✅ **DefaultActions**: Acciones que se toman cuando llega una petición

**DefaultActions**:
Define qué hacer con el tráfico que llega:
- **Type: forward**: Reenviar el tráfico a un Target Group
- **TargetGroupArn**: El Target Group al que se reenvía el tráfico

**¿Qué hace?**
1. **Escucha**: Espera conexiones en el puerto especificado (80 para HTTP)
2. **Recibe peticiones**: Cuando llega una petición HTTP al ALB en el puerto 80
3. **Enruta**: Reenvía la petición al Target Group configurado usando la acción "forward"

**Opciones adicionales** (no usadas en esta plantilla):
- **Rules**: Reglas avanzadas de enrutamiento basadas en paths, hosts, headers, etc.
- **Certificates**: Certificados SSL/TLS para HTTPS (requiere ACM)

**Propósito**:
- Define en qué puerto y protocolo escucha el ALB
- Especifica a dónde se reenvía el tráfico (Target Group)
- Conecta el ALB con el Target Group

---

## Relación entre los 3 componentes

```
┌─────────────────────────────────────────────────────────┐
│                    INTERNET                              │
│  Petición HTTP a: alb-xxxxx.us-east-1.elb.amazonaws.com │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ↓
┌─────────────────────────────────────────────────────────┐
│  1️⃣ Load Balancer (WebALB)                              │
│  - DNS público único                                    │
│  - Recibe todas las peticiones                          │
│  - Distribuido en múltiples AZs                         │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ↓ (Listener enruta aquí)
┌─────────────────────────────────────────────────────────┐
│  3️⃣ Listener (WebListener)                              │
│  - Escucha en puerto 80 (HTTP)                          │
│  - Regla: Forward todo el tráfico a →                   │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ↓ (Reenvía al Target Group)
┌─────────────────────────────────────────────────────────┐
│  2️⃣ Target Group (WebTargetGroup)                       │
│  - Lista de instancias EC2                              │
│  - Health checks automáticos                            │
│  - Solo instancias "healthy" reciben tráfico            │
└───────────────────────┬─────────────────────────────────┘
                        │
                        ↓ (Distribuye entre instancias)
┌─────────────────────────────────────────────────────────┐
│  Instancias EC2 (desde Auto Scaling Group)              │
│  - Instancia 1 (Subnet1)                                │
│  - Instancia 2 (Subnet2)                                │
│  - ...                                                  │
└─────────────────────────────────────────────────────────┘
```

**Flujo completo**:
1. **Internet** → Petición HTTP al DNS del ALB
2. **ALB** → Recibe la petición
3. **Listener** → Escucha en puerto 80, reenvía al Target Group
4. **Target Group** → Selecciona una instancia saludable
5. **Instancia EC2** → Procesa la petición y responde
6. **ALB** → Reenvía la respuesta al cliente

---

## Conexión del ALB con el Auto Scaling Group

### ¿Cómo se conectan?

El **Auto Scaling Group (ASG)** y el **ALB** se conectan a través del **Target Group**. Aquí está el código relevante:

```yaml
Ec2AutoScalingGroup:
  Properties:
    TargetGroupARNs:
      - !Ref WebTargetGroup    # ← Conexión con el Target Group
```

**Conexión**:
```
Auto Scaling Group → Target Group ← ALB
                     (punto de conexión)
```

### ¿Cómo funciona la integración?

1. **Registro automático**:
   - Cuando el ASG crea una nueva instancia EC2, automáticamente la **registra en el Target Group**
   - No necesitas hacer nada manualmente

2. **Health Checks**:
   - El Target Group realiza health checks en las instancias registradas
   - Si una instancia no está saludable, el ALB **no le envía tráfico**

3. **Eliminación automática**:
   - Cuando el ASG elimina una instancia (escalado hacia abajo o reemplazo), automáticamente se **desregistra del Target Group**

4. **Distribución de tráfico**:
   - El ALB distribuye el tráfico entre todas las instancias **saludables** registradas en el Target Group

### Ventajas de esta integración

✅ **Escalado automático**:
- Si escalas el ASG de 1 a 5 instancias, todas se registran automáticamente en el Target Group
- El ALB automáticamente comienza a distribuir el tráfico entre las 5 instancias

✅ **Alta disponibilidad**:
- Si una instancia falla, el ASG la reemplaza automáticamente
- La nueva instancia se registra automáticamente en el Target Group

✅ **Health checks**:
- El Target Group verifica que las instancias estén saludables antes de enviarles tráfico
- Si una instancia falla el health check, se excluye del tráfico automáticamente

✅ **Sin configuración manual**:
- No necesitas registrar/desregistrar instancias manualmente
- Todo es automático

---

## Resumen: ¿Qué se necesita para crear un ALB?

### Componentes mínimos requeridos:

1. ✅ **Load Balancer (ALB)**
   - Scheme (internet-facing o internal)
   - Mínimo 2 subredes en diferentes AZs
   - Security Group

2. ✅ **Target Group**
   - Puerto y protocolo
   - Tipo de target (instance, IP, Lambda)
   - Configuración de Health Check

3. ✅ **Listener**
   - Puerto y protocolo
   - Acción por defecto (forward al Target Group)

### Integración opcional pero recomendada:

4. ✅ **Auto Scaling Group**
   - Conectar mediante `TargetGroupARNs`
   - Permite registro automático de instancias
   - Escalado automático con distribución de tráfico

---

## Comparación: Con y sin Target Group

| Aspecto | Sin Target Group | Con Target Group |
|---------|------------------|------------------|
| **Registro de instancias** | Manual | Automático (con ASG) |
| **Health checks** | No disponible | Automáticos |
| **Distribución de tráfico** | No funciona | Funciona correctamente |
| **Escalado automático** | No soportado | Soportado |
| **ALB funcional** | ❌ No | ✅ Sí |

**Conclusión**: El Target Group es **esencial** para que el ALB funcione. Sin él, el ALB no sabe a dónde enviar el tráfico.

---

## Comparación: Con y sin Listener

| Aspecto | Sin Listener | Con Listener |
|---------|--------------|--------------|
| **Puerto de escucha** | No configurado | Configurado (80) |
| **Reenvío de tráfico** | No funciona | Funciona |
| **ALB funcional** | ❌ No (no escucha) | ✅ Sí |

**Conclusión**: El Listener es **esencial** para que el ALB escuche y enrute el tráfico. Sin él, el ALB no sabe qué hacer con las peticiones entrantes.

---

## Ejemplo práctico: Flujo completo

**Escenario**: Usuario accede a `http://alb-xxxxx.us-east-1.elb.amazonaws.com`

1. **Usuario** hace petición HTTP → `GET / HTTP/1.1`

2. **DNS** resuelve el nombre del ALB → IP del ALB

3. **ALB (WebALB)** recibe la petición en una de sus subredes

4. **Listener (WebListener)** escucha en puerto 80:
   - "¿Qué hago con esta petición?"
   - Acción: `forward` al Target Group `WebTargetGroup`

5. **Target Group (WebTargetGroup)** selecciona una instancia:
   - Verifica instancias saludables
   - Selecciona instancia 1 (estado: healthy)
   - Reenvía la petición a instancia 1

6. **Instancia EC2** procesa la petición:
   - Apache recibe la petición
   - PHP genera la respuesta
   - Envía respuesta: `HTTP/1.1 200 OK` + HTML

7. **Target Group** reenvía la respuesta al ALB

8. **ALB** reenvía la respuesta al usuario

9. **Usuario** ve la página web con la información de la instancia

**Todo este proceso es transparente para el usuario final.**

---

### 7. Auto Scaling Group

#### **Ec2AutoScalingGroup**
- **Tipo**: `AWS::AutoScaling::AutoScalingGroup`
- **Nombre**: Configurable (por defecto `asg-santiago`)
- **Configuración de escalado**:
  - **MinSize**: Configurable (por defecto `1`)
  - **MaxSize**: Configurable (por defecto `1`)
  - **DesiredCapacity**: Configurable (por defecto `1`)
- **Subnets**: Distribuido en 2 subredes (`Subnet1` y `Subnet2`) para alta disponibilidad
- **Launch Template**: Usa `Ec2LaunchTemplate` con la versión más reciente
- **Health Check**:
  - Tipo: `EC2` (verifica el estado de las instancias)
  - Grace Period: 300 segundos (tiempo de gracia antes de considerar una instancia no saludable)
- **Tags**: 
  - Etiqueta `Name` propagada a todas las instancias creadas
- **Integración con ALB**:
  - Conectado al `WebTargetGroup` para registro automático de instancias
  - Las instancias se registran automáticamente cuando se crean
  - Las instancias no saludables se eliminan automáticamente

**Funcionalidad de Auto Scaling**:
- Si una instancia falla, el ASG la reemplaza automáticamente
- Las instancias se distribuyen en múltiples zonas de disponibilidad
- Integración con CloudWatch para métricas y alertas (configuración adicional requerida)

---

## Flujo de Tráfico

```
Internet
   ↓
Application Load Balancer (ALB)
   ├── Health Check: Verifica que las instancias respondan en /
   └── Distribución de tráfico HTTP (puerto 80)
       ↓
   Target Group (WebTargetGroup)
       ↓
   Instancias EC2 en Auto Scaling Group
       ├── Instancia 1 (Subnet1)
       ├── Instancia 2 (Subnet2)
       └── ...
       ↓
   Apache + PHP
       └── Página web mostrando información de la instancia
```

**Características del flujo**:
1. El tráfico HTTP entra por el ALB (DNS público)
2. El ALB distribuye el tráfico entre instancias saludables
3. Las instancias están en diferentes subredes/AZs para redundancia
4. Si una instancia falla, el ALB la excluye automáticamente del tráfico
5. El Auto Scaling Group detecta instancias no saludables y las reemplaza

---

## Scripts de Inicialización (UserData)

Ambas configuraciones (instancia EC2 directa y Launch Template) incluyen el mismo script de inicialización:

**Funcionalidad**:
1. **Actualización del sistema**: `yum update -y`
2. **Instalación de software**:
   - Apache HTTP Server (`httpd`)
   - PHP
3. **Configuración de servicios**:
   - Habilita Apache para iniciarse al arrancar
   - Inicia el servicio Apache
4. **Obtención de metadatos**:
   - Usa IMDSv2 (Instance Metadata Service v2) con token de seguridad
   - Fallback a IMDSv1 si IMDSv2 no está disponible
   - Obtiene: IP pública, IP privada, Availability Zone
5. **Creación de página web**:
   - Genera `/var/www/html/index.php`
   - Muestra información de la instancia en formato HTML

**Seguridad IMDSv2**:
El script primero intenta obtener un token IMDSv2 (más seguro) y si falla, usa IMDSv1 como fallback.

---

## Outputs Generados

La plantilla genera 5 outputs:

| Output | Descripción | Valor |
|--------|-------------|-------|
| `Ec2InstanceId` | ID de la instancia EC2 directa creada | `!Ref Ec2Instance` |
| `Ec2PublicIp` | IP pública de la instancia EC2 directa | `!GetAtt Ec2Instance.PublicIp` |
| `AlbDNSName` | **DNS name del Application Load Balancer** (usar para acceder a la aplicación) | `!GetAtt WebALB.DNSName` |
| `AutoScalingGroupName` | Nombre del Auto Scaling Group | `!Ref Ec2AutoScalingGroup` |
| `LaunchTemplateId` | ID del Launch Template creado | `!Ref Ec2LaunchTemplate` |

**Outputs exportados** (para uso en otros stacks):
- `{StackName}-AutoScalingGroupName`
- `{StackName}-LaunchTemplateId`

**Acceso a la aplicación**:
Para acceder a la aplicación web, usa el DNS name del ALB desde el output `AlbDNSName`:
```
http://{alb-dns-name}
```

---

## Arquitectura de Alta Disponibilidad

La infraestructura está diseñada para alta disponibilidad:

1. **Múltiples zonas de disponibilidad**: 
   - ALB y ASG distribuyen recursos en `Subnet1` y `Subnet2` (diferentes AZs)

2. **Health Checks**:
   - ALB verifica salud de instancias cada cierto intervalo
   - Instancias no saludables se excluyen automáticamente

3. **Auto Scaling**:
   - Reemplazo automático de instancias fallidas
   - Posibilidad de escalado horizontal (ajustando `MinSize`, `MaxSize`, `DesiredCapacity`)

4. **Balanceo de carga**:
   - Distribución uniforme del tráfico entre instancias
   - Eliminación de punto único de fallo

---

## Configuración de Seguridad

### Permisos IAM
- **Principio de menor privilegio**: Solo `AmazonSSMManagedInstanceCore` para administración
- **Sin permisos administrativos innecesarios** en las instancias

### Security Groups
- **AlbSecurityGroup**: Solo puerto 80 desde internet
- **InstanceSecurityGroup**: 
  - HTTP solo desde ALB (no desde internet directamente)
  - SSH abierto (considerar restringir en producción)

### Mejoras recomendadas para producción:
1. Restringir SSH a IPs específicas o usar solo SSM Session Manager
2. Implementar HTTPS/SSL en el ALB (requiere certificado ACM)
3. Configurar WAF (Web Application Firewall) en el ALB
4. Habilitar logging de acceso del ALB en S3
5. Implementar VPC Flow Logs para auditoría de red

---

## Uso y Despliegue

### Pre-requisitos
1. AWS CLI configurado con credenciales válidas
2. VPC y subredes existentes (o usar los valores por defecto)
3. Permisos IAM suficientes para crear los recursos

### Despliegue
```bash
aws cloudformation create-stack \
  --stack-name mi-infraestructura \
  --template-body file://infra.yml \
  --parameters ParameterKey=SubnetId,ParameterValue=subnet-xxxxx
```

### Actualización
```bash
aws cloudformation update-stack \
  --stack-name mi-infraestructura \
  --template-body file://infra.yml \
  --parameters ParameterKey=SubnetId,ParameterValue=subnet-xxxxx
```

### Eliminación
```bash
aws cloudformation delete-stack --stack-name mi-infraestructura
```

---

## Integración con SSM Parameter Store

Puedes usar el script `scripts/create_ssm_params.py` para crear parámetros en SSM Parameter Store con los valores por defecto de esta plantilla:

```bash
python3 scripts/create_ssm_params.py \
  --template infra.yml \
  --prefix /santiago \
  --region us-east-1 \
  --profile default
```

Esto creará parámetros SSM para todos los parámetros que tengan valores por defecto, permitiendo referencia desde otras plantillas CloudFormation.

---

## Resumen de Recursos Creados

| Tipo de Recurso | Cantidad | Nombres |
|----------------|----------|---------|
| IAM Role | 1 | Ec2InstanceRole |
| IAM Instance Profile | 1 | Ec2InstanceProfile |
| EC2 Instance | 1 | (configurable, default: santiago) |
| Launch Template | 1 | lt-santiago |
| Security Groups | 2 | AlbSecurityGroup, InstanceSecurityGroup |
| Application Load Balancer | 1 | alb-{StackName} |
| Target Group | 1 | tg-{StackName} |
| Listener | 1 | (asociado al ALB) |
| Auto Scaling Group | 1 | asg-santiago |

**Total**: ~11 recursos principales (más recursos internos de AWS)
