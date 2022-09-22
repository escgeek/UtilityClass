/*------------------------------------------------------------------------+
Author: Eric Clay (escgeek@gmail.com)

Covering Classes: 
UG_UtilityClass

------------------------------------------------------------------------+*/
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
        
        // Update Record
        UG_UtilityClass.safeDML(accountList, 'Update', 'Account', 'Test Method', 'Account', false);
        
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

    @isTest
    static void handleGenericError_Test(){

        test.startTest();
        // Normal Record
        UG_UtilityClass.handleGenericError('Account','methodName','shortDesc','404','errorMsg','actionType','0013t00002WDV53');
        // Null Test
        UG_UtilityClass.handleGenericError(null,null,null,null,null,null,null);
        test.stopTest();

        // Two Error records should have been created - one with values and another with null values
        Integer genericErrorCount = [SELECT count() FROM Error__c];
        System.assertEquals(2, genericErrorCount, 'Should be two error records');
    }

}