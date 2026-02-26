@IsTest
private class ContactTriggerHandlerTest {

    @IsTest
    static void testCreateAppFromCandidateStub() {
        List<Contact> contacts = new List<Contact>();
        Map<Id, Contact> oldMap = new Map<Id, Contact>();

        Test.startTest();
        // Should not throw - method is a no-op stub
        ContactTriggerHandler.createAppFromCandidate(contacts, oldMap);
        ContactTriggerHandler.createAppFromCandidate(contacts, null);
        Test.stopTest();
    }

    @IsTest
    static void testSendAuthorizationEmailStub() {
        List<Contact> contacts = new List<Contact>();
        Map<Id, Contact> oldMap = new Map<Id, Contact>();

        Test.startTest();
        ContactTriggerHandler.sendAuthorizationEmail(contacts, oldMap);
        Test.stopTest();
    }

    @IsTest
    static void testSetDecisionDateStub() {
        List<Contact> contacts = new List<Contact>();
        Map<Id, Contact> oldMap = new Map<Id, Contact>();

        Test.startTest();
        ContactTriggerHandler.setDecisionDate(contacts, oldMap);
        Test.stopTest();
    }

    @IsTest
    static void testTriggerFiresOnInsert() {
        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();

        Test.startTest();
        Contact c = new Contact(
            RecordTypeId = candidateRtId,
            FirstName = 'Trigger',
            LastName = 'Test',
            Email = 'trigger@test.com'
        );
        insert c;
        Test.stopTest();

        // Verify contact was inserted successfully (trigger didn't block it)
        Contact inserted = [SELECT Id, FirstName FROM Contact WHERE Id = :c.Id];
        System.assertEquals('Trigger', inserted.FirstName);
    }

    @IsTest
    static void testTriggerFiresOnUpdate() {
        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = new Contact(
            RecordTypeId = candidateRtId,
            FirstName = 'Before',
            LastName = 'Update',
            Email = 'update@test.com'
        );
        insert c;

        Test.startTest();
        c.FirstName = 'After';
        update c;
        Test.stopTest();

        Contact updated = [SELECT FirstName FROM Contact WHERE Id = :c.Id];
        System.assertEquals('After', updated.FirstName);
    }
}
