SqlQuery q = new SqlQuery('facetable');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test 1: COALESCE (Replacing NULLs with 'N/A')
q.field('pk')
    .field('distinct_some_null', 'original')
    .field(SqlQuery.coalesce(SqlQuery.literal('distinct_some_null'), 'N/A'), 'coalesced')
    .orderBy('pk', Query.SortOrder.ASCX)
    .lim(15)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 09: Null Handling');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows');
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Object original = row.get('original');
    String coalesced = (String) row.get('coalesced');

    if (original == null || String.isBlank(String.valueOf(original))) {
        Assert.areEqual('N/A', coalesced, 'Should use default value when null/blank');
    } else {
        Assert.areEqual(String.valueOf(original), coalesced, 'Should use original value when available');
    }
}

// Test 2: IS NULL / IS NOT NULL counts
Integer totalCount = new SqlQuery('facetable')
    .useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'))
    .fetchCount();

Integer nonNullCount = new SqlQuery('facetable')
    .useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'))
    .addCondition(SqlQuery.COND.field('distinct_some_null').isNotNull())
    .fetchCount();

Integer nullCount = new SqlQuery('facetable')
    .useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'))
    .addCondition(SqlQuery.COND.field('distinct_some_null').isNull())
    .fetchCount();

System.debug('Total: ' + totalCount + ', Non-Null: ' + nonNullCount + ', Null: ' + nullCount);
Assert.areEqual(totalCount, nonNullCount + nullCount, 'Counts should add up');

System.debug('E2E Test 09 Passed');
