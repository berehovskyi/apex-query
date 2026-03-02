// 09_joins.apex
SoqlQuery q = SoqlQuery.of(Contact.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('Name')
    .addConditionIn('AccountId', SoqlQuery.of(Account.SObjectType).field('Id').addConditionEq('Industry', 'Technology'))
    .addConditionNotIn('Id', SoqlQuery.of(Case.SObjectType).field('ContactId').addConditionEq('Status', 'Closed'))
    .debug();

Integer count = q.fetchCount();
List<Contact> results = q.fetch();

System.debug('E2E Test 09: Joins');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should execute join query');
Assert.isTrue(!results.isEmpty(), 'Should execute join query');
System.debug('E2E Test 09 Passed');
