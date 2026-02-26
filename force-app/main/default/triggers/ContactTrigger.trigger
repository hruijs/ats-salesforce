trigger ContactTrigger on Contact (before insert, before update, after insert, after update, after delete, after undelete) {

    public static RecordType cddRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Contact' AND Name = 'Candidate' LIMIT 1];

    If (Trigger.isBefore) {
        If (Trigger.isInsert) {
         /*   for (Contact cdd : Trigger.new) {
                if (cdd.RecordTypeId == cddRecordType.Id) {
                    Id cddDupe = ContactTriggerHandler.checkDuplicates(cdd);
                    If (cddDupe != null) {
                        cdd.addError('This candidate already exists.');
                    }
                }
            } */
        } else if (Trigger.isUpdate) {
            ContactTriggerHandler.setDecisionDate(Trigger.new, Trigger.oldMap);
        }
    } else If (Trigger.isAfter) {

        If (Trigger.isInsert) {
            ContactTriggerHandler.createAppFromCandidate(Trigger.new, null);
        }

        If (Trigger.isUpdate) {
            ContactTriggerHandler.createAppFromCandidate(Trigger.new, Trigger.oldMap);
            ContactTriggerHandler.sendAuthorizationEmail(Trigger.new, Trigger.oldMap);
            //ContactTriggerHandler.uncheckActive(Trigger.new, Trigger.oldMap);
        }
    }
}