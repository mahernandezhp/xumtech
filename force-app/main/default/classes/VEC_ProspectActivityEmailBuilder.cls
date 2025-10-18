/**
 * @description Builder class para construir emails de notificación a managers sobre asesores sin actividad
 * @author Marco Hernandez
 * @version 1.5
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor          | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Marco Hernandez | Creación inicial - Builder para construcción
 *         |            |                 | de emails con templates y attachments CSV
 * 1.1     | 2025-10-17 | Marco Hernandez | Optimización: setTargetObjectId para no contar
 *         |            |                 | contra límites diarios de email
 * 1.2     | 2025-10-17 | Marco Hernandez | Optimización queries: getAllManagersInfo para
 *         |            |                 | evitar múltiples queries en loop
 * 1.3     | 2025-10-17 | Marco Hernandez | Mega-optimización: Uso de Manager data del primer
 *         |            |                 | asesor eliminando query adicional de managers
 * 1.4     | 2025-10-17 | Marco Hernandez | Flexibilidad: emailTemplateName por parámetro
 *         |            |                 | en buildManagerNotificationEmails
 * 1.5     | 2025-10-17 | Marco Hernandez | Validaciones: Agregadas validaciones de parámetros
 *         |            |                 | null/vacíos siguiendo recomendaciones SonarCloud
 * =============================================================================
 */
public class VEC_ProspectActivityEmailBuilder {
    
    // Variables de instancia para configuración (no static)
    private final Integer maxAttachmentSizeBytes;
    private final String csvHeader;
    private final String csvFilename;
    private final String defaultLastLead;
    
    // Instancias de consultas especializadas
    private final VEC_EmailTemplateQueries emailTemplateQueries;
    private final VEC_OrgWideEmailAddressQueries orgWideEmailQueries;
    
    /**
     * @description Constructor con inyección de dependencias
     */
    public VEC_ProspectActivityEmailBuilder() {
        this.emailTemplateQueries = new VEC_EmailTemplateQueries();
        this.orgWideEmailQueries = new VEC_OrgWideEmailAddressQueries();
        
        // Inicializar configuración por defecto
        this.maxAttachmentSizeBytes = 25 * 1024 * 1024; // 25MB
        this.csvHeader = 'Nombre del Asesor,Email,Perfil,Último Lead Creado\n';
        this.csvFilename = 'Asesores_Sin_Actividad.csv';
        this.defaultLastLead = 'Más de 14 días';
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
        
        // Inicializar configuración por defecto
        this.maxAttachmentSizeBytes = 25 * 1024 * 1024; // 25MB
        this.csvHeader = 'Nombre del Asesor,Email,Perfil,Último Lead Creado\n';
        this.csvFilename = 'Asesores_Sin_Actividad.csv';
        this.defaultLastLead = 'Más de 14 días';
    }
    
    /**
     * @description Constructor para testing con configuración personalizada
     * @param emailTemplateQueries Mock de email template queries
     * @param orgWideEmailQueries Mock de org wide email queries
     * @param maxAttachmentSize Tamaño máximo de attachment en bytes
     * @param csvFilename Nombre del archivo CSV
     */
    public VEC_ProspectActivityEmailBuilder(
        VEC_EmailTemplateQueries emailTemplateQueries,
        VEC_OrgWideEmailAddressQueries orgWideEmailQueries,
        Integer maxAttachmentSize,
        String csvFilename
    ) {
        this.emailTemplateQueries = emailTemplateQueries;
        this.orgWideEmailQueries = orgWideEmailQueries;
        this.maxAttachmentSizeBytes = maxAttachmentSize;
        this.csvFilename = csvFilename;
        
        // Valores por defecto para el resto
        this.csvHeader = 'Nombre del Asesor,Email,Perfil,Último Lead Creado\n';
        this.defaultLastLead = 'Más de 14 días';
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
        return buildManagerNotificationEmails(managersToAdvisorsMap, null);
    }
    
    /**
     * @description Construye emails para notificar a managers sobre asesores sin actividad
     * @param managersToAdvisorsMap Mapa de managers y sus asesores sin actividad
     * @param emailTemplateName Nombre del developer del email template (opcional)
     * @return List<Messaging.SingleEmailMessage> Lista de emails listos para enviar
     * @throws VEC_ProspectActivityException Si hay errores en la construcción
     */
    public List<Messaging.SingleEmailMessage> buildManagerNotificationEmails(
        Map<Id, List<User>> managersToAdvisorsMap,
        String emailTemplateName
    ) {
        // Validaciones de parámetros (SonarCloud)
        if (managersToAdvisorsMap == null || managersToAdvisorsMap.isEmpty()) {
            System.debug('VEC_ProspectActivityEmailBuilder: No hay managers para notificar');
            return new List<Messaging.SingleEmailMessage>();
        }
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        try {
            // Obtener configuración una sola vez (optimización)
            EmailTemplate template = getEmailTemplate(emailTemplateName);
            OrgWideEmailAddress orgEmail = getOrgWideEmailAddress();
            
            if (template == null) {
                throw new VEC_ProspectActivityException('Email template no encontrado');
            }
            
            // Construir un email por manager
            for (Id managerId : managersToAdvisorsMap.keySet()) {
                List<User> advisorsWithoutActivity = managersToAdvisorsMap.get(managerId);
                
                if (advisorsWithoutActivity != null && !advisorsWithoutActivity.isEmpty()) {
                    // Obtener información del manager del primer asesor (todos tienen el mismo manager)
                    User firstAdvisor = advisorsWithoutActivity[0];
                    
                    if (firstAdvisor.Manager != null) {
                        Messaging.SingleEmailMessage email = buildSingleManagerEmail(
                            firstAdvisor.Manager, 
                            advisorsWithoutActivity, 
                            template, 
                            orgEmail
                        );
                        
                        if (email != null) {
                            emails.add(email);
                        }
                    } else {
                        System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailBuilder: Manager no encontrado para asesor: ' + firstAdvisor.Name);
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
     * @param manager Información del manager
     * @param advisors Lista de asesores sin actividad
     * @param template Template del email
     * @param orgEmail Dirección organizacional
     * @return Messaging.SingleEmailMessage Email construido
     */
    private Messaging.SingleEmailMessage buildSingleManagerEmail(
        User manager,
        List<User> advisors,
        EmailTemplate template,
        OrgWideEmailAddress orgEmail
    ) {
        try {
            // Construir email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Configuración básica
            email.setToAddresses(new List<String>{ manager.Email });
            email.setSubject(buildEmailSubject(template.Subject, advisors.size()));
            email.setHtmlBody(buildEmailBody(template.HtmlValue, manager, advisors));
            
            // Configurar targetObjectId para que NO cuente contra límites diarios
            email.setTargetObjectId(manager.Id);
            email.setSaveAsActivity(false); // No guardar como actividad
            
            // Configurar dirección organizacional si está disponible
            if (orgEmail != null) {
                email.setOrgWideEmailAddressId(orgEmail.Id);
            }
            
            // Generar y adjuntar CSV
            attachCSVReport(email, advisors, manager.Name);
            
            return email;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error construyendo email para manager ' + manager.Id + ': ' + e.getMessage());
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
        // Validaciones de parámetros (SonarCloud)
        String subject = String.isNotBlank(templateSubject) ? templateSubject : 'Notificación de Actividad de Asesores';
        Integer count = advisorCount != null ? advisorCount : 0;
        
        return subject
            .replace('{!advisorCount}', String.valueOf(count))
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
        // Validaciones de parámetros (SonarCloud)
        String body = String.isNotBlank(templateBody) ? templateBody : 'Notificación de actividad de asesores.';
        String managerName = (manager != null && String.isNotBlank(manager.Name)) ? manager.Name : 'Manager';
        Integer advisorCount = (advisors != null) ? advisors.size() : 0;
        String advisorsList = (advisors != null && !advisors.isEmpty()) ? buildAdvisorsListHtml(advisors) : '<p>No hay asesores sin actividad.</p>';
        
        return body
            .replace('{!managerName}', managerName)
            .replace('{!advisorCount}', String.valueOf(advisorCount))
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
        // Validaciones de parámetros (SonarCloud)
        if (advisors == null || advisors.isEmpty()) {
            return '<p>No hay asesores sin actividad.</p>';
        }
        
        List<String> advisorItems = new List<String>();
        
        for (User advisor : advisors) {
            if (advisor != null) {
                String advisorName = String.isNotBlank(advisor.Name) ? advisor.Name : 'Nombre no disponible';
                String advisorEmail = String.isNotBlank(advisor.Email) ? advisor.Email : 'Email no disponible';
                advisorItems.add('<li>' + advisorName + ' (' + advisorEmail + ')</li>');
            }
        }
        
        return advisorItems.isEmpty() ? '<p>No hay asesores válidos.</p>' : '<ul>' + String.join(advisorItems, '') + '</ul>';
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
            
            // Verificar tamaño del attachment (validación de límites)
            if (csvBlob.size() > maxAttachmentSizeBytes) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailBuilder: CSV muy grande para ' + managerName + ': ' + csvBlob.size() + ' bytes');
                return; // No adjuntar si es muy grande
            }
            
            Messaging.EmailFileAttachment csvAttachment = new Messaging.EmailFileAttachment();
            csvAttachment.setFileName(csvFilename);
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
        csvBuilder.append(csvHeader);
        
        for (User advisor : advisors) {
            csvBuilder.append(advisor.Name)
                     .append(',')
                     .append(advisor.Email != null ? advisor.Email : 'N/A')
                     .append(',')
                     .append(advisor.Profile?.Name != null ? advisor.Profile.Name : 'N/A')
                     .append(',')
                     .append(defaultLastLead)
                     .append('\n');
        }
        
        return csvBuilder.toString();
    }
    
    /**
     * @description Obtiene el email template configurado
     * @param emailTemplateName Nombre del developer del template (opcional)
     * @return EmailTemplate Template o null si no existe
     */
    private EmailTemplate getEmailTemplate(String emailTemplateName) {
        try {
            if (String.isNotBlank(emailTemplateName)) {
                return emailTemplateQueries.getProspectActivityEmailTemplate(emailTemplateName);
            } else {
                return emailTemplateQueries.getProspectActivityEmailTemplate();
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailBuilder: Error obteniendo template: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene el email template configurado (método legacy)
     * @return EmailTemplate Template o null si no existe
     */
    private EmailTemplate getEmailTemplate() {
        return getEmailTemplate(null);
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
     * @description Clase de excepción personalizada para el builder
     */
    public class VEC_ProspectActivityException extends Exception {
        // Excepción personalizada para manejo de errores específicos
    }
}