/**
 * Script para programar el job de verificación de actividad de prospectos
 * 
 * Instrucciones de uso:
 * 1. Abrir Developer Console en Salesforce
 * 2. Ir a Debug > Open Execute Anonymous Window
 * 3. Copiar y pegar este código
 * 4. Ejecutar
 * 
 * El job se ejecutará de lunes a viernes a las 9:00 AM
 */

// Cancelar jobs existentes (opcional)
VEC_ProspectActivityScheduler.cancelExistingJobs();

// Programar el nuevo job
String jobId = VEC_ProspectActivityScheduler.scheduleJob();

System.debug('Job programado exitosamente con ID: ' + jobId);

// Validar configuración del sistema
System.debug('=== VALIDACIÓN DEL SISTEMA ===');
System.debug(VEC_ProspectActivityUtils.validateSystemConfiguration());

// Mostrar estadísticas actuales
System.debug('=== ESTADÍSTICAS ACTUALES ===');
System.debug(VEC_ProspectActivityUtils.getActivityStatistics());

System.debug('=== CONFIGURACIÓN COMPLETADA ===');