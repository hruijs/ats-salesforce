trigger ContactTrigger on Contact (before update, after insert, after update) {

    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            ContactTriggerHandler.setDecisionDate(Trigger.new, Trigger.oldMap);
        }
    } else if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ContactTriggerHandler.createAppFromCandidate(Trigger.new, null);
        }
        if (Trigger.isUpdate) {
            ContactTriggerHandler.createAppFromCandidate(Trigger.new, Trigger.oldMap);
            ContactTriggerHandler.sendAuthorizationEmail(Trigger.new, Trigger.oldMap);
        }
    }
}
