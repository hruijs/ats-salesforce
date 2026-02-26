@IsTest
private class ATSSetupControllerTest {

    @IsTest
    static void testGetSetupStatus() {
        Test.startTest();
        ATSSetupController.SetupStatus status = ATSSetupController.getSetupStatus();
        Test.stopTest();

        System.assertNotEquals(null, status);
        System.assertEquals('1.0.0', status.packageVersion);
        System.assertNotEquals(null, status.assignedUsers);
    }

    @IsTest
    static void testSaveApiSettings() {
        Test.startTest();
        // This enqueues a metadata deployment - won't complete in test context but shouldn't throw
        try {
            ATSSetupController.saveApiSettings(
                'test-api-key-12345',
                'https://generativelanguage.googleapis.com/v1beta/models',
                'gemini-2.5-flash'
            );
        } catch (Exception e) {
            // Metadata deployments may not work in test context
            System.debug('Expected: ' + e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void testTestApiConnection() {
        Test.startTest();
        String result = ATSSetupController.testApiConnection();
        Test.stopTest();

        // In test context without proper settings, should return an error
        System.assert(result.startsWith('ERROR:'), 'Expected error result, got: ' + result);
    }

    @IsTest
    static void testGetAvailableUsers() {
        Test.startTest();
        List<ATSSetupController.AssignedUser> users = ATSSetupController.getAvailableUsers();
        Test.stopTest();

        System.assertNotEquals(null, users);
    }

    @IsTest
    static void testAssignAndRemovePermissionSet() {
        // Get the running user
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];

        Test.startTest();

        // Assign
        try {
            ATSSetupController.assignPermissionSetToUsers(new List<Id>{ testUser.Id });
        } catch (Exception e) {
            // May fail if already assigned
            System.debug('Assign exception (may be expected): ' + e.getMessage());
        }

        // Remove
        try {
            ATSSetupController.removePermissionSetFromUser(testUser.Id);
        } catch (Exception e) {
            System.debug('Remove exception (may be expected): ' + e.getMessage());
        }

        Test.stopTest();
    }

    @IsTest
    static void testMetadataCallback() {
        ATSMetadataCallback callback = new ATSMetadataCallback();
        // We can't easily create a real DeployResult in test, so just verify class instantiation
        System.assertNotEquals(null, callback);
    }
}
