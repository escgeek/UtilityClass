/*--------------------------------------------------------------------------------------------------------------------+
Author: Eric Clay (eric@ultrageek.com)

Covering Classes: UG_UtilityClass
--------------------------------------------------------------------------------------------------------------------+*/
@isTest 
public class UG_UtilityClassTest {

    @isTest
    public static void safeDML_Test(){

        // Create Test Record
        Account a = new Account(Name = 'Test Account'); // Add your usual test factory account method to create but not insert the record
        List<Account> accountList = new List<Account>{a}; // Add it to a list to stay consistent with how the method is usually used
        
        test.startTest();

        // Insert Record
        UG_UtilityClass.safeDML(accountList, 'Insert', 'Account', 'Test Method', 'Account', false);
        
        // Update Record - Will throw an error
        UG_UtilityClass.safeDML(accountList, 'Update', 'Account', 'Test Method'); // Test the 'short' method
        
        // Upsert Record with Key
        UG_UtilityClass.safeDML(accountList, 'Upsert2', 'Account', 'Test Method', 'Account', false, 'Id');

        // Time to throw an error
        a.Name = '========================================================================================================String longer than 255 characters=======================================================================================================================';
        
        // Upsert Record
        UG_UtilityClass.safeDML(accountList, 'Upsert', 'Account', 'Test Method', 'Account', false);
        
        // Delete Record
        UG_UtilityClass.safeDML(accountList, 'Delete', 'Account', 'Test Method', 'Account', false);

        // Test the CPQ Trigger Disable
        //UG_UtilityClass.toggleCPQTriggers(true); // Toggles off
        //UG_UtilityClass.toggleCPQTriggers(true); // Toggles back on

        test.stopTest();

        // Created, updated, deleted. Should be zero (0)
        Integer accountCount = [SELECT count() FROM Account];
        System.assertEquals(0, accountCount, 'Should be zero accounts after creating, updating, and then deleting Account record');
        

    }

    @isTest public static void errorMethod_Test(){
        Id accountId = UG_UtilityClass.generateRecordId('Account');
        test.startTest();
        // No Return
        Error__c returnError = UG_UtilityClass.createError(
            'Account',
            'className.methodName',
            'Account Class',
            'Callout Failed',
            'Test Failed',
            'Insert',
            accountId
        );
        // Insert and Return record
        Error__c insertError = UG_UtilityClass.createError(
            'Account',
            'className.methodName',
            'Account Class',
            'Callout Failed',
            'Test Failed',
            'Insert',
            accountId,
            true
        );
        test.stopTest();
        Integer errorCount = [SELECT COUNT() FROM Error__c];
        Assert.areEqual(1, errorCount, 'Only 1 record should be created');
    }

    @isTest static void utilityMethod_Test(){
        test.startTest();
        // Test creaeting a record id
        Id accountId = UG_UtilityClass.generateRecordId('Account');

        // Test random function
        String random10 = UG_UtilityClass.random(); // Calls random() for coverage
        String random6 = UG_UtilityClass.random(6); // Calls random() for coverage
        test.stopTest();
        // Test Results
        System.assertEquals('001', String.valueOf(accountId).left(3));

    }
}