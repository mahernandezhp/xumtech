/**
 * @description Clase centralizada para consultas SOQL de Profile
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para Profile del sistema VEC
 * =============================================================================
 */
public class VEC_ProfileQueries {
    
    /**
     * @description Constructor
     */
    public VEC_ProfileQueries() {
        // Constructor vacío - no necesita configuración específica
    }
    
    /**
     * @description Obtiene perfiles específicos del sistema VEC
     * @param profileNames Lista de nombres de perfiles a buscar
     * @return List<Profile> Lista de perfiles encontrados
     */
    public List<Profile> getVECProfiles(List<String> profileNames) {
        return [
            SELECT Id, Name, Description, UserType
            FROM Profile
            WHERE Name IN :profileNames
        ];
    }
    
    /**
     * @description Obtiene perfil por nombre específico
     * @param profileName Nombre del perfil a buscar
     * @return Profile Perfil encontrado o null si no existe
     */
    public Profile getProfileByName(String profileName) {
        List<Profile> profiles = [
            SELECT Id, Name, Description, UserType
            FROM Profile
            WHERE Name = :profileName
            LIMIT 1
        ];
        
        return profiles.isEmpty() ? null : profiles[0];
    }
    
    /**
     * @description Obtiene todos los perfiles activos del sistema
     * @return List<Profile> Lista de todos los perfiles
     */
    public List<Profile> getAllProfiles() {
        return [
            SELECT Id, Name, Description, UserType
            FROM Profile
            ORDER BY Name
        ];
    }
    
    /**
     * @description Obtiene perfiles por tipo de usuario
     * @param userType Tipo de usuario (Standard, PowerCustomerSuccess, etc.)
     * @return List<Profile> Lista de perfiles del tipo especificado
     */
    public List<Profile> getProfilesByUserType(String userType) {
        return [
            SELECT Id, Name, Description, UserType
            FROM Profile
            WHERE UserType = :userType
            ORDER BY Name
        ];
    }
    
    /**
     * @description Valida existencia de perfiles requeridos
     * @param profileNames Lista de nombres de perfiles a validar
     * @return Map<String, Boolean> Mapa con perfil como key y existencia como value
     */
    public Map<String, Boolean> validateProfiles(List<String> profileNames) {
        Map<String, Boolean> profileExists = new Map<String, Boolean>();
        
        List<Profile> foundProfiles = getVECProfiles(profileNames);
        Set<String> foundProfileNames = new Set<String>();
        
        for (Profile p : foundProfiles) {
            foundProfileNames.add(p.Name);
        }
        
        for (String profileName : profileNames) {
            profileExists.put(profileName, foundProfileNames.contains(profileName));
        }
        
        return profileExists;
    }
    
    /**
     * @description Valida si existe un perfil específico
     * @param profileName Nombre del perfil a validar
     * @return Boolean True si existe el perfil
     */
    public Boolean validateProfile(String profileName) {
        try {
            Integer count = [
                SELECT COUNT()
                FROM Profile
                WHERE Name = :profileName
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProfileQueries: Error validando perfil: ' + e.getMessage());
            return false;
        }
    }
}