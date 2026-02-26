public with sharing class ApplicationController {

    public class ApplicationWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String candidateName;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public Id jobId;
        @AuraEnabled public String stage;
        @AuraEnabled public String subStatus;
        @AuraEnabled public String source;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Decimal overallRating;
        @AuraEnabled public Decimal daysInStage;
        @AuraEnabled public String candidateEmail;
        @AuraEnabled public String candidatePhone;
        @AuraEnabled public String currentJobTitle;
    }

    public class PipelineStats {
        @AuraEnabled public Integer totalNew = 0;
        @AuraEnabled public Integer totalScreening = 0;
        @AuraEnabled public Integer totalInterview = 0;
        @AuraEnabled public Integer totalEvaluation = 0;
        @AuraEnabled public Integer totalOffer = 0;
        @AuraEnabled public Integer totalHired = 0;
        @AuraEnabled public Integer totalRejected = 0;
        @AuraEnabled public Integer totalWithdrawn = 0;
        @AuraEnabled public Integer totalActive = 0;
    }

    public class JobDashboardData {
        @AuraEnabled public Job__c job;
        @AuraEnabled public PipelineStats stats;
        @AuraEnabled public Integer totalApplications;
        @AuraEnabled public Integer interviewsThisWeek;
    }

    @AuraEnabled(cacheable=true)
    public static List<ApplicationWrapper> getApplicationsByJob(Id jobId) {
        List<ApplicationWrapper> wrappers = new List<ApplicationWrapper>();

        for (Application__c app : [
            SELECT Id, Name, Stage__c, Sub_Status__c, Source__c, Applied_Date__c,
                   Overall_Rating__c, Days_in_Current_Stage__c,
                   Candidate__r.FirstName, Candidate__r.LastName, Candidate__r.Id,
                   Candidate__r.Email, Candidate__r.Phone, Candidate__r.Current_Job_Title__c,
                   Job__r.Title__c, Job__r.Id
            FROM Application__c
            WHERE Job__c = :jobId
            ORDER BY Applied_Date__c DESC
        ]) {
            ApplicationWrapper w = new ApplicationWrapper();
            w.id = app.Id;
            w.name = app.Name;
            w.candidateName = app.Candidate__r.FirstName + ' ' + app.Candidate__r.LastName;
            w.candidateId = app.Candidate__r.Id;
            w.jobTitle = app.Job__r.Title__c;
            w.jobId = app.Job__r.Id;
            w.stage = app.Stage__c;
            w.subStatus = app.Sub_Status__c;
            w.source = app.Source__c;
            w.appliedDate = app.Applied_Date__c;
            w.overallRating = app.Overall_Rating__c;
            w.daysInStage = app.Days_in_Current_Stage__c;
            w.candidateEmail = app.Candidate__r.Email;
            w.candidatePhone = app.Candidate__r.Phone;
            w.currentJobTitle = app.Candidate__r.Current_Job_Title__c;
            wrappers.add(w);
        }

        return wrappers;
    }

    @AuraEnabled(cacheable=true)
    public static PipelineStats getPipelineStats(Id jobId) {
        PipelineStats stats = new PipelineStats();

        for (AggregateResult ar : [
            SELECT Stage__c stage, COUNT(Id) cnt
            FROM Application__c
            WHERE Job__c = :jobId
            GROUP BY Stage__c
        ]) {
            String stage = (String) ar.get('stage');
            Integer count = (Integer) ar.get('cnt');

            if (stage == 'New') stats.totalNew = count;
            else if (stage == 'Screening') stats.totalScreening = count;
            else if (stage == 'Interview') stats.totalInterview = count;
            else if (stage == 'Evaluation') stats.totalEvaluation = count;
            else if (stage == 'Offer') stats.totalOffer = count;
            else if (stage == 'Hired') stats.totalHired = count;
            else if (stage == 'Rejected') stats.totalRejected = count;
            else if (stage == 'Withdrawn') stats.totalWithdrawn = count;
        }

        stats.totalActive = stats.totalNew + stats.totalScreening +
            stats.totalInterview + stats.totalEvaluation + stats.totalOffer;

        return stats;
    }

    @AuraEnabled(cacheable=true)
    public static List<JobDashboardData> getJobDashboard() {
        List<JobDashboardData> dashboard = new List<JobDashboardData>();

        List<Job__c> openJobs = [
            SELECT Id, Name, Title__c, Department__c, Location__c, Job_Type__c,
                   Status__c, Priority__c, Open_Date__c, Hiring_Manager__c,
                   Hiring_Manager__r.Name, Recruiter__r.Name, Number_of_Openings__c,
                   Active_Applications__c
            FROM Job__c
            WHERE Status__c IN ('Open', 'On Hold')
            ORDER BY Priority__c DESC, Open_Date__c ASC
        ];

        Set<Id> jobIds = new Set<Id>();
        for (Job__c j : openJobs) jobIds.add(j.Id);

        // Get pipeline stats per job
        Map<Id, PipelineStats> statsMap = new Map<Id, PipelineStats>();
        for (Id jId : jobIds) statsMap.put(jId, new PipelineStats());

        for (AggregateResult ar : [
            SELECT Job__c jobId, Stage__c stage, COUNT(Id) cnt
            FROM Application__c
            WHERE Job__c IN :jobIds
            GROUP BY Job__c, Stage__c
        ]) {
            Id jobId = (Id) ar.get('jobId');
            String stage = (String) ar.get('stage');
            Integer count = (Integer) ar.get('cnt');
            PipelineStats s = statsMap.get(jobId);

            if (stage == 'New') s.totalNew = count;
            else if (stage == 'Screening') s.totalScreening = count;
            else if (stage == 'Interview') s.totalInterview = count;
            else if (stage == 'Evaluation') s.totalEvaluation = count;
            else if (stage == 'Offer') s.totalOffer = count;
            else if (stage == 'Hired') s.totalHired = count;
            else if (stage == 'Rejected') s.totalRejected = count;
            else if (stage == 'Withdrawn') s.totalWithdrawn = count;
        }

        // Get interview counts this week
        Date weekStart = Date.today().toStartOfWeek();
        Date weekEnd = weekStart.addDays(7);
        Map<Id, Integer> interviewCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Application__r.Job__c jobId, COUNT(Id) cnt
            FROM Interview__c
            WHERE Application__r.Job__c IN :jobIds
              AND Scheduled_Date__c >= :weekStart
              AND Scheduled_Date__c < :weekEnd
              AND Status__c = 'Scheduled'
            GROUP BY Application__r.Job__c
        ]) {
            interviewCounts.put((Id) ar.get('jobId'), (Integer) ar.get('cnt'));
        }

        for (Job__c job : openJobs) {
            JobDashboardData d = new JobDashboardData();
            d.job = job;
            PipelineStats s = statsMap.get(job.Id);
            s.totalActive = s.totalNew + s.totalScreening + s.totalInterview +
                s.totalEvaluation + s.totalOffer;
            d.stats = s;
            d.totalApplications = s.totalActive + s.totalHired + s.totalRejected + s.totalWithdrawn;
            d.interviewsThisWeek = interviewCounts.containsKey(job.Id) ? interviewCounts.get(job.Id) : 0;
            dashboard.add(d);
        }

        return dashboard;
    }

    @AuraEnabled
    public static void updateApplicationStage(Id applicationId, String newStage) {
        Application__c app = new Application__c(
            Id = applicationId,
            Stage__c = newStage,
            Last_Stage_Change_Date__c = Date.today()
        );

        if (newStage == 'Rejected') {
            app.Sub_Status__c = null;
        }

        update app;
    }
}