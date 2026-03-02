SqlQuery accountCte = CdpSqlQuery.of('ssot__Account__dlm')
    .field('ssot__Id__c')
    .addCondition('ssot__PrimaryIndustry__c IS NOT NULL');

CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm', 'a');
q.with('industry_accounts', accountCte)
    .field('a.ssot__Id__c', 'account_id')
    .field('a.ssot__PrimaryIndustry__c', 'industry')
    .innerJoin('industry_accounts', 'ia')
    .onx('a.ssot__Id__c = ia.ssot__Id__c')
    .orderBy('a.ssot__CreatedDate__c', Query.SortOrder.ASCX)
    .lim(5)
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('WITH industry_accounts AS ('), 'Expected WITH clause');
Assert.isTrue(sql.contains('INNER JOIN industry_accounts ia ON a.ssot__Id__c = ia.ssot__Id__c'), 'Expected CTE join');

List<Object> rows = q.fetch();
Assert.isTrue(!rows.isEmpty(), 'Expected rows for CTE query');

Map<String, Object> firstRow = (Map<String, Object>) rows[0];
Assert.isTrue(firstRow.containsKey('account_id'), 'Row should include account_id alias');
Assert.isTrue(firstRow.containsKey('industry'), 'Row should include industry alias');

System.debug('E2E CDP Test 02 Passed');
