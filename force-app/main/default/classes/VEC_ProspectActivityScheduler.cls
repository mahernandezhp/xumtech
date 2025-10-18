/**
 * @description Schedulable class para ejecutar el job de verificación de actividad de prospectos
 *              y notificación por email a managers sobre asesores sin actividad
 * @author Sistema
 * @version 1.3
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Job para notificar managers 
 *         |            |         | sobre asesores sin actividad de prospectos
 * 1.1     | 2025-10-17 | Sistema | Ajuste tamaño de lote a 50 para límites de email
 * 1.2     | 2025-10-17 | Sistema | Optimización: Uso directo de VEC_ProspectActivityEmailService
 *         |            |         | para orquestar todo el proceso de envío de correos
 * =============================================================================
 */
public class VEC_ProspectActivityScheduler implements Schedulable {
    
    // Instancia del service de email
    private final VEC_ProspectActivityEmailService emailService;
    
    /**
     * @description Constructor por defecto
     */
    public VEC_ProspectActivityScheduler() {
        this.emailService = new VEC_ProspectActivityEmailService();
    }
    
    /**
     * @description Constructor para testing con mock
     * @param emailService Mock del service de email
     */
    public VEC_ProspectActivityScheduler(VEC_ProspectActivityEmailService emailService) {
        this.emailService = emailService;
    }
    
    /**
     * @description Método principal del Schedulable que procesa directamente
     * @param sc Contexto del schedulable
     */
    public void execute(SchedulableContext sc) {
        try {
            System.debug('VEC_ProspectActivityScheduler: Iniciando procesamiento de emails de actividad de prospectos');
            
            // Procesar usando el service de email
            VEC_ProspectActivityEmailService.ProcessResult result = emailService.processInactiveAdvisorsAndSendEmails();
            
            if (result.success) {
                System.debug('VEC_ProspectActivityScheduler: Procesamiento exitoso - ' + result.message);
                if (result.emailBatchJobId != null) {
                    System.debug('VEC_ProspectActivityScheduler: Email Batch Job ID: ' + result.emailBatchJobId);
                }
                if (result.managersNotified != null) {
                    System.debug('VEC_ProspectActivityScheduler: Managers notificados: ' + result.managersNotified);
                }
                if (result.advisorsWithoutActivity != null) {
                    System.debug('VEC_ProspectActivityScheduler: Asesores sin actividad: ' + result.advisorsWithoutActivity);
                }
            } else {
                System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityScheduler: Error en procesamiento - ' + result.message);
                if (result.exception != null) {
                    System.debug(LoggingLevel.ERROR, 'Exception details: ' + result.exception.getStackTraceString());
                }
            }
            
            // Log de procesamiento detallado
            if (result.processingLog != null && !result.processingLog.isEmpty()) {
                for (String logEntry : result.processingLog) {
                    System.debug('ProcessingLog: ' + logEntry);
                }
            }
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_ProspectActivityScheduler Error: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Stack Trace: ' + e.getStackTraceString());
        }
    }
    
    /**
     * @description Método utilitario para programar el job (Lunes a Viernes 9 AM)
     * @return String Job ID del job programado
     */
    public static String scheduleJob() {
        VEC_ProspectActivityScheduler scheduler = new VEC_ProspectActivityScheduler();
        
        // Expresión cron: Segundos Minutos Horas Día_del_mes Mes Día_de_la_semana
        // 0 0 9 ? * MON-FRI = Todos los días laborables a las 9:00 AM
        String cronExpression = '0 0 9 ? * MON-FRI';
        
        return System.schedule('VEC Prospect Activity Alert - Weekdays 9AM', 
                              cronExpression, 
                              scheduler);
    }
    
    /**
     * @description Método para cancelar jobs programados existentes
     */
    public static void cancelExistingJobs() {
        List<CronTrigger> existingJobs = [
            SELECT Id, CronJobDetail.Name 
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE 'VEC Prospect Activity Alert%'
        ];
        
        for (CronTrigger job : existingJobs) {
            System.abortJob(job.Id);
        }
        
        System.debug('VEC_ProspectActivityScheduler: ' + existingJobs.size() + ' jobs cancelados');
    }
}