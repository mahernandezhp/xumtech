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
 * 1.1     | 2025-10-17 | Sistema | Refactoring: Uso de VEC_LeadQueries para
 *         |            |         | centralizar consultas SOQL
 * 1.2     | 2025-10-17 | Sistema | Separación: Uso de VEC_UserQueries y 
 *         |            |         | VEC_SystemQueries según responsabilidades
 * 1.3     | 2025-10-17 | Sistema | Especialización: Uso de clases específicas por
 *         |            |         | objeto (EmailTemplate, OrgWideEmailAddress)
 * =============================================================================
 */
public class VEC_ProspectActivityEmailProcessor implements Queueable {
    
    // Variables de instancia para configuración (no static)
    private final Integer maxEmailsPerTransaction;
    private final Integer maxAttachmentSize;
    
    private Map<Id, List<User>> managersToAdvisorsMap;
    private List<Id> managerIdsToProcess;
    private Integer currentIndex;
    private Integer emailsSent;
    
    // Instancias de consultas especializadas
    private VEC_EmailTemplateQueries emailTemplateQueries;
    private VEC_OrgWideEmailAddressQueries orgWideEmailQueries;
    
    // Lista de emails pre-construidos para envío directo
    private List<Messaging.SingleEmailMessage> preBuiltEmails;
    
    /**
     * @description Constructor
     */
    public VEC_ProspectActivityEmailProcessor() {
        this.currentIndex = 0;
        this.emailsSent = 0;
        
        // Inicializar configuración por defecto
        this.maxEmailsPerTransaction = 10;
        this.maxAttachmentSize = 25 * 1024 * 1024; // 25MB
        
        // Inicializar instancias de consultas especializadas
        this.emailTemplateQueries = new VEC_EmailTemplateQueries();
        this.orgWideEmailQueries = new VEC_OrgWideEmailAddressQueries();
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
     * @description Método para procesar emails ya construidos (nueva funcionalidad)
     * @param emails Lista de emails pre-construidos listos para enviar
     * @return VEC_ProspectActivityEmailProcessor Instancia para encolar
     */
    public VEC_ProspectActivityEmailProcessor processPreBuiltEmails(List<Messaging.SingleEmailMessage> emails) {
        this.preBuiltEmails = emails != null ? emails : new List<Messaging.SingleEmailMessage>();
        return this;
    }
    
    /**
     * @description Método execute del Queueable
     * @param context Contexto del queueable
     */
    public void execute(QueueableContext context) {
        try {
            // Determinar qué tipo de procesamiento realizar
            if (preBuiltEmails != null && !preBuiltEmails.isEmpty()) {
                executePreBuiltEmailProcessing();
            } else if (managersToAdvisorsMap != null && !managersToAdvisorsMap.isEmpty()) {
                executeLegacyEmailProcessing();
            } else {
                System.debug('VEC_ProspectActivityEmailProcessor: No hay emails para procesar');
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor execute error: ' + e.getMessage());
        }
    }
    
    /**
     * @description Procesa emails ya construidos (nuevo flujo)
     */
    private void executePreBuiltEmailProcessing() {
        System.debug('VEC_ProspectActivityEmailProcessor: Procesando ' + preBuiltEmails.size() + ' emails pre-construidos');
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        Integer emailsProcessed = 0;
        
        // Enviar hasta maxEmailsPerTransaction emails
        for (Messaging.SingleEmailMessage email : preBuiltEmails) {
            if (emailsProcessed >= maxEmailsPerTransaction) {
                break;
            }
            
            emailsToSend.add(email);
            emailsProcessed++;
        }
        
        // Enviar emails
        if (!emailsToSend.isEmpty()) {
            sendEmails(emailsToSend);
        }
        
        // Si quedan emails por procesar, encolar siguiente lote
        if (preBuiltEmails.size() > emailsProcessed) {
            List<Messaging.SingleEmailMessage> remainingEmails = new List<Messaging.SingleEmailMessage>();
            for (Integer i = emailsProcessed; i < preBuiltEmails.size(); i++) {
                remainingEmails.add(preBuiltEmails[i]);
            }
            
            VEC_ProspectActivityEmailProcessor nextProcessor = new VEC_ProspectActivityEmailProcessor();
            System.enqueueJob(nextProcessor.processPreBuiltEmails(remainingEmails));
            
            System.debug('VEC_ProspectActivityEmailProcessor: ' + remainingEmails.size() + ' emails restantes encolados');
        }
    }
    
    /**
     * @description Procesa emails usando el flujo legacy (mantener compatibilidad)
     */
    private void executeLegacyEmailProcessing() {
        System.debug('VEC_ProspectActivityEmailProcessor: Procesando emails legacy. Índice: ' + currentIndex + ' de ' + managerIdsToProcess.size());
        
        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();
        Integer emailsInThisBatch = 0;
        
        // Procesar hasta maxEmailsPerTransaction managers
        while (currentIndex < managerIdsToProcess.size() && emailsInThisBatch < maxEmailsPerTransaction) {
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
        
        // Enviar emails
        if (!emailsToSend.isEmpty()) {
            sendEmails(emailsToSend);
        }
        
        // Si aún hay managers por procesar, encolar siguiente lote
        if (currentIndex < managerIdsToProcess.size()) {
            System.enqueueJob(this);
        } else {
            System.debug('VEC_ProspectActivityEmailProcessor: Proceso legacy completado. Total emails enviados: ' + emailsSent);
        }
    }
    
    /**
     * @description Envía lista de emails y procesa resultados
     * @param emailsToSend Lista de emails a enviar
     */
    private void sendEmails(List<Messaging.SingleEmailMessage> emailsToSend) {
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(emailsToSend);
            processEmailResults(results);
            emailsSent += emailsToSend.size();
            
            System.debug('VEC_ProspectActivityEmailProcessor: ' + emailsToSend.size() + ' emails enviados exitosamente');
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityEmailProcessor: Error enviando emails: ' + e.getMessage());
        }
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
            // Obtener datos del manager usando consulta centralizada de usuarios
            User manager = userQueries.getManagerById(managerId);
            if (manager == null) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: Manager no encontrado: ' + managerId);
                return null;
            }
            
            // Obtener Email Template usando consulta centralizada del sistema
            EmailTemplate template = emailTemplateQueries.getProspectActivityEmailTemplate();
            if (template == null) {
                System.debug(LoggingLevel.WARN, 'VEC_ProspectActivityEmailProcessor: Email template no encontrado');
                return null;
            }
            
            // Obtener OrgWideEmailAddress usando consulta centralizada del sistema
            OrgWideEmailAddress orgEmail = orgWideEmailQueries.getOrgWideEmailAddress();
            
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
    
    // Métodos removidos - ahora se usan las consultas centralizadas de VEC_LeadQueries
    
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