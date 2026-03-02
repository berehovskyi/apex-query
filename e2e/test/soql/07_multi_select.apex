// 07_multi_select.apex
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .fields('Name, Interests__c')
    .addCondition(SoqlQuery.COND.field('Interests__c').includes(new Set<String>{ 'Technology', 'Finance' }))
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 07: Multi-Select');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should find accounts with Tech or Finance interests');
Assert.isTrue(!results.isEmpty(), 'Should find accounts with Tech or Finance interests');
System.debug('E2E Test 07 Passed');
