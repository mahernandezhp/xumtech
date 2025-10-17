/**
 * @description Clase centralizada para consultas SOQL de RecordType
 * @author Sistema
 * @version 1.0
 * @since 2025-10-17
 * 
 * Historial de Modificaciones:
 * =============================================================================
 * Versión | Fecha      | Autor   | Descripción
 * =============================================================================
 * 1.0     | 2025-10-17 | Sistema | Creación inicial - Consultas específicas
 *         |            |         | para RecordType del sistema VEC
 * =============================================================================
 */
public class VEC_RecordTypeQueries {
    
    /**
     * @description Constructor
     */
    public VEC_RecordTypeQueries() {
        // Constructor vacío - no necesita configuración específica
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
            System.debug(LoggingLevel.ERROR, 'VEC_RecordTypeQueries: Error validando RecordType: ' + e.getMessage());
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
     * @description Obtiene RecordType por ID
     * @param recordTypeId ID del RecordType
     * @return RecordType RecordType encontrado o null si no existe
     */
    public RecordType getRecordTypeById(Id recordTypeId) {
        List<RecordType> recordTypes = [
            SELECT Id, Name, DeveloperName, SObjectType, IsActive, Description
            FROM RecordType
            WHERE Id = :recordTypeId
            LIMIT 1
        ];
        
        return recordTypes.isEmpty() ? null : recordTypes[0];
    }
    
    /**
     * @description Obtiene el RecordType por defecto para un sObject
     * @param sobjectType Tipo de sObject
     * @return RecordType RecordType por defecto o null si no existe
     */
    public RecordType getDefaultRecordType(String sobjectType) {
        List<RecordType> recordTypes = [
            SELECT Id, Name, DeveloperName, SObjectType, IsActive, Description
            FROM RecordType
            WHERE SObjectType = :sobjectType
            AND IsActive = true
            ORDER BY Name
            LIMIT 1
        ];
        
        return recordTypes.isEmpty() ? null : recordTypes[0];
    }
    
    /**
     * @description Valida si existe un RecordType específico
     * @param sobjectType Tipo de sObject
     * @param recordTypeDeveloperName Nombre del developer del RecordType
     * @return Boolean True si existe el RecordType
     */
    public Boolean validateRecordType(String sobjectType, String recordTypeDeveloperName) {
        try {
            Integer count = [
                SELECT COUNT()
                FROM RecordType
                WHERE SObjectType = :sobjectType
                AND DeveloperName = :recordTypeDeveloperName
                AND IsActive = true
            ];
            return count > 0;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'VEC_RecordTypeQueries: Error validando RecordType: ' + e.getMessage());
            return false;
        }
    }
}