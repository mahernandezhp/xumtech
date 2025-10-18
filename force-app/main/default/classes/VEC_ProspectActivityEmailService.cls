/**
 * @description Service class para orquestar el proceso completo de notificación por email
 *              a managers sobre asesores sin actividad de prospectos
 * @author Marco Hernandez
 * @version 1.4
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * ===============================================================================
 * VERSION | FECHA      | AUTOR          | DESCRIPCION
 * ===============================================================================
 * 1.0     | 2025-01-17 | Marco Hernandez| Creación inicial del service para 
 *         |            |                | orquestación de notificaciones por email
 * -------------------------------------------------------------------------------
 * 1.1     | 2025-10-17 | Marco Hernandez| Agregados parámetros flexibles con Sets,
 *         |            |                | validaciones SonarCloud y manejo de errores
 * -------------------------------------------------------------------------------
 * 1.2     | 2025-10-17 | Marco Hernandez| Optimización de VEC_UserQueries y 
 *         |            |                | VEC_ProspectActivityEmailBuilder
 * -------------------------------------------------------------------------------
 * 1.3     | 2025-10-17 | Marco Hernandez | Simplificación: Solo filtro por perfil de asesor,
 *         |            |                | eliminado filtro de manager. Limpieza de métodos unused
 * -------------------------------------------------------------------------------
 * 1.4     | 2025-01-17 | Marco Hernandez | Reducción de complejidad ciclomatica siguiendo
 *         |            |                | recomendaciones SonarCloud. Extracción de métodos
 *         |            |                | para mejorar legibilidad y mantenibilidad
 * ===============================================================================
 */
public class VEC_ProspectActivityEmailService {
    
    // Constantes para configuración
    private final Integer ACTIVITY_PERIOD_DAYS = -14;
    private final Integer EMAIL_BATCH_SIZE = 10; // Límite de Salesforce para envío
    private final String DEFAULT_EMAIL_TEMPLATE_NAME = 'VEC_Manager_Prospect_Activity_Alert';
    private final Set<String> DEFAULT_LEAD_RECORD_TYPES = new Set<String>{ 'Empresas_U4O' };
    private final Set<String> DEFAULT_ADVISOR_PROFILES = new Set<String>{ 'VEC Asesor U4O' };
    
    // Instancias de clases de consulta y construcción
    private final VEC_UserQueries userQueries;
    private final VEC_LeadQueries leadQueries;
    private final VEC_ProspectActivityEmailBuilder emailBuilder;
    
    // Variables para tracking y resultado
    private final List<String> processingLog;
    
    /**
     * @description Constructor por defecto
     */
    public VEC_ProspectActivityEmailService() {
        this.userQueries = new VEC_UserQueries();
        this.leadQueries = new VEC_LeadQueries();
        this.emailBuilder = new VEC_ProspectActivityEmailBuilder();
        this.processingLog = new List<String>();
    }
    
    /**
     * @description Clase para encapsular el resultado del procesamiento
     */
    public class ProcessResult {
        public Boolean success { get; set; }
        public String message { get; set; }
        public String emailBatchJobId { get; set; }
        public Integer managersNotified { get; set; }
        public Integer advisorsWithoutActivity { get; set; }
        public Exception exception { get; set; }
        public List<String> processingLog { get; set; }
        
        public ProcessResult() {
            this.success = false;
            this.managersNotified = 0;
            this.advisorsWithoutActivity = 0;
            this.processingLog = new List<String>();
        }
    }
    
    /**
     * @description Método principal para procesar asesores inactivos y enviar notificaciones
     * @return ProcessResult Resultado del procesamiento
     */
    public ProcessResult processInactiveAdvisorsAndSendEmails() {
        return processInactiveAdvisorsAndSendEmails(DEFAULT_EMAIL_TEMPLATE_NAME, DEFAULT_LEAD_RECORD_TYPES, DEFAULT_ADVISOR_PROFILES);
    }

    /**
     * @description Método principal para procesar asesores inactivos y enviar notificaciones
     * @param advisorProfiles Set de nombres de perfiles de asesores a incluir
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @param emailTemplateName Nombre del developer del email template
     * @return ProcessResult Resultado del procesamiento
     */
    public ProcessResult processInactiveAdvisorsAndSendEmails(Set<String> advisorProfiles, Set<String> leadRecordTypes, String emailTemplateName) {
        ProcessResult result = new ProcessResult();
        
        try {
            logMessage('=== INICIANDO PROCESAMIENTO VEC PROSPECT ACTIVITY ===');
            
            // 1. Obtener asesores activos con validaciones
            List<User> activeAdvisors = getActiveAdvisorsWithValidation(advisorProfiles);
            if (activeAdvisors.isEmpty()) {
                return buildSuccessResult(result, 'No se encontraron asesores activos con los perfiles especificados');
            }
            
            // 2. Identificar asesores sin actividad reciente
            Map<Id, List<User>> managersToInactiveAdvisors = identifyInactiveAdvisors(activeAdvisors, leadRecordTypes);
            if (managersToInactiveAdvisors.isEmpty()) {
                return buildSuccessResult(result, 'No se encontraron asesores sin actividad reciente');
            }
            
            // 3. Construir y enviar notificaciones
            return buildAndSendNotifications(managersToInactiveAdvisors, emailTemplateName);
            
        } catch (Exception e) {
            return buildExceptionResult(e);
        }
    }
    
    /**
     * @description Obtiene asesores activos con validaciones
     * @param advisorProfiles Set de perfiles de asesores
     * @return List<User> Lista de asesores activos
     */
    private List<User> getActiveAdvisorsWithValidation(Set<String> advisorProfiles) {
        Set<String> validProfiles = (advisorProfiles != null && !advisorProfiles.isEmpty()) 
            ? advisorProfiles 
            : DEFAULT_ADVISOR_PROFILES;
            
        List<User> activeAdvisors = userQueries.getActiveAdvisorsWithManagers(validProfiles);
        logMessage('Asesores activos encontrados: ' + activeAdvisors.size());
        
        return activeAdvisors;
    }
    
    /**
     * @description Construye emails y los envía via batch
     * @param managersToInactiveAdvisors Mapa de managers a asesores inactivos
     * @param emailTemplateName Nombre del template de email
     * @return ProcessResult Resultado del proceso
     */
    private ProcessResult buildAndSendNotifications(Map<Id, List<User>> managersToInactiveAdvisors, String emailTemplateName) {
        // 3. Construir emails de notificación
        List<Messaging.SingleEmailMessage> emails = buildNotificationEmails(managersToInactiveAdvisors, emailTemplateName);
        
        if (emails.isEmpty()) {
            return buildErrorResult(new ProcessResult(), 'No se pudieron construir los emails de notificación');
        }
        
        // 4. Enviar emails via batch
        String batchJobId = sendEmailsViaBatch(emails);
        
        // 5. Construir resultado exitoso
        logMessage('=== PROCESAMIENTO COMPLETADO EXITOSAMENTE ===');
        return buildFinalResult(managersToInactiveAdvisors, batchJobId);
    }
    
    /**
     * @description Obtiene todos los asesores activos usando VEC_UserQueries
     * @param advisorProfiles Set de perfiles de asesores
     * @return List<User> Lista de asesores activos
     */
    private List<User> getActiveAdvisors(Set<String> advisorProfiles) {
        // Validaciones de parámetros (SonarCloud)
        Set<String> validProfiles = (advisorProfiles != null && !advisorProfiles.isEmpty()) 
            ? advisorProfiles 
            : DEFAULT_ADVISOR_PROFILES;
            
        try {
            return userQueries.getActiveAdvisorsWithManagers(validProfiles);
        } catch (Exception e) {
            logMessage('Error obteniendo asesores activos: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al consultar asesores activos: ' + e.getMessage(), e);
        }
    }
    
    /**
     * @description Obtiene todos los asesores activos usando valores por defecto (método legacy)
     * @return List<User> Lista de asesores activos
     */
    private List<User> getActiveAdvisors() {
        return getActiveAdvisors(DEFAULT_ADVISOR_PROFILES);
    }
    
    /**
     * @description Identifica asesores sin actividad reciente de Leads
     * @param activeAdvisors Lista de asesores activos
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @return Map<Id, List<User>> Mapa de manager ID a lista de asesores sin actividad
     */
    private Map<Id, List<User>> identifyInactiveAdvisors(List<User> activeAdvisors, Set<String> leadRecordTypes) {
        Map<Id, List<User>> managersToInactiveAdvisors = new Map<Id, List<User>>();
        
        try {
            Set<Id> advisorIds = extractAdvisorIds(activeAdvisors);
            Set<Id> activeAdvisorIds = getAdvisorsWithRecentActivity(advisorIds, leadRecordTypes);
            
            logMessage('Asesores con actividad reciente: ' + activeAdvisorIds.size());
            
            Integer totalInactiveAdvisors = groupInactiveAdvisorsByManager(
                activeAdvisors, 
                activeAdvisorIds, 
                managersToInactiveAdvisors
            );
            
            logMessage('Total asesores sin actividad: ' + totalInactiveAdvisors);
            logMessage('Managers a notificar: ' + managersToInactiveAdvisors.size());
            
        } catch (Exception e) {
            logMessage('Error identificando asesores inactivos: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al identificar asesores inactivos: ' + e.getMessage(), e);
        }
        
        return managersToInactiveAdvisors;
    }
    
    /**
     * @description Extrae IDs de asesores de la lista
     * @param activeAdvisors Lista de asesores activos
     * @return Set<Id> Set de IDs de asesores
     */
    private Set<Id> extractAdvisorIds(List<User> activeAdvisors) {
        Set<Id> advisorIds = new Set<Id>();
        for (User advisor : activeAdvisors) {
            advisorIds.add(advisor.Id);
        }
        return advisorIds;
    }
    
    /**
     * @description Agrupa asesores sin actividad por manager
     * @param activeAdvisors Lista de todos los asesores activos
     * @param activeAdvisorIds IDs de asesores con actividad reciente
     * @param managersToInactiveAdvisors Mapa para agrupar por manager
     * @return Integer Número total de asesores sin actividad
     */
    private Integer groupInactiveAdvisorsByManager(
        List<User> activeAdvisors, 
        Set<Id> activeAdvisorIds, 
        Map<Id, List<User>> managersToInactiveAdvisors
    ) {
        Integer totalInactiveAdvisors = 0;
        
        for (User advisor : activeAdvisors) {
            if (isInactiveAdvisorWithManager(advisor, activeAdvisorIds)) {
                addAdvisorToManagerGroup(advisor, managersToInactiveAdvisors);
                totalInactiveAdvisors++;
                logMessage('Asesor sin actividad: ' + advisor.Name + ' (Manager: ' + advisor.Manager?.Name + ')');
            }
        }
        
        return totalInactiveAdvisors;
    }
    
    /**
     * @description Verifica si un asesor está inactivo y tiene manager
     * @param advisor Asesor a evaluar
     * @param activeAdvisorIds IDs de asesores con actividad reciente
     * @return Boolean true si está inactivo y tiene manager
     */
    private Boolean isInactiveAdvisorWithManager(User advisor, Set<Id> activeAdvisorIds) {
        return !activeAdvisorIds.contains(advisor.Id) && advisor.ManagerId != null;
    }
    
    /**
     * @description Agrega asesor al grupo de su manager
     * @param advisor Asesor a agregar
     * @param managersToInactiveAdvisors Mapa de agrupación
     */
    private void addAdvisorToManagerGroup(User advisor, Map<Id, List<User>> managersToInactiveAdvisors) {
        if (!managersToInactiveAdvisors.containsKey(advisor.ManagerId)) {
            managersToInactiveAdvisors.put(advisor.ManagerId, new List<User>());
        }
        managersToInactiveAdvisors.get(advisor.ManagerId).add(advisor);
    }
    
    /**
     * @description Obtiene asesores con actividad reciente de Leads
     * @param advisorIds Set de IDs de asesores
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @return Set<Id> IDs de asesores con actividad reciente
     */
    private Set<Id> getAdvisorsWithRecentActivity(Set<Id> advisorIds, Set<String> leadRecordTypes) {
        Set<Id> activeAdvisors = new Set<Id>();
        
        // Validaciones de parámetros (SonarCloud)
        if (advisorIds == null || advisorIds.isEmpty()) {
            logMessage('WARN: advisorIds es null o vacío');
            return activeAdvisors;
        }
        
        Date activityThreshold = Date.today().addDays(ACTIVITY_PERIOD_DAYS);
        Set<String> validRecordTypes = getValidRecordTypes(leadRecordTypes);
        
        try {
            List<Lead> recentLeads = leadQueries.getManualLeadsByAdvisors(advisorIds, activityThreshold, validRecordTypes);
            activeAdvisors = extractAdvisorsFromManualLeads(recentLeads);
            
        } catch (Exception e) {
            logMessage('Error consultando actividad de Leads: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al consultar actividad de Leads: ' + e.getMessage(), e);
        }
        
        return activeAdvisors;
    }
    
    /**
     * @description Obtiene record types válidos, usando defaults si es necesario
     * @param leadRecordTypes Set de record types proporcionados
     * @return Set<String> Record types válidos a usar
     */
    private Set<String> getValidRecordTypes(Set<String> leadRecordTypes) {
        return (leadRecordTypes != null && !leadRecordTypes.isEmpty()) 
            ? leadRecordTypes 
            : DEFAULT_LEAD_RECORD_TYPES;
    }
    
    /**
     * @description Extrae IDs de asesores de Leads creados manualmente
     * @param recentLeads Lista de Leads recientes
     * @return Set<Id> IDs de asesores con actividad manual
     */
    private Set<Id> extractAdvisorsFromManualLeads(List<Lead> recentLeads) {
        Set<Id> activeAdvisors = new Set<Id>();
        
        // Filtrar solo Leads creados manualmente (CreatedById = OwnerId)
        for (Lead lead : recentLeads) {
            if (isManuallyCreatedLead(lead)) {
                activeAdvisors.add(lead.CreatedById);
            }
        }
        
        return activeAdvisors;
    }
    
    /**
     * @description Verifica si un Lead fue creado manualmente
     * @param lead Lead a verificar
     * @return Boolean true si fue creado manualmente
     */
    private Boolean isManuallyCreatedLead(Lead lead) {
        return lead != null && lead.CreatedById == lead.OwnerId;
    }
    
    /**
     * @description Construye emails de notificación usando VEC_ProspectActivityEmailBuilder
     * @param managersToInactiveAdvisors Mapa de managers a asesores sin actividad
     * @param emailTemplateName Nombre del developer del email template
     * @return List<Messaging.SingleEmailMessage> Lista de emails construidos
     */
    private List<Messaging.SingleEmailMessage> buildNotificationEmails(Map<Id, List<User>> managersToInactiveAdvisors, String emailTemplateName) {
        try {
            logMessage('Construyendo emails de notificación...');
            
            List<Messaging.SingleEmailMessage> emails = emailBuilder.buildManagerNotificationEmails(managersToInactiveAdvisors, emailTemplateName);
            
            logMessage('Emails construidos: ' + emails.size());
            
            return emails;
            
        } catch (Exception e) {
            logMessage('Error construyendo emails: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al construir emails de notificación: ' + e.getMessage(), e);
        }
    }
    
    /**
     * @description Envía emails usando VEC_EmailSendBatch
     * @param emails Lista de emails para enviar
     * @return String Job ID del batch de envío
     */
    private String sendEmailsViaBatch(List<Messaging.SingleEmailMessage> emails) {
        try {
            logMessage('Iniciando envío de emails via batch...');
            
            VEC_EmailSendBatch emailBatch = new VEC_EmailSendBatch(emails, 'VEC Prospect Activity Notifications');
            String batchJobId = Database.executeBatch(emailBatch, EMAIL_BATCH_SIZE);
            
            logMessage('Batch de envío iniciado con Job ID: ' + batchJobId);
            
            return batchJobId;
            
        } catch (Exception e) {
            logMessage('Error enviando emails via batch: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al enviar emails via batch: ' + e.getMessage(), e);
        }
    }
    
    /**
     * @description Construye el resultado final exitoso
     * @param managersToInactiveAdvisors Mapa de resultados
     * @param batchJobId ID del job de batch
     * @return ProcessResult Resultado final
     */
    private ProcessResult buildFinalResult(Map<Id, List<User>> managersToInactiveAdvisors, String batchJobId) {
        ProcessResult result = new ProcessResult();
        result.success = true;
        result.emailBatchJobId = batchJobId;
        result.managersNotified = managersToInactiveAdvisors.size();
        result.advisorsWithoutActivity = calculateTotalInactiveAdvisors(managersToInactiveAdvisors);
        result.message = buildSuccessMessage(result.managersNotified, result.advisorsWithoutActivity, batchJobId);
        
        return result;
    }
    
    /**
     * @description Calcula el total de asesores sin actividad
     * @param managersToInactiveAdvisors Mapa de managers a asesores inactivos
     * @return Integer Total de asesores sin actividad
     */
    private Integer calculateTotalInactiveAdvisors(Map<Id, List<User>> managersToInactiveAdvisors) {
        Integer totalInactiveAdvisors = 0;
        for (List<User> advisors : managersToInactiveAdvisors.values()) {
            totalInactiveAdvisors += advisors.size();
        }
        return totalInactiveAdvisors;
    }
    
    /**
     * @description Construye mensaje de éxito con formato
     * @param managersNotified Número de managers notificados
     * @param advisorsWithoutActivity Número de asesores sin actividad
     * @param batchJobId ID del job de batch
     * @return String Mensaje formateado
     */
    private String buildSuccessMessage(Integer managersNotified, Integer advisorsWithoutActivity, String batchJobId) {
        return String.format(
            'Procesamiento exitoso: {0} managers notificados sobre {1} asesores sin actividad. Batch Job ID: {2}',
            new List<Object>{ managersNotified, advisorsWithoutActivity, batchJobId }
        );
    }
    
    /**
     * @description Construye resultado de éxito simple
     * @param result Resultado base
     * @param message Mensaje
     * @return ProcessResult Resultado exitoso
     */
    private ProcessResult buildSuccessResult(ProcessResult result, String message) {
        result.success = true;
        result.message = message;
        logMessage(message);
        return result;
    }
    
    /**
     * @description Construye resultado de error
     * @param result Resultado base
     * @param message Mensaje de error
     * @return ProcessResult Resultado de error
     */
    private ProcessResult buildErrorResult(ProcessResult result, String message) {
        result.success = false;
        result.message = message;
        logMessage('ERROR: ' + message);
        return result;
    }
    
    /**
     * @description Construye resultado por excepción
     * @param e Excepción capturada
     * @return ProcessResult Resultado de excepción
     */
    private ProcessResult buildExceptionResult(Exception e) {
        ProcessResult result = new ProcessResult();
        result.success = false;
        result.exception = e;
        result.message = 'Error durante el procesamiento: ' + e.getMessage();
        
        logMessage('EXCEPTION: ' + e.getMessage());
        logMessage('Stack Trace: ' + e.getStackTraceString());
        
        return result;
    }
    
    /**
     * @description Agrega un mensaje al log de procesamiento
     * @param message Mensaje a registrar
     */
    private void logMessage(String message) {
        String logEntry = buildLogEntry(message);
        this.processingLog.add(logEntry);
        System.debug(logEntry);
    }
    
    /**
     * @description Construye una entrada de log con timestamp
     * @param message Mensaje base
     * @return String Entrada de log formateada
     */
    private String buildLogEntry(String message) {
        String timestamp = DateTime.now().format('yyyy-MM-dd HH:mm:ss');
        return '[' + timestamp + '] VEC_ProspectActivityEmailService: ' + message;
    }
    
    /**
     * @description Excepción personalizada para el service
     */
    public class ProspectActivityEmailServiceException extends Exception {}
}