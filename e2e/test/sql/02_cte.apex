SqlQuery q = new SqlQuery('facetable', 'f');
q.useDriver(new DatasetteDriver('https://latest.datasette.io/fixtures/-/query.json'));

// 1. Define Subquery/CTE
SqlQuery recentFacetables = new SqlQuery('facetable')
    .field('pk')
    .field('planet_int')
    .wherex(SqlQuery.COND.field('created').gt('2019-01-01'));

q.with('recent_cte', recentFacetables)
    .field('f.pk')
    .field('f.created')
    .field('cte.planet_int')
    .field('rank() OVER (PARTITION BY f.state ORDER BY f.planet_int)', 'rank_val') // Window Fn
    .innerJoin('recent_cte', 'cte')
    .onx('f.pk = cte.pk') // Join on CTE
    .lim(5)
    .debug();

Integer count = q.fetchCount();
List<Object> results = q.fetch();

System.debug('E2E Test 01: Simple Query');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should return at least one row');
Assert.isTrue(!results.isEmpty(), 'Results list should not be empty');
System.debug('E2E Test 01 Passed');
