/**
 * @description Clase centralizada para consultas SOQL de CronTrigger
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para CronTrigger del sistema VEC
 * =============================================================================
 */
public class VEC_CronTriggerQueries {
    
    // Variables de instancia para configuración
    private final String jobNamePattern;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_CronTriggerQueries() {
        this.jobNamePattern = 'VEC Prospect Activity Alert%';
    }
    
    /**
     * @description Constructor con configuración personalizada (para testing)
     * @param jobNamePattern Patrón para buscar jobs
     */
    public VEC_CronTriggerQueries(String jobNamePattern) {
        this.jobNamePattern = jobNamePattern;
    }
    
    /**
     * @description Obtiene jobs programados del sistema de alertas
     * @return List<CronTrigger> Lista de jobs programados
     */
    public List<CronTrigger> getScheduledProspectActivityJobs() {
        return [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime, 
                   CronExpression, StartTime, EndTime
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE :jobNamePattern
        ];
    }
    
    /**
     * @description Obtiene todos los CronTriggers activos del sistema VEC
     * @return List<CronTrigger> Lista de jobs VEC activos
     */
    public List<CronTrigger> getVECScheduledJobs() {
        return [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime, 
                   CronExpression, StartTime, EndTime, CronJobDetail.JobType
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'VEC%'
            AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
            ORDER BY NextFireTime
        ];
    }
    
    /**
     * @description Obtiene CronTrigger por nombre específico del job
     * @param jobName Nombre exacto del job
     * @return CronTrigger Job encontrado o null si no existe
     */
    public CronTrigger getCronTriggerByJobName(String jobName) {
        List<CronTrigger> jobs = [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime, 
                   CronExpression, StartTime, EndTime
            FROM CronTrigger 
            WHERE CronJobDetail.Name = :jobName
            LIMIT 1
        ];
        
        return jobs.isEmpty() ? null : jobs[0];
    }
    
    /**
     * @description Obtiene jobs programados por estado específico
     * @param states Lista de estados a filtrar (WAITING, ACQUIRED, EXECUTING, etc.)
     * @return List<CronTrigger> Lista de jobs en los estados especificados
     */
    public List<CronTrigger> getCronTriggersByState(List<String> states) {
        return [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime, 
                   CronExpression, StartTime, EndTime
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'VEC%'
            AND State IN :states
            ORDER BY NextFireTime
        ];
    }
    
    /**
     * @description Cuenta jobs activos del sistema VEC
     * @return Integer Número de jobs activos
     */
    public Integer countActiveVECJobs() {
        try {
            return [
                SELECT COUNT()
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE 'VEC%'
                AND State IN ('WAITING', 'ACQUIRED', 'EXECUTING')
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_CronTriggerQueries: Error contando jobs: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Valida si hay jobs programados para el patrón configurado
     * @return Boolean True si hay jobs programados
     */
    public Boolean hasScheduledJobs() {
        try {
            Integer count = [
                SELECT COUNT()
                FROM CronTrigger 
                WHERE CronJobDetail.Name LIKE :jobNamePattern
                AND State IN ('WAITING', 'ACQUIRED')
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_CronTriggerQueries: Error validando jobs: ' + e.getMessage());
            return false;
        }
    }
}