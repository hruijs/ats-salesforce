@isTest
private class ApplicationControllerTest {

    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Company');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Jan',
            LastName = 'Tester',
            AccountId = acc.Id,
            Email = 'jan@test.com'
        );
        insert con;

        Job__c job = new Job__c(
            Title__c = 'Software Engineer',
            Status__c = 'Open',
            Priority__c = 'High'
        );
        insert job;

        Application__c app = new Application__c(
            Candidate__c = con.Id,
            Job__c = job.Id,
            Stage__c = 'New',
            Applied_Date__c = Date.today()
        );
        insert app;

        Interview__c interview = new Interview__c(
            Application__c = app.Id,
            Round__c = 1,
            Interview_Type__c = 'Phone Screen',
            Scheduled_Date__c = DateTime.now().addDays(1),
            Status__c = 'Scheduled'
        );
        insert interview;
    }

    @isTest
    static void testGetApplicationsByJob() {
        Job__c job = [SELECT Id FROM Job__c LIMIT 1];

        Test.startTest();
        List<ApplicationController.ApplicationWrapper> apps =
            ApplicationController.getApplicationsByJob(job.Id);
        Test.stopTest();

        System.assertEquals(1, apps.size());
        System.assertEquals('Jan Tester', apps[0].candidateName);
        System.assertEquals('New', apps[0].stage);
    }

    @isTest
    static void testGetPipelineStats() {
        Job__c job = [SELECT Id FROM Job__c LIMIT 1];

        Test.startTest();
        ApplicationController.PipelineStats stats =
            ApplicationController.getPipelineStats(job.Id);
        Test.stopTest();

        System.assertEquals(1, stats.totalNew);
        System.assertEquals(1, stats.totalActive);
    }

    @isTest
    static void testGetJobDashboard() {
        Test.startTest();
        List<ApplicationController.JobDashboardData> dashboard =
            ApplicationController.getJobDashboard();
        Test.stopTest();

        System.assertEquals(1, dashboard.size());
        System.assertEquals('Software Engineer', dashboard[0].job.Title__c);
    }

    @isTest
    static void testUpdateApplicationStage() {
        Application__c app = [SELECT Id FROM Application__c LIMIT 1];

        Test.startTest();
        ApplicationController.updateApplicationStage(app.Id, 'Screening');
        Test.stopTest();

        Application__c updated = [SELECT Stage__c, Last_Stage_Change_Date__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals('Screening', updated.Stage__c);
        System.assertEquals(Date.today(), updated.Last_Stage_Change_Date__c);
    }
}
