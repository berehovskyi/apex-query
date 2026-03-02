CdpSqlQuery aggregateQ = CdpSqlQuery.of('ssot__Account__dlm');
aggregateQ.field('ssot__PrimaryIndustry__c', 'industry')
    .countAll('cnt')
    .addCondition('ssot__PrimaryIndustry__c IS NOT NULL')
    .groupBy('ssot__PrimaryIndustry__c')
    .orderBy('cnt', Query.SortOrder.DESCX)
    .lim(5)
    .debug();

List<Object> aggregateRows = aggregateQ.fetch();
Assert.isTrue(!aggregateRows.isEmpty(), 'Expected aggregate rows');
Assert.isTrue(aggregateQ.toInlineString().contains('GROUP BY ssot__PrimaryIndustry__c'), 'Expected GROUP BY in SQL');
Assert.isTrue(aggregateQ.toInlineString().contains('ORDER BY cnt DESC'), 'Expected ORDER BY in SQL');

CdpSqlQuery unionQ1 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
unionQ1.addCondition('ssot__PrimaryIndustry__c = \'Healthcare\'');
CdpSqlQuery unionQ2 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
unionQ2.addCondition('ssot__PrimaryIndustry__c = \'Technology\'');
unionQ1.unionAll(unionQ2).lim(20).debug();

List<Object> unionRows = unionQ1.fetch();
Assert.isTrue(!unionRows.isEmpty(), 'Expected rows for UNION ALL');
Assert.isTrue(unionQ1.toInlineString().contains('UNION ALL'), 'Expected UNION ALL in SQL');

CdpSqlQuery intersectQ1 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
intersectQ1.addCondition('ssot__Name__c IS NOT NULL');
CdpSqlQuery intersectQ2 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
intersectQ2.addCondition('ssot__PrimaryIndustry__c IS NOT NULL');
intersectQ1.intersect(intersectQ2).lim(20).debug();

List<Object> intersectRows = intersectQ1.fetch();
Assert.isTrue(!intersectRows.isEmpty(), 'Expected rows for INTERSECT');
Assert.isTrue(intersectQ1.toInlineString().contains('INTERSECT'), 'Expected INTERSECT in SQL');

CdpSqlQuery exceptQ1 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
exceptQ1.addCondition('ssot__Name__c IS NOT NULL');
CdpSqlQuery exceptQ2 = (CdpSqlQuery) CdpSqlQuery.of('ssot__Account__dlm').field('ssot__ExternalRecordId__c');
exceptQ2.addCondition('ssot__PrimaryIndustry__c = \'Healthcare\'');
exceptQ1.except(exceptQ2).lim(20).debug();

List<Object> exceptRows = exceptQ1.fetch();
Assert.isTrue(!exceptRows.isEmpty(), 'Expected rows for EXCEPT');
Assert.isTrue(exceptQ1.toInlineString().contains('EXCEPT'), 'Expected EXCEPT in SQL');

System.debug('E2E CDP Test 05 Passed');
