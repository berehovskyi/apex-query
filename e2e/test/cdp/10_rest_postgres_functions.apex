Object createdDay = SqlQuery.dateTrunc('day', SqlQuery.literal('a.ssot__CreatedDate__c'));
Object industryNorm = SqlQuery.coalesce(SqlQuery.literal('a.ssot__PrimaryIndustry__c'), 'Unknown');

CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm', 'a');
q.useRestDriver('DataCloud')
    .field(createdDay, 'created_day')
    .field(industryNorm, 'industry_norm')
    .countAll('cnt')
    .groupBy(createdDay)
    .groupBy(industryNorm)
    .orderBy('created_day', Query.SortOrder.DESCX)
    .lim(10)
    .useTimer()
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('DATE_TRUNC(\'day\', a.ssot__CreatedDate__c)'), 'Expected DATE_TRUNC expression');
Assert.isTrue(sql.contains('COALESCE(a.ssot__PrimaryIndustry__c'), 'Expected COALESCE expression');

List<Object> rows = q.fetch();
Integer count = q.fetchCount();

Assert.isTrue(!rows.isEmpty(), 'Expected rows for REST Postgres-function query');
Assert.isTrue(count >= rows.size(), 'Expected fetchCount() to be greater than or equal to fetched row count');

Object firstRow = rows[0];
if (firstRow instanceof Map<String, Object>) {
    Map<String, Object> row = (Map<String, Object>) firstRow;
    Assert.isTrue(row.containsKey('created_day'), 'Expected created_day alias');
    Assert.isTrue(row.containsKey('industry_norm'), 'Expected industry_norm alias');
    Assert.isTrue(row.containsKey('cnt'), 'Expected cnt alias');
} else if (firstRow instanceof List<Object>) {
    List<Object> row = (List<Object>) firstRow;
    Assert.isTrue(row.size() >= 3, 'Expected at least 3 selected columns in positional row');
    Assert.isNotNull(row[0], 'created_day should be present');
    Assert.isNotNull(row[1], 'industry_norm should be present');
    Assert.isNotNull(row[2], 'cnt should be present');
} else {
    Assert.fail('Unexpected row shape from REST driver: ' + String.valueOf(firstRow));
}

System.debug('E2E CDP Test 10 Passed');
