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
    
    /**
     * @description Obtiene datos de un manager específico
     * @param managerId ID del manager
     * @return User Datos del manager
     */
    public User getManagerById(Id managerId) {
        List<User> managers = [
            SELECT Id, Name, Email 
            FROM User 
            WHERE Id = :managerId 
            LIMIT 1
        ];
        
        return managers.isEmpty() ? null : managers[0];
    }
    
    /**
     * @description Obtiene todos los asesores activos (sin restricción de manager)
     * @return List<User> Lista de asesores activos
     */
    public List<User> getAllActiveAdvisors() {
        return [
            SELECT Id, Name, Email, ManagerId, Profile.Name
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = :advisorProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
        ];
    }
    
    /**
     * @description Obtiene todos los managers activos
     * @return List<User> Lista de managers activos
     */
    public List<User> getAllActiveManagers() {
        return [
            SELECT Id, Name, Email, Profile.Name
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = :managerProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
        ];
    }
    
    /**
     * @description Cuenta total de asesores activos
     * @return Integer Número de asesores activos
     */
    public Integer countActiveAdvisors() {
        return [
            SELECT COUNT()
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = :advisorProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
            AND ManagerId != null
        ];
    }
    
    /**
     * @description Cuenta total de managers activos
     * @return Integer Número de managers activos
     */
    public Integer countActiveManagers() {
        return [
            SELECT COUNT()
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = :managerProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
        ];
    }
    
    /**
     * @description Obtiene conteos de usuarios por perfil para estadísticas
     * @return Map<String, Integer> Mapa con perfil como key y conteo como value
     */
    public Map<String, Integer> getUserCountsByProfile() {
        Map<String, Integer> profileCounts = new Map<String, Integer>();
        
        for (AggregateResult ar : [
            SELECT Profile.Name profileName, COUNT(Id) userCount
            FROM User 
            WHERE IsActive = true
            AND Profile.Name IN (:advisorProfile, :managerProfile)
            GROUP BY Profile.Name
        ]) {
            profileCounts.put((String)ar.get('profileName'), (Integer)ar.get('userCount'));
        }
        
        return profileCounts;
    }
    
    /**
     * @description Valida si existen los perfiles requeridos en el sistema
     * @return Map<String, Boolean> Mapa con perfil como key y existencia como value
     */
    public Map<String, Boolean> validateRequiredProfiles() {
        Map<String, Boolean> profileExists = new Map<String, Boolean>();
        
        Map<String, Integer> counts = getUserCountsByProfile();
        profileExists.put(advisorProfile, counts.containsKey(advisorProfile) && counts.get(advisorProfile) > 0);
        profileExists.put(managerProfile, counts.containsKey(managerProfile) && counts.get(managerProfile) > 0);
        
        return profileExists;
    }
    
    /**
     * @description Obtiene asesores por IDs específicos
     * @param advisorIds Set de IDs de asesores
     * @return List<User> Lista de asesores encontrados
     */
    public List<User> getAdvisorsByIds(Set<Id> advisorIds) {
        return [
            SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email, Profile.Name
            FROM User 
            WHERE Id IN :advisorIds
            AND IsActive = true
            AND Profile.Name = :advisorProfile
        ];
    }
    
    /**
     * @description Obtiene managers por IDs específicos
     * @param managerIds Set de IDs de managers
     * @return List<User> Lista de managers encontrados
     */
    public List<User> getManagersByIds(Set<Id> managerIds) {
        return [
            SELECT Id, Name, Email, Profile.Name
            FROM User 
            WHERE Id IN :managerIds
            AND IsActive = true
            AND Profile.Name = :managerProfile
        ];
    }
    
    /**
     * @description Obtiene la relación manager-asesores para un conjunto de managers
     * @param managerIds Set de IDs de managers
     * @return Map<Id, List<User>> Mapa con manager ID como key y lista de asesores como value
     */
    public Map<Id, List<User>> getManagerToAdvisorsMap(Set<Id> managerIds) {
        Map<Id, List<User>> managerToAdvisors = new Map<Id, List<User>>();
        
        List<User> advisors = [
            SELECT Id, Name, Email, ManagerId, Profile.Name
            FROM User 
            WHERE ManagerId IN :managerIds
            AND IsActive = true
            AND Profile.Name = :advisorProfile
            AND Email != null
            AND (NOT Email LIKE '%.invalid')
        ];
        
        for (User advisor : advisors) {
            if (!managerToAdvisors.containsKey(advisor.ManagerId)) {
                managerToAdvisors.put(advisor.ManagerId, new List<User>());
            }
            managerToAdvisors.get(advisor.ManagerId).add(advisor);
        }
        
        return managerToAdvisors;
    }
    
    /**
     * @description Valida si un usuario es asesor activo
     * @param userId ID del usuario a validar
     * @return Boolean True si es asesor activo
     */
    public Boolean isActiveAdvisor(Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM User 
            WHERE Id = :userId
            AND IsActive = true
            AND Profile.Name = :advisorProfile
        ];
        return count > 0;
    }
    
    /**
     * @description Valida si un usuario es manager activo
     * @param userId ID del usuario a validar
     * @return Boolean True si es manager activo
     */
    public Boolean isActiveManager(Id userId) {
        Integer count = [
            SELECT COUNT()
            FROM User 
            WHERE Id = :userId
            AND IsActive = true
            AND Profile.Name = :managerProfile
        ];
        return count > 0;
    }
    
    /**
     * @description Método utilitario para obtener constantes de perfiles
     * @return Map<String, String> Constantes de perfiles utilizadas
     */
    public Map<String, String> getUserProfileConstants() {
        return new Map<String, String>{
            'ADVISOR_PROFILE' => advisorProfile,
            'MANAGER_PROFILE' => managerProfile
        };
    }
}