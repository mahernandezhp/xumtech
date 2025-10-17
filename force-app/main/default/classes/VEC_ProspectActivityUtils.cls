/**
 * @description Clase utilitaria para testing y ejecución manual del sistema de alertas de actividad
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Utilidades para testing
 *         |            |         | y ejecución manual del sistema
 * 1.1     | 2025-10-17 | Sistema | Refactoring: Uso de VEC_LeadQueries para
 *         |            |         | centralizar consultas SOQL y validaciones
 * 1.2     | 2025-10-17 | Sistema | Separación: Uso de VEC_UserQueries, VEC_LeadQueries
 *         |            |         | y VEC_SystemQueries según responsabilidades
 * =============================================================================
 */
public class VEC_ProspectActivityUtils {
    
    // Instancias de consultas especializadas
    private VEC_UserQueries userQueries;
    private VEC_LeadQueries leadQueries;
    private VEC_EmailTemplateQueries emailTemplateQueries;
    private VEC_OrgWideEmailAddressQueries orgWideEmailQueries;
    private VEC_RecordTypeQueries recordTypeQueries;
    private VEC_CronTriggerQueries cronTriggerQueries;
    
    /**
     * @description Constructor
     */
    public VEC_ProspectActivityUtils() {
        this.userQueries = new VEC_UserQueries();
        this.leadQueries = new VEC_LeadQueries();
        this.emailTemplateQueries = new VEC_EmailTemplateQueries();
        this.orgWideEmailQueries = new VEC_OrgWideEmailAddressQueries();
        this.recordTypeQueries = new VEC_RecordTypeQueries();
        this.cronTriggerQueries = new VEC_CronTriggerQueries();
    }
    
    /**
     * @description Ejecuta el proceso completo de verificación de actividad manualmente
     * @return String Resultado de la ejecución
     */
    public String executeManualCheck() {
        try {
            VEC_ProspectActivityBatch batch = new VEC_ProspectActivityBatch();
            Id batchId = Database.executeBatch(batch, 50); // Ajustado a 50 para respetar límites
            
            return 'Batch ejecutado exitosamente. Job ID: ' + batchId;
            
        } catch (Exception e) {
            return 'Error ejecutando batch: ' + e.getMessage();
        }
    }
    
    /**
     * @description Programa el job de verificación de actividad
     * @return String Resultado de la programación
     */
    public String scheduleProspectActivityJob() {
        try {
            // Cancelar jobs existentes primero
            VEC_ProspectActivityScheduler.cancelExistingJobs();
            
            // Programar nuevo job
            String jobId = VEC_ProspectActivityScheduler.scheduleJob();
            
            return 'Job programado exitosamente. Job ID: ' + jobId;
            
        } catch (Exception e) {
            return 'Error programando job: ' + e.getMessage();
        }
    }
    
    /**
     * @description Obtiene estadísticas de asesores y actividad
     * @return String Reporte de estadísticas
     */
    public String getActivityStatistics() {
        try {
            // Usar consultas centralizadas de usuarios para contar
            Integer totalAdvisors = userQueries.countActiveAdvisors();
            Integer totalManagers = userQueries.countActiveManagers();
            
            // Actividad reciente (últimos 14 días) - Solo Leads
            Date twoWeeksAgo = Date.today().addDays(-14);
            
            Set<Id> activeAdvisorIds = new Set<Id>();
            
            // Obtener todos los asesores para verificar su actividad
            List<User> allAdvisors = userQueries.getActiveAdvisorsWithManagers();
            Set<Id> allAdvisorIds = new Set<Id>();
            for (User advisor : allAdvisors) {
                allAdvisorIds.add(advisor.Id);
            }
            
            // Usar consulta centralizada para obtener Leads manuales
            List<Lead> recentLeads = leadQueries.getManualLeadsByAdvisors(allAdvisorIds, twoWeeksAgo);
            
            // Filtrar Leads creados manualmente
            for (Lead lead : recentLeads) {
                if (lead.CreatedById == lead.OwnerId) {
                    activeAdvisorIds.add(lead.CreatedById);
                }
            }
            
            Integer advisorsWithActivity = activeAdvisorIds.size();
            Integer advisorsWithoutActivity = totalAdvisors - advisorsWithActivity;
            
            String report = 'ESTADÍSTICAS DE ACTIVIDAD DE LEADS\n';
            report += '=====================================\n';
            report += 'Total Asesores Activos: ' + totalAdvisors + '\n';
            report += 'Total Managers Activos: ' + totalManagers + '\n';
            report += 'Asesores con Actividad de Leads (14 días): ' + advisorsWithActivity + '\n';
            report += 'Asesores SIN Actividad de Leads (14 días): ' + advisorsWithoutActivity + '\n';
            report += 'Porcentaje de Actividad: ' + (totalAdvisors > 0 ? (advisorsWithActivity * 100 / totalAdvisors) : 0) + '%\n';
            report += 'Criterios: Leads RecordType "Empresas U4O", No Convertidos, Creación Manual\n';
            report += 'Fecha de Consulta: ' + System.now().format() + '\n';
            
            return report;
            
        } catch (Exception e) {
            return 'Error obteniendo estadísticas: ' + e.getMessage();
        }
    }
    
    /**
     * @description Valida la configuración del sistema antes de la ejecución
     * @return String Resultado de la validación
     */
    public String validateSystemConfiguration() {
        List<String> issues = new List<String>();
        
        try {
            // Verificar Email Template usando consulta centralizada del sistema
            EmailTemplate template = emailTemplateQueries.getProspectActivityEmailTemplate();
            if (template == null) {
                issues.add('❌ Email Template "VEC_Manager_Prospect_Activity_Alert" no encontrado');
            } else {
                issues.add('✅ Email Template configurado correctamente');
            }
            
            // Verificar OrgWideEmailAddress usando consulta centralizada del sistema
            OrgWideEmailAddress orgEmail = orgWideEmailQueries.getOrgWideEmailAddress();
            if (orgEmail == null) {
                issues.add('❌ No hay OrgWideEmailAddress configurado');
            } else {
                issues.add('✅ OrgWideEmailAddress disponible: ' + orgEmail.Address);
            }
            
            // Verificar perfiles usando consulta centralizada de usuarios
            Map<String, Integer> profileCounts = userQueries.getUserCountsByProfile();
            
            Integer advisorCount = profileCounts.get('VEC Asesor U4O') != null ? profileCounts.get('VEC Asesor U4O') : 0;
            Integer managerCount = profileCounts.get('Gerente U4O') != null ? profileCounts.get('Gerente U4O') : 0;
            
            issues.add('✅ Asesores encontrados: ' + advisorCount);
            issues.add('✅ Managers encontrados: ' + managerCount);
            
            if (advisorCount == 0) {
                issues.add('⚠️ No se encontraron asesores con perfil "VEC Asesor U4O"');
            }
            
            if (managerCount == 0) {
                issues.add('⚠️ No se encontraron managers con perfil "Gerente U4O"');
            }
            
            // Verificar RecordType usando consulta centralizada del sistema
            Boolean recordTypeExists = recordTypeQueries.validateLeadRecordType('Empresas_U4O');
            if (recordTypeExists) {
                issues.add('✅ RecordType "Empresas U4O" para Leads configurado');
            } else {
                issues.add('❌ RecordType "Empresas U4O" para Leads no encontrado');
            }
            
            // Verificar jobs programados usando consulta centralizada del sistema
            List<CronTrigger> scheduledJobs = cronTriggerQueries.getScheduledProspectActivityJobs();
            
            if (scheduledJobs.isEmpty()) {
                issues.add('❌ No hay jobs programados');
            } else {
                for (CronTrigger job : scheduledJobs) {
                    issues.add('✅ Job programado: ' + job.CronJobDetail.Name + ' (Estado: ' + job.State + ')');
                }
            }
            
        } catch (Exception e) {
            issues.add('❌ Error durante validación: ' + e.getMessage());
        }
        
        return 'VALIDACIÓN DE CONFIGURACIÓN\n' +
               '============================\n' +
               String.join(issues, '\n') + '\n';
    }
    
    /**
     * @description Método para ejecutar desde Developer Console
     * Ejemplo de uso: VEC_ProspectActivityUtils utils = new VEC_ProspectActivityUtils(); utils.runFromConsole();
     */
    public void runFromConsole() {
        System.debug('=== VEC PROSPECT ACTIVITY SYSTEM ===');
        System.debug(validateSystemConfiguration());
        System.debug(getActivityStatistics());
        System.debug('=======================================');
    }
}