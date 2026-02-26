public with sharing class ContactTriggerHandler {
    // Legacy trigger handler - methods kept as stubs for backward compatibility
    // ATS candidate management is handled by ATSHubController

    public static void createAppFromCandidate(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        // No-op: Applications are created via ATSHubController
    }

    public static void sendAuthorizationEmail(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        // No-op: Not part of the ATS package
    }

    public static void setDecisionDate(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        // No-op: Decision date logic not applicable in ATS package
    }
}
