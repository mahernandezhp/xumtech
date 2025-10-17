/**
 * @description Queueable class para procesar envío de emails a managers con límites de Salesforce
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Procesador de emails con
 *         |            |         | manejo de límites y generación de CSV
 * =============================================================================
 */
public class VEC_ProspectActivityEmailProcessor implements Queueable {
    
    private static final Integer MAX_EMAILS_PER_TRANSACTION = 10;
    private static final Integer MAX_ATTACHMENT_SIZE = 25 * 1024 * 1024; // 25MB
    
    private Map<Id, List<User>> managersToAdvisorsMap;
    private List<Id> managerIdsToProcess;
    private Integer currentIndex;
    private Integer emailsSent;
    
    /**
     * @description Constructor
     */
    public VEC_ProspectActivityEmailProcessor() {
        this.currentIndex = 0;
        this.emailsSent = 0;
    }
    
    /**
     * @description Método principal para procesar notificaciones a managers
     * @param managersMap Mapa de managers y sus asesores sin actividad
     * @return VEC_ProspectActivityEmailProcessor Instancia para encolar
     */
    public VEC_ProspectActivityEmailProcessor processManagerNotifications(Map<Id, List<User>> managersMap) {
        this.managersToAdvisorsMap = managersMap;
        this.managerIdsToProcess = new List<Id>(managersMap.keySet());
        return this;
    }
    
    /**
     * @description Método execute del Queueable
     * @param context Contexto del queueable
     */
    public void execute(QueueableContext context) {
        try {
            System.debug('VEC_ProspectActivityEmailProcessor: Procesando emails. Índice: ' + currentIndex + ' de ' + managerIdsToProcess.size());
            
            List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
            Integer emailsInThisBatch = 0;
            
            // Procesar hasta MAX_EMAILS_PER_TRANSACTION o hasta terminar la lista
            while (currentIndex < managerIdsToProcess.size() && emailsInThisBatch < MAX_EMAILS_PER_TRANSACTION) {
                Id managerId = managerIdsToProcess[currentIndex];
                List<User> inactiveAdvisors = managersToAdvisorsMap.get(managerId);
                
                if (inactiveAdvisors != null && !inactiveAdvisors.isEmpty()) {
                    Messaging.SingleEmailMessage email = createManagerNotificationEmail(managerId, inactiveAdvisors);
                    if (email != null) {
                        emailsToSend.add(email);
                        emailsInThisBatch++;
                    }
                }
                
                currentIndex++;
            }
            
            // Enviar emails si hay alguno
            if (!emailsToSend.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);
                processEmailResults(results);
                emailsSent += emailsToSend.size();
            }
            
            // Si aún hay managers por procesar, encolar siguiente lote
            if (currentIndex < managerIdsToProcess.size()) {
                System.enqueueJob(this);
            } else {
                System.debug('VEC_ProspectActivityEmailProcessor: Proceso completado. Total emails enviados: ' + emailsSent);
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Crea email de notificación para un manager
     * @param managerId ID del manager
     * @param inactiveAdvisors Lista de asesores sin actividad
     * @return Messaging.SingleEmailMessage Email configurado
     */
    private Messaging.SingleEmailMessage createManagerNotificationEmail(Id managerId, List<User> inactiveAdvisors) {
        try {
            // Obtener datos del manager
            User manager = [
                SELECT Id, Name, Email 
                FROM User 
                WHERE Id = :managerId 
                LIMIT 1
            ];
            
            // Obtener Email Template
            EmailTemplate template = getEmailTemplate();
            if (template == null) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: Email template no encontrado');
                return null;
            }
            
            // Obtener OrgWideEmailAddress
            OrgWideEmailAddress orgEmail = getOrgWideEmailAddress();
            
            // Crear email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            
            // Configurar email básico
            email.setTargetObjectId(managerId); // Para tracking interno
            email.setTemplateId(template.Id);
            email.setSaveAsActivity(false); // No guardar como actividad
            
            if (orgEmail != null) {
                email.setOrgWideEmailAddressId(orgEmail.Id);
            }
            
            // Crear y adjuntar CSV
            Messaging.EmailFileAttachment csvAttachment = createCSVAttachment(inactiveAdvisors);
            if (csvAttachment != null) {
                email.setFileAttachments(new List<Messaging.EmailFileAttachment>{csvAttachment});
            }
            
            return email;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor createEmail Error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Crea archivo CSV con datos de asesores inactivos
     * @param inactiveAdvisors Lista de asesores sin actividad
     * @return Messaging.EmailFileAttachment Archivo CSV adjunto
     */
    private Messaging.EmailFileAttachment createCSVAttachment(List<User> inactiveAdvisors) {
        try {
            String csvContent = 'Nombre del Asesor,Link al Usuario\n';
            
            for (User advisor : inactiveAdvisors) {
                String userLink = URL.getSalesforceBaseUrl().toExternalForm() + '/' + advisor.Id;
                csvContent += '"' + advisor.Name + '","' + userLink + '"\n';
            }
            
            Blob csvBlob = Blob.valueOf(csvContent);
            
            // Verificar tamaño del archivo
            if (csvBlob.size() > MAX_ATTACHMENT_SIZE) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: CSV demasiado grande, reduciendo contenido');
                // En caso de archivo muy grande, truncar contenido
                csvContent = csvContent.substring(0, 1000) + '\n... (contenido truncado por tamaño)';
                csvBlob = Blob.valueOf(csvContent);
            }
            
            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Asesores_Sin_Actividad_Leads_' + Date.today().format() + '.csv');
            attachment.setBody(csvBlob);
            attachment.setContentType('text/csv');
            
            return attachment;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor createCSV Error: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene el Email Template para notificaciones
     * @return EmailTemplate Template configurado
     */
    private EmailTemplate getEmailTemplate() {
        try {
            return [
                SELECT Id, Name, Subject, Body, HtmlValue
                FROM EmailTemplate 
                WHERE DeveloperName = 'VEC_Manager_Prospect_Activity_Alert'
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: Template no encontrado: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene OrgWideEmailAddress para envíos
     * @return OrgWideEmailAddress Dirección organizacional
     */
    private OrgWideEmailAddress getOrgWideEmailAddress() {
        try {
            return [
                SELECT Id, Address, DisplayName
                FROM OrgWideEmailAddress 
                WHERE IsAllowAllProfiles = true
                LIMIT 1
            ];
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: OrgWideEmail no encontrado: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Procesa resultados del envío de emails
     * @param results Resultados del envío
     */
    private void processEmailResults(Messaging.SendEmailResult[] results) {
        for (Integer i = 0; i < results.size(); i++) {
            Messaging.SendEmailResult result = results[i];
            if (result.isSuccess()) {
                System.debug('VEC_ProspectActivityEmailProcessor: Email ' + i + ' enviado exitosamente');
            } else {
                System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor: Error enviando email ' + i + ': ' + result.getErrors());
            }
        }
    }
}