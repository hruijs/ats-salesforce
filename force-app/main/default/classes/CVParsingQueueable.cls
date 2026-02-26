public class CVParsingQueueable implements Queueable, Database.AllowsCallouts {

    private Id contactId;
    private Id contentVersionId;

    public CVParsingQueueable(Id contactId, Id contentVersionId) {
        this.contactId = contactId;
        this.contentVersionId = contentVersionId;
    }

    public void execute(QueueableContext context) {
        try {
            ContentVersion cv = [
                SELECT VersionData, Title, FileExtension
                FROM ContentVersion
                WHERE Id = :contentVersionId
                LIMIT 1
            ];

            String base64Pdf = EncodingUtil.base64Encode(cv.VersionData);
            GeminiService.CVData parsedData = GeminiService.parseCvFromPdf(base64Pdf);

            updateContactRecord(parsedData);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CV Parsing failed for Contact ' + contactId + ': ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, e.getStackTraceString());
        }
    }

    private void updateContactRecord(GeminiService.CVData data) {
        Contact contact = new Contact(Id = this.contactId);

        if (String.isNotBlank(data.firstName)) {
            contact.FirstName = data.firstName;
        }
        if (String.isNotBlank(data.lastName)) {
            contact.LastName = data.lastName;
        }
        if (String.isNotBlank(data.email)) {
            contact.Email = data.email;
        }
        if (String.isNotBlank(data.phone)) {
            contact.Phone = data.phone;
        }
        if (String.isNotBlank(data.linkedInUrl)) {
            contact.LinkedIn_URL__c = data.linkedInUrl;
        }
        if (String.isNotBlank(data.currentJobTitle)) {
            contact.Current_Job_Title__c = data.currentJobTitle;
        }
        if (String.isNotBlank(data.currentCompany)) {
            contact.Current_Company__c = data.currentCompany;
        }
        if (data.yearsOfExperience != null) {
            contact.Years_of_Experience__c = data.yearsOfExperience;
        }
        if (String.isNotBlank(data.summary)) {
            contact.Professional_Summary__c = data.summary;
        }
        if (String.isNotBlank(data.availability)) {
            contact.Availability__c = data.availability;
        }

        // Skills as semicolon-separated string
        if (data.skills != null && !data.skills.isEmpty()) {
            contact.Skills__c = String.join(data.skills, '; ');
        }

        // Languages
        if (data.languages != null && !data.languages.isEmpty()) {
            contact.Languages__c = String.join(data.languages, '; ');
        }

        // Education summary
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

        // Work experience
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
}
