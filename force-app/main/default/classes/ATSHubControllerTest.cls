@IsTest
private class ATSHubControllerTest {

    @TestSetup
    static void setup() {
        Job__c job = new Job__c(
            Title__c = 'Test Developer',
            Status__c = 'Open',
            Department__c = 'Engineering',
            Location__c = 'Amsterdam'
        );
        insert job;

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = new Contact(
            RecordTypeId = candidateRtId,
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'test@example.com',
            Current_Job_Title__c = 'Developer',
            Current_Company__c = 'Test Corp',
            CV_Parsed__c = true
        );
        insert c;

        Application__c app = new Application__c(
            Candidate__c = c.Id,
            Job__c = job.Id,
            Stage__c = 'New',
            Applied_Date__c = Date.today()
        );
        insert app;
    }

    @IsTest
    static void testGetOpenJobs() {
        List<Job__c> jobs = ATSHubController.getOpenJobs();
        System.assertEquals(1, jobs.size());
        System.assertEquals('Test Developer', jobs[0].Title__c);
    }

    @IsTest
    static void testGetRecentCandidates() {
        List<ATSHubController.CandidateWrapper> candidates = ATSHubController.getRecentCandidates();
        System.assertEquals(1, candidates.size());
        System.assertEquals('Test Candidate', candidates[0].name);
        System.assertEquals(1, candidates[0].applicationCount);
    }

    @IsTest
    static void testCreateCandidateWithApplication() {
        Job__c job = [SELECT Id FROM Job__c LIMIT 1];

        GeminiService.CVData data = new GeminiService.CVData();
        data.firstName = 'Jan';
        data.lastName = 'de Vries';
        data.email = 'jan@example.com';
        data.phone = '+31612345678';
        data.currentJobTitle = 'Senior Developer';
        data.currentCompany = 'TechCo';
        data.yearsOfExperience = 5;
        data.skills = new List<String>{'Java', 'Apex', 'LWC'};
        data.languages = new List<String>{'Dutch', 'English'};
        data.summary = 'Experienced developer';

        String jsonData = JSON.serialize(data);

        Test.startTest();
        Id contactId = ATSHubController.createCandidateWithApplication(
            jsonData, job.Id, 'LinkedIn', null, null
        );
        Test.stopTest();

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = [SELECT FirstName, LastName, Email, CV_Parsed__c, Skills__c, RecordTypeId FROM Contact WHERE Id = :contactId];
        System.assertEquals('Jan', c.FirstName);
        System.assertEquals('de Vries', c.LastName);
        System.assertEquals(true, c.CV_Parsed__c);
        System.assertEquals(candidateRtId, c.RecordTypeId);
        System.assert(c.Skills__c.contains('Java'));

        List<Application__c> apps = [SELECT Stage__c, Source__c FROM Application__c WHERE Candidate__c = :contactId];
        System.assertEquals(1, apps.size());
        System.assertEquals('New', apps[0].Stage__c);
        System.assertEquals('LinkedIn', apps[0].Source__c);
    }

    @IsTest
    static void testCreateCandidateWithoutJob() {
        GeminiService.CVData data = new GeminiService.CVData();
        data.firstName = 'Anna';
        data.lastName = 'Bakker';
        data.email = 'anna@example.com';

        String jsonData = JSON.serialize(data);

        Test.startTest();
        Id contactId = ATSHubController.createCandidateWithApplication(
            jsonData, null, 'Website', null, null
        );
        Test.stopTest();

        Contact c = [SELECT FirstName, LastName FROM Contact WHERE Id = :contactId];
        System.assertEquals('Anna', c.FirstName);

        List<Application__c> apps = [SELECT Id FROM Application__c WHERE Candidate__c = :contactId];
        System.assertEquals(0, apps.size());
    }

    @IsTest
    static void testParseCvFromUploadFailsGracefully() {
        Test.startTest();
        try {
            ATSHubController.parseCvFromUpload('invalidbase64');
            System.assert(false, 'Should have thrown exception');
        } catch (AuraHandledException e) {
            System.assert(e.getMessage().contains('CV parsing failed'));
        }
        Test.stopTest();
    }
}
