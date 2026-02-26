public with sharing class GeminiService {

    private static final String SYSTEM_PROMPT =
        'You are a CV/resume parser. Extract structured data from the provided CV document. ' +
        'The CV may be in Dutch or English. Always return field values in the original language of the CV. ' +
        'For dates, use format YYYY-MM. If a field is not present in the CV, return null. ' +
        'For the Dutch education system: MBO = vocational education, HBO = university of applied sciences, WO = research university. ' +
        'Parse all work experience entries. For skills, list individual skills as separate array items.';

    public class CVData {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String linkedInUrl;
        @AuraEnabled public String currentJobTitle;
        @AuraEnabled public String currentCompany;
        @AuraEnabled public Decimal yearsOfExperience;
        @AuraEnabled public List<String> skills;
        @AuraEnabled public List<String> languages;
        @AuraEnabled public List<Education> education;
        @AuraEnabled public List<WorkExperience> workExperience;
        @AuraEnabled public String summary;
        @AuraEnabled public String availability;
    }

    public class Education {
        @AuraEnabled public String institution;
        @AuraEnabled public String degree;
        @AuraEnabled public String fieldOfStudy;
        @AuraEnabled public String startYear;
        @AuraEnabled public String endYear;
    }

    public class WorkExperience {
        @AuraEnabled public String company;
        @AuraEnabled public String jobTitle;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String description;
    }

    public static CVData parseCvFromPdf(String base64Pdf) {
        CV_Parser_Settings__mdt settings = [
            SELECT API_Key__c, API_Endpoint__c, Model_Name__c
            FROM CV_Parser_Settings__mdt
            WHERE DeveloperName = 'Gemini'
            LIMIT 1
        ];

        String endpoint = settings.API_Endpoint__c + '/' +
            settings.Model_Name__c + ':generateContent?key=' + settings.API_Key__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(120000);

        Map<String, Object> requestBody = buildRequestBody(base64Pdf);
        req.setBody(JSON.serialize(requestBody));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() != 200) {
            throw new GeminiServiceException(
                'Gemini API returned status ' + res.getStatusCode() + ': ' + res.getBody()
            );
        }

        return parseResponse(res.getBody());
    }

    private static Map<String, Object> buildRequestBody(String base64Pdf) {
        Map<String, Object> requestBody = new Map<String, Object>();

        // System instruction
        requestBody.put('systemInstruction', new Map<String, Object>{
            'parts' => new List<Map<String, Object>>{
                new Map<String, Object>{ 'text' => SYSTEM_PROMPT }
            }
        });

        // Content with PDF and prompt
        Map<String, Object> pdfPart = new Map<String, Object>{
            'inlineData' => new Map<String, Object>{
                'mimeType' => 'application/pdf',
                'data' => base64Pdf
            }
        };

        Map<String, Object> textPart = new Map<String, Object>{
            'text' => 'Parse this CV and extract all relevant information into the structured format.'
        };

        requestBody.put('contents', new List<Map<String, Object>>{
            new Map<String, Object>{
                'parts' => new List<Map<String, Object>>{ pdfPart, textPart }
            }
        });

        // Generation config with JSON schema
        requestBody.put('generationConfig', new Map<String, Object>{
            'responseMimeType' => 'application/json',
            'responseSchema' => buildCvSchema()
        });

        return requestBody;
    }

    private static Map<String, Object> buildCvSchema() {
        return new Map<String, Object>{
            'type' => 'object',
            'properties' => new Map<String, Object>{
                'firstName' => new Map<String, Object>{ 'type' => 'string' },
                'lastName' => new Map<String, Object>{ 'type' => 'string' },
                'email' => new Map<String, Object>{ 'type' => 'string' },
                'phone' => new Map<String, Object>{ 'type' => 'string' },
                'linkedInUrl' => new Map<String, Object>{ 'type' => 'string' },
                'currentJobTitle' => new Map<String, Object>{ 'type' => 'string' },
                'currentCompany' => new Map<String, Object>{ 'type' => 'string' },
                'yearsOfExperience' => new Map<String, Object>{ 'type' => 'number' },
                'skills' => new Map<String, Object>{
                    'type' => 'array',
                    'items' => new Map<String, Object>{ 'type' => 'string' }
                },
                'languages' => new Map<String, Object>{
                    'type' => 'array',
                    'items' => new Map<String, Object>{ 'type' => 'string' }
                },
                'education' => new Map<String, Object>{
                    'type' => 'array',
                    'items' => new Map<String, Object>{
                        'type' => 'object',
                        'properties' => new Map<String, Object>{
                            'institution' => new Map<String, Object>{ 'type' => 'string' },
                            'degree' => new Map<String, Object>{ 'type' => 'string' },
                            'fieldOfStudy' => new Map<String, Object>{ 'type' => 'string' },
                            'startYear' => new Map<String, Object>{ 'type' => 'string' },
                            'endYear' => new Map<String, Object>{ 'type' => 'string' }
                        }
                    }
                },
                'workExperience' => new Map<String, Object>{
                    'type' => 'array',
                    'items' => new Map<String, Object>{
                        'type' => 'object',
                        'properties' => new Map<String, Object>{
                            'company' => new Map<String, Object>{ 'type' => 'string' },
                            'jobTitle' => new Map<String, Object>{ 'type' => 'string' },
                            'startDate' => new Map<String, Object>{ 'type' => 'string' },
                            'endDate' => new Map<String, Object>{ 'type' => 'string' },
                            'description' => new Map<String, Object>{ 'type' => 'string' }
                        }
                    }
                },
                'summary' => new Map<String, Object>{ 'type' => 'string' },
                'availability' => new Map<String, Object>{ 'type' => 'string' }
            }
        };
    }

    private static CVData parseResponse(String responseBody) {
        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

        List<Object> candidates = (List<Object>) responseMap.get('candidates');
        if (candidates == null || candidates.isEmpty()) {
            throw new GeminiServiceException('No candidates in Gemini response');
        }

        Map<String, Object> candidate = (Map<String, Object>) candidates[0];
        Map<String, Object> content = (Map<String, Object>) candidate.get('content');
        List<Object> parts = (List<Object>) content.get('parts');

        if (parts == null || parts.isEmpty()) {
            throw new GeminiServiceException('No parts in Gemini response');
        }

        Map<String, Object> part = (Map<String, Object>) parts[0];
        String jsonText = (String) part.get('text');

        return (CVData) JSON.deserialize(jsonText, CVData.class);
    }

    public class GeminiServiceException extends Exception {}
}
