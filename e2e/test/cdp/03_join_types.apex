CdpSqlQuery innerQ = CdpSqlQuery.of('ssot__Account__dlm', 'a');
innerQ.field('a.ssot__Id__c', 'left_id')
    .field('b.ssot__Id__c', 'right_id')
    .innerJoin('ssot__Account__dlm', 'b')
    .onx('a.ssot__Id__c = b.ssot__Id__c')
    .lim(3)
    .debug();
Assert.isTrue(innerQ.toInlineString().contains('INNER JOIN ssot__Account__dlm b'), 'Expected INNER JOIN in SQL');
Assert.isTrue(!innerQ.fetch().isEmpty(), 'Expected rows for INNER JOIN');

CdpSqlQuery leftQ = CdpSqlQuery.of('ssot__Account__dlm', 'a');
leftQ.field('a.ssot__Id__c', 'left_id')
    .field('b.ssot__Id__c', 'right_id')
    .leftJoin('ssot__Account__dlm', 'b')
    .onx('a.ssot__Id__c = b.ssot__Id__c')
    .lim(3)
    .debug();
Assert.isTrue(leftQ.toInlineString().contains('LEFT JOIN ssot__Account__dlm b'), 'Expected LEFT JOIN in SQL');
Assert.isTrue(!leftQ.fetch().isEmpty(), 'Expected rows for LEFT JOIN');

CdpSqlQuery rightQ = CdpSqlQuery.of('ssot__Account__dlm', 'a');
rightQ.field('a.ssot__Id__c', 'left_id')
    .field('b.ssot__Id__c', 'right_id')
    .rightJoin('ssot__Account__dlm', 'b')
    .onx('a.ssot__Id__c = b.ssot__Id__c')
    .lim(3)
    .debug();
Assert.isTrue(rightQ.toInlineString().contains('RIGHT JOIN ssot__Account__dlm b'), 'Expected RIGHT JOIN in SQL');
Assert.isTrue(!rightQ.fetch().isEmpty(), 'Expected rows for RIGHT JOIN');

CdpSqlQuery fullQ = CdpSqlQuery.of('ssot__Account__dlm', 'a');
fullQ.field('a.ssot__Id__c', 'left_id')
    .field('b.ssot__Id__c', 'right_id')
    .fullJoin('ssot__Account__dlm', 'b')
    .onx('a.ssot__Id__c = b.ssot__Id__c')
    .lim(3)
    .debug();
Assert.isTrue(fullQ.toInlineString().contains('FULL JOIN ssot__Account__dlm b'), 'Expected FULL JOIN in SQL');
Assert.isTrue(!fullQ.fetch().isEmpty(), 'Expected rows for FULL JOIN');

CdpSqlQuery crossQ = CdpSqlQuery.of('ssot__Account__dlm', 'a');
crossQ.field('a.ssot__Id__c', 'left_id')
    .field('b.ssot__Id__c', 'right_id')
    .crossJoin('ssot__Account__dlm', 'b')
    .lim(1)
    .debug();
Assert.isTrue(crossQ.toInlineString().contains('CROSS JOIN ssot__Account__dlm b'), 'Expected CROSS JOIN in SQL');
try {
    List<Object> crossRows = crossQ.fetch();
    Assert.isTrue(!crossRows.isEmpty(), 'Expected rows for CROSS JOIN');
} catch (Exception e) {
    String msg = e.getMessage();
    Boolean isKnownUnsupported =
        msg != null && (msg.contains('Cross Joins are not supported') || msg.contains('Cross joins are not supported'));
    if (isKnownUnsupported) {
        System.debug('CROSS JOIN execution skipped: backend reports unsupported feature.');
    } else {
        throw e;
    }
}

System.debug('E2E CDP Test 03 Passed');
