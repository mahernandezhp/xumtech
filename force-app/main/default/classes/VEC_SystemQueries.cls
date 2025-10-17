/**
 * @description Clase centralizada para consultas SOQL de configuración del sistema y metadata
 * @author Sistema
 * @version 1.1
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas de sistema,
 *         |            |         | templates, jobs y configuración
 * 1.1     | 2025-10-17 | Sistema | Refactoring: Remoción de static, métodos de
 *         |            |         | instancia para mejor testing
 * =============================================================================
 */
public class VEC_SystemQueries {
    
    // Variables de instancia para configuración del sistema
    private final String emailTemplateDeveloperName;
    private final String jobNamePattern;
    
    /**
     * @description Constructor con valores por defecto
     */
    public VEC_SystemQueries() {
        this.emailTemplateDeveloperName = 'VEC_Manager_Prospect_Activity_Alert';
        this.jobNamePattern = 'VEC Prospect Activity Alert%';
    }
    
    /**
     * @description Constructor con configuración personalizada (para testing)
     * @param emailTemplateDeveloperName Nombre del email template
     * @param jobNamePattern Patrón para buscar jobs
     */
    public VEC_SystemQueries(String emailTemplateDeveloperName, String jobNamePattern) {
        this.emailTemplateDeveloperName = emailTemplateDeveloperName;
        this.jobNamePattern = jobNamePattern;
    }
    
    /**
     * @description Obtiene el Email Template para notificaciones
     * @return EmailTemplate Template configurado o null si no existe
     */
    public EmailTemplate getProspectActivityEmailTemplate() {
        List<EmailTemplate> templates = [
            SELECT Id, Name, Subject, Body, HtmlValue
            FROM EmailTemplate 
            WHERE DeveloperName = :emailTemplateDeveloperName
            LIMIT 1
        ];
        
        return templates.isEmpty() ? null : templates[0];
    }
    
    /**
     * @description Obtiene OrgWideEmailAddress para envíos institucionales
     * @return OrgWideEmailAddress Dirección organizacional o null si no existe
     */
    public OrgWideEmailAddress getOrgWideEmailAddress() {
        List<OrgWideEmailAddress> orgEmails = [
            SELECT Id, Address, DisplayName
            FROM OrgWideEmailAddress 
            WHERE IsAllowAllProfiles = true
            LIMIT 1
        ];
        
        return orgEmails.isEmpty() ? null : orgEmails[0];
    }
    
    /**
     * @description Obtiene todos los OrgWideEmailAddress disponibles
     * @return List<OrgWideEmailAddress> Lista de direcciones organizacionales
     */
    public List<OrgWideEmailAddress> getAllOrgWideEmailAddresses() {
        return [
            SELECT Id, Address, DisplayName, IsAllowAllProfiles
            FROM OrgWideEmailAddress 
            ORDER BY DisplayName
        ];
    }
    
    /**
     * @description Obtiene jobs programados del sistema de alertas
     * @return List<CronTrigger> Lista de jobs programados
     */
    public List<CronTrigger> getScheduledProspectActivityJobs() {
        return [
            SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime, 
                   CronExpression, StartTime, EndTime
            FROM CronTrigger 
            WHERE CronJobDetail.Name LIKE :jobNamePattern
        ];
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
     * @description Valida si existe el RecordType requerido para Leads
     * @param recordTypeDeveloperName Nombre del developer del RecordType
     * @return Boolean True si existe el RecordType activo
     */
    public Boolean validateLeadRecordType(String recordTypeDeveloperName) {
        try {
            Integer count = [
                SELECT COUNT()
                FROM RecordType
                WHERE SObjectType = 'Lead'
                AND DeveloperName = :recordTypeDeveloperName
                AND IsActive = true
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_SystemQueries: Error validando RecordType: ' + e.getMessage());
            return false;
        }
    }
    
    /**
     * @description Obtiene información detallada de un RecordType específico
     * @param sobjectType Tipo de sObject (ej: 'Lead', 'Opportunity')
     * @param recordTypeDeveloperName Nombre del developer del RecordType
     * @return RecordType Información del RecordType o null si no existe
     */
    public RecordType getRecordTypeInfo(String sobjectType, String recordTypeDeveloperName) {
        List<RecordType> recordTypes = [
            SELECT Id, Name, DeveloperName, SObjectType, IsActive, Description
            FROM RecordType
            WHERE SObjectType = :sobjectType
            AND DeveloperName = :recordTypeDeveloperName
            LIMIT 1
        ];
        
        return recordTypes.isEmpty() ? null : recordTypes[0];
    }
    
    /**
     * @description Obtiene todos los RecordTypes activos para un sObject
     * @param sobjectType Tipo de sObject
     * @return List<RecordType> Lista de RecordTypes activos
     */
    public List<RecordType> getActiveRecordTypes(String sobjectType) {
        return [
            SELECT Id, Name, DeveloperName, SObjectType, IsActive, Description
            FROM RecordType
            WHERE SObjectType = :sobjectType
            AND IsActive = true
            ORDER BY Name
        ];
    }
    
    /**
     * @description Obtiene perfiles específicos del sistema VEC
     * @param profileNames Lista de nombres de perfiles a buscar
     * @return List<Profile> Lista de perfiles encontrados
     */
    public List<Profile> getVECProfiles(List<String> profileNames) {
        return [
            SELECT Id, Name, Description, UserType
            FROM Profile
            WHERE Name IN :profileNames
        ];
    }
    
    /**
     * @description Valida existencia de perfiles requeridos
     * @param profileNames Lista de nombres de perfiles a validar
     * @return Map<String, Boolean> Mapa con perfil como key y existencia como value
     */
    public Map<String, Boolean> validateProfiles(List<String> profileNames) {
        Map<String, Boolean> profileExists = new Map<String, Boolean>();
        
        List<Profile> foundProfiles = getVECProfiles(profileNames);
        Set<String> foundProfileNames = new Set<String>();
        
        for (Profile p : foundProfiles) {
            foundProfileNames.add(p.Name);
        }
        
        for (String profileName : profileNames) {
            profileExists.put(profileName, foundProfileNames.contains(profileName));
        }
        
        return profileExists;
    }
    
    /**
     * @description Obtiene configuración de límites del sistema
     * @return Map<String, Object> Información de límites relevantes
     */
    public Map<String, Object> getSystemLimits() {
        Map<String, Object> limits = new Map<String, Object>();
        
        limits.put('emailInvocations', Limits.getEmailInvocations());
        limits.put('limitEmailInvocations', Limits.getLimitEmailInvocations());
        limits.put('dmlStatements', Limits.getDmlStatements());
        limits.put('limitDmlStatements', Limits.getLimitDmlStatements());
        limits.put('queries', Limits.getQueries());
        limits.put('limitQueries', Limits.getLimitQueries());
        limits.put('heapSize', Limits.getHeapSize());
        limits.put('limitHeapSize', Limits.getLimitHeapSize());
        
        return limits;
    }
    
    /**
     * @description Obtiene información de AsyncApexJob para monitoreo de batches
     * @param jobTypes Lista de tipos de job a buscar (ej: 'BatchApex', 'Queueable')
     * @return List<AsyncApexJob> Lista de jobs async
     */
    public List<AsyncApexJob> getAsyncApexJobs(List<String> jobTypes) {
        return [
            SELECT Id, JobType, ApexClass.Name, Status, JobItemsProcessed, TotalJobItems,
                   NumberOfErrors, CreatedDate, CompletedDate, ExtendedStatus
            FROM AsyncApexJob
            WHERE JobType IN :jobTypes
            AND ApexClass.Name LIKE 'VEC%'
            ORDER BY CreatedDate DESC
            LIMIT 50
        ];
    }
    
    /**
     * @description Método utilitario para obtener constantes del sistema
     * @return Map<String, String> Constantes utilizadas en el sistema
     */
    public Map<String, String> getSystemConstants() {
        return new Map<String, String>{
            'EMAIL_TEMPLATE_DEV_NAME' => emailTemplateDeveloperName,
            'JOB_NAME_PATTERN' => jobNamePattern
        };
    }
}