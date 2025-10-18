/**
 * @description Clase centralizada para todas las consultas SOQL relacionadas con Leads
 * @author Sistema
 * @version 1.4
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
 * 1.3     | 2025-10-17 | Sistema | Flexibilidad: RecordTypes como Set<String>
 *         |            |         | en parámetros con métodos legacy compatibles
 * 1.4     | 2025-10-17 | Sistema | Limpieza: Remoción de métodos no utilizados
 *         |            |         | por otras clases VEC_ para simplificar clase
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
     * @param recordTypes Set de nombres de RecordTypes a filtrar
     * @return List<Lead> Lista de Leads que cumplen criterios
     */
    public List<Lead> getManualLeadsByAdvisors(Set<Id> advisorIds, Date fromDate, Set<String> recordTypes) {
        return [
            SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted, Name, CreatedDate
            FROM Lead
            WHERE CreatedById IN :advisorIds
            AND CreatedDate >= :fromDate
            AND IsConverted = false
            AND RecordType.DeveloperName IN :recordTypes
        ];
    }
    
    /**
     * @description Obtiene Leads creados manualmente por asesores específicos en un período (método legacy)
     * @param advisorIds Set de IDs de asesores a verificar
     * @param fromDate Fecha desde la cual verificar actividad
     * @return List<Lead> Lista de Leads que cumplen criterios
     */
    public List<Lead> getManualLeadsByAdvisors(Set<Id> advisorIds, Date fromDate) {
        Set<String> defaultRecordTypes = new Set<String>{ this.leadRecordType };
        return getManualLeadsByAdvisors(advisorIds, fromDate, defaultRecordTypes);
    }
}