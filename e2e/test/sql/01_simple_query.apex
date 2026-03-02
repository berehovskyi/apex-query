SqlQuery q = new SqlQuery('facetable');
// Use the canonical query endpoint to avoid redirects
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

q.field('pk').field('created').field('planet_int').wherex(SqlQuery.COND.field('planet_int').gt(0)).lim(5).debug();

Integer count = q.fetchCount();
List<Object> results = q.fetch();
Object explain = q.explain();

System.debug('E2E Test 01: Simple Query');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should return at least one row');
Assert.isTrue(!results.isEmpty(), 'Results list should not be empty');
Assert.isNotNull(explain, 'Explain result should not be null');
System.debug('E2E Test 01 Passed');
