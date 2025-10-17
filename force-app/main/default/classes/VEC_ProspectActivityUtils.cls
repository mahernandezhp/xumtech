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
 * =============================================================================
 */
public class VEC_ProspectActivityUtils {
    
    /**
     * @description Ejecuta el proceso completo de verificación de actividad manualmente
     * @return String Resultado de la ejecución
     */
    public static String executeManualCheck() {
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
    public static String scheduleProspectActivityJob() {
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
    public static String getActivityStatistics() {
        try {
            // Contar asesores activos
            Integer totalAdvisors = [
                SELECT COUNT()
                FROM User 
                WHERE IsActive = true
                AND Profile.Name = 'VEC Asesor U4O'
                AND Email != null
                AND (NOT Email LIKE '%.invalid')
                AND ManagerId != null
            ];
            
            // Contar managers activos
            Integer totalManagers = [
                SELECT COUNT()
                FROM User 
                WHERE IsActive = true
                AND Profile.Name = 'Gerente U4O'
                AND Email != null
                AND (NOT Email LIKE '%.invalid')
            ];
            
            // Actividad reciente (últimos 14 días) - Solo Leads
            Date twoWeeksAgo = Date.today().addDays(-14);
            
            Set<Id> activeAdvisorIds = new Set<Id>();
            
            // Leads creados manualmente con RecordType "Empresas U4O" y no convertidos
            for (Lead lead : [
                SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted
                FROM Lead
                WHERE CreatedDate >= :twoWeeksAgo
                AND IsConverted = false
                AND RecordType.DeveloperName = 'Empresas_U4O'
            ]) {
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
    public static String validateSystemConfiguration() {
        List<String> issues = new List<String>();
        
        try {
            // Verificar Email Template
            List<EmailTemplate> templates = [
                SELECT Id, Name 
                FROM EmailTemplate 
                WHERE DeveloperName = 'VEC_Manager_Prospect_Activity_Alert'
            ];
            
            if (templates.isEmpty()) {
                issues.add('❌ Email Template "VEC_Manager_Prospect_Activity_Alert" no encontrado');
            } else {
                issues.add('✅ Email Template configurado correctamente');
            }
            
            // Verificar OrgWideEmailAddress
            List<OrgWideEmailAddress> orgEmails = [
                SELECT Id, Address, DisplayName
                FROM OrgWideEmailAddress 
                WHERE IsAllowAllProfiles = true
            ];
            
            if (orgEmails.isEmpty()) {
                issues.add('❌ No hay OrgWideEmailAddress configurado');
            } else {
                issues.add('✅ OrgWideEmailAddress disponible: ' + orgEmails[0].Address);
            }
            
            // Verificar perfiles
            Map<String, Integer> profileCounts = new Map<String, Integer>();
            
            for (AggregateResult ar : [
                SELECT Profile.Name profileName, COUNT(Id) userCount
                FROM User 
                WHERE IsActive = true
                AND Profile.Name IN ('VEC Asesor U4O', 'Gerente U4O')
                GROUP BY Profile.Name
            ]) {
                profileCounts.put((String)ar.get('profileName'), (Integer)ar.get('userCount'));
            }
            
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
            
            // Verificar jobs programados
            List<CronTrigger> scheduledJobs = [
                SELECT Id, CronJobDetail.Name, State, NextFireTime
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE 'VEC Prospect Activity Alert%'
            ];
            
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
     * Ejemplo de uso: VEC_ProspectActivityUtils.runFromConsole();
     */
    public static void runFromConsole() {
        System.debug('=== VEC PROSPECT ACTIVITY SYSTEM ===');
        System.debug(validateSystemConfiguration());
        System.debug(getActivityStatistics());
        System.debug('=======================================');
    }
}