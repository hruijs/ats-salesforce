public with sharing class ATSHubController {

    public class CandidateWrapper {
        @AuraEnabled public Id contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String currentJobTitle;
        @AuraEnabled public String currentCompany;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public Boolean cvParsed;
        @AuraEnabled public Integer applicationCount;
        @AuraEnabled public String skills;
        @AuraEnabled public String languages;
        @AuraEnabled public String candidateSource;
        @AuraEnabled public Decimal yearsOfExperience;
        @AuraEnabled public String linkedInUrl;
        @AuraEnabled public String availability;
        @AuraEnabled public String professionalSummary;
        @AuraEnabled public String educationSummary;
        @AuraEnabled public String workExperience;
        @AuraEnabled public DateTime cvParsedDate;
    }

    @AuraEnabled
    public static GeminiService.CVData parseCvFromUpload(String base64Pdf) {
        try {
            return GeminiService.parseCvFromPdf(base64Pdf);
        } catch (Exception e) {
            throw new AuraHandledException('CV parsing failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id createCandidateWithApplication(String parsedDataJson, Id jobId, String source, String base64Pdf, String fileName) {
        GeminiService.CVData data = (GeminiService.CVData) JSON.deserialize(parsedDataJson, GeminiService.CVData.class);

        // Create Contact with Candidate record type
        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        Contact c = new Contact();
        c.RecordTypeId = candidateRtId;
        c.FirstName = data.firstName;
        c.LastName = data.lastName;
        c.Email = data.email;
        c.Phone = data.phone;
        c.LinkedIn_URL__c = data.linkedInUrl;
        c.Current_Job_Title__c = data.currentJobTitle;
        c.Current_Company__c = data.currentCompany;
        c.Years_of_Experience__c = data.yearsOfExperience;
        c.Professional_Summary__c = data.summary;
        c.Availability__c = data.availability;
        c.Candidate_Source__c = source;

        if (data.skills != null && !data.skills.isEmpty()) {
            c.Skills__c = String.join(data.skills, '; ');
        }
        if (data.languages != null && !data.languages.isEmpty()) {
            c.Languages__c = String.join(data.languages, '; ');
        }
        if (data.education != null && !data.education.isEmpty()) {
            List<String> eduLines = new List<String>();
            for (GeminiService.Education edu : data.education) {
                String line = '';
                if (String.isNotBlank(edu.degree)) line += edu.degree;
                if (String.isNotBlank(edu.fieldOfStudy)) line += ' - ' + edu.fieldOfStudy;
                if (String.isNotBlank(edu.institution)) line += ' @ ' + edu.institution;
                if (String.isNotBlank(edu.startYear) || String.isNotBlank(edu.endYear)) {
                    line += ' (' + (edu.startYear != null ? edu.startYear : '') +
                            ' - ' + (edu.endYear != null ? edu.endYear : 'heden') + ')';
                }
                eduLines.add(line.trim());
            }
            c.Education_Summary__c = String.join(eduLines, '\n');
        }
        if (data.workExperience != null && !data.workExperience.isEmpty()) {
            List<String> expLines = new List<String>();
            for (GeminiService.WorkExperience exp : data.workExperience) {
                String line = '';
                if (String.isNotBlank(exp.jobTitle)) line += exp.jobTitle;
                if (String.isNotBlank(exp.company)) line += ' @ ' + exp.company;
                if (String.isNotBlank(exp.startDate) || String.isNotBlank(exp.endDate)) {
                    line += ' (' + (exp.startDate != null ? exp.startDate : '') +
                            ' - ' + (exp.endDate != null ? exp.endDate : 'heden') + ')';
                }
                if (String.isNotBlank(exp.description)) {
                    line += '\n  ' + exp.description;
                }
                expLines.add(line.trim());
            }
            c.Work_Experience__c = String.join(expLines, '\n\n');
        }

        c.CV_Parsed__c = true;
        c.CV_Parsed_Date__c = DateTime.now();
        insert c;

        // Link PDF file to Contact
        if (String.isNotBlank(base64Pdf)) {
            ContentVersion cv = new ContentVersion();
            cv.Title = String.isNotBlank(fileName) ? fileName.removeEnd('.pdf') : 'CV - ' + data.firstName + ' ' + data.lastName;
            cv.PathOnClient = (String.isNotBlank(fileName) ? fileName : 'cv.pdf');
            cv.VersionData = EncodingUtil.base64Decode(base64Pdf);
            cv.FirstPublishLocationId = c.Id;
            insert cv;
        }

        // Create Application if job is selected
        if (jobId != null) {
            Application__c app = new Application__c();
            app.Candidate__c = c.Id;
            app.Job__c = jobId;
            app.Stage__c = 'New';
            app.Source__c = source;
            app.Applied_Date__c = Date.today();
            insert app;
        }

        return c.Id;
    }

    @AuraEnabled(cacheable=true)
    public static List<Job__c> getOpenJobs() {
        return [
            SELECT Id, Title__c, Department__c, Location__c, Status__c
            FROM Job__c
            WHERE Status__c = 'Open'
            ORDER BY Title__c ASC
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<CandidateWrapper> getRecentCandidates() {
        List<CandidateWrapper> wrappers = new List<CandidateWrapper>();

        Map<Id, Integer> appCounts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Candidate__c cId, COUNT(Id) cnt
            FROM Application__c
            GROUP BY Candidate__c
        ]) {
            appCounts.put((Id) ar.get('cId'), (Integer) ar.get('cnt'));
        }

        Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
        for (Contact c : [
            SELECT Id, FirstName, LastName, Email, Current_Job_Title__c,
                   Current_Company__c, CreatedDate, CV_Parsed__c
            FROM Contact
            WHERE RecordTypeId = :candidateRtId
            ORDER BY CreatedDate DESC
            LIMIT 50
        ]) {
            CandidateWrapper w = new CandidateWrapper();
            w.contactId = c.Id;
            w.name = c.FirstName + ' ' + c.LastName;
            w.email = c.Email;
            w.currentJobTitle = c.Current_Job_Title__c;
            w.currentCompany = c.Current_Company__c;
            w.createdDate = c.CreatedDate;
            w.cvParsed = c.CV_Parsed__c;
            w.applicationCount = appCounts.containsKey(c.Id) ? appCounts.get(c.Id) : 0;
            wrappers.add(w);
        }

        return wrappers;
    }

    @AuraEnabled
    public static List<CandidateWrapper> getCandidates(String searchTerm) {
        try {
            List<CandidateWrapper> wrappers = new List<CandidateWrapper>();

            Map<Id, Integer> appCounts = new Map<Id, Integer>();
            for (AggregateResult ar : [
                SELECT Candidate__c cId, COUNT(Id) cnt
                FROM Application__c
                WHERE Candidate__c != null
                GROUP BY Candidate__c
            ]) {
                appCounts.put((Id) ar.get('cId'), (Integer) ar.get('cnt'));
            }

            Id candidateRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName().get('Candidate').getRecordTypeId();
            String liketerm = '';
            String query = 'SELECT Id, FirstName, LastName, Email, Phone, ' +
                'Current_Job_Title__c, Current_Company__c, CreatedDate, CV_Parsed__c, ' +
                'CV_Parsed_Date__c, Skills__c, Languages__c, Candidate_Source__c, ' +
                'Years_of_Experience__c, LinkedIn_URL__c, Availability__c, ' +
                'Professional_Summary__c, Education_Summary__c, Work_Experience__c ' +
                'FROM Contact WHERE RecordTypeId = :candidateRtId';

            if (String.isNotBlank(searchTerm)) {
                liketerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
                query += ' AND (FirstName LIKE :liketerm OR LastName LIKE :liketerm ' +
                         'OR Email LIKE :liketerm OR Current_Job_Title__c LIKE :liketerm ' +
                         'OR Current_Company__c LIKE :liketerm)';
            }

            query += ' ORDER BY CreatedDate DESC LIMIT 200';

            for (Contact c : Database.query(query)) {
                CandidateWrapper w = new CandidateWrapper();
                w.contactId = c.Id;
                w.name = (c.FirstName != null ? c.FirstName : '') + ' ' + c.LastName;
                w.email = c.Email;
                w.phone = c.Phone;
                w.currentJobTitle = c.Current_Job_Title__c;
                w.currentCompany = c.Current_Company__c;
                w.createdDate = c.CreatedDate;
                w.cvParsed = c.CV_Parsed__c;
                w.cvParsedDate = c.CV_Parsed_Date__c;
                w.skills = c.Skills__c;
                w.languages = c.Languages__c;
                w.candidateSource = c.Candidate_Source__c;
                w.yearsOfExperience = c.Years_of_Experience__c;
                w.linkedInUrl = c.LinkedIn_URL__c;
                w.availability = c.Availability__c;
                w.professionalSummary = c.Professional_Summary__c;
                w.educationSummary = c.Education_Summary__c;
                w.workExperience = c.Work_Experience__c;
                w.applicationCount = appCounts.containsKey(c.Id) ? appCounts.get(c.Id) : 0;
                wrappers.add(w);
            }

            return wrappers;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to search candidates: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static Id assignCandidateToJob(Id contactId, Id jobId, String source) {
        // Check for duplicate assignment
        List<Application__c> existing = [
            SELECT Id FROM Application__c
            WHERE Candidate__c = :contactId AND Job__c = :jobId
            LIMIT 1
        ];
        if (!existing.isEmpty()) {
            throw new AuraHandledException('This candidate is already assigned to this job.');
        }

        Application__c app = new Application__c();
        app.Candidate__c = contactId;
        app.Job__c = jobId;
        app.Stage__c = 'New';
        app.Source__c = source;
        app.Applied_Date__c = Date.today();
        insert app;

        return app.Id;
    }

    // ─── Interview / Application Detail ───

    public class InterviewWrapper {
        @AuraEnabled public Id id;
        @AuraEnabled public String name;
        @AuraEnabled public String interviewType;
        @AuraEnabled public DateTime scheduledDate;
        @AuraEnabled public Integer round;
        @AuraEnabled public String status;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal durationMinutes;
        @AuraEnabled public String location;
        @AuraEnabled public String videoLink;
        @AuraEnabled public String interviewerName;
        @AuraEnabled public Id interviewerId;
        @AuraEnabled public String interviewer2Name;
        @AuraEnabled public Id interviewer2Id;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public Id applicationId;
    }

    public class CandidateApplication {
        @AuraEnabled public Id applicationId;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String stage;
    }

    public class CandidateInterviewData {
        @AuraEnabled public List<InterviewWrapper> interviews;
        @AuraEnabled public List<CandidateApplication> applications;
    }

    public class UpcomingInterview {
        @AuraEnabled public Id id;
        @AuraEnabled public String candidateName;
        @AuraEnabled public String candidateInitials;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String interviewType;
        @AuraEnabled public DateTime scheduledDate;
        @AuraEnabled public String status;
        @AuraEnabled public Integer round;
        @AuraEnabled public String interviewerName;
        @AuraEnabled public Id interviewerId;
        @AuraEnabled public String interviewer2Name;
        @AuraEnabled public Id interviewer2Id;
        @AuraEnabled public String notes;
        @AuraEnabled public Decimal durationMinutes;
        @AuraEnabled public String location;
        @AuraEnabled public String videoLink;
        @AuraEnabled public Id applicationId;
    }

    public class ApplicationDetail {
        @AuraEnabled public Id applicationId;
        @AuraEnabled public String candidateName;
        @AuraEnabled public Id candidateId;
        @AuraEnabled public String candidateEmail;
        @AuraEnabled public String candidatePhone;
        @AuraEnabled public String currentJobTitle;
        @AuraEnabled public String stage;
        @AuraEnabled public String source;
        @AuraEnabled public Date appliedDate;
        @AuraEnabled public Decimal overallRating;
        @AuraEnabled public List<InterviewWrapper> interviews;
    }

    @AuraEnabled
    public static ApplicationDetail getApplicationDetail(Id applicationId) {
        Application__c app = [
            SELECT Id, Stage__c, Source__c, Applied_Date__c, Overall_Rating__c,
                   Candidate__r.Id, Candidate__r.FirstName, Candidate__r.LastName,
                   Candidate__r.Email, Candidate__r.Phone, Candidate__r.Current_Job_Title__c
            FROM Application__c
            WHERE Id = :applicationId
            LIMIT 1
        ];

        ApplicationDetail detail = new ApplicationDetail();
        detail.applicationId = app.Id;
        detail.candidateName = app.Candidate__r.FirstName + ' ' + app.Candidate__r.LastName;
        detail.candidateId = app.Candidate__r.Id;
        detail.candidateEmail = app.Candidate__r.Email;
        detail.candidatePhone = app.Candidate__r.Phone;
        detail.currentJobTitle = app.Candidate__r.Current_Job_Title__c;
        detail.stage = app.Stage__c;
        detail.source = app.Source__c;
        detail.appliedDate = app.Applied_Date__c;
        detail.overallRating = app.Overall_Rating__c;

        detail.interviews = new List<InterviewWrapper>();
        for (Interview__c iv : [
            SELECT Id, Name, Interview_Type__c, Scheduled_Date__c, Round__c, Status__c,
                   Notes__c, Duration_Minutes__c, Location__c, Video_Link__c,
                   Interviewer__r.Name, Interviewer__c,
                   Interviewer_2__r.Name, Interviewer_2__c
            FROM Interview__c
            WHERE Application__c = :applicationId
            ORDER BY Round__c ASC, Scheduled_Date__c ASC
        ]) {
            InterviewWrapper iw = new InterviewWrapper();
            iw.id = iv.Id;
            iw.name = iv.Name;
            iw.interviewType = iv.Interview_Type__c;
            iw.scheduledDate = iv.Scheduled_Date__c;
            iw.round = iv.Round__c != null ? iv.Round__c.intValue() : 0;
            iw.status = iv.Status__c;
            iw.notes = iv.Notes__c;
            iw.durationMinutes = iv.Duration_Minutes__c;
            iw.location = iv.Location__c;
            iw.videoLink = iv.Video_Link__c;
            iw.interviewerName = iv.Interviewer__r.Name;
            iw.interviewerId = iv.Interviewer__c;
            iw.interviewer2Name = iv.Interviewer_2__r.Name;
            iw.interviewer2Id = iv.Interviewer_2__c;
            iw.applicationId = applicationId;
            detail.interviews.add(iw);
        }

        return detail;
    }

    @AuraEnabled
    public static Id saveInterview(String interviewJson) {
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(interviewJson);

        Interview__c iv = new Interview__c();

        Boolean isUpdate = fields.containsKey('Id') && fields.get('Id') != null;
        if (isUpdate) {
            iv.Id = (Id) fields.get('Id');
        }
        // Application__c is Master-Detail — only set on insert, not writeable on update
        if (!isUpdate && fields.containsKey('Application__c')) {
            iv.Application__c = (Id) fields.get('Application__c');
        }
        if (fields.containsKey('Interview_Type__c')) iv.Interview_Type__c = (String) fields.get('Interview_Type__c');
        if (fields.containsKey('Status__c')) iv.Status__c = (String) fields.get('Status__c');
        if (fields.containsKey('Notes__c')) iv.Notes__c = (String) fields.get('Notes__c');
        if (fields.containsKey('Location__c')) iv.Location__c = (String) fields.get('Location__c');
        if (fields.containsKey('Video_Link__c')) iv.Video_Link__c = (String) fields.get('Video_Link__c');
        if (fields.containsKey('Round__c') && fields.get('Round__c') != null) {
            iv.Round__c = Decimal.valueOf(String.valueOf(fields.get('Round__c')));
        }
        if (fields.containsKey('Duration_Minutes__c') && fields.get('Duration_Minutes__c') != null) {
            iv.Duration_Minutes__c = Decimal.valueOf(String.valueOf(fields.get('Duration_Minutes__c')));
        }
        if (fields.containsKey('Scheduled_Date__c') && fields.get('Scheduled_Date__c') != null) {
            iv.Scheduled_Date__c = DateTime.valueOf(((String) fields.get('Scheduled_Date__c')).replace('T', ' '));
        }
        if (fields.containsKey('Interviewer__c')) {
            iv.Interviewer__c = fields.get('Interviewer__c') != null && String.valueOf(fields.get('Interviewer__c')) != '' ? (Id) fields.get('Interviewer__c') : null;
        }
        if (fields.containsKey('Interviewer_2__c')) {
            iv.Interviewer_2__c = fields.get('Interviewer_2__c') != null && String.valueOf(fields.get('Interviewer_2__c')) != '' ? (Id) fields.get('Interviewer_2__c') : null;
        }

        if (iv.Id != null) {
            update iv;
        } else {
            insert iv;
        }

        return iv.Id;
    }

    @AuraEnabled
    public static void updateApplicationRating(Id applicationId, Decimal rating) {
        Application__c app = new Application__c(Id = applicationId, Overall_Rating__c = rating);
        update app;
    }

    // ─── Candidate Interviews ───

    @AuraEnabled
    public static CandidateInterviewData getInterviewsByCandidate(Id contactId) {
        CandidateInterviewData data = new CandidateInterviewData();
        data.interviews = new List<InterviewWrapper>();
        data.applications = new List<CandidateApplication>();

        for (Application__c app : [
            SELECT Id, Job__r.Title__c, Stage__c
            FROM Application__c
            WHERE Candidate__c = :contactId
            ORDER BY Applied_Date__c DESC
        ]) {
            CandidateApplication ca = new CandidateApplication();
            ca.applicationId = app.Id;
            ca.jobTitle = app.Job__r.Title__c;
            ca.stage = app.Stage__c;
            data.applications.add(ca);
        }

        for (Interview__c iv : [
            SELECT Id, Name, Interview_Type__c, Scheduled_Date__c, Round__c, Status__c,
                   Notes__c, Duration_Minutes__c, Location__c, Video_Link__c,
                   Interviewer__r.Name, Interviewer__c,
                   Interviewer_2__r.Name, Interviewer_2__c,
                   Application__c, Application__r.Job__r.Title__c
            FROM Interview__c
            WHERE Application__r.Candidate__c = :contactId
            ORDER BY Scheduled_Date__c DESC
        ]) {
            InterviewWrapper iw = new InterviewWrapper();
            iw.id = iv.Id;
            iw.name = iv.Name;
            iw.interviewType = iv.Interview_Type__c;
            iw.scheduledDate = iv.Scheduled_Date__c;
            iw.round = iv.Round__c != null ? iv.Round__c.intValue() : 0;
            iw.status = iv.Status__c;
            iw.notes = iv.Notes__c;
            iw.durationMinutes = iv.Duration_Minutes__c;
            iw.location = iv.Location__c;
            iw.videoLink = iv.Video_Link__c;
            iw.interviewerName = iv.Interviewer__r.Name;
            iw.interviewerId = iv.Interviewer__c;
            iw.interviewer2Name = iv.Interviewer_2__r.Name;
            iw.interviewer2Id = iv.Interviewer_2__c;
            iw.jobTitle = iv.Application__r.Job__r.Title__c;
            iw.applicationId = iv.Application__c;
            data.interviews.add(iw);
        }

        return data;
    }

    @AuraEnabled
    public static void deleteInterview(Id interviewId) {
        Interview__c iv = [SELECT Id FROM Interview__c WHERE Id = :interviewId LIMIT 1];
        delete iv;
    }

    @AuraEnabled(cacheable=true)
    public static List<UpcomingInterview> getUpcomingInterviews() {
        List<UpcomingInterview> result = new List<UpcomingInterview>();
        for (Interview__c iv : [
            SELECT Id, Interview_Type__c, Scheduled_Date__c, Status__c, Round__c,
                   Notes__c, Duration_Minutes__c, Location__c, Video_Link__c,
                   Interviewer__r.Name, Interviewer__c,
                   Interviewer_2__r.Name, Interviewer_2__c,
                   Application__c,
                   Application__r.Candidate__r.FirstName, Application__r.Candidate__r.LastName,
                   Application__r.Job__r.Title__c
            FROM Interview__c
            WHERE Scheduled_Date__c >= TODAY
              AND Status__c IN ('Scheduled', 'Rescheduled')
            ORDER BY Scheduled_Date__c ASC
            LIMIT 20
        ]) {
            UpcomingInterview ui = new UpcomingInterview();
            ui.id = iv.Id;
            String fn = iv.Application__r.Candidate__r.FirstName;
            String ln = iv.Application__r.Candidate__r.LastName;
            ui.candidateName = (fn != null ? fn : '') + ' ' + ln;
            ui.jobTitle = iv.Application__r.Job__r.Title__c;
            ui.interviewType = iv.Interview_Type__c;
            ui.scheduledDate = iv.Scheduled_Date__c;
            ui.status = iv.Status__c;
            ui.round = iv.Round__c != null ? iv.Round__c.intValue() : 0;
            ui.interviewerName = iv.Interviewer__r.Name;
            ui.interviewerId = iv.Interviewer__c;
            ui.interviewer2Name = iv.Interviewer_2__r.Name;
            ui.interviewer2Id = iv.Interviewer_2__c;
            ui.notes = iv.Notes__c;
            ui.durationMinutes = iv.Duration_Minutes__c;
            ui.location = iv.Location__c;
            ui.videoLink = iv.Video_Link__c;
            ui.applicationId = iv.Application__c;
            String initials = '';
            if (fn != null && fn.length() > 0) initials += fn.substring(0, 1);
            if (ln != null && ln.length() > 0) initials += ln.substring(0, 1);
            ui.candidateInitials = initials.toUpperCase();
            result.add(ui);
        }
        return result;
    }

    // ─── Jobs ───

    @AuraEnabled
    public static Id saveJob(String jobJson) {
        Map<String, Object> fields = (Map<String, Object>) JSON.deserializeUntyped(jobJson);

        Job__c job = new Job__c();

        if (fields.containsKey('Id') && fields.get('Id') != null) {
            job.Id = (Id) fields.get('Id');
        }

        if (fields.containsKey('Title__c')) job.Title__c = (String) fields.get('Title__c');
        if (fields.containsKey('Department__c')) job.Department__c = (String) fields.get('Department__c');
        if (fields.containsKey('Location__c')) job.Location__c = (String) fields.get('Location__c');
        if (fields.containsKey('Job_Type__c')) job.Job_Type__c = (String) fields.get('Job_Type__c');
        if (fields.containsKey('Status__c')) job.Status__c = (String) fields.get('Status__c');
        if (fields.containsKey('Priority__c')) job.Priority__c = (String) fields.get('Priority__c');
        if (fields.containsKey('Description__c')) job.Description__c = (String) fields.get('Description__c');
        if (fields.containsKey('Requirements__c')) job.Requirements__c = (String) fields.get('Requirements__c');
        if (fields.containsKey('Number_of_Openings__c') && fields.get('Number_of_Openings__c') != null) {
            job.Number_of_Openings__c = Decimal.valueOf(String.valueOf(fields.get('Number_of_Openings__c')));
        }
        if (fields.containsKey('Salary_Min__c') && fields.get('Salary_Min__c') != null) {
            job.Salary_Min__c = Decimal.valueOf(String.valueOf(fields.get('Salary_Min__c')));
        }
        if (fields.containsKey('Salary_Max__c') && fields.get('Salary_Max__c') != null) {
            job.Salary_Max__c = Decimal.valueOf(String.valueOf(fields.get('Salary_Max__c')));
        }

        if (job.Id != null) {
            update job;
        } else {
            if (job.Status__c == null) job.Status__c = 'Open';
            if (job.Priority__c == null) job.Priority__c = 'Medium';
            job.Open_Date__c = Date.today();
            insert job;
        }

        return job.Id;
    }

    @AuraEnabled
    public static void closeJob(Id jobId) {
        Job__c job = new Job__c(Id = jobId, Status__c = 'Closed - Filled', Close_Date__c = Date.today());
        update job;
    }

    // ─── Users ───

    @AuraEnabled(cacheable=true)
    public static List<UserOption> getActiveUsers() {
        List<UserOption> options = new List<UserOption>();
        for (User u : [SELECT Id, Name FROM User WHERE IsActive = true ORDER BY Name ASC LIMIT 200]) {
            UserOption opt = new UserOption();
            opt.userId = u.Id;
            opt.userName = u.Name;
            options.add(opt);
        }
        return options;
    }

    public class UserOption {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
    }
}
