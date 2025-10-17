/**
 * @description Clase centralizada para consultas de límites del sistema Salesforce
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para límites del sistema Salesforce
 * =============================================================================
 */
public class VEC_SystemLimitsQueries {
    
    /**
     * @description Constructor
     */
    public VEC_SystemLimitsQueries() {
        // Constructor vacío - no necesita configuración específica
    }
    
    /**
     * @description Obtiene configuración de límites del sistema
     * @return Map<String, Object> Información de límites relevantes
     */
    public Map<String, Object> getSystemLimits() {
        Map<String, Object> limits = new Map<String, Object>();
        
        limits.put('emailInvocations', Limits.getEmailInvocations());
        limits.put('limitEmailInvocations', Limits.getLimitEmailInvocations());
        limits.put('dmlStatements', Limits.getDmlStatements());
        limits.put('limitDmlStatements', Limits.getLimitDmlStatements());
        limits.put('queries', Limits.getQueries());
        limits.put('limitQueries', Limits.getLimitQueries());
        limits.put('heapSize', Limits.getHeapSize());
        limits.put('limitHeapSize', Limits.getLimitHeapSize());
        
        return limits;
    }
    
    /**
     * @description Obtiene límites específicos de email
     * @return Map<String, Integer> Límites de email actuales y máximos
     */
    public Map<String, Integer> getEmailLimits() {
        return new Map<String, Integer>{
            'currentEmailInvocations' => Limits.getEmailInvocations(),
            'maxEmailInvocations' => Limits.getLimitEmailInvocations(),
            'remainingEmails' => Limits.getLimitEmailInvocations() - Limits.getEmailInvocations()
        };
    }
    
    /**
     * @description Obtiene límites específicos de DML
     * @return Map<String, Integer> Límites de DML actuales y máximos
     */
    public Map<String, Integer> getDMLLimits() {
        return new Map<String, Integer>{
            'currentDMLStatements' => Limits.getDmlStatements(),
            'maxDMLStatements' => Limits.getLimitDmlStatements(),
            'remainingDML' => Limits.getLimitDmlStatements() - Limits.getDmlStatements(),
            'currentDMLRows' => Limits.getDmlRows(),
            'maxDMLRows' => Limits.getLimitDmlRows(),
            'remainingDMLRows' => Limits.getLimitDmlRows() - Limits.getDmlRows()
        };
    }
    
    /**
     * @description Obtiene límites específicos de queries SOQL
     * @return Map<String, Integer> Límites de queries actuales y máximos
     */
    public Map<String, Integer> getQueryLimits() {
        return new Map<String, Integer>{
            'currentQueries' => Limits.getQueries(),
            'maxQueries' => Limits.getLimitQueries(),
            'remainingQueries' => Limits.getLimitQueries() - Limits.getQueries(),
            'currentQueryRows' => Limits.getQueryRows(),
            'maxQueryRows' => Limits.getLimitQueryRows(),
            'remainingQueryRows' => Limits.getLimitQueryRows() - Limits.getQueryRows()
        };
    }
    
    /**
     * @description Obtiene límites de memoria heap
     * @return Map<String, Integer> Límites de heap actuales y máximos
     */
    public Map<String, Integer> getHeapLimits() {
        return new Map<String, Integer>{
            'currentHeapSize' => Limits.getHeapSize(),
            'maxHeapSize' => Limits.getLimitHeapSize(),
            'remainingHeap' => Limits.getLimitHeapSize() - Limits.getHeapSize()
        };
    }
    
    /**
     * @description Obtiene límites de CPU time
     * @return Map<String, Integer> Límites de CPU time actuales y máximos
     */
    public Map<String, Integer> getCPULimits() {
        return new Map<String, Integer>{
            'currentCpuTime' => Limits.getCpuTime(),
            'maxCpuTime' => Limits.getLimitCpuTime(),
            'remainingCpuTime' => Limits.getLimitCpuTime() - Limits.getCpuTime()
        };
    }
    
    /**
     * @description Verifica si hay suficientes límites de email disponibles
     * @param emailsToSend Cantidad de emails que se planea enviar
     * @return Boolean True si hay suficientes límites disponibles
     */
    public Boolean hasEmailLimitsAvailable(Integer emailsToSend) {
        Integer remaining = Limits.getLimitEmailInvocations() - Limits.getEmailInvocations();
        return remaining >= emailsToSend;
    }
    
    /**
     * @description Verifica si hay suficientes límites de queries disponibles
     * @param queriesToExecute Cantidad de queries que se planea ejecutar
     * @return Boolean True si hay suficientes límites disponibles
     */
    public Boolean hasQueryLimitsAvailable(Integer queriesToExecute) {
        Integer remaining = Limits.getLimitQueries() - Limits.getQueries();
        return remaining >= queriesToExecute;
    }
    
    /**
     * @description Obtiene un resumen completo de todos los límites críticos
     * @return Map<String, Object> Resumen completo de límites
     */
    public Map<String, Object> getCompleteLimitsReport() {
        Map<String, Object> report = new Map<String, Object>();
        
        report.put('email', getEmailLimits());
        report.put('dml', getDMLLimits());
        report.put('query', getQueryLimits());
        report.put('heap', getHeapLimits());
        report.put('cpu', getCPULimits());
        report.put('timestamp', System.now());
        
        return report;
    }
}