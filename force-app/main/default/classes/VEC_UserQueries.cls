/**
 * @description Clase centralizada para todas las consultas SOQL relacionadas con Users (Asesores y Managers)
 * @author Sistema
 * @version 1.4
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Separación de consultas
 *         |            |         | de User desde VEC_LeadQueries
 * 1.1     | 2025-10-17 | Sistema | Refactoring: Remoción de static, métodos de
 *         |            |         | instancia para mejor testing
 * 1.2     | 2025-10-17 | Sistema | Flexibilidad: Perfiles como Set<String>
 *         |            |         | en parámetros con métodos legacy compatibles
 * 1.3     | 2025-10-17 | Sistema | Simplificación: Solo filtro por perfil de asesor,
 *         |            |         | manager puede ser de cualquier perfil
 * 1.4     | 2025-10-17 | Sistema | Validaciones: Agregadas validaciones de parámetros
 *         |            |         | null/vacíos siguiendo recomendaciones SonarCloud
 * =============================================================================
 */
public class VEC_UserQueries {
    
    // Constantes para criterios de consulta
    private final Set<String> advisorProfiles;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_UserQueries() {
        this.advisorProfiles = new Set<String>{ 'VEC Asesor U4O' };
    }
    
    /**
     * @description Constructor con perfiles personalizados (para testing)
     * @param advisorProfiles Set de nombres de perfiles de asesores
     */
    public VEC_UserQueries(Set<String> advisorProfiles) {
        this.advisorProfiles = advisorProfiles != null ? advisorProfiles : new Set<String>();
    }
    
    /**
     * @description Constructor legacy con perfil individual (para compatibilidad)
     * @param advisorProfile Nombre del perfil de asesor
     */
    public VEC_UserQueries(String advisorProfile) {
        this.advisorProfiles = new Set<String>{ advisorProfile };
    }
    
    /**
     * @description Obtiene todos los asesores activos con sus managers
     * @param advisorProfiles Set de nombres de perfiles de asesores
     * @return List<User> Lista de asesores activos
     */
    public List<User> getActiveAdvisorsWithManagers(Set<String> advisorProfiles) {
        // Validaciones de parámetros (SonarCloud)
        if (advisorProfiles == null || advisorProfiles.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'VEC_UserQueries: advisorProfiles es null o vacío');
            return new List<User>();
        }
        
        return [
            SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Profile.Name
            FROM User 
            WHERE IsActive = true
            AND Profile.Name IN :advisorProfiles
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
            AND ManagerId != null
            AND Manager.IsActive = true
            AND (NOT Manager.Email LIKE '%.invalid')
        ];
    }
    
    /**
     * @description Obtiene todos los asesores activos con sus managers (método legacy)
     * @return List<User> Lista de asesores activos
     */
    public List<User> getActiveAdvisorsWithManagers() {
        return getActiveAdvisorsWithManagers(this.advisorProfiles);
    }
    
}