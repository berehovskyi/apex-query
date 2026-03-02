// 03_multi_currency.apex
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('Name, AnnualRevenue, CurrencyIsoCode')
    .addCondition(
        SoqlQuery.ors(
            SoqlQuery.COND.field(Account.AnnualRevenue).ge(SoqlQuery.CUR.of('EUR', 1000000)),
            SoqlQuery.COND.field(Account.AnnualRevenue).le(SoqlQuery.CUR.of('EUR', 500000))
        )
    )
    .orderBy('AnnualRevenue', Query.SortOrder.DESCX)
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 03: Multi-Currency');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should return records matching currency criteria');
Assert.isTrue(!results.isEmpty(), 'Results should not be empty');
System.debug('E2E Test 03 Passed');
