/**
 * @description Service class para orquestar el proceso completo de notificación por email
 *              a managers sobre asesores sin actividad de prospectos
 * @author Marco Hernandez
 * @version 1.3
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor          | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Marco Hernandez | Creación inicial - Service para orquestar
 *         |            |                 | consultas, construcción de emails y envío
 * 1.1     | 2025-10-17 | Marco Hernandez | Flexibilidad: Soporte para múltiples
 *         |            |                 | RecordTypes como Set<String> parámetro
 * 1.2     | 2025-10-17 | Marco Hernandez | Flexibilidad: Soporte para múltiples
 *         |            |                 | perfiles de usuarios como Set<String>
 * 1.3     | 2025-10-17 | Marco Hernandez | Simplificación: Solo filtro por perfil de asesor,
 *         |            |                 | manager puede ser de cualquier perfil
 * =============================================================================
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
     * @description Constructor para testing con mocks
     * @param userQueries Mock de user queries
     * @param leadQueries Mock de lead queries
     * @param emailBuilder Mock de email builder
     */
    public VEC_ProspectActivityEmailService(
        VEC_UserQueries userQueries, 
        VEC_LeadQueries leadQueries, 
        VEC_ProspectActivityEmailBuilder emailBuilder
    ) {
        this.userQueries = userQueries;
        this.leadQueries = leadQueries;
        this.emailBuilder = emailBuilder;
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
     * @param emailTemplateName Nombre del developer del email template a usar
     * @return ProcessResult Resultado del procesamiento
     */
    public ProcessResult processInactiveAdvisorsAndSendEmails(String emailTemplateName) {
        return processInactiveAdvisorsAndSendEmails(emailTemplateName, DEFAULT_LEAD_RECORD_TYPES, DEFAULT_ADVISOR_PROFILES);
    }
    
    /**
     * @description Método principal para procesar asesores inactivos y enviar notificaciones
     * @param emailTemplateName Nombre del developer del email template a usar
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @return ProcessResult Resultado del procesamiento
     */
    public ProcessResult processInactiveAdvisorsAndSendEmails(String emailTemplateName, Set<String> leadRecordTypes) {
        return processInactiveAdvisorsAndSendEmails(emailTemplateName, leadRecordTypes, DEFAULT_ADVISOR_PROFILES);
    }
    
    /**
     * @description Método principal para procesar asesores inactivos y enviar notificaciones
     * @param emailTemplateName Nombre del developer del email template a usar
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @param advisorProfiles Set de perfiles de asesores a considerar
     * @return ProcessResult Resultado del procesamiento
     */
    public ProcessResult processInactiveAdvisorsAndSendEmails(String emailTemplateName, Set<String> leadRecordTypes, Set<String> advisorProfiles) {
        ProcessResult result = new ProcessResult();
        
        try {
            logMessage('Iniciando procesamiento de asesores sin actividad');
            
            // 1. Obtener todos los asesores activos con sus managers
            List<User> activeAdvisors = getActiveAdvisors(advisorProfiles);
            if (activeAdvisors.isEmpty()) {
                return buildSuccessResult(result, 'No se encontraron asesores activos para procesar');
            }
            
            logMessage('Asesores activos encontrados: ' + activeAdvisors.size());
            
            // 2. Identificar asesores sin actividad reciente
            Map<Id, List<User>> managersToInactiveAdvisors = identifyInactiveAdvisors(activeAdvisors, leadRecordTypes);
            
            if (managersToInactiveAdvisors.isEmpty()) {
                return buildSuccessResult(result, 'No se encontraron asesores sin actividad');
            }
            
            // 3. Construir emails de notificación
            List<Messaging.SingleEmailMessage> emails = buildNotificationEmails(managersToInactiveAdvisors, emailTemplateName);
            
            if (emails.isEmpty()) {
                return buildErrorResult(result, 'No se pudieron construir los emails de notificación');
            }
            
            // 4. Enviar emails usando VEC_EmailSendBatch
            String batchJobId = sendEmailsViaBatch(emails);
            
            // 5. Preparar resultado exitoso
            result = buildFinalResult(managersToInactiveAdvisors, batchJobId);
            
            logMessage('Procesamiento completado exitosamente');
            
        } catch (Exception e) {
            result = buildExceptionResult(e);
        }
        
        result.processingLog = new List<String>(this.processingLog);
        return result;
    }
    
    /**
     * @description Obtiene todos los asesores activos usando VEC_UserQueries
     * @param advisorProfiles Set de perfiles de asesores
     * @return List<User> Lista de asesores activos
     */
    private List<User> getActiveAdvisors(Set<String> advisorProfiles) {
        try {
            return userQueries.getActiveAdvisorsWithManagers(advisorProfiles);
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
            // Extraer IDs de asesores
            Set<Id> advisorIds = new Set<Id>();
            for (User advisor : activeAdvisors) {
                advisorIds.add(advisor.Id);
            }
            
            // Obtener asesores con actividad reciente usando VEC_LeadQueries
            Date activityThreshold = Date.today().addDays(ACTIVITY_PERIOD_DAYS);
            Set<Id> activeAdvisorIds = getAdvisorsWithRecentActivity(advisorIds, activityThreshold, leadRecordTypes);
            
            logMessage('Asesores con actividad reciente: ' + activeAdvisorIds.size());
            
            // Consolidar asesores sin actividad por manager
            Integer totalInactiveAdvisors = 0;
            for (User advisor : activeAdvisors) {
                if (!activeAdvisorIds.contains(advisor.Id) && advisor.ManagerId != null) {
                    if (!managersToInactiveAdvisors.containsKey(advisor.ManagerId)) {
                        managersToInactiveAdvisors.put(advisor.ManagerId, new List<User>());
                    }
                    managersToInactiveAdvisors.get(advisor.ManagerId).add(advisor);
                    totalInactiveAdvisors++;
                    
                    logMessage('Asesor sin actividad: ' + advisor.Name + ' (Manager: ' + advisor.Manager?.Name + ')');
                }
            }
            
            logMessage('Total asesores sin actividad: ' + totalInactiveAdvisors);
            logMessage('Managers a notificar: ' + managersToInactiveAdvisors.size());
            
        } catch (Exception e) {
            logMessage('Error identificando asesores inactivos: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al identificar asesores inactivos: ' + e.getMessage(), e);
        }
        
        return managersToInactiveAdvisors;
    }
    
    /**
     * @description Obtiene asesores con actividad reciente de Leads
     * @param advisorIds Set de IDs de asesores
     * @param activityThreshold Fecha límite de actividad
     * @param leadRecordTypes Set de RecordTypes de Lead a considerar para actividad
     * @return Set<Id> IDs de asesores con actividad reciente
     */
    private Set<Id> getAdvisorsWithRecentActivity(Set<Id> advisorIds, Date activityThreshold, Set<String> leadRecordTypes) {
        Set<Id> activeAdvisors = new Set<Id>();
        
        try {
            List<Lead> recentLeads = leadQueries.getManualLeadsByAdvisors(advisorIds, activityThreshold, leadRecordTypes);
            
            // Filtrar solo Leads creados manualmente (CreatedById = OwnerId)
            for (Lead lead : recentLeads) {
                if (lead.CreatedById == lead.OwnerId) {
                    activeAdvisors.add(lead.CreatedById);
                }
            }
            
        } catch (Exception e) {
            logMessage('Error consultando actividad de Leads: ' + e.getMessage());
            throw new ProspectActivityEmailServiceException('Error al consultar actividad de Leads: ' + e.getMessage(), e);
        }
        
        return activeAdvisors;
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
        
        // Calcular total de asesores sin actividad
        Integer totalInactiveAdvisors = 0;
        for (List<User> advisors : managersToInactiveAdvisors.values()) {
            totalInactiveAdvisors += advisors.size();
        }
        result.advisorsWithoutActivity = totalInactiveAdvisors;
        
        result.message = String.format(
            'Procesamiento exitoso: {0} managers notificados sobre {1} asesores sin actividad. Batch Job ID: {2}',
            new List<Object>{ result.managersNotified, result.advisorsWithoutActivity, batchJobId }
        );
        
        return result;
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
        String timestamp = DateTime.now().format('yyyy-MM-dd HH:mm:ss');
        String logEntry = '[' + timestamp + '] VEC_ProspectActivityEmailService: ' + message;
        
        this.processingLog.add(logEntry);
        System.debug(logEntry);
    }
    
    /**
     * @description Excepción personalizada para el service
     */
    public class ProspectActivityEmailServiceException extends Exception {}
}