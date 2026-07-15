// 12_named_query.apex
SoqlQuery.Named query = SoqlQuery.ofNamed('AccountsByName')
    .useRestDriver('SelfREST')
    .setBatchSize(200)
    .setQueryMore(true)
    .withBindings(new Map<String, Object>{ 'name' => '__NO_ACCOUNT_HAS_THIS_NAME__' });

List<Account> results = (List<Account>) query.fetchInto(List<Account>.class);
Integer generatedCount = 0;
for (Account account : results) {
    if (account.Name?.startsWith('Named Query E2E ') == true) {
        generatedCount++;
    }
}

System.debug('E2E Test 12: Named Query');
System.debug('Fetched: ' + results.size());
Assert.isTrue(results.size() > 2000, 'QueryMore should hydrate records beyond the first 2,000-row page');
Assert.areEqual(2000, generatedCount, 'Named Query should include every generated Account');
System.debug('E2E Test 12 Passed');
