// 08_aggregates.apex
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .fields('Id, Name')
    .subQuery('Contacts', SoqlQuery.of('Contact').field('Id').lim(1))
    .addConditionNotIn('Id', SoqlQuery.of('Case').field('AccountId').addConditionEq('Status', 'New'))
    .orderBy('Name', Query.SortOrder.ASCX)
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 08: Aggregates/Joins');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should find accounts without new cases');
Assert.isTrue(!results.isEmpty(), 'Should find accounts without new cases');
System.debug('E2E Test 08 Passed');
