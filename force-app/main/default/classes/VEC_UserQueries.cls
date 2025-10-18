/**
 * @description Clase centralizada para todas las consultas SOQL relacionadas con Users (Asesores y Managers)
 * @author Sistema
 * @version 1.1
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
 * 1.2     | 2025-10-17 | Sistema | Nuevo método: getActiveAdvisorsByProfile para
 *         |            |         | VEC_ProspectActivityProcessor optimizado
 * =============================================================================
 */
public class VEC_UserQueries {
    
    // Constantes para criterios de consulta
    private final String advisorProfile;
    private final String managerProfile;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_UserQueries() {
        this.advisorProfile = 'VEC Asesor U4O';
        this.managerProfile = 'Gerente U4O';
    }
    
    /**
     * @description Constructor con perfiles personalizados (para testing)
     * @param advisorProfile Nombre del perfil de asesor
     * @param managerProfile Nombre del perfil de manager
     */
    public VEC_UserQueries(String advisorProfile, String managerProfile) {
        this.advisorProfile = advisorProfile;
        this.managerProfile = managerProfile;
    }
    
    /**
     * @description Obtiene todos los asesores activos con sus managers
     * @return List<User> Lista de asesores activos
     */
    public List<User> getActiveAdvisorsWithManagers() {
        return [
            SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Profile.Name
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = :advisorProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
            AND ManagerId != null
            AND Manager.IsActive = true
            AND Manager.Profile.Name = :managerProfile
            AND (NOT Manager.Email LIKE '%.invalid')
        ];
    }
    
}