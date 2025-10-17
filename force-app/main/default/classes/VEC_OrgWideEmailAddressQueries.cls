/**
 * @description Clase centralizada para consultas SOQL de OrgWideEmailAddress
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para OrgWideEmailAddress del sistema VEC
 * =============================================================================
 */
public class VEC_OrgWideEmailAddressQueries {
    
    /**
     * @description Constructor
     */
    public VEC_OrgWideEmailAddressQueries() {
        // Constructor vacío - no necesita configuración específica
    }
    
    /**
     * @description Obtiene OrgWideEmailAddress para envíos institucionales
     * @return OrgWideEmailAddress Dirección organizacional o null si no existe
     */
    public OrgWideEmailAddress getOrgWideEmailAddress() {
        List<OrgWideEmailAddress> orgEmails = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress 
            WHERE IsAllowAllProfiles = true
            LIMIT 1
        ];
        
        return orgEmails.isEmpty() ? null : orgEmails[0];
    }
    
    /**
     * @description Obtiene todos los OrgWideEmailAddress disponibles
     * @return List<OrgWideEmailAddress> Lista de direcciones organizacionales
     */
    public List<OrgWideEmailAddress> getAllOrgWideEmailAddresses() {
        return [
            SELECT Id, Address, DisplayName, IsAllowAllProfiles
            FROM OrgWideEmailAddress 
            ORDER BY DisplayName
        ];
    }
    
    /**
     * @description Obtiene OrgWideEmailAddress por dirección específica
     * @param emailAddress Dirección de email a buscar
     * @return OrgWideEmailAddress Dirección encontrada o null si no existe
     */
    public OrgWideEmailAddress getOrgWideEmailByAddress(String emailAddress) {
        List<OrgWideEmailAddress> orgEmails = [
            SELECT Id, Address, DisplayName, IsAllowAllProfiles
            FROM OrgWideEmailAddress 
            WHERE Address = :emailAddress
            LIMIT 1
        ];
        
        return orgEmails.isEmpty() ? null : orgEmails[0];
    }
    
    /**
     * @description Obtiene OrgWideEmailAddress activos para todos los perfiles
     * @return List<OrgWideEmailAddress> Lista de direcciones permitidas para todos
     */
    public List<OrgWideEmailAddress> getOrgWideEmailsForAllProfiles() {
        return [
            SELECT Id, Address, DisplayName, IsAllowAllProfiles
            FROM OrgWideEmailAddress 
            WHERE IsAllowAllProfiles = true
            ORDER BY DisplayName
        ];
    }
    
    /**
     * @description Valida si existe al menos una OrgWideEmailAddress activa
     * @return Boolean True si existe al menos una dirección organizacional
     */
    public Boolean hasActiveOrgWideEmailAddress() {
        try {
            Integer count = [
                SELECT COUNT()
                FROM OrgWideEmailAddress
                WHERE IsAllowAllProfiles = true
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_OrgWideEmailAddressQueries: Error validando direcciones: ' + e.getMessage());
            return false;
        }
    }
}