public with sharing class ATSSetupController {

    public class SetupStatus {
        @AuraEnabled public Boolean apiKeyConfigured;
        @AuraEnabled public String apiEndpoint;
        @AuraEnabled public String modelName;
        @AuraEnabled public String maskedApiKey;
        @AuraEnabled public Integer usersWithPermSet;
        @AuraEnabled public List<AssignedUser> assignedUsers;
        @AuraEnabled public String packageVersion;
        @AuraEnabled public Boolean remoteSiteActive;
    }

    public class AssignedUser {
        @AuraEnabled public Id userId;
        @AuraEnabled public String userName;
        @AuraEnabled public String profileName;
    }

    @AuraEnabled
    public static SetupStatus getSetupStatus() {
        SetupStatus status = new SetupStatus();
        status.packageVersion = '1.0.0';

        // Check CV Parser settings
        try {
            CV_Parser_Settings__mdt settings = CV_Parser_Settings__mdt.getInstance('Gemini');
            if (settings != null) {
                String key = settings.API_Key__c;
                status.apiKeyConfigured = String.isNotBlank(key) && key != 'YOUR_API_KEY_HERE';
                status.apiEndpoint = settings.API_Endpoint__c;
                status.modelName = settings.Model_Name__c;
                if (status.apiKeyConfigured && key.length() > 8) {
                    status.maskedApiKey = key.substring(0, 4) + '****' + key.substring(key.length() - 4);
                } else if (status.apiKeyConfigured) {
                    status.maskedApiKey = '****';
                } else {
                    status.maskedApiKey = 'Not configured';
                }
            } else {
                status.apiKeyConfigured = false;
                status.maskedApiKey = 'Not configured';
            }
        } catch (Exception e) {
            status.apiKeyConfigured = false;
            status.maskedApiKey = 'Error reading settings';
        }

        // Check permission set assignments
        status.assignedUsers = new List<AssignedUser>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId, Assignee.Name, Assignee.Profile.Name
            FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'ATS_User'
            ORDER BY Assignee.Name ASC
        ]) {
            AssignedUser au = new AssignedUser();
            au.userId = psa.AssigneeId;
            au.userName = psa.Assignee.Name;
            au.profileName = psa.Assignee.Profile.Name;
            status.assignedUsers.add(au);
        }
        status.usersWithPermSet = status.assignedUsers.size();

        return status;
    }

    @AuraEnabled
    public static void saveApiSettings(String apiKey, String endpoint, String model) {
        Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
        customMetadata.fullName = 'CV_Parser_Settings.Gemini';
        customMetadata.label = 'Gemini';

        Metadata.CustomMetadataValue apiKeyField = new Metadata.CustomMetadataValue();
        apiKeyField.field = 'API_Key__c';
        apiKeyField.value = apiKey;
        customMetadata.values.add(apiKeyField);

        Metadata.CustomMetadataValue endpointField = new Metadata.CustomMetadataValue();
        endpointField.field = 'API_Endpoint__c';
        endpointField.value = endpoint;
        customMetadata.values.add(endpointField);

        Metadata.CustomMetadataValue modelField = new Metadata.CustomMetadataValue();
        modelField.field = 'Model_Name__c';
        modelField.value = model;
        customMetadata.values.add(modelField);

        Metadata.DeployContainer container = new Metadata.DeployContainer();
        container.addMetadata(customMetadata);

        Metadata.Operations.enqueueDeployment(container, new ATSMetadataCallback());
    }

    @AuraEnabled
    public static String testApiConnection() {
        CV_Parser_Settings__mdt settings;
        try {
            settings = CV_Parser_Settings__mdt.getInstance('Gemini');
        } catch (Exception e) {
            return 'ERROR: Could not read CV Parser settings.';
        }

        if (settings == null || String.isBlank(settings.API_Key__c) || settings.API_Key__c == 'YOUR_API_KEY_HERE') {
            return 'ERROR: API key is not configured. Please save your API key first.';
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(settings.API_Endpoint__c + '/' + settings.Model_Name__c + '?key=' + settings.API_Key__c);
            req.setMethod('GET');
            req.setTimeout(15000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200) {
                return 'SUCCESS';
            } else {
                return 'ERROR: HTTP ' + res.getStatusCode() + ' - Check your API key and endpoint.';
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static List<AssignedUser> getAvailableUsers() {
        Set<Id> assignedIds = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment
            WHERE PermissionSet.Name = 'ATS_User'
        ]) {
            assignedIds.add(psa.AssigneeId);
        }

        List<AssignedUser> available = new List<AssignedUser>();
        for (User u : [
            SELECT Id, Name, Profile.Name
            FROM User
            WHERE IsActive = true AND Id NOT IN :assignedIds
            ORDER BY Name ASC
            LIMIT 200
        ]) {
            AssignedUser au = new AssignedUser();
            au.userId = u.Id;
            au.userName = u.Name;
            au.profileName = u.Profile.Name;
            available.add(au);
        }
        return available;
    }

    @AuraEnabled
    public static void assignPermissionSetToUsers(List<Id> userIds) {
        Id permSetId = [SELECT Id FROM PermissionSet WHERE Name = 'ATS_User' LIMIT 1].Id;

        Set<Id> alreadyAssigned = new Set<Id>();
        for (PermissionSetAssignment psa : [
            SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSetId = :permSetId
        ]) {
            alreadyAssigned.add(psa.AssigneeId);
        }

        List<PermissionSetAssignment> newAssignments = new List<PermissionSetAssignment>();
        for (Id userId : userIds) {
            if (!alreadyAssigned.contains(userId)) {
                newAssignments.add(new PermissionSetAssignment(
                    AssigneeId = userId,
                    PermissionSetId = permSetId
                ));
            }
        }

        if (!newAssignments.isEmpty()) {
            insert newAssignments;
        }
    }

    @AuraEnabled
    public static void removePermissionSetFromUser(Id userId) {
        List<PermissionSetAssignment> assignments = [
            SELECT Id FROM PermissionSetAssignment
            WHERE AssigneeId = :userId AND PermissionSet.Name = 'ATS_User'
        ];
        if (!assignments.isEmpty()) {
            delete assignments;
        }
    }
}
