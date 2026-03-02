CdpSqlQuery groupingSetsQ = CdpSqlQuery.of('ssot__Account__dlm');
groupingSetsQ.field('ssot__PrimaryIndustry__c', 'industry')
    .field('ssot__AccountRatingType__c', 'rating')
    .countAll('cnt')
    .groupByGroupingSets(
        new List<Object>{
            '(ssot__PrimaryIndustry__c)',
            '(ssot__AccountRatingType__c)',
            '(ssot__PrimaryIndustry__c, ssot__AccountRatingType__c)'
        }
    )
    .lim(20)
    .debug();

String groupingSetsSql = groupingSetsQ.toInlineString();
Assert.isTrue(groupingSetsSql.contains('GROUP BY GROUPING SETS'), 'Expected GROUPING SETS in SQL');

List<Object> groupingRows = groupingSetsQ.fetch();
Assert.isTrue(!groupingRows.isEmpty(), 'Expected rows for GROUPING SETS query');

CdpSqlQuery valuesQ = CdpSqlQuery.of('ssot__Account__dlm');
valuesQ.field('v.kind')
    .field('v.rank_num')
    .values(
        new List<List<Object>>{
            new List<Object>{ 'high', 1 },
            new List<Object>{ 'medium', 2 },
            new List<Object>{ 'low', 3 }
        },
        'v',
        new List<String>{ 'kind', 'rank_num' }
    )
    .orderBy('v.rank_num', Query.SortOrder.ASCX)
    .debug();

String valuesSql = valuesQ.toInlineString();
Assert.isTrue(valuesSql.contains('FROM (VALUES'), 'Expected VALUES in SQL');

List<Object> valuesRows = valuesQ.fetch();
Assert.areEqual(3, valuesRows.size(), 'VALUES query should return exactly 3 rows');
Map<String, Object> firstValueRow = (Map<String, Object>) valuesRows[0];
Assert.isTrue(firstValueRow.containsKey('kind'), 'VALUES row should include kind column');
Assert.isTrue(firstValueRow.containsKey('rank_num'), 'VALUES row should include rank_num column');

System.debug('E2E CDP Test 08 Passed');
