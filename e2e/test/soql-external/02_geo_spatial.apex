// 02_geo_spatial.apex
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('Name, BillingAddress')
    .addCondition(
        SoqlQuery.COND.field(
                SoqlQuery.GEO.distance(
                    'BillingAddress',
                    Location.newInstance(37.775, -122.418),
                    SoqlQuery.DistanceUnit.MI
                )
            )
            .lt(100)
    )
    .orderBy(SoqlQuery.GEO.distance('BillingAddress', Location.newInstance(34.05, -118.24), SoqlQuery.DistanceUnit.MI))
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 02: Geo-Spatial');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should find accounts near LA');
Assert.isTrue(!results.isEmpty(), 'Results should not be empty');
System.debug('E2E Test 02 Passed');
