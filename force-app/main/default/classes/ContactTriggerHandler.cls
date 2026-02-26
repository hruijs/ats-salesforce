public with sharing class ContactTriggerHandler {

    public static RecordType cddRecordType = [SELECT Id FROM RecordType WHERE SobjectType = 'Contact' AND Name = 'Candidate' LIMIT 1];

    public static Id checkDuplicates(Contact candidate) {

        List<Contact> candidates = [SELECT Id FROM Contact WHERE Email = :candidate.Email AND RecordTypeId = :cddRecordType.Id];
        if (candidates.size() > 0) {
            return candidates[0].Id;
        } else {
            return null;
        }
    }

    public static void uncheckActive(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        Set<Id> vacIds = new Set<Id>();

        for (Contact cdd : candidates) {
            if (String.isNotBlank(cdd.Vacancy__c)) {
                vacIds.add(cdd.Vacancy__c);
            }
        }

        List<Vacancy__c> vacList = [SELECT Id, Active__c, Permanent__c, (SELECT Id, Status__c FROM Contacts__r WHERE RecordTypeId = :cddRecordType.Id) FROM Vacancy__c WHERE Id IN :vacIds];
        List<Vacancy__c> vacListToUpdate = new List<Vacancy__c>();

        for (Vacancy__c vac : vacList) {
            for (Contact cdd : vac.Contacts__r) {
                if (oldCandidates.get(cdd.Id).Status__c != null) {
                    if (cdd.Status__c != oldCandidates.get(cdd.Id).Status__c && cdd.Status__c == 'Hired' && !vac.Permanent__c) {
                        vac.Active__c = false;
                        vacListToUpdate.add(vac);
                    }
                }
            }
        }

        if (vacListToUpdate.size() > 0) {
            update vacListToUpdate;
        }
    }

    public static void createAppFromCandidate(List<Contact> candidates, Map<Id,Contact> oldCandidates) {

        List<Application__c> apps = new List<Application__c>();

        for (Contact cdd : candidates) {
            if (cdd.RecordTypeId == cddRecordType.Id) {
                If (oldCandidates == null) {
                    if (cdd.Status__c == 'Applying' && cdd.Vacancy__c != null) {
                        apps.add(createApp(cdd));
                    }
                } else {
                    if (cdd.Status__c != oldCandidates.get(cdd.Id).Status__c && cdd.Status__c == 'Applying' && cdd.Vacancy__c != null) {
                        apps.add(createApp(cdd));
                    }
                }
            }
        }

        if (apps.size() > 0) {
            insert apps;
        }

    }

    public static void sendAuthorizationEmail(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        // EmailManager reference removed - not part of the ATS package
    }

    public static void setDecisionDate(List<Contact> candidates, Map<Id,Contact> oldCandidates) {
        for (Contact cdd : candidates) {
            Contact oldCdd = oldCandidates.get(cdd.Id);

            if (cdd.RecordTypeId == cddRecordType.Id) {
                if (isCandidateFinished(cdd) && !isCandidateFinished(oldCdd)) {
                    cdd.Decision_Date__c = System.today();
                } else if (!isCandidateFinished(cdd) && isCandidateStatusChanged(cdd,oldCdd)) {
                    cdd.Decision_Date__c = null;
                }
            }
        }

    }

    private static Application__c createApp(Contact cdd) {
        Application__c app = new Application__c();
        app.Contact__c = cdd.Id;
        app.Vacancy__c = cdd.Vacancy__c;
        app.Status__c = 'New';

        return app;
    }

    private static Boolean isCandidateFinished(Contact cdd) {
        return cdd.Status__c == 'Hired' || cdd.Status__c == 'Not hired' || cdd.Status__c == 'Not hired (For now)';
    }

    private static Boolean isCandidateStatusChanged(Contact cdd, Contact oldCdd) {
        return cdd.Status__c != oldCdd.Status__c;
    }
}