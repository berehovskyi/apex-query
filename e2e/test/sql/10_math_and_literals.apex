SqlQuery q = new SqlQuery('facetable');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test 1: Arithmetic in SELECT (pk + 10, planet_int * 2)
q.field('pk')
    .field(SqlQuery.literal('pk + 10'), 'pk_plus_ten')
    .field(SqlQuery.literal('planet_int * 2'), 'planet_doubled')
    .addCondition(SqlQuery.COND.field('pk').le(5))
    .orderBy('pk', Query.SortOrder.ASCX)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 10.1: Arithmetic in SELECT');
System.debug('Results: ' + results.size());

Assert.isTrue(!results.isEmpty(), 'Should return rows');
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Integer pk = Integer.valueOf(row.get('pk'));
    Integer pkPlusTen = Integer.valueOf(row.get('pk_plus_ten'));
    Assert.areEqual(pk + 10, pkPlusTen, 'Arithmetic pk + 10 failed');
}

// Test 2: Arithmetic in WHERE (pk * 2 > 20)
SqlQuery q2 = new SqlQuery('facetable');
q2.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));
q2.field('pk').addCondition('pk * 2 > 20').orderBy('pk', Query.SortOrder.ASCX).debug();

List<Object> results2 = q2.fetch();
System.debug('E2E Test 10.2: Arithmetic in WHERE');
System.debug('Results: ' + results2.size());

Assert.isTrue(!results2.isEmpty(), 'Should return rows for pk * 2 > 20');
for (Object rowObj : results2) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Integer pk = Integer.valueOf(row.get('pk'));
    Assert.isTrue(pk > 10, 'pk * 2 > 20 means pk should be > 10');
}

// Test 3: Raw String Literals
SqlQuery q3 = new SqlQuery('facetable');
q3.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));
q3.field(SqlQuery.literal('\'StaticVal\''), 'static_col').lim(1).debug();

List<Object> results3 = q3.fetch();
Assert.isTrue(!results3.isEmpty(), 'Should return rows');
Map<String, Object> firstRow = (Map<String, Object>) results3[0];
Assert.areEqual('StaticVal', firstRow.get('static_col'), 'Literal string failed');

System.debug('E2E Test 10 Passed');
