/**
 * @description Batch class para procesar asesores sin actividad de prospectos y notificar a managers
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Batch para identificar asesores
 *         |            |         | sin actividad y generar notificaciones a managers
 * 1.1     | 2025-10-17 | Sistema | Ajustes: Solo Leads, RecordType "Empresas U4O",
 *         |            |         | No convertidos, Lote de 50 registros
 * 1.2     | 2025-10-17 | Sistema | Refactoring: Uso de VEC_LeadQueries para
 *         |            |         | centralizar consultas SOQL
 * 1.3     | 2025-10-17 | Sistema | Separación: Uso de VEC_UserQueries, VEC_LeadQueries
 *         |            |         | y VEC_SystemQueries según responsabilidades
 * 1.4     | 2025-10-17 | Sistema | Fix: Consolidación garantizada - UN solo email
 *         |            |         | por manager con TODOS sus asesores sin actividad
 * 1.5     | 2025-10-17 | Sistema | SonarCloud: Separación de responsabilidades con
 *         |            |         | EmailBuilder, constantes, manejo de excepciones
 * =============================================================================
 */
public class VEC_ProspectActivityBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Constantes para evitar números mágicos (SonarCloud)
    private static final Integer ACTIVITY_PERIOD_DAYS = -14;
    private static final String ADVISOR_PROFILE_NAME = 'VEC Asesor U4O';
    private static final String MANAGER_PROFILE_NAME = 'Gerente U4O';
    private static final String INVALID_EMAIL_PATTERN = '%.invalid';
    
    // Variables para tracking durante la ejecución del batch
    private final Map<Id, List<User>> managersToAdvisorsMap;
    private final List<String> errorLog;
    
    // Instancias de consultas y builder
    private final VEC_LeadQueries leadQueries;
    private final VEC_ProspectActivityEmailBuilder emailBuilder;
    
    /**
     * @description Constructor del batch con inyección de dependencias
     */
    public VEC_ProspectActivityBatch() {
        this.managersToAdvisorsMap = new Map<Id, List<User>>();
        this.errorLog = new List<String>();
        this.leadQueries = new VEC_LeadQueries();
        this.emailBuilder = new VEC_ProspectActivityEmailBuilder();
    }
    
    /**
     * @description Constructor para testing con mocks
     * @param leadQueries Mock de lead queries
     * @param emailBuilder Mock de email builder
     */
    public VEC_ProspectActivityBatch(VEC_LeadQueries leadQueries, VEC_ProspectActivityEmailBuilder emailBuilder) {
        this.managersToAdvisorsMap = new Map<Id, List<User>>();
        this.errorLog = new List<String>();
        this.leadQueries = leadQueries;
        this.emailBuilder = emailBuilder;
    }
    
    /**
     * @description Método start del batch - obtiene todos los asesores activos
     * @param bc Contexto del batch
     * @return Database.QueryLocator Query locator con los asesores
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('VEC_ProspectActivityBatch: Iniciando batch de verificación de actividad');
        
        // Query parametrizada usando constantes (SonarCloud)
        String query = buildAdvisorQuery();
        
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Construye la query para obtener asesores activos
     * @return String Query SOQL
     */
    private String buildAdvisorQuery() {
        return 'SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Profile.Name ' +
               'FROM User ' +
               'WHERE IsActive = true ' +
               'AND Profile.Name = :ADVISOR_PROFILE_NAME ' +
               'AND Email != null ' +
               'AND (NOT Email LIKE :INVALID_EMAIL_PATTERN) ' +
               'AND ManagerId != null ' +
               'AND Manager.IsActive = true ' +
               'AND Manager.Profile.Name = :MANAGER_PROFILE_NAME ' +
               'AND (NOT Manager.Email LIKE :INVALID_EMAIL_PATTERN)';
    }
    
    /**
     * @description Método execute del batch - procesa cada lote de asesores
     * @param bc Contexto del batch
     * @param scope Lista de registros a procesar
     */
    public void execute(Database.BatchableContext bc, List<User> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('VEC_ProspectActivityBatch: Scope vacío, saltando procesamiento');
            return;
        }
        
        try {
            System.debug('VEC_ProspectActivityBatch: Procesando lote de ' + scope.size() + ' asesores');
            
            // Extraer IDs de asesores
            Set<Id> advisorIds = extractAdvisorIds(scope);
            
            // Verificar actividad reciente
            Date activityThreshold = Date.today().addDays(ACTIVITY_PERIOD_DAYS);
            Set<Id> activeAdvisorIds = getAdvisorsWithRecentActivity(advisorIds, activityThreshold);
            
            // Consolidar asesores sin actividad por manager
            consolidateInactiveAdvisors(scope, activeAdvisorIds);
            
            System.debug('VEC_ProspectActivityBatch: Total managers acumulados: ' + managersToAdvisorsMap.size());
            
        } catch (Exception e) {
            handleExecuteException(e);
        }
    }
    
    /**
     * @description Extrae los IDs de los asesores del scope
     * @param scope Lista de usuarios
     * @return Set<Id> Set de IDs de asesores
     */
    private Set<Id> extractAdvisorIds(List<User> scope) {
        Set<Id> advisorIds = new Set<Id>();
        for (User advisor : scope) {
            if (advisor?.Id != null) {
                advisorIds.add(advisor.Id);
            }
        }
        return advisorIds;
    }
    
    /**
     * @description Consolida asesores sin actividad agrupados por manager
     * @param scope Lista de asesores del lote actual
     * @param activeAdvisorIds Set de IDs de asesores con actividad reciente
     */
    private void consolidateInactiveAdvisors(List<User> scope, Set<Id> activeAdvisorIds) {
        for (User advisor : scope) {
            if (advisor?.Id != null && advisor?.ManagerId != null && !activeAdvisorIds.contains(advisor.Id)) {
                // Asesor sin actividad - agregar a la lista del manager
                if (!managersToAdvisorsMap.containsKey(advisor.ManagerId)) {
                    managersToAdvisorsMap.put(advisor.ManagerId, new List<User>());
                }
                managersToAdvisorsMap.get(advisor.ManagerId).add(advisor);
                
                System.debug('VEC_ProspectActivityBatch: Asesor sin actividad: ' + advisor.Name + 
                           ' (Manager: ' + advisor.Manager?.Name + ')');
            }
        }
    }
    
    /**
     * @description Maneja excepciones del método execute
     * @param e Excepción capturada
     */
    private void handleExecuteException(Exception e) {
        String error = 'Error en execute: ' + e.getMessage() + ' - ' + e.getStackTraceString();
        errorLog.add(error);
        System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityBatch: ' + error);
    }
    
    /**
     * @description Método finish del batch - construye y envía notificaciones consolidadas
     * @param bc Contexto del batch
     */
    public void finish(Database.BatchableContext bc) {
        try {
            System.debug('VEC_ProspectActivityBatch: Finalizando batch. Managers a notificar: ' + managersToAdvisorsMap.size());
            
            logManagersSummary();
            
            if (!managersToAdvisorsMap.isEmpty()) {
                processEmailNotifications();
            } else {
                System.debug('VEC_ProspectActivityBatch: No hay asesores sin actividad - No se enviarán emails');
            }
            
            logFinalSummary();
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityBatch finish error: ' + e.getMessage());
        }
    }
    
    /**
     * @description Procesa las notificaciones por email usando el builder
     */
    private void processEmailNotifications() {
        try {
            System.debug('VEC_ProspectActivityBatch: Construyendo emails...');
            
            // Usar el builder para construir emails
            List<Messaging.SingleEmailMessage> emails = emailBuilder.buildManagerNotificationEmails(managersToAdvisorsMap);
            
            if (!emails.isEmpty()) {
                // Enviar emails usando el processor
                VEC_ProspectActivityEmailProcessor emailProcessor = new VEC_ProspectActivityEmailProcessor();
                System.enqueueJob(emailProcessor.processPreBuiltEmails(emails));
                
                System.debug('VEC_ProspectActivityBatch: ' + emails.size() + ' emails construidos y encolados para envío');
            } else {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityBatch: No se pudieron construir emails');
            }
            
        } catch (Exception e) {
            String errorMsg = 'Error procesando notificaciones: ' + e.getMessage();
            errorLog.add(errorMsg);
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityBatch: ' + errorMsg);
        }
    }
    
    /**
     * @description Registra resumen de managers y sus asesores sin actividad
     */
    private void logManagersSummary() {
        for (Id managerId : managersToAdvisorsMap.keySet()) {
            List<User> advisorsWithoutActivity = managersToAdvisorsMap.get(managerId);
            System.debug('VEC_ProspectActivityBatch: Manager ' + managerId + 
                       ' tiene ' + advisorsWithoutActivity.size() + ' asesores sin actividad');
            
            for (User advisor : advisorsWithoutActivity) {
                System.debug('  - ' + advisor.Name + ' (' + advisor.Email + ')');
            }
        }
    }
    
    /**
     * @description Registra estadísticas finales del proceso
     */
    private void logFinalSummary() {
        Integer totalAdvisorsWithoutActivity = 0;
        for (List<User> advisors : managersToAdvisorsMap.values()) {
            totalAdvisorsWithoutActivity += advisors.size();
        }
        
        System.debug('VEC_ProspectActivityBatch: RESUMEN FINAL:');
        System.debug('  - Managers a notificar: ' + managersToAdvisorsMap.size());
        System.debug('  - Total asesores sin actividad: ' + totalAdvisorsWithoutActivity);
        System.debug('  - Emails que se enviarán: ' + managersToAdvisorsMap.size() + ' (UNO por manager)');
        
        if (!errorLog.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityBatch: Errores encontrados: ' + String.join(errorLog, '\n'));
        }
    }
    
    /**
     * @description Obtiene asesores que han creado Leads manuales recientemente
     * @param advisorIds Set de IDs de asesores a verificar
     * @param fromDate Fecha desde la cual verificar actividad
     * @return Set<Id> IDs de asesores con actividad reciente
     */
    private Set<Id> getAdvisorsWithRecentActivity(Set<Id> advisorIds, Date fromDate) {
        Set<Id> activeAdvisors = new Set<Id>();
        
        // Usar consulta centralizada para obtener Leads manuales
        List<Lead> recentLeads = leadQueries.getManualLeadsByAdvisors(advisorIds, fromDate);
        
        // Filtrar solo Leads creados manualmente (CreatedById = OwnerId)
        for (Lead lead : recentLeads) {
            if (lead.CreatedById == lead.OwnerId) {
                activeAdvisors.add(lead.CreatedById);
            }
        }
        
        System.debug('VEC_ProspectActivityBatch: ' + activeAdvisors.size() + ' asesores con actividad reciente de Leads encontrados');
        return activeAdvisors;
    }
}