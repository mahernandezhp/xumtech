/**
 * @description Clase centralizada para consultas SOQL de EmailTemplate
 * @author Marco Hernandez
 * @version 1.2
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor           | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema         | Creación inicial - Consultas específicas
 *         |            |                 | para EmailTemplate del sistema VEC
 * 1.1     | 2025-10-17 | Sistema         | Sobrecarga método getProspectActivityEmailTemplate
 *         |            |                 | para aceptar emailTemplateDeveloperName por parámetro
 * 1.2     | 2025-01-17 | Marco Hernandez | Limpieza: Removidos métodos no utilizados
 *         |            |                 | (getVECEmailTemplates, getEmailTemplateByDeveloperName,
 *         |            |                 | validateEmailTemplate) para reducir complejidad
 * =============================================================================
 */
public class VEC_EmailTemplateQueries {

    /**
     * @description Obtiene el Email Template para notificaciones
     * @param emailTemplateDeveloperName Nombre del developer del email template
     * @return EmailTemplate Template configurado o null si no existe
     */
    public EmailTemplate getProspectActivityEmailTemplate(String emailTemplateDeveloperName) {
        if (String.isBlank(emailTemplateDeveloperName)) {
            System.debug(LoggingLevel.WARN, 'VEC_EmailTemplateQueries: emailTemplateDeveloperName es null o vacío');
            return null;
        }
        List<EmailTemplate> templates = [
            SELECT Id, Name, Subject, Body, HtmlValue
            FROM EmailTemplate 
            WHERE DeveloperName = :emailTemplateDeveloperName
            LIMIT 1
        ];
        
        return templates.isEmpty() ? null : templates[0];
    }
    
}