/**
 * @description Batch class para enviar emails de notificación de 10 en 10 respetando límites de Salesforce
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Batch especializado para
 *         |            |         | envío de emails respetando límites de 10 por transacción
 * =============================================================================
 */
public class VEC_EmailSendBatch implements Database.Batchable<Messaging.SingleEmailMessage> {
    
    // Variables de instancia para configuración
    private final List<Messaging.SingleEmailMessage> emailsToProcess;
    private final String processName;
    
    /**
     * @description Constructor principal
     * @param emails Lista de emails pre-construidos para enviar
     */
    public VEC_EmailSendBatch(List<Messaging.SingleEmailMessage> emails) {
        this.emailsToProcess = emails != null ? emails : new List<Messaging.SingleEmailMessage>();
        this.processName = 'VEC Prospect Activity Notifications';
    }
    
    /**
     * @description Constructor para testing con nombre personalizado
     * @param emails Lista de emails pre-construidos para enviar
     * @param processName Nombre del proceso para logging
     */
    public VEC_EmailSendBatch(List<Messaging.SingleEmailMessage> emails, String processName) {
        this.emailsToProcess = emails != null ? emails : new List<Messaging.SingleEmailMessage>();
        this.processName = processName != null ? processName : 'VEC Email Process';
    }
    
    /**
     * @description Método start del batch - devuelve iterable de emails
     * @param bc Contexto del batch
     * @return Iterable<Messaging.SingleEmailMessage> Iterable de emails para procesar
     */
    public Iterable<Messaging.SingleEmailMessage> start(Database.BatchableContext bc) {
        System.debug('VEC_EmailSendBatch: Iniciando envío de ' + emailsToProcess.size() + ' emails');
        System.debug('VEC_EmailSendBatch: Proceso: ' + processName);
        
        return emailsToProcess;
    }
    
    /**
     * @description Método execute del batch - envía emails del scope (máximo 10)
     * @param bc Contexto del batch
     * @param scope Lista de emails a enviar en este lote
     */
    public void execute(Database.BatchableContext bc, List<Messaging.SingleEmailMessage> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('VEC_EmailSendBatch: Scope vacío, saltando envío');
            return;
        }
        
        try {
            System.debug('VEC_EmailSendBatch: Enviando lote de ' + scope.size() + ' emails');
            
            // Enviar emails del scope
            Messaging.SendEmailResult[] results = Messaging.sendEmail(scope);
            
            // Procesar resultados
            processEmailResults(results, scope.size());
            
        } catch (Exception e) {
            handleExecuteException(e, scope.size());
        }
    }
    
    /**
     * @description Método finish del batch - logging final del proceso
     * @param bc Contexto del batch
     */
    public void finish(Database.BatchableContext bc) {
        try {
            System.debug('VEC_EmailSendBatch: Proceso de envío completado');
            System.debug('VEC_EmailSendBatch: Total emails procesados: ' + emailsToProcess.size());
            System.debug('VEC_EmailSendBatch: Proceso: ' + processName);
            
            // Obtener información del batch job
            logBatchJobInfo(bc.getJobId());
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_EmailSendBatch finish error: ' + e.getMessage());
        }
    }
    
    /**
     * @description Procesa los resultados del envío de emails
     * @param results Resultados del envío
     * @param emailCount Cantidad de emails enviados
     */
    private void processEmailResults(Messaging.SendEmailResult[] results, Integer emailCount) {
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errors = new List<String>();
        
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                successCount++;
            } else {
                errorCount++;
                List<Messaging.SendEmailError> emailErrors = results[i].getErrors();
                for (Messaging.SendEmailError error : emailErrors) {
                    String errorMsg = 'Email ' + (i + 1) + ': ' + error.getMessage() + 
                                    ' (Code: ' + error.getStatusCode() + ')';
                    errors.add(errorMsg);
                }
            }
        }
        
        // Logging de resultados
        System.debug('VEC_EmailSendBatch: Emails enviados exitosamente: ' + successCount + '/' + emailCount);
        
        if (errorCount > 0) {
            System.debug(LoggingLevel.WARN, 'VEC_EmailSendBatch: Emails con error: ' + errorCount);
            System.debug(LoggingLevel.WARN, 'VEC_EmailSendBatch: Errores: ' + String.join(errors, '; '));
        }
    }
    
    /**
     * @description Maneja excepciones durante el execute
     * @param e Excepción capturada
     * @param scopeSize Tamaño del scope que falló
     */
    private void handleExecuteException(Exception e, Integer scopeSize) {
        String errorMsg = 'Error enviando lote de ' + scopeSize + ' emails: ' + e.getMessage();
        System.debug(LoggingLevel.ERROR, 'VEC_EmailSendBatch: ' + errorMsg);
        System.debug(LoggingLevel.ERROR, 'VEC_EmailSendBatch Stack Trace: ' + e.getStackTraceString());
    }
    
    /**
     * @description Registra información del batch job para monitoreo
     * @param jobId ID del batch job
     */
    private void logBatchJobInfo(Id jobId) {
        try {
            List<AsyncApexJob> jobs = [
                SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors,
                       CreatedDate, CompletedDate, ExtendedStatus
                FROM AsyncApexJob
                WHERE Id = :jobId
                LIMIT 1
            ];
            
            if (!jobs.isEmpty()) {
                AsyncApexJob job = jobs[0];
                System.debug('VEC_EmailSendBatch Job Info:');
                System.debug('  - Status: ' + job.Status);
                System.debug('  - Items Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
                System.debug('  - Errors: ' + job.NumberOfErrors);
                System.debug('  - Duration: ' + job.CreatedDate + ' - ' + job.CompletedDate);
                
                if (String.isNotBlank(job.ExtendedStatus)) {
                    System.debug('  - Extended Status: ' + job.ExtendedStatus);
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'VEC_EmailSendBatch: No se pudo obtener info del job: ' + e.getMessage());
        }
    }
    
    /**
     * @description Método estático para lanzar el batch con configuración óptima
     * @param emails Lista de emails para enviar
     * @param processName Nombre del proceso para logging
     * @return Id ID del batch job
     */
    public static Id launchEmailBatch(List<Messaging.SingleEmailMessage> emails, String processName) {
        if (emails == null || emails.isEmpty()) {
            System.debug('VEC_EmailSendBatch: No hay emails para procesar');
            return null;
        }
        
        VEC_EmailSendBatch batch = new VEC_EmailSendBatch(emails, processName);
        
        // Lanzar con scope de 10 (límite de emails por transacción)
        Id jobId = Database.executeBatch(batch, 10);
        
        System.debug('VEC_EmailSendBatch: Batch lanzado con Job ID: ' + jobId);
        System.debug('VEC_EmailSendBatch: Procesando ' + emails.size() + ' emails de 10 en 10');
        
        return jobId;
    }
}