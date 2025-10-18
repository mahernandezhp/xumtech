/**
 * @description Clase centralizada para consultas SOQL de EmailTemplate
 * @author Sistema
 * @version 1.1
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para EmailTemplate del sistema VEC
 * 1.1     | 2025-10-17 | Sistema | Sobrecarga método getProspectActivityEmailTemplate
 *         |            |         | para aceptar emailTemplateDeveloperName por parámetro
 * =============================================================================
 */
public class VEC_EmailTemplateQueries {
    
    // Variables de instancia para configuración
    private final String emailTemplateDeveloperName;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_EmailTemplateQueries() {
        this.emailTemplateDeveloperName = 'VEC_Manager_Prospect_Activity_Alert';
    }
    
    /**
     * @description Constructor con configuración personalizada (para testing)
     * @param emailTemplateDeveloperName Nombre del email template
     */
    public VEC_EmailTemplateQueries(String emailTemplateDeveloperName) {
        this.emailTemplateDeveloperName = emailTemplateDeveloperName;
    }
    
    /**
     * @description Obtiene el Email Template para notificaciones
     * @param emailTemplateDeveloperName Nombre del developer del email template
     * @return EmailTemplate Template configurado o null si no existe
     */
    public EmailTemplate getProspectActivityEmailTemplate(String emailTemplateDeveloperName) {
        List<EmailTemplate> templates = [
            SELECT Id, Name, Subject, Body, HtmlValue
            FROM EmailTemplate 
            WHERE DeveloperName = :emailTemplateDeveloperName
            LIMIT 1
        ];
        
        return templates.isEmpty() ? null : templates[0];
    }
    
    /**
     * @description Obtiene el Email Template para notificaciones usando valor por defecto
     * @return EmailTemplate Template configurado o null si no existe
     */
    public EmailTemplate getProspectActivityEmailTemplate() {
        return getProspectActivityEmailTemplate(this.emailTemplateDeveloperName);
    }
    
    /**
     * @description Obtiene todos los Email Templates relacionados con VEC
     * @return List<EmailTemplate> Lista de templates VEC
     */
    public List<EmailTemplate> getVECEmailTemplates() {
        return [
            SELECT Id, Name, DeveloperName, Subject, Body, HtmlValue, IsActive
            FROM EmailTemplate 
            WHERE DeveloperName LIKE 'VEC%'
            ORDER BY Name
        ];
    }
    
    /**
     * @description Obtiene Email Template por DeveloperName
     * @param developerName Nombre del developer del template
     * @return EmailTemplate Template encontrado o null si no existe
     */
    public EmailTemplate getEmailTemplateByDeveloperName(String developerName) {
        List<EmailTemplate> templates = [
            SELECT Id, Name, DeveloperName, Subject, Body, HtmlValue, IsActive
            FROM EmailTemplate 
            WHERE DeveloperName = :developerName
            LIMIT 1
        ];
        
        return templates.isEmpty() ? null : templates[0];
    }
    
    /**
     * @description Valida si existe un Email Template específico
     * @param developerName Nombre del developer del template
     * @return Boolean True si existe el template
     */
    public Boolean validateEmailTemplate(String developerName) {
        try {
            Integer count = [
                SELECT COUNT()
                FROM EmailTemplate
                WHERE DeveloperName = :developerName
                AND IsActive = true
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_EmailTemplateQueries: Error validando template: ' + e.getMessage());
            return false;
        }
    }
}