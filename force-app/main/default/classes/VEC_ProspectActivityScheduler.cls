/**
 * @description Schedulable class para ejecutar el job de verificación de actividad de prospectos
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Job para notificar managers 
 *         |            |         | sobre asesores sin actividad de prospectos
 * 1.1     | 2025-10-17 | Sistema | Ajuste tamaño de lote a 50 para límites de email
 * =============================================================================
 */
public class VEC_ProspectActivityScheduler implements Schedulable {
    
    /**
     * @description Método principal del Schedulable que ejecuta el batch
     * @param sc Contexto del schedulable
     */
    public void execute(SchedulableContext sc) {
        try {
            // Ejecutar el batch para procesar asesores sin actividad
            VEC_ProspectActivityBatch batch = new VEC_ProspectActivityBatch();
            Database.executeBatch(batch, 50); // Procesar en lotes de 50 para respetar límites de email
            
            // Log de ejecución
            System.debug('VEC_ProspectActivityScheduler: Batch ejecutado exitosamente');
            
        } catch (Exception e) {
            // Log de error
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