SqlQuery q = new SqlQuery('facetable');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test Group By + Having (Fluent)
q.field('on_earth')
    .field(SqlQuery.AGG.countAll(), 'cnt')
    .groupBy('on_earth')
    .havingx(SqlQuery.HAV.countAll().gt(1))
    .orderBy('cnt', Query.SortOrder.DESCX)
    .lim(5)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 05: Aggregate & Having');
System.debug('Results: ' + results.size());
Assert.isTrue(!results.isEmpty(), 'Should return rows');
System.debug('E2E Test 05 Passed');
