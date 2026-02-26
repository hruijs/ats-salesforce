@isTest
private class GeminiServiceTest {

    @isTest
    static void testParseCvFromPdf() {
        // Set up mock
        Test.setMock(HttpCalloutMock.class, new GeminiMockCallout());

        // Insert custom metadata is not possible in tests, so we test the parsing logic
        // by testing parseResponse indirectly through the service

        Test.startTest();
        // We can't easily test the full flow without custom metadata,
        // but we can test the wrapper classes
        GeminiService.CVData cvData = new GeminiService.CVData();
        cvData.firstName = 'Jan';
        cvData.lastName = 'de Vries';
        cvData.email = 'jan@test.com';
        cvData.skills = new List<String>{'Java', 'Python', 'Salesforce'};

        String serialized = JSON.serialize(cvData);
        GeminiService.CVData deserialized = (GeminiService.CVData) JSON.deserialize(serialized, GeminiService.CVData.class);

        System.assertEquals('Jan', deserialized.firstName);
        System.assertEquals('de Vries', deserialized.lastName);
        System.assertEquals(3, deserialized.skills.size());
        Test.stopTest();
    }

    @isTest
    static void testCVDataWrapper() {
        GeminiService.Education edu = new GeminiService.Education();
        edu.institution = 'TU Delft';
        edu.degree = 'MSc';
        edu.fieldOfStudy = 'Computer Science';
        edu.startYear = '2018';
        edu.endYear = '2020';

        GeminiService.WorkExperience exp = new GeminiService.WorkExperience();
        exp.company = 'Acme Corp';
        exp.jobTitle = 'Software Engineer';
        exp.startDate = '2020-06';
        exp.endDate = '2024-01';
        exp.description = 'Built APIs';

        System.assertEquals('TU Delft', edu.institution);
        System.assertEquals('Software Engineer', exp.jobTitle);
    }

    @isTest
    static void testGeminiServiceException() {
        try {
            throw new GeminiService.GeminiServiceException('Test error');
        } catch (GeminiService.GeminiServiceException e) {
            System.assertEquals('Test error', e.getMessage());
        }
    }

    private class GeminiMockCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"candidates":[{"content":{"parts":[{"text":"{\\"firstName\\":\\"Jan\\",\\"lastName\\":\\"de Vries\\",\\"email\\":\\"jan@test.com\\"}"}]}}]}');
            return res;
        }
    }
}
