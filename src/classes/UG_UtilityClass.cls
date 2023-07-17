/*--------------------------------------------------------------------------------------------------------------------+
Author: Eric Clay (eric@ultrageek.com)

History: This class started as a way to do two things: catch errors and prevent trigger recursion. Over the years and 
via different projects I have made small updates and improvements on the methods to make them easier to use and more
flexible for more use cases.

Methods

safeDML - Method that inserts, updates, upserts, and deletes records with support for disabling CPQ Triggers and using 
the updatePending variable to prevent recursiveness/triggers from refiring again as needed. USes a custom object named
'Errors__c' to log DML errors for additional tracking, reporting, and debugging. Previously this method was called 
'safeUpdate' but I renamed tihs method since it does a lot more than just do updates.

createError - Method for creating either single record or returning the record so it can be inserted as part of a list
of errors. Queueable or batch class finalizers would only need 1 record were maybe web service callout errors would 
require to just return the record and do the DML after the callout has completed.

generateRecordId - It is safer and best practice to create record Id's vs. using hardcoded Ids across instances and more 
importantly across customers. Method from the Financial Force project that returns a made up record Id with the correct object 
prefix in a valid 18 character format. Made 1 small update on how it works to make it easier to use but otherwise
the exact same. Very useful in test classes when you do not need to insert a record but need a record Id.

random - Method used to create a random string of characters. Good for creating unique email address, street addresses, 
etc. for creating data for regression testing and test classes.

2019-05-19 - First Iteration
2022-09-22 - Updates for publishing out to Github
2023-07-12 - Quality of Life type Updates: Shorter safeDML method, Upsert field support, Error Message Map

Test Class: UG_UtilityClassTest
--------------------------------------------------------------------------------------------------------------------+*/
public class UG_UtilityClass {

    public static Boolean updatesPending = false;

    public static Map<Id, String> errorMessages;
    // New simple mode - Shortens the required arguments and uses assumed defaults that are appropriate 99% of the time 
    public static void safeDML(list<sObject> records, String dmlType, String objectName, String methodName){
        safeDML(records, dmlType, objectName, methodName, null, false, null);
    }
    // CPQ disable triggers support
    public static void safeDML(list<sObject> records, String dmlType, String objectName, String methodName, String errorMessage, Boolean disableCPQTriggers){
        safeDML(records, dmlType, objectName, methodName, errorMessage, disableCPQTriggers, null);
    }
    // Full command with Upsert2 support passing a specific upsert field
    public static void safeDML(list<sObject> records, String dmlType, String objectName, String methodName, String errorMessage, Boolean disableCPQTriggers, String upsertField){
        // Environment switches
        updatesPending = true; // Prevents triggers that have the 'UG_UtilityClass.updatesPending' check from refiring
        // toggleCPQTriggers(disableCPQTriggers); // CPQ Support - Triggers Toggle On/Off - Uncomment to add and use
        // Default Error Message
        errorMessage = (errorMessage == null) ? dmlType + 'ing ' + objectName + ' records' : errorMessage;
        errorMessage = (errorMessage.contains('eing')) ? errorMessage.replace('eing', 'ing') : errorMessage;
        // Variables
        dmlType = dmlType?.toUpperCase(); 
        if(records.size() > 0){
            // Logic
            system.debug('[DML ' + dmlType + ' Action][' + records.size() + '] - ' + errorMessage + ': ' + records);
            switch on dmlType {
                when 'UPDATE'{
                    List<Database.SaveResult> results = Database.update(records, false);
                    handleErrors(JSON.serialize(results), records, objectName, methodName, dmlType.toUpperCase(), errorMessage);
                }
                when 'INSERT'{
                    List<Database.SaveResult> results = Database.insert(records,false);
                    handleErrors(JSON.serialize(results), records, objectName, methodName, dmlType.toUpperCase(), errorMessage);
                }
                when 'UPSERT'{
                    List<Database.UpsertResult> results = Database.upsert(records,false);
                    handleErrors(JSON.serialize(results), records, objectName, methodName, dmlType.toUpperCase(), errorMessage);
                }
                when 'UPSERT2'{
                    Schema.SObjectField externalField = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(upsertField);
                    List<Database.UpsertResult> results = Database.upsert(records, externalField, false);
                    handleErrors(JSON.serialize(results), records, objectName, methodName, dmlType.toUpperCase(), errorMessage);
                }
                when 'DELETE'{
                    List<Database.DeleteResult> results = Database.delete(records,false);
                    handleErrors(JSON.serialize(results), records, objectName, methodName, dmlType.toUpperCase(), errorMessage);
                }
            }
        }
        // toggleCPQTriggers(disableCPQTriggers); // CPQ Support - Triggers Toggle On/Off - Uncomment to add 
        updatesPending = false;
    }

    // CPQ Support - Triggers Toggle On/Off - Uncomment to add 
    /* public static void toggleCPQTriggers(Boolean disableCPQTriggers){
        // Toggle CPQ Triggers for updates that do not require CPQ automation
        if(disableCPQTriggers){
            if(SBQQ.TriggerControl.isEnabled()){
                SBQQ.TriggerControl.disable();
            } else {
                SBQQ.TriggerControl.enable();
            }
        }
    } */

    /* public static boolean triggerDisabled(string triggerOrClass){
        // Checks to make sure that there is a custom setting named "Trigger FailSafe Switch" and used to manage 
        // dynamically disabling classes or methods.
        // How this is used is by creating a custom setting and then for certain classes, triggers, or processes you 
        // create a record with a unique name that this meethod then uses to control execution with the default being
        // on or enabled. This is just a simple solution assuming that there is not already a trigger handler in place
        // already to handle these types of controls.
        // The reason to use a custom setting over a custom metadata setting is flexibility and typically this is only 
        // needed for emergency and debug situations so the need to persist data across orgs is not critical. It is also
        // something that could be either data loaded or loaded via an apex script.
        // 
        // Example: if(UG_UtilityClass.triggerDisabled('UG_UtilityClass')) return; // Stops if the Custom Setting 'UG_UtilityClass' is 'Disabled' under Custom Setting 'Trigger FailSafe Switch'
        Apex_Failsafe_Switch__mdt quick_Disable = Apex_Failsafe_Switch__mdt.getInstance(triggerOrClass);
        if(quick_Disable != NULL && quick_Disable.Disable__c == true){
            system.debug('[triggerDisabled] Class or Trigger Disabled: ' + triggerOrClass);
            return true;
        }
        else {
            return false;
        }
    } */

    // Error handling method
    public static void handleErrors( 
        String saveResults, 
        List <sObject> records,
        String objectName, 
        String methodName, 
        String dmlType, 
        String shortDesc
    ) {
        errorMessages = (errorMessages == null) ? new Map<Id, String>() : errorMessages; // This was added to support returning the error messages 
        List<Error__c> errors = new List<Error__c>();
        Integer index = 0;
        for(DatabaseResult dml : (list<UG_UtilityClass.DatabaseResult>) JSON.deserialize(saveResults, list<UG_UtilityClass.DatabaseResult>.class)){
            String recordId = (dmlType != null) ? records.get(index).Id : null;
            if(!dml.success){
                Error e = dml.errors[0];
                System.debug('DatabaseResult: ' + dml + ' Error: ' + e); // This debug message helps when debugging test classes where an error record will not be persisted after the test class finishes
                // The object and destination fields can be changed as needed to work with existing objects
                errors.add(new Error__c (
                    Object__c = objectName,
                    Source__c = methodName, // Would recommend class.method : 'UG_UtilityClass.handleErrors'
                    Action__c = dmlType,
                    Error_Description__c = shortDesc,
                    Record_Id__c = recordId,
                    // Error Messages
                    Error_Message__c = e.message?.left(255), 
                    Cause__c = e.statusCode,
                    Raw_Error_Message__c = String.valueOf(dml)?.left(255)
                ));
                errorMessages.put(recordId, e.message); // DML errors map
            }
            ++index;
        }
        safeDML(errors, 'Insert', 'Error__c', 'UG_UtilityClass.handleErrors', 'Oops...our error handler threw an error!',false);
    }
    // Logging errors outside of DML errors - Supports creating 1 or returning the record in order to insert as part of a list
    public static Error__c createError( 
        String objectName, 
        String methodName, 
        String shortDesc,
        String statusCode,
        String errorMsg,
        String actionType,
        String recordId
    ){
        return createError(objectName, methodName, shortDesc, statusCode, errorMsg, actionType, recordId, false);
    }
    public static Error__c createError( 
        String objectName, 
        String methodName, 
        String shortDesc,
        String statusCode,
        String errorMsg,
        String actionType,
        String recordId,
        Boolean insertRecord
    ){
        Error__c newError = new Error__c(
            Object__c = objectName,
            Source__c = methodName, // Would recommend class.method : 'UG_UtilityClass.handleErrors'
            Action__c = actionType, // Would recommend what type of action caused this error if not a DML action
            Error_Description__c = shortDesc,
            Record_Id__c = recordId,
            // Error Messages
            Error_Message__c = errorMsg?.left(255), 
            Cause__c = statusCode,
            Raw_Error_Message__c = errorMsg?.left(255)
        );
        if(insertRecord){
            insert newError;
        }
        return newError;
    }
    // Returns a random string
    public static String random(){
        return random(10);
    }
    public static String random(Integer length){
        // Max of 24 characters
        Blob blobKey = crypto.generateAesKey(128);
        String random = EncodingUtil.base64encode(blobKey);
        random = (length > 0 && length < 25) ? random.left(length) : random.left(10);
        return random;
    }
    // This can be in your test factory or as a separate utility for generating record id's used in test classes
    /**
	 * Generate a fake Salesforce Id for the given SObjectType
	 * This is from fflib_IDGenerator
	 */
    private static Integer fakeIdCount = 0;
	private static final String ID_PATTERN = '000000000000';
	public static Id generateRecordId(String objectName){
        // Usage:
        // Id accountId = UG_UtilityClass.generateRecordId('Account');
        // Debug returns: 001000000000001AAA, 001000000000002AAA, etc.
		fakeIdCount++;
        String keyPrefix = Schema.getGlobalDescribe().get(objectName)?.getDescribe().getKeyPrefix();
		String fakeIdPrefix = ID_PATTERN.substring(0, 12 - fakeIdCount.format().length());
		return Id.valueOf(keyPrefix + fakeIdPrefix + fakeIdCount);
	}

    // Error handling object
    public class DatabaseResult {
        public Id id;
        public Boolean success;
        public List<Error> errors;
    }
    public class Error {
        public String statusCode;
        public String message;
        public List<String> fields;
    }

}