@IsTest
private class CVParsingQueueableTest {

    @TestSetup
    static void setup() {
        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = new Contact(
            RecordTypeId = candidateRtId,
            FirstName = 'Raw',
            LastName = 'Candidate',
            Email = 'raw@example.com'
        );
        insert c;

        // Create a fake PDF ContentVersion linked to the contact
        ContentVersion cv = new ContentVersion();
        cv.Title = 'TestCV';
        cv.PathOnClient = 'testcv.pdf';
        cv.VersionData = Blob.valueOf('fake pdf content');
        cv.FirstPublishLocationId = c.Id;
        insert cv;
    }

    @IsTest
    static void testQueueableExecuteWithMock() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        // Mock the Gemini API callout
        Test.setMock(HttpCalloutMock.class, new GeminiParseMock());

        Test.startTest();
        System.enqueueJob(new CVParsingQueueable(c.Id, cv.Id));
        Test.stopTest();

        // Verify the contact was updated with parsed data
        Contact updated = [SELECT FirstName, LastName, Email, CV_Parsed__c, Skills__c,
                                  Current_Job_Title__c, Current_Company__c
                           FROM Contact WHERE Id = :c.Id];
        System.assertEquals(true, updated.CV_Parsed__c);
    }

    @IsTest
    static void testQueueableHandlesException() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        // Mock that returns an error
        Test.setMock(HttpCalloutMock.class, new GeminiErrorMock());

        Test.startTest();
        // Should not throw - errors are caught and logged
        System.enqueueJob(new CVParsingQueueable(c.Id, cv.Id));
        Test.stopTest();

        // Contact should remain unchanged (parsing failed gracefully)
        Contact unchanged = [SELECT CV_Parsed__c FROM Contact WHERE Id = :c.Id];
        // CV_Parsed__c was not set in TestSetup, so it should still be false
        System.assertEquals(false, unchanged.CV_Parsed__c);
    }

    @IsTest
    static void testConstructor() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];
        ContentVersion cv = [SELECT Id FROM ContentVersion LIMIT 1];

        CVParsingQueueable q = new CVParsingQueueable(c.Id, cv.Id);
        System.assertNotEquals(null, q);
    }

    // Mock that returns a valid Gemini response
    private class GeminiParseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String cvJson = '{"firstName":"Parsed","lastName":"Person","email":"parsed@test.com",' +
                '"currentJobTitle":"Engineer","currentCompany":"TestCo","skills":["Java","Apex"]}';
            res.setBody('{"candidates":[{"content":{"parts":[{"text":' + JSON.serialize(cvJson) + '}]}}]}');
            return res;
        }
    }

    // Mock that returns an error
    private class GeminiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error":"Internal Server Error"}');
            return res;
        }
    }
}
