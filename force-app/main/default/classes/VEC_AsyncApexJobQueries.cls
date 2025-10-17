/**
 * @description Clase centralizada para consultas SOQL de AsyncApexJob
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para AsyncApexJob del sistema VEC
 * =============================================================================
 */
public class VEC_AsyncApexJobQueries {
    
    /**
     * @description Constructor
     */
    public VEC_AsyncApexJobQueries() {
        // Constructor vacío - no necesita configuración específica
    }
    
    /**
     * @description Obtiene información de AsyncApexJob para monitoreo de batches
     * @param jobTypes Lista de tipos de job a buscar (ej: 'BatchApex', 'Queueable')
     * @return List<AsyncApexJob> Lista de jobs async
     */
    public List<AsyncApexJob> getAsyncApexJobs(List<String> jobTypes) {
        return [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE JobType IN :jobTypes
            AND ApexClass.Name LIKE 'VEC%'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description Obtiene todos los AsyncApexJob del sistema VEC
     * @return List<AsyncApexJob> Lista de jobs VEC
     */
    public List<AsyncApexJob> getVECAsyncApexJobs() {
        return [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE ApexClass.Name LIKE 'VEC%'
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];
    }
    
    /**
     * @description Obtiene AsyncApexJob por ID específico
     * @param jobId ID del job a buscar
     * @return AsyncApexJob Job encontrado o null si no existe
     */
    public AsyncApexJob getAsyncApexJobById(Id jobId) {
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE Id = :jobId
            LIMIT 1
        ];
        
        return jobs.isEmpty() ? null : jobs[0];
    }
    
    /**
     * @description Obtiene AsyncApexJob por clase específica
     * @param apexClassName Nombre de la clase Apex
     * @return List<AsyncApexJob> Lista de jobs para la clase
     */
    public List<AsyncApexJob> getAsyncApexJobsByClass(String apexClassName) {
        return [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE ApexClass.Name = :apexClassName
            ORDER BY CreatedDate DESC
            LIMIT 20
        ];
    }
    
    /**
     * @description Obtiene AsyncApexJob por estado específico
     * @param statuses Lista de estados a filtrar (Completed, Processing, Aborted, etc.)
     * @return List<AsyncApexJob> Lista de jobs en los estados especificados
     */
    public List<AsyncApexJob> getAsyncApexJobsByStatus(List<String> statuses) {
        return [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE ApexClass.Name LIKE 'VEC%'
            AND Status IN :statuses
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description Cuenta AsyncApexJob activos del sistema VEC
     * @return Integer Número de jobs en proceso
     */
    public Integer countActiveVECJobs() {
        try {
            return [
                SELECT COUNT()
                FROM AsyncApexJob
                WHERE ApexClass.Name LIKE 'VEC%'
                AND Status IN ('Processing', 'Preparing', 'Queued')
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_AsyncApexJobQueries: Error contando jobs: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Obtiene estadísticas de AsyncApexJob por tipo
     * @return Map<String, Integer> Estadísticas por tipo de job
     */
    public Map<String, Integer> getJobStatisticsByType() {
        Map<String, Integer> statistics = new Map<String, Integer>();
        
        try {
            List<AggregateResult> results = [
                SELECT JobType, COUNT(Id) jobCount
                FROM AsyncApexJob
                WHERE ApexClass.Name LIKE 'VEC%'
                GROUP BY JobType
            ];
            
            for (AggregateResult ar : results) {
                String jobType = (String) ar.get('JobType');
                Integer count = (Integer) ar.get('jobCount');
                statistics.put(jobType, count);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_AsyncApexJobQueries: Error obteniendo estadísticas: ' + e.getMessage());
        }
        
        return statistics;
    }
}