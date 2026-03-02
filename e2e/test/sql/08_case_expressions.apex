SqlQuery q = new SqlQuery('facetable');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test 1: Simple CASE (matching state)
Object simpleCase = SqlQuery.CASEX.match('state')
    .when('CA')
    .then('California')
    .when('MI')
    .then('Michigan')
    .elsex('Other')
    .end();

// Test 2: Searched CASE (numeric PK ranges)
Object searchedCase = SqlQuery.CASEX
    .when(SqlQuery.COND.field('pk').gt(10))
    .then('High')
    .when(SqlQuery.COND.field('pk').gt(5))
    .then('Mid')
    .elsex('Low')
    .end();

q.field('pk')
    .field('state')
    .field(simpleCase, 'state_full')
    .field(searchedCase, 'pk_category')
    .orderBy('pk', Query.SortOrder.ASCX)
    .lim(15)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 08: CASE Expressions');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows');
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Integer pk = Integer.valueOf(row.get('pk'));
    String state = (String) row.get('state');
    String stateFull = (String) row.get('state_full');
    String pkCategory = (String) row.get('pk_category');

    // Verify Simple CASE
    if (state == 'CA') {
        Assert.areEqual('California', stateFull);
    } else if (state == 'MI') {
        Assert.areEqual('Michigan', stateFull);
    } else {
        Assert.areEqual('Other', stateFull);
    }

    // Verify Searched CASE
    if (pk > 10) {
        Assert.areEqual('High', pkCategory);
    } else if (pk > 5) {
        Assert.areEqual('Mid', pkCategory);
    } else {
        Assert.areEqual('Low', pkCategory);
    }
}

System.debug('E2E Test 08 Passed');
