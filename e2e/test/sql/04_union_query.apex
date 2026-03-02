SqlQuery q1 = new SqlQuery('facetable').field('pk').wherex(SqlQuery.COND.field('pk').lt(5));
SqlQuery q2 = new SqlQuery('facetable').field('pk').wherex(SqlQuery.COND.field('pk').gt(10));

// Combine with Union All
q1.unionAll(q2).useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json')).lim(20).debug();

List<Object> results = q1.fetch();
System.debug('E2E Test 04: Union Query');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows from union');
// Verify we have IDs < 5 and > 10
Boolean foundSmall = false;
Boolean foundLarge = false;
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Integer pk = Integer.valueOf(row.get('pk'));
    if (pk < 5) {
        foundSmall = true;
    }
    if (pk > 10) {
        foundLarge = true;
    }
}
Assert.isTrue(foundSmall, 'Should have rows from first query (pk < 5)');
Assert.isTrue(foundLarge, 'Should have rows from second query (pk > 10)');
System.debug('E2E Test 04 Passed');
