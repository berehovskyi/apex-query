SqlQuery q = new SqlQuery('facetable', 'f');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test Fluent Window Builder
q.field('pk')
    .field('state')
    .field('planet_int')
    .field(SqlQuery.WIN.rowNumber().partitionBy('state').orderBy('planet_int').toString(), 'row_num')
    .lim(10)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 03: Window Functions (Fluent)');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows');
Map<String, Object> firstRow = (Map<String, Object>) results[0];
Assert.isTrue(firstRow.containsKey('row_num'), 'Should contain window function result');
System.debug('E2E Test 03 Passed');
