/**
 * @description Clase centralizada para todas las consultas SOQL relacionadas con Leads
 * @author Sistema
 * @version 1.5
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
 * 1.5     | 2025-10-17 | Sistema | Validaciones: Agregadas validaciones de parámetros
 *         |            |         | null/vacíos siguiendo recomendaciones SonarCloud
 * =============================================================================
 */
public class VEC_LeadQueries {

    /**
     * @description Obtiene Leads creados manualmente por asesores específicos en un período
     * @param advisorIds Set de IDs de asesores a verificar
     * @param fromDate Fecha desde la cual verificar actividad
     * @param recordTypes Set de nombres de RecordTypes a filtrar
     * @return List<Lead> Lista de Leads que cumplen criterios
     */
    public List<Lead> getManualLeadsByAdvisors(Set<Id> advisorIds, Date fromDate, Set<String> recordTypes) {
        // Validaciones de parámetros (SonarCloud)
        if (advisorIds == null || advisorIds.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'VEC_LeadQueries: advisorIds es null o vacío');
            return new List<Lead>();
        }
        
        if (fromDate == null) {
            System.debug(LoggingLevel.WARN, 'VEC_LeadQueries: fromDate es null');
            return new List<Lead>();
        }
        
        if (recordTypes == null || recordTypes.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'VEC_LeadQueries: recordTypes es null o vacío');
            return new List<Lead>();
        }
        
        return [
            SELECT CreatedById, OwnerId, RecordType.DeveloperName, IsConverted, Name, CreatedDate
            FROM Lead
            WHERE CreatedById IN :advisorIds
            AND CreatedDate >= :fromDate
            AND IsConverted = false
            AND RecordType.DeveloperName IN :recordTypes
        ];
    }
}