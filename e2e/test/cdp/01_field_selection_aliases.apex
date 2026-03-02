CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm', 'a');
q.field('a.ssot__Id__c', 'account_id')
    .field('a.ssot__Name__c', 'account_name')
    .field('a.ssot__CreatedDate__c', 'created_at')
    .addCondition(SqlQuery.COND.field('a.ssot__Name__c').isNotNull())
    .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.DESCX)
    .lim(5)
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('a.ssot__Id__c account_id'), 'Expected field alias for account_id');
Assert.isTrue(sql.contains('a.ssot__Name__c account_name'), 'Expected field alias for account_name');

List<Object> rows = q.fetch();
Integer count = q.fetchCount();

Assert.isTrue(!rows.isEmpty(), 'Expected rows for field selection + aliases');
Assert.isTrue(count >= rows.size(), 'Expected fetchCount() to be greater than or equal to fetched row count');

Map<String, Object> firstRow = (Map<String, Object>) rows[0];
Assert.isTrue(firstRow.containsKey('account_id'), 'Row should include account_id alias');
Assert.isTrue(firstRow.containsKey('account_name'), 'Row should include account_name alias');
Assert.isTrue(firstRow.containsKey('created_at'), 'Row should include created_at alias');

System.debug('E2E CDP Test 01 Passed');
