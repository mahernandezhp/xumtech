/**
 * @description Builder class para construir emails de notificación a managers sobre asesores sin actividad
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Builder para construcción
 *         |            |         | de emails con templates y attachments CSV
 * =============================================================================
 */
public class VEC_ProspectActivityEmailBuilder {
    
    // Constantes para evitar números mágicos (SonarCloud)
    private static final Integer MAX_ATTACHMENT_SIZE_BYTES = 25 * 1024 * 1024; // 25MB
    private static final String CSV_HEADER = 'Nombre del Asesor,Email,Perfil,Último Lead Creado\n';
    private static final String CSV_FILENAME = 'Asesores_Sin_Actividad.csv';
    private static final String DEFAULT_LAST_LEAD = 'Más de 14 días';
    
    // Instancias de consultas especializadas
    private final VEC_EmailTemplateQueries emailTemplateQueries;
    private final VEC_OrgWideEmailAddressQueries orgWideEmailQueries;
    
    /**
     * @description Constructor con inyección de dependencias
     */
    public VEC_ProspectActivityEmailBuilder() {
        this.emailTemplateQueries = new VEC_EmailTemplateQueries();
        this.orgWideEmailQueries = new VEC_OrgWideEmailAddressQueries();
    }
    
    /**
     * @description Constructor para testing con mocks
     * @param emailTemplateQueries Mock de email template queries
     * @param orgWideEmailQueries Mock de org wide email queries
     */
    public VEC_ProspectActivityEmailBuilder(
        VEC_EmailTemplateQueries emailTemplateQueries,
        VEC_OrgWideEmailAddressQueries orgWideEmailQueries
    ) {
        this.emailTemplateQueries = emailTemplateQueries;
        this.orgWideEmailQueries = orgWideEmailQueries;
    }
    
    /**
     * @description Construye emails para notificar a managers sobre asesores sin actividad
     * @param managersToAdvisorsMap Mapa de managers y sus asesores sin actividad
     * @return List<Messaging.SingleEmailMessage> Lista de emails listos para enviar
     * @throws VEC_ProspectActivityException Si hay errores en la construcción
     */
    public List<Messaging.SingleEmailMessage> buildManagerNotificationEmails(
        Map<Id, List<User>> managersToAdvisorsMap
    ) {
        if (managersToAdvisorsMap == null || managersToAdvisorsMap.isEmpty()) {
            System.debug('VEC_ProspectActivityEmailBuilder: No hay managers para notificar');
            return new List<Messaging.SingleEmailMessage>();
        }
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        try {
            // Obtener configuración una sola vez (optimización)
            EmailTemplate template = getEmailTemplate();
            OrgWideEmailAddress orgEmail = getOrgWideEmailAddress();
            
            if (template == null) {
                throw new VEC_ProspectActivityException('Email template no encontrado');
            }
            
            // Construir un email por manager
            for (Id managerId : managersToAdvisorsMap.keySet()) {
                List<User> advisorsWithoutActivity = managersToAdvisorsMap.get(managerId);
                
                if (advisorsWithoutActivity != null && !advisorsWithoutActivity.isEmpty()) {
                    Messaging.SingleEmailMessage email = buildSingleManagerEmail(
                        managerId, 
                        advisorsWithoutActivity, 
                        template, 
                        orgEmail
                    );
                    
                    if (email != null) {
                        emails.add(email);
                    }
                }
            }
            
            System.debug('VEC_ProspectActivityEmailBuilder: ' + emails.size() + ' emails construidos exitosamente');
            
        } catch (Exception e) {
            String errorMsg = 'Error construyendo emails: ' + e.getMessage();
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: ' + errorMsg);
            throw new VEC_ProspectActivityException(errorMsg, e);
        }
        
        return emails;
    }
    
    /**
     * @description Construye un email individual para un manager específico
     * @param managerId ID del manager
     * @param advisors Lista de asesores sin actividad
     * @param template Template del email
     * @param orgEmail Dirección organizacional
     * @return Messaging.SingleEmailMessage Email construido
     */
    private Messaging.SingleEmailMessage buildSingleManagerEmail(
        Id managerId,
        List<User> advisors,
        EmailTemplate template,
        OrgWideEmailAddress orgEmail
    ) {
        try {
            // Obtener información del manager
            User manager = getManagerInfo(managerId);
            if (manager == null) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailBuilder: Manager no encontrado: ' + managerId);
                return null;
            }
            
            // Construir email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Configuración básica
            email.setToAddresses(new List<String>{ manager.Email });
            email.setSubject(buildEmailSubject(template.Subject, advisors.size()));
            email.setHtmlBody(buildEmailBody(template.HtmlValue, manager, advisors));
            
            // Configurar dirección organizacional si está disponible
            if (orgEmail != null) {
                email.setOrgWideEmailAddressId(orgEmail.Id);
            }
            
            // Generar y adjuntar CSV
            attachCSVReport(email, advisors, manager.Name);
            
            return email;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error construyendo email para manager ' + managerId + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Construye el subject del email personalizado
     * @param templateSubject Subject del template
     * @param advisorCount Cantidad de asesores sin actividad
     * @return String Subject personalizado
     */
    private String buildEmailSubject(String templateSubject, Integer advisorCount) {
        return templateSubject
            .replace('{!advisorCount}', String.valueOf(advisorCount))
            .replace('{!date}', Date.today().format());
    }
    
    /**
     * @description Construye el body del email con merge fields
     * @param templateBody Body del template
     * @param manager Información del manager
     * @param advisors Lista de asesores sin actividad
     * @return String Body personalizado
     */
    private String buildEmailBody(String templateBody, User manager, List<User> advisors) {
        String advisorsList = buildAdvisorsListHtml(advisors);
        
        return templateBody
            .replace('{!managerName}', manager.Name)
            .replace('{!advisorCount}', String.valueOf(advisors.size()))
            .replace('{!advisorsList}', advisorsList)
            .replace('{!date}', Date.today().format())
            .replace('{!period}', '14 días');
    }
    
    /**
     * @description Construye la lista HTML de asesores para el email
     * @param advisors Lista de asesores sin actividad
     * @return String Lista HTML formateada
     */
    private String buildAdvisorsListHtml(List<User> advisors) {
        List<String> advisorItems = new List<String>();
        
        for (User advisor : advisors) {
            advisorItems.add('<li>' + advisor.Name + ' (' + advisor.Email + ')</li>');
        }
        
        return '<ul>' + String.join(advisorItems, '') + '</ul>';
    }
    
    /**
     * @description Adjunta reporte CSV al email
     * @param email Email al cual adjuntar
     * @param advisors Lista de asesores para el CSV
     * @param managerName Nombre del manager para logging
     */
    private void attachCSVReport(Messaging.SingleEmailMessage email, List<User> advisors, String managerName) {
        try {
            String csvContent = generateCSVContent(advisors);
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Verificar tamaño del attachment (SonarCloud - validación de límites)
            if (csvBlob.size() > MAX_ATTACHMENT_SIZE_BYTES) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailBuilder: CSV muy grande para ' + managerName + ': ' + csvBlob.size() + ' bytes');
                return; // No adjuntar si es muy grande
            }
            
            Messaging.EmailFileAttachment csvAttachment = new Messaging.EmailFileAttachment();
            csvAttachment.setFileName(CSV_FILENAME);
            csvAttachment.setBody(csvBlob);
            csvAttachment.setContentType('text/csv');
            
            email.setFileAttachments(new List<Messaging.EmailFileAttachment>{ csvAttachment });
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error generando CSV para ' + managerName + ': ' + e.getMessage());
            // Continuar sin attachment si hay error
        }
    }
    
    /**
     * @description Genera el contenido CSV de asesores sin actividad
     * @param advisors Lista de asesores
     * @return String Contenido CSV
     */
    private String generateCSVContent(List<User> advisors) {
        StringBuilder csvBuilder = new StringBuilder();
        csvBuilder.append(CSV_HEADER);
        
        for (User advisor : advisors) {
            csvBuilder.append(advisor.Name)
                     .append(',')
                     .append(advisor.Email != null ? advisor.Email : 'N/A')
                     .append(',')
                     .append(advisor.Profile?.Name != null ? advisor.Profile.Name : 'N/A')
                     .append(',')
                     .append(DEFAULT_LAST_LEAD)
                     .append('\n');
        }
        
        return csvBuilder.toString();
    }
    
    /**
     * @description Obtiene el email template configurado
     * @return EmailTemplate Template o null si no existe
     */
    private EmailTemplate getEmailTemplate() {
        try {
            return emailTemplateQueries.getProspectActivityEmailTemplate();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error obteniendo template: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene la dirección organizacional configurada
     * @return OrgWideEmailAddress Dirección o null si no existe
     */
    private OrgWideEmailAddress getOrgWideEmailAddress() {
        try {
            return orgWideEmailQueries.getOrgWideEmailAddress();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error obteniendo org email: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene información del manager por ID
     * @param managerId ID del manager
     * @return User Información del manager o null si no existe
     */
    private User getManagerInfo(Id managerId) {
        try {
            List<User> managers = [
                SELECT Id, Name, Email, Profile.Name
                FROM User
                WHERE Id = :managerId
                AND IsActive = true
                LIMIT 1
            ];
            
            return managers.isEmpty() ? null : managers[0];
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error obteniendo manager: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Clase de excepción personalizada para el builder
     */
    public class VEC_ProspectActivityException extends Exception {
        // Excepción personalizada para manejo de errores específicos
    }
}