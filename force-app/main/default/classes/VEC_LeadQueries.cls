/**
 * @description Clase centralizada para todas las consultas SOQL relacionadas con Leads
 * @author Sistema
 * @version 1.2
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Centralización de consultas
 *         |            |         | SOQL para el sistema de alertas de Leads
 * 1.1     | 2025-10-17 | Sistema | Separación: Consultas de User movidas a 
 *         |            |         | VEC_UserQueries, solo Leads aquí
 * 1.2     | 2025-10-17 | Sistema | Refactoring: Remoción de static, métodos de
 *         |            |         | instancia para mejor testing
 * =============================================================================
 */
public class VEC_LeadQueries {
    
    // Variable de instancia para criterios de consulta de Leads
    private final String leadRecordType;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_LeadQueries() {
        this.leadRecordType = 'Empresas_U4O';
    }
    
    /**
     * @description Constructor con RecordType personalizado (para testing)
     * @param leadRecordType Nombre del RecordType de Lead
     */
    public VEC_LeadQueries(String leadRecordType) {
        this.leadRecordType = leadRecordType;
    }
    
    /**
     * @description Obtiene Leads creados manualmente por asesores específicos en un período
     * @param advisorIds Set de IDs de asesores a verificar
     * @param fromDate Fecha desde la cual verificar actividad
     * @return List<Lead> Lista de Leads que cumplen criterios
     */
    public List<Lead> getManualLeadsByAdvisors(Set<Id> advisorIds, Date fromDate) {
        return [
            SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted, Name, CreatedDate
            FROM Lead
            WHERE CreatedById IN :advisorIds
            AND CreatedDate >= :fromDate
            AND IsConverted = false
            AND RecordType.DeveloperName = :leadRecordType
        ];
    }
    
    /**
     * @description Obtiene todos los Leads del RecordType Empresas U4O en un período
     * @param fromDate Fecha desde la cual buscar
     * @return List<Lead> Lista de Leads encontrados
     */
    public List<Lead> getEmpresasLeadsByDate(Date fromDate) {
        return [
            SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted, Name, CreatedDate, Status
            FROM Lead
            WHERE CreatedDate >= :fromDate
            AND RecordType.DeveloperName = :leadRecordType
            AND IsConverted = false
        ];
    }
    
    /**
     * @description Cuenta Leads por asesor en un período específico
     * @param advisorIds Set de IDs de asesores
     * @param fromDate Fecha desde la cual contar
     * @return Map<Id, Integer> Mapa con asesor ID como key y conteo como value
     */
    public Map<Id, Integer> getLeadCountByAdvisor(Set<Id> advisorIds, Date fromDate) {
        Map<Id, Integer> leadCounts = new Map<Id, Integer>();
        
        for (AggregateResult ar : [
            SELECT CreatedById advisorId, COUNT(Id) leadCount
            FROM Lead
            WHERE CreatedById IN :advisorIds
            AND CreatedDate >= :fromDate
            AND IsConverted = false
            AND RecordType.DeveloperName = :leadRecordType
            GROUP BY CreatedById
        ]) {
            leadCounts.put((Id)ar.get('advisorId'), (Integer)ar.get('leadCount'));
        }
        
        return leadCounts;
    }
    
    /**
     * @description Obtiene Leads por Status específico
     * @param status Status del Lead a filtrar
     * @param fromDate Fecha desde la cual buscar
     * @return List<Lead> Lista de Leads con el status especificado
     */
    public List<Lead> getLeadsByStatus(String status, Date fromDate) {
        return [
            SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted, Name, CreatedDate, Status
            FROM Lead
            WHERE Status = :status
            AND CreatedDate >= :fromDate
            AND RecordType.DeveloperName = :leadRecordType
            AND IsConverted = false
        ];
    }
    
    /**
     * @description Obtiene estadísticas de actividad de Leads para un período específico
     * @param fromDate Fecha desde la cual contar actividad
     * @return Map<String, Object> Estadísticas de actividad
     */
    public Map<String, Object> getLeadActivityStats(Date fromDate) {
        Map<String, Object> stats = new Map<String, Object>();
        
        // Contar Leads totales en el período
        Integer totalLeads = [
            SELECT COUNT()
            FROM Lead
            WHERE CreatedDate >= :fromDate
            AND RecordType.DeveloperName = :leadRecordType
            AND IsConverted = false
        ];
        
        // Contar Leads manuales en el período
        Integer manualLeads = 0;
        for (Lead lead : [
            SELECT CreatedById, OwnerId
            FROM Lead
            WHERE CreatedDate >= :fromDate
            AND RecordType.DeveloperName = :leadRecordType
            AND IsConverted = false
        ]) {
            if (lead.CreatedById == lead.OwnerId) {
                manualLeads++;
            }
        }
        
        stats.put('totalLeads', totalLeads);
        stats.put('manualLeads', manualLeads);
        stats.put('automaticLeads', totalLeads - manualLeads);
        stats.put('fromDate', fromDate);
        
        return stats;
    }
    
    /**
     * @description Método utilitario para obtener constantes de Leads
     * @return Map<String, String> Constantes de Leads utilizadas
     */
    public Map<String, String> getLeadConstants() {
        return new Map<String, String>{
            'LEAD_RECORD_TYPE' => leadRecordType
        };
    }
}