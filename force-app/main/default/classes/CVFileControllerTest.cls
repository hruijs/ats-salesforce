@isTest
private class CVFileControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Candidate',
            AccountId = acc.Id,
            Email = 'test@example.com'
        );
        insert con;

        // Create a test PDF file
        ContentVersion cv = new ContentVersion(
            Title = 'Test CV',
            PathOnClient = 'test_cv.pdf',
            VersionData = Blob.valueOf('test pdf content'),
            IsMajorVersion = true
        );
        insert cv;

        // Get the ContentDocumentId
        cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        // Link to the contact
        ContentDocumentLink cdl = new ContentDocumentLink(
            ContentDocumentId = cv.ContentDocumentId,
            LinkedEntityId = con.Id,
            ShareType = 'V'
        );
        insert cdl;
    }

    @isTest
    static void testGetLatestCvFileId() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        String fileId = CVFileController.getLatestCvFileId(con.Id);
        Test.stopTest();

        System.assertNotEquals(null, fileId, 'Should return a file ID');
    }

    @isTest
    static void testGetLatestCvFile() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        Test.startTest();
        ContentVersion cv = CVFileController.getLatestCvFile(con.Id);
        Test.stopTest();

        System.assertNotEquals(null, cv, 'Should return a ContentVersion');
        System.assertEquals('Test CV', cv.Title);
    }

    @isTest
    static void testGetLatestCvFileId_NoFile() {
        Account acc = new Account(Name = 'Test Account 2');
        insert acc;
        Contact con = new Contact(FirstName = 'No', LastName = 'File', AccountId = acc.Id);
        insert con;

        Test.startTest();
        String fileId = CVFileController.getLatestCvFileId(con.Id);
        Test.stopTest();

        System.assertEquals(null, fileId, 'Should return null when no file exists');
    }

    @isTest
    static void testSaveParsedDataToContact() {
        Contact con = [SELECT Id FROM Contact LIMIT 1];

        GeminiService.CVData data = new GeminiService.CVData();
        data.firstName = 'Jan';
        data.lastName = 'de Vries';
        data.email = 'jan@devries.nl';
        data.phone = '06-12345678';
        data.currentJobTitle = 'Software Engineer';
        data.skills = new List<String>{'Java', 'Apex', 'LWC'};
        data.languages = new List<String>{'Nederlands', 'Engels'};

        GeminiService.Education edu = new GeminiService.Education();
        edu.institution = 'TU Delft';
        edu.degree = 'MSc';
        edu.fieldOfStudy = 'Computer Science';
        edu.startYear = '2018';
        edu.endYear = '2020';
        data.education = new List<GeminiService.Education>{ edu };

        GeminiService.WorkExperience exp = new GeminiService.WorkExperience();
        exp.company = 'Acme Corp';
        exp.jobTitle = 'Software Engineer';
        exp.startDate = '2020-06';
        exp.endDate = '2024-01';
        data.workExperience = new List<GeminiService.WorkExperience>{ exp };

        String jsonData = JSON.serialize(data);

        Test.startTest();
        CVFileController.saveParsedDataToContact(con.Id, jsonData);
        Test.stopTest();

        Contact updated = [
            SELECT FirstName, LastName, Email, Current_Job_Title__c,
                   Skills__c, CV_Parsed__c
            FROM Contact WHERE Id = :con.Id
        ];

        System.assertEquals('Jan', updated.FirstName);
        System.assertEquals('de Vries', updated.LastName);
        System.assert(updated.Skills__c.contains('Java'));
        System.assertEquals(true, updated.CV_Parsed__c);
    }
}
