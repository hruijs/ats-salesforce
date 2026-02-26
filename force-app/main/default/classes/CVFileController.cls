public with sharing class CVFileController {

    @AuraEnabled(cacheable=true)
    public static String getLatestCvFileId(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
        ];

        if (links.isEmpty()) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> versions = [
            SELECT Id
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND FileExtension = 'pdf'
              AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return versions.isEmpty() ? null : versions[0].Id;
    }

    @AuraEnabled(cacheable=true)
    public static ContentVersion getLatestCvFile(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
        ];

        if (links.isEmpty()) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, ContentDocumentId, ContentSize, CreatedDate
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND FileExtension = 'pdf'
              AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return versions.isEmpty() ? null : versions[0];
    }

    @AuraEnabled
    public static GeminiService.CVData parseCvForContact(Id contactId) {
        ContentVersion cv = getLatestCvVersion(contactId);
        if (cv == null) {
            throw new AuraHandledException('No PDF file found for this contact.');
        }

        String base64Pdf = EncodingUtil.base64Encode(cv.VersionData);

        try {
            GeminiService.CVData parsedData = GeminiService.parseCvFromPdf(base64Pdf);
            return parsedData;
        } catch (Exception e) {
            throw new AuraHandledException('CV parsing failed: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void saveParsedDataToContact(Id contactId, String parsedDataJson) {
        GeminiService.CVData data = (GeminiService.CVData) JSON.deserialize(parsedDataJson, GeminiService.CVData.class);

        Contact contact = new Contact(Id = contactId);

        contact.FirstName = data.firstName;
        contact.LastName = data.lastName;
        contact.Email = data.email;
        contact.Phone = data.phone;
        contact.LinkedIn_URL__c = data.linkedInUrl;
        contact.Current_Job_Title__c = data.currentJobTitle;
        contact.Current_Company__c = data.currentCompany;
        contact.Years_of_Experience__c = data.yearsOfExperience;
        contact.Professional_Summary__c = data.summary;
        contact.Availability__c = data.availability;

        if (data.skills != null && !data.skills.isEmpty()) {
            contact.Skills__c = String.join(data.skills, '; ');
        }
        if (data.languages != null && !data.languages.isEmpty()) {
            contact.Languages__c = String.join(data.languages, '; ');
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
            contact.Education_Summary__c = String.join(eduLines, '\n');
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
            contact.Work_Experience__c = String.join(expLines, '\n\n');
        }

        contact.CV_Parsed__c = true;
        contact.CV_Parsed_Date__c = DateTime.now();

        update contact;
    }

    private static ContentVersion getLatestCvVersion(Id recordId) {
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
            ORDER BY SystemModstamp DESC
        ];

        if (links.isEmpty()) return null;

        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            docIds.add(link.ContentDocumentId);
        }

        List<ContentVersion> versions = [
            SELECT Id, Title, FileExtension, VersionData, ContentDocumentId
            FROM ContentVersion
            WHERE ContentDocumentId IN :docIds
              AND FileExtension = 'pdf'
              AND IsLatest = true
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        return versions.isEmpty() ? null : versions[0];
    }
}
