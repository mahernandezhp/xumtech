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
 * =============================================================================
 */
public class VEC_ProspectActivityBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    // Variables para tracking durante la ejecución del batch
    private Map<Id, List<User>> managersToAdvisorsMap;
    private Set<String> processedManagers;
    private Integer emailsSent;
    private List<String> errorLog;
    
    // Instancias de consultas
    private VEC_LeadQueries leadQueries;
    
    /**
     * @description Constructor del batch
     */
    public VEC_ProspectActivityBatch() {
        this.managersToAdvisorsMap = new Map<Id, List<User>>();
        this.processedManagers = new Set<String>();
        this.emailsSent = 0;
        this.errorLog = new List<String>();
        this.leadQueries = new VEC_LeadQueries();
    }
    
    /**
     * @description Método start del batch - obtiene todos los asesores activos
     * @param bc Contexto del batch
     * @return Database.QueryLocator Query locator con los asesores
     */
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug('VEC_ProspectActivityBatch: Iniciando batch de verificación de actividad');
        
        // Usar consulta centralizada para obtener asesores activos
        String query = 'SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Profile.Name ' +
                      'FROM User ' +
                      'WHERE IsActive = true ' +
                      'AND Profile.Name = \'VEC Asesor U4O\' ' +
                      'AND Email != null ' +
                      'AND (NOT Email LIKE \'%.invalid\') ' +
                      'AND ManagerId != null ' +
                      'AND Manager.IsActive = true ' +
                      'AND Manager.Profile.Name = \'Gerente U4O\' ' +
                      'AND (NOT Manager.Email LIKE \'%.invalid\')';
        
        return Database.getQueryLocator(query);
    }
    
    /**
     * @description Método execute del batch - procesa cada lote de asesores
     * @param bc Contexto del batch
     * @param scope Lista de registros a procesar
     */
    public void execute(Database.BatchableContext bc, List<User> scope) {
        try {
            System.debug('VEC_ProspectActivityBatch: Procesando lote de ' + scope.size() + ' asesores');
            
            // Obtener IDs de asesores
            Set<Id> advisorIds = new Set<Id>();
            for (User advisor : scope) {
                advisorIds.add(advisor.Id);
            }
            
            // Verificar actividad de prospectos en los últimos 14 días
            Date twoWeeksAgo = Date.today().addDays(-14);
            Set<Id> activeAdvisorIds = getAdvisorsWithRecentActivity(advisorIds, twoWeeksAgo);
            
            // Identificar asesores SIN actividad y agrupar por manager
            for (User advisor : scope) {
                if (!activeAdvisorIds.contains(advisor.Id)) {
                    // Este asesor NO ha creado prospectos manuales en 2 semanas
                    if (!managersToAdvisorsMap.containsKey(advisor.ManagerId)) {
                        managersToAdvisorsMap.put(advisor.ManagerId, new List<User>());
                    }
                    managersToAdvisorsMap.get(advisor.ManagerId).add(advisor);
                }
            }
            
        } catch (Exception e) {
            String error = 'Error en execute: ' + e.getMessage() + ' - ' + e.getStackTraceString();
            errorLog.add(error);
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityBatch: ' + error);
        }
    }
    
    /**
     * @description Método finish del batch - envía notificaciones consolidadas
     * @param bc Contexto del batch
     */
    public void finish(Database.BatchableContext bc) {
        try {
            System.debug('VEC_ProspectActivityBatch: Finalizando batch. Managers a notificar: ' + managersToAdvisorsMap.size());
            
            if (!managersToAdvisorsMap.isEmpty()) {
                // Procesar notificaciones por lotes para respetar límites
                VEC_ProspectActivityEmailProcessor emailProcessor = new VEC_ProspectActivityEmailProcessor();
                System.enqueueJob(emailProcessor.processManagerNotifications(managersToAdvisorsMap));
            }
            
            // Log final
            System.debug('VEC_ProspectActivityBatch: Proceso completado');
            if (!errorLog.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityBatch: Errores encontrados: ' + String.join(errorLog, '\n'));
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityBatch finish error: ' + e.getMessage());
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