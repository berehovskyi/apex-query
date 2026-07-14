SqlQuery q = new SqlQuery('facetable', 'f');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// Test 1: EXISTS (Rows where planet_int is 1 and pk is in the same table)
// Effectively a semi-join simulation
q.field('*')
    .addCondition(
        SqlQuery.exists(
            new SqlQuery('facetable', 'f2')
                .field(SqlQuery.literal(1))
                .addCondition(SqlQuery.COND.field('f2.pk').eq(SqlQuery.literal('f.pk')))
                .addCondition(SqlQuery.COND.field('f2.planet_int').eq(1))
        )
    )
    .lim(5)
    .debug();

List<Object> results = q.fetch();
System.debug('E2E Test 06.1: EXISTS');
System.debug('Results: ' + results.size());
Assert.isTrue(!results.isEmpty(), 'Should return rows for EXISTS');
for (Object rowObj : results) {
    Map<String, Object> row = (Map<String, Object>) rowObj;
    Assert.areEqual(1, row.get('planet_int'), 'Should only return rows with planet_int = 1');
}

// Test 2: ALL (Rows where pk is greater than all pk values in a small subset)
SqlQuery q2 = new SqlQuery('facetable', 'f');
q2.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));
q2.field('pk')
    .addCondition(
        SqlQuery.COND.field('pk')
            .gt(
                SqlQuery.all(
                    new SqlQuery('facetable').field('pk').lim(2) // pk 1 and 2
                )
            )
    )
    .orderBy('pk', Query.SortOrder.ASCX)
    .lim(5)
    .debug();

String allSql = q2.toInlineString();
Assert.isTrue(
    allSql.contains('pk > ALL (SELECT pk FROM facetable LIMIT 2)'),
    'Expected quantified ALL subquery: ' + allSql
);
System.debug('E2E Test 06.2 SKIPPED: Datasette SQLite does not support the ALL quantified operator.');

System.debug('E2E Test 06 Passed');
