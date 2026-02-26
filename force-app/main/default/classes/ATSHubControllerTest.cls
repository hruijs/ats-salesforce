@IsTest
private class ATSHubControllerTest {

    @TestSetup
    static void setup() {
        Job__c job = new Job__c(
            Title__c = 'Test Developer',
            Status__c = 'Open',
            Department__c = 'Engineering',
            Location__c = 'Amsterdam',
            Priority__c = 'High'
        );
        insert job;

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = new Contact(
            RecordTypeId = candidateRtId,
            FirstName = 'Test',
            LastName = 'Candidate',
            Email = 'test@example.com',
            Phone = '+31600000000',
            Current_Job_Title__c = 'Developer',
            Current_Company__c = 'Test Corp',
            Skills__c = 'Java; Apex',
            Languages__c = 'Dutch; English',
            CV_Parsed__c = true
        );
        insert c;

        Application__c app = new Application__c(
            Candidate__c = c.Id,
            Job__c = job.Id,
            Stage__c = 'New',
            Source__c = 'LinkedIn',
            Applied_Date__c = Date.today()
        );
        insert app;

        Interview__c iv = new Interview__c(
            Application__c = app.Id,
            Round__c = 1,
            Interview_Type__c = 'Phone Screen',
            Scheduled_Date__c = DateTime.now().addDays(1),
            Status__c = 'Scheduled',
            Duration_Minutes__c = 60,
            Location__c = 'Online',
            Notes__c = 'Test notes'
        );
        insert iv;
    }

    // ─── getOpenJobs ───

    @IsTest
    static void testGetOpenJobs() {
        List<Job__c> jobs = ATSHubController.getOpenJobs();
        System.assertEquals(1, jobs.size());
        System.assertEquals('Test Developer', jobs[0].Title__c);
    }

    // ─── getRecentCandidates ───

    @IsTest
    static void testGetRecentCandidates() {
        List<ATSHubController.CandidateWrapper> candidates = ATSHubController.getRecentCandidates();
        System.assertEquals(1, candidates.size());
        System.assertEquals('Test Candidate', candidates[0].name);
        System.assertEquals(1, candidates[0].applicationCount);
    }

    // ─── createCandidateWithApplication ───

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
        data.availability = 'Immediately';

        GeminiService.Education edu = new GeminiService.Education();
        edu.degree = 'MSc';
        edu.fieldOfStudy = 'Computer Science';
        edu.institution = 'TU Delft';
        edu.startYear = '2015';
        edu.endYear = '2017';
        data.education = new List<GeminiService.Education>{ edu };

        GeminiService.WorkExperience exp = new GeminiService.WorkExperience();
        exp.jobTitle = 'Developer';
        exp.company = 'TechCo';
        exp.startDate = '2017-06';
        exp.endDate = '2024-01';
        exp.description = 'Built Apex solutions';
        data.workExperience = new List<GeminiService.WorkExperience>{ exp };

        String jsonData = JSON.serialize(data);

        Test.startTest();
        Id contactId = ATSHubController.createCandidateWithApplication(
            jsonData, job.Id, 'LinkedIn', null, null
        );
        Test.stopTest();

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = [SELECT FirstName, LastName, Email, CV_Parsed__c, Skills__c, RecordTypeId,
                            Education_Summary__c, Work_Experience__c, Professional_Summary__c
                     FROM Contact WHERE Id = :contactId];
        System.assertEquals('Jan', c.FirstName);
        System.assertEquals('de Vries', c.LastName);
        System.assertEquals(true, c.CV_Parsed__c);
        System.assertEquals(candidateRtId, c.RecordTypeId);
        System.assert(c.Skills__c.contains('Java'));
        System.assert(c.Education_Summary__c != null);
        System.assert(c.Work_Experience__c != null);

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
            jsonData, null, 'Career Page', null, null
        );
        Test.stopTest();

        Contact c = [SELECT FirstName, LastName FROM Contact WHERE Id = :contactId];
        System.assertEquals('Anna', c.FirstName);

        List<Application__c> apps = [SELECT Id FROM Application__c WHERE Candidate__c = :contactId];
        System.assertEquals(0, apps.size());
    }

    // ─── parseCvFromUpload ───

    @IsTest
    static void testParseCvFromUploadFailsGracefully() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ATSHubController.parseCvFromUpload('invalidbase64');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Expected AuraHandledException to be thrown');
    }

    // ─── getCandidates ───

    @IsTest
    static void testGetCandidatesNoSearch() {
        Test.startTest();
        List<ATSHubController.CandidateWrapper> candidates = ATSHubController.getCandidates(null);
        Test.stopTest();

        System.assertEquals(1, candidates.size());
        System.assertEquals('test@example.com', candidates[0].email);
        System.assert(candidates[0].skills != null);
    }

    @IsTest
    static void testGetCandidatesWithSearch() {
        Test.startTest();
        List<ATSHubController.CandidateWrapper> results = ATSHubController.getCandidates('Test');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('Test Candidate', results[0].name);
    }

    @IsTest
    static void testGetCandidatesNoMatch() {
        Test.startTest();
        List<ATSHubController.CandidateWrapper> results = ATSHubController.getCandidates('ZZZZNONEXISTENT');
        Test.stopTest();

        System.assertEquals(0, results.size());
    }

    // ─── assignCandidateToJob ───

    @IsTest
    static void testAssignCandidateToJob() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];
        // Create a second job to assign to
        Job__c job2 = new Job__c(Title__c = 'QA Engineer', Status__c = 'Open');
        insert job2;

        Test.startTest();
        Id appId = ATSHubController.assignCandidateToJob(c.Id, job2.Id, 'Referral');
        Test.stopTest();

        Application__c app = [SELECT Stage__c, Source__c, Job__c FROM Application__c WHERE Id = :appId];
        System.assertEquals('New', app.Stage__c);
        System.assertEquals('Referral', app.Source__c);
        System.assertEquals(job2.Id, app.Job__c);
    }

    @IsTest
    static void testAssignCandidateToJobDuplicate() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];
        Job__c job = [SELECT Id FROM Job__c LIMIT 1];

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            // Candidate is already assigned to this job in TestSetup
            ATSHubController.assignCandidateToJob(c.Id, job.Id, 'LinkedIn');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown, 'Expected duplicate assignment exception');
    }

    // ─── getApplicationDetail ───

    @IsTest
    static void testGetApplicationDetail() {
        Application__c app = [SELECT Id FROM Application__c LIMIT 1];

        Test.startTest();
        ATSHubController.ApplicationDetail detail = ATSHubController.getApplicationDetail(app.Id);
        Test.stopTest();

        System.assertEquals('Test Candidate', detail.candidateName);
        System.assertEquals('New', detail.stage);
        System.assertEquals('LinkedIn', detail.source);
        System.assert(detail.interviews.size() > 0);
        System.assertEquals('Phone Screen', detail.interviews[0].interviewType);
    }

    // ─── saveInterview ───

    @IsTest
    static void testSaveNewInterview() {
        Application__c app = [SELECT Id FROM Application__c LIMIT 1];

        Map<String, Object> ivFields = new Map<String, Object>{
            'Application__c' => app.Id,
            'Interview_Type__c' => 'Technical',
            'Status__c' => 'Scheduled',
            'Round__c' => 2,
            'Duration_Minutes__c' => 90,
            'Location__c' => 'Office',
            'Scheduled_Date__c' => String.valueOf(DateTime.now().addDays(3)).replace(' ', 'T'),
            'Notes__c' => 'Technical assessment'
        };

        Test.startTest();
        Id ivId = ATSHubController.saveInterview(JSON.serialize(ivFields));
        Test.stopTest();

        Interview__c iv = [SELECT Interview_Type__c, Round__c, Duration_Minutes__c FROM Interview__c WHERE Id = :ivId];
        System.assertEquals('Technical', iv.Interview_Type__c);
        System.assertEquals(2, iv.Round__c);
        System.assertEquals(90, iv.Duration_Minutes__c);
    }

    @IsTest
    static void testUpdateInterview() {
        Interview__c existing = [SELECT Id FROM Interview__c LIMIT 1];

        Map<String, Object> ivFields = new Map<String, Object>{
            'Id' => existing.Id,
            'Status__c' => 'Completed',
            'Notes__c' => 'Good interview'
        };

        Test.startTest();
        Id ivId = ATSHubController.saveInterview(JSON.serialize(ivFields));
        Test.stopTest();

        Interview__c iv = [SELECT Status__c, Notes__c FROM Interview__c WHERE Id = :ivId];
        System.assertEquals('Completed', iv.Status__c);
        System.assertEquals('Good interview', iv.Notes__c);
    }

    // ─── updateApplicationRating ───

    @IsTest
    static void testUpdateApplicationRating() {
        Application__c app = [SELECT Id FROM Application__c LIMIT 1];

        Test.startTest();
        ATSHubController.updateApplicationRating(app.Id, 4.5);
        Test.stopTest();

        Application__c updated = [SELECT Overall_Rating__c FROM Application__c WHERE Id = :app.Id];
        System.assertEquals(4.5, updated.Overall_Rating__c);
    }

    // ─── getInterviewsByCandidate ───

    @IsTest
    static void testGetInterviewsByCandidate() {
        Contact c = [SELECT Id FROM Contact WHERE LastName = 'Candidate' LIMIT 1];

        Test.startTest();
        ATSHubController.CandidateInterviewData data = ATSHubController.getInterviewsByCandidate(c.Id);
        Test.stopTest();

        System.assertEquals(1, data.applications.size());
        System.assertEquals('Test Developer', data.applications[0].jobTitle);
        System.assertEquals(1, data.interviews.size());
        System.assertEquals('Phone Screen', data.interviews[0].interviewType);
    }

    // ─── deleteInterview ───

    @IsTest
    static void testDeleteInterview() {
        Interview__c iv = [SELECT Id FROM Interview__c LIMIT 1];

        Test.startTest();
        ATSHubController.deleteInterview(iv.Id);
        Test.stopTest();

        List<Interview__c> remaining = [SELECT Id FROM Interview__c WHERE Id = :iv.Id];
        System.assertEquals(0, remaining.size());
    }

    // ─── getUpcomingInterviews ───

    @IsTest
    static void testGetUpcomingInterviews() {
        Test.startTest();
        List<ATSHubController.UpcomingInterview> upcoming = ATSHubController.getUpcomingInterviews();
        Test.stopTest();

        System.assert(upcoming.size() > 0);
        System.assertEquals('Test Candidate', upcoming[0].candidateName);
        System.assertEquals('TC', upcoming[0].candidateInitials);
        System.assertEquals('Phone Screen', upcoming[0].interviewType);
    }

    // ─── saveJob ───

    @IsTest
    static void testSaveNewJob() {
        Map<String, Object> jobFields = new Map<String, Object>{
            'Title__c' => 'UX Designer',
            'Department__c' => 'Marketing',
            'Location__c' => 'Rotterdam',
            'Job_Type__c' => 'Full-time',
            'Description__c' => 'Design awesome UX',
            'Requirements__c' => '3+ years experience',
            'Number_of_Openings__c' => 2,
            'Salary_Min__c' => 50000,
            'Salary_Max__c' => 70000
        };

        Test.startTest();
        Id jobId = ATSHubController.saveJob(JSON.serialize(jobFields));
        Test.stopTest();

        Job__c job = [SELECT Title__c, Status__c, Priority__c, Open_Date__c, Department__c, Salary_Min__c
                      FROM Job__c WHERE Id = :jobId];
        System.assertEquals('UX Designer', job.Title__c);
        System.assertEquals('Open', job.Status__c);
        System.assertEquals('Medium', job.Priority__c);
        System.assertEquals(Date.today(), job.Open_Date__c);
        System.assertEquals(50000, job.Salary_Min__c);
    }

    @IsTest
    static void testUpdateJob() {
        Job__c existing = [SELECT Id FROM Job__c LIMIT 1];

        Map<String, Object> jobFields = new Map<String, Object>{
            'Id' => existing.Id,
            'Title__c' => 'Senior Developer',
            'Status__c' => 'On Hold'
        };

        Test.startTest();
        Id jobId = ATSHubController.saveJob(JSON.serialize(jobFields));
        Test.stopTest();

        Job__c job = [SELECT Title__c, Status__c FROM Job__c WHERE Id = :jobId];
        System.assertEquals('Senior Developer', job.Title__c);
        System.assertEquals('On Hold', job.Status__c);
    }

    // ─── closeJob ───

    @IsTest
    static void testCloseJob() {
        Job__c job = [SELECT Id FROM Job__c LIMIT 1];

        Test.startTest();
        ATSHubController.closeJob(job.Id);
        Test.stopTest();

        Job__c closed = [SELECT Status__c, Close_Date__c FROM Job__c WHERE Id = :job.Id];
        System.assertEquals('Closed - Filled', closed.Status__c);
        System.assertEquals(Date.today(), closed.Close_Date__c);
    }

    // ─── getActiveUsers ───

    @IsTest
    static void testGetActiveUsers() {
        Test.startTest();
        List<ATSHubController.UserOption> users = ATSHubController.getActiveUsers();
        Test.stopTest();

        System.assert(users.size() > 0, 'Should return at least the running user');
        System.assert(users[0].userName != null);
        System.assert(users[0].userId != null);
    }
}
