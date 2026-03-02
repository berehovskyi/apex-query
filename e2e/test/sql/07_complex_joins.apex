SqlQuery q1 = new SqlQuery('facetable', 'f');
q1.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// 1. Define a CTE for California rows
SqlQuery caRows = new SqlQuery('facetable').field('pk').addCondition(SqlQuery.COND.field('state').eq('CA'));

// 2. Define a CTE for Earth rows
SqlQuery earthRows = new SqlQuery('facetable').field('pk').addCondition(SqlQuery.COND.field('on_earth').eq(1));

q1.with('ca_pks', caRows)
    .with('earth_pks', earthRows)
    .field('f.pk')
    .field('f.state')
    .field('f.on_earth')
    .innerJoin('ca_pks', 'cte')
    .onx('f.pk = cte.pk')
    .innerJoin('earth_pks', 'sub')
    .onx('f.pk = sub.pk')
    .orderBy('f.pk', Query.SortOrder.ASCX)
    .lim(5)
    .debug();

List<Object> results = q1.fetch();
System.debug('E2E Test 07: Complex Joins (Double CTE Join)');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows (Expected rows 1-10)');
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Assert.areEqual('CA', row.get('state'), 'Should be filtered by CTE join (CA)');
    Assert.areEqual(1, row.get('on_earth'), 'Should be filtered by Subquery join (on_earth=1)');
}

System.debug('E2E Test 07 Passed');
