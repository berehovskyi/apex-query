// 10_pagination.apex
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('Name, Industry')
    .withStrip(AccessType.READABLE)
    .orderBy('Name', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST)
    .lim(10)
    .offset(5)
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 10: Pagination');
System.debug('Count: ' + count);
Assert.isTrue(count <= 10, 'Should respect limit');
Assert.isTrue(results.size() <= 10, 'Should respect limit');
System.debug('E2E Test 10 Passed');
