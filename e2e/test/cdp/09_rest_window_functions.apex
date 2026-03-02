CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm', 'a');
q.useRestDriver('DataCloud')
    .field('a.ssot__ExternalRecordId__c', 'account_external_id')
    .field('a.ssot__PrimaryIndustry__c', 'industry')
    .field(
        SqlQuery.WIN
            .denseRank()
            .partitionBy('a.ssot__PrimaryIndustry__c')
            .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
            .toString(),
        'industry_rank'
    )
    .field(
        SqlQuery.WIN
            .rowNumber()
            .partitionBy('a.ssot__PrimaryIndustry__c')
            .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
            .toString(),
        'row_num'
    )
    .addCondition('a.ssot__PrimaryIndustry__c IS NOT NULL')
    .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .lim(10)
    .useTimer()
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('DENSE_RANK() OVER ('), 'Expected DENSE_RANK window function');
Assert.isTrue(sql.contains('ROW_NUMBER() OVER ('), 'Expected ROW_NUMBER window function');

List<Object> rows = q.fetch();
Integer count = q.fetchCount();

Assert.isTrue(!rows.isEmpty(), 'Expected rows for REST window-function query');
Assert.isTrue(count >= rows.size(), 'Expected fetchCount() to be greater than or equal to fetched row count');

Object firstRow = rows[0];
if (firstRow instanceof Map<String, Object>) {
    Map<String, Object> row = (Map<String, Object>) firstRow;
    Assert.isTrue(row.containsKey('industry_rank'), 'Expected industry_rank alias');
    Assert.isTrue(row.containsKey('row_num'), 'Expected row_num alias');
    Assert.isNotNull(row.get('industry_rank'), 'industry_rank should be present');
    Assert.isNotNull(row.get('row_num'), 'row_num should be present');
} else if (firstRow instanceof List<Object>) {
    List<Object> row = (List<Object>) firstRow;
    Assert.isTrue(row.size() >= 4, 'Expected at least 4 selected columns in positional row');
    Assert.isNotNull(row[2], 'industry_rank should be present');
    Assert.isNotNull(row[3], 'row_num should be present');
} else {
    Assert.fail('Unexpected row shape from REST driver: ' + String.valueOf(firstRow));
}

System.debug('E2E CDP Test 09 Passed');
