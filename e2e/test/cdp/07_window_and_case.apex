Object ratingBucket = SqlQuery.CASEX
    .when(SqlQuery.COND.field('a.ssot__AccountRatingType__c').eq('Hot'))
    .then('A')
    .when(SqlQuery.COND.field('a.ssot__AccountRatingType__c').eq('Warm'))
    .then('B')
    .elsex('C')
    .end();

CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm', 'a');
q.field('a.ssot__ExternalRecordId__c', 'account_external_id')
    .field('a.ssot__PrimaryIndustry__c', 'industry')
    .field(
        SqlQuery.WIN
            .rowNumber()
            .partitionBy('a.ssot__PrimaryIndustry__c')
            .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
            .toString(),
        'row_num'
    )
    .field(ratingBucket, 'rating_bucket')
    .addCondition('a.ssot__Name__c IS NOT NULL')
    .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .lim(10)
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('ROW_NUMBER() OVER ('), 'Expected window function in SQL');
Assert.isTrue(sql.contains('CASE WHEN a.ssot__AccountRatingType__c ='), 'Expected CASE expression in SQL');

List<Object> rows = q.fetch();
Assert.isTrue(!rows.isEmpty(), 'Expected rows for window + CASE query');

Map<String, Object> firstRow = (Map<String, Object>) rows[0];
Assert.isTrue(firstRow.containsKey('row_num'), 'Expected row_num alias from window function');
Assert.isTrue(firstRow.containsKey('rating_bucket'), 'Expected rating_bucket alias from CASE');

String bucket = String.valueOf(firstRow.get('rating_bucket'));
Assert.isTrue(bucket == 'A' || bucket == 'B' || bucket == 'C', 'rating_bucket should map to A/B/C');

System.debug('E2E CDP Test 07 Passed');
