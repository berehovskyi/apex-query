// cleanup_data.apex
System.debug('Cleaning up E2E test data...');

// 1. Delete FeedItems (Posts on Tasks/Cases)
Set<Id> taskIds = new Map<Id, Task>([SELECT Id FROM Task WHERE ExternalId__c LIKE 'TASK_%']).keySet();
if (!taskIds.isEmpty()) {
    delete [SELECT Id FROM FeedItem WHERE ParentId IN :taskIds];
}
Set<Id> caseIds = new Map<Id, Case>([SELECT Id FROM Case WHERE ExternalId__c LIKE 'CAS_%']).keySet();
if (!caseIds.isEmpty()) {
    delete [SELECT Id FROM FeedItem WHERE ParentId IN :caseIds];
}

// 2. Delete Tasks (Cascades to TaskFeed)
delete [SELECT Id FROM Task WHERE ExternalId__c LIKE 'TASK_%'];

// 3. Delete Cases
delete [SELECT Id FROM Case WHERE ExternalId__c LIKE 'CAS_%'];

// 4. Delete Contacts
delete [SELECT Id FROM Contact WHERE ExternalId__c LIKE 'CON_%' OR Email LIKE '%@acc-%'];

// 5. Delete Accounts
delete [SELECT Id FROM Account WHERE ExternalId__c LIKE 'ACC_%'];

System.debug('Cleanup finished.');
