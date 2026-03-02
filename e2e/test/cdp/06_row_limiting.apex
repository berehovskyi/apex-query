CdpSqlQuery fetchFirstQ = CdpSqlQuery.of('ssot__Account__dlm');
fetchFirstQ.field('ssot__ExternalRecordId__c')
    .orderBy('ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .orderBy('ssot__ExternalRecordId__c', Query.SortOrder.ASCX)
    .fetchFirst(3)
    .debug();

Assert.isTrue(fetchFirstQ.toInlineString().contains('FETCH FIRST 3 ROWS ONLY'), 'Expected FETCH FIRST syntax');
try {
    List<Object> fetchFirstRows = fetchFirstQ.fetch();
    Assert.isTrue(!fetchFirstRows.isEmpty(), 'Expected rows for FETCH FIRST');
    Assert.isTrue(fetchFirstRows.size() <= 3, 'FETCH FIRST should cap rows at 3');
} catch (Exception e) {
    String msg = e.getMessage();
    Boolean isKnownUnsupported =
        msg != null && (msg.contains('mismatched input \'FETCH\'') || msg.contains('Expecting: \';\', <EOF>'));
    if (isKnownUnsupported) {
        System.debug('FETCH FIRST execution skipped: backend parser does not support FETCH syntax.');
    } else {
        throw e;
    }
}

CdpSqlQuery fetchNextQ = CdpSqlQuery.of('ssot__Account__dlm');
fetchNextQ.field('ssot__ExternalRecordId__c')
    .orderBy('ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .orderBy('ssot__ExternalRecordId__c', Query.SortOrder.ASCX)
    .fetchNext(2)
    .debug();

Assert.isTrue(fetchNextQ.toInlineString().contains('FETCH NEXT 2 ROWS ONLY'), 'Expected FETCH NEXT syntax');
try {
    List<Object> fetchNextRows = fetchNextQ.fetch();
    Assert.isTrue(!fetchNextRows.isEmpty(), 'Expected rows for FETCH NEXT');
    Assert.isTrue(fetchNextRows.size() <= 2, 'FETCH NEXT should cap rows at 2');
} catch (Exception e) {
    String msg = e.getMessage();
    Boolean isKnownUnsupported =
        msg != null && (msg.contains('mismatched input \'FETCH\'') || msg.contains('Expecting: \';\', <EOF>'));
    if (isKnownUnsupported) {
        System.debug('FETCH NEXT execution skipped: backend parser does not support FETCH syntax.');
    } else {
        throw e;
    }
}

CdpSqlQuery baseQ = CdpSqlQuery.of('ssot__Account__dlm');
baseQ.field('ssot__ExternalRecordId__c')
    .orderBy('ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .orderBy('ssot__ExternalRecordId__c', Query.SortOrder.ASCX)
    .lim(1);
List<Object> baseRows = baseQ.fetch();

CdpSqlQuery limitOffsetQ = CdpSqlQuery.of('ssot__Account__dlm');
limitOffsetQ.field('ssot__ExternalRecordId__c')
    .orderBy('ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .orderBy('ssot__ExternalRecordId__c', Query.SortOrder.ASCX)
    .lim(1)
    .offset(1)
    .debug();

List<Object> limitOffsetRows = limitOffsetQ.fetch();
Assert.isTrue(!limitOffsetRows.isEmpty(), 'Expected rows for LIMIT/OFFSET');
Assert.isTrue(limitOffsetQ.toInlineString().contains('LIMIT 1 OFFSET 1'), 'Expected LIMIT/OFFSET syntax');

if (!baseRows.isEmpty()) {
    String firstBaseId = String.valueOf(((Map<String, Object>) baseRows[0]).get('ssot__ExternalRecordId__c'));
    String firstOffsetId = String.valueOf(((Map<String, Object>) limitOffsetRows[0]).get('ssot__ExternalRecordId__c'));
    Assert.isTrue(firstBaseId != firstOffsetId, 'OFFSET should move to a different row');
}

System.debug('E2E CDP Test 06 Passed');
