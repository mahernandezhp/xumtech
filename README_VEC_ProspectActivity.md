# Sistema de Alertas de Actividad de Leads VEC

## Descripción General

Este sistema automatizado monitorea la actividad de creación manual de Leads con RecordType "Empresas U4O" por parte de los asesores y envía alertas a sus managers cuando no hay actividad en las últimas 2 semanas.

## Componentes del Sistema

### 1. Clases Apex

#### `VEC_ProspectActivityScheduler`
- **Propósito**: Clase Schedulable para ejecutar el proceso automáticamente
- **Programación**: Lunes a Viernes a las 9:00 AM
- **Expresión Cron**: `0 0 9 ? * MON-FRI`

#### `VEC_ProspectActivityBatch`
- **Propósito**: Procesa asesores y identifica inactividad en creación de Leads
- **Funcionalidad**: 
  - Busca asesores activos con perfil "VEC Asesor U4O"
  - Verifica actividad de creación manual de Leads RecordType "Empresas U4O"
  - Solo considera Leads no convertidos
  - Agrupa asesores sin actividad por manager
  - **Tamaño de lote**: 50 registros para respetar límites de email

#### `VEC_ProspectActivityEmailProcessor`
- **Propósito**: Maneja el envío de emails respetando límites de Salesforce
- **Características**:
  - Procesamiento en lotes (máximo 10 emails por transacción)
  - Generación automática de archivos CSV
  - Uso de Email Templates y OrgWideEmailAddress

#### `VEC_ProspectActivityUtils`
- **Propósito**: Utilidades para testing y ejecución manual
- **Funciones**: Validación de configuración, estadísticas, ejecución manual

#### `VEC_UserQueries`
- **Propósito**: Consultas SOQL específicas para usuarios (Asesores y Managers)
- **Funciones**: 
  - Consultas de asesores activos con managers
  - Datos específicos de managers
  - Conteos y estadísticas de usuarios
  - Validaciones de perfiles
  - Relaciones manager-asesor

#### `VEC_LeadQueries`
- **Propósito**: Consultas SOQL específicas para Leads
- **Funciones**: 
  - Leads manuales por asesores y período
  - Conteos de Leads por asesor
  - Estadísticas de actividad de Leads
  - Filtros por RecordType "Empresas U4O"
  - Leads por status

#### `VEC_SystemQueries`
- **Propósito**: Consultas SOQL de configuración del sistema
- **Funciones**: 
  - Email Templates y OrgWideEmailAddress
  - Jobs programados y AsyncApexJobs
  - Validación de RecordTypes y Perfiles
  - Límites del sistema
  - Metadata del sistema

### 2. Email Template

#### `VEC_Manager_Prospect_Activity_Alert`
- **Ubicación**: `/email/VEC_EmailTemplates/`
- **Propósito**: Template personalizado para notificaciones a managers
- **Características**: Texto profesional con instrucciones claras

### 3. Scripts de Configuración

#### `scheduleProspectActivityJob.apex`
- **Ubicación**: `/scripts/apex/`
- **Propósito**: Script para programar y validar el sistema

## Criterios de Identificación

### Prospecto Manual (Lead)
Un Lead se considera "manual" cuando:
- `CreatedById` = `OwnerId` (mismo usuario creó y es propietario)
- `RecordType.DeveloperName` = "Empresas_U4O"
- `IsConverted` = false (no convertido)

### Usuarios Considerados
- **Asesores**: Perfil "VEC Asesor U4O"
- **Managers**: Perfil "Gerente U4O"
- Solo usuarios activos (`IsActive = true`)
- Email válido (que NO termine en `.invalid`)

### Período de Evaluación
- Últimas 2 semanas (14 días) desde la fecha de ejecución

## Límites de Salesforce Considerados

### Límites de Email
- **SingleEmailMessage**: 10 emails por transacción
- **Archivos adjuntos**: Máximo 25MB
- **Límite diario**: 5,000 emails por organización

### Estrategias de Mitigación
- Uso de Queueable para procesamiento en lotes
- Un email por manager (consolidado)
- Validación de tamaños de archivo
- Manejo de errores y reintentos

## Instalación y Configuración

### Prerequisitos
1. **Perfiles configurados**:
   - "VEC Asesor U4O"
   - "Gerente U4O"

2. **RecordType configurado**:
   - Lead RecordType "Empresas U4O" (DeveloperName: "Empresas_U4O")

3. **OrgWideEmailAddress configurado**:
   - Dirección de email organizacional habilitada
   - `IsAllowAllProfiles = true`

### Pasos de Instalación

1. **Deploy de componentes**:
   ```bash
   # Desde VS Code con Salesforce CLI
   sfdx force:source:deploy -p force-app/main/default/classes/VEC_*
   sfdx force:source:deploy -p force-app/main/default/email/VEC_EmailTemplates/
   ```

2. **Programar el job**:
   - Abrir Developer Console
   - Ejecutar script: `scripts/apex/scheduleProspectActivityJob.apex`

3. **Validar configuración**:
   ```apex
   // En Developer Console
   VEC_ProspectActivityUtils.runFromConsole();
   ```

## Uso y Operación

### Ejecución Automática
- El sistema se ejecuta automáticamente de lunes a viernes a las 9:00 AM
- No requiere intervención manual una vez configurado

### Ejecución Manual
```apex
// Ejecutar verificación inmediata
String result = VEC_ProspectActivityUtils.executeManualCheck();
System.debug(result);

// Obtener estadísticas
String stats = VEC_ProspectActivityUtils.getActivityStatistics();
System.debug(stats);
```

### Monitoreo
```apex
// Validar configuración del sistema
String validation = VEC_ProspectActivityUtils.validateSystemConfiguration();
System.debug(validation);
```

## Estructura de Archivos

```
force-app/main/default/
├── classes/
│   ├── VEC_ProspectActivityScheduler.cls
│   ├── VEC_ProspectActivityScheduler.cls-meta.xml
│   ├── VEC_ProspectActivityBatch.cls
│   ├── VEC_ProspectActivityBatch.cls-meta.xml
│   ├── VEC_ProspectActivityEmailProcessor.cls
│   ├── VEC_ProspectActivityEmailProcessor.cls-meta.xml
│   ├── VEC_ProspectActivityUtils.cls
│   ├── VEC_ProspectActivityUtils.cls-meta.xml
│   ├── VEC_UserQueries.cls
│   ├── VEC_UserQueries.cls-meta.xml
│   ├── VEC_LeadQueries.cls
│   ├── VEC_LeadQueries.cls-meta.xml
│   ├── VEC_SystemQueries.cls
│   └── VEC_SystemQueries.cls-meta.xml
└── email/
    └── VEC_EmailTemplates/
        ├── VEC_Manager_Prospect_Activity_Alert.email
        └── VEC_Manager_Prospect_Activity_Alert.email-meta.xml

scripts/apex/
└── scheduleProspectActivityJob.apex
```

## Funcionalidades del Email

### Contenido del Email
- Saludo personalizado al manager
- Explicación clara del propósito
- Instrucciones de acción
- Información sobre el archivo adjunto

### Archivo CSV Adjunto
- **Nombre**: `Asesores_Sin_Actividad_Leads_[FECHA].csv`
- **Contenido**: 
  - Nombre del asesor
  - Link directo al perfil del usuario en Salesforce
- **Formato**: CSV estándar compatible con Excel

### Configuraciones de Tracking
- `targetObjectId`: Configurado al manager para tracking interno
- `setSaveAsActivity(false)`: No genera actividades
- Uso de OrgWideEmailAddress para emails institucionales

## Troubleshooting

### Problemas Comunes

1. **Email Template no encontrado**:
   ```
   Verificar que el template "VEC_Manager_Prospect_Activity_Alert" existe
   ```

2. **OrgWideEmailAddress no configurado**:
   ```
   Configurar una dirección organizacional con IsAllowAllProfiles = true
   ```

3. **Perfiles no encontrados**:
   ```
   Verificar que existen los perfiles "VEC Asesor U4O" y "Gerente U4O"
   ```

4. **Límites de email excedidos**:
   ```
   El sistema maneja automáticamente los límites con procesamiento en lotes
   ```

### Logs y Debug
- Todos los componentes incluyen logging detallado
- Usar `System.debug()` para monitorear ejecución
- Revisar Setup > Apex Jobs para estado de batches

## Arquitectura del Sistema

### Separación de Responsabilidades
- **VEC_ProspectActivityScheduler**: Programación y orquestación
- **VEC_ProspectActivityBatch**: Lógica de procesamiento principal
- **VEC_ProspectActivityEmailProcessor**: Manejo de comunicaciones
- **VEC_UserQueries**: Capa de acceso a datos de usuarios
- **VEC_LeadQueries**: Capa de acceso a datos de Leads
- **VEC_SystemQueries**: Capa de acceso a configuración del sistema
- **VEC_ProspectActivityUtils**: Herramientas de administración

### Ventajas de la Centralización de Consultas
- **Reutilización**: Consultas disponibles para múltiples clases
- **Mantenimiento**: Cambios en una sola ubicación
- **Consistencia**: Criterios uniformes en todo el sistema
- **Testing**: Fácil simulación de datos para pruebas
- **Performance**: Optimización centralizada de consultas

## Mantenimiento

### Actualizaciones
- Versionar cambios en el encabezado de cada clase
- Documentar modificaciones en el historial
- Probar en Sandbox antes de producción
- **Consultas**: Modificar en las clases Query específicas:
  - **Usuarios**: `VEC_UserQueries`
  - **Leads**: `VEC_LeadQueries` 
  - **Sistema**: `VEC_SystemQueries`

### Monitoreo Periódico
- Revisar logs de ejecución semanalmente
- Validar estadísticas de actividad mensualmente
- Verificar configuración de email template trimestralmente
- **Performance**: Monitorear tiempos de consulta en clases Query

---

**Versión**: 1.3  
**Fecha de Creación**: 2025-10-17  
**Última Actualización**: 2025-10-17  
**Cambios v1.3**: Separación especializada de consultas SOQL en 3 clases:
- VEC_UserQueries (usuarios)
- VEC_LeadQueries (Leads)  
- VEC_SystemQueries (configuración)