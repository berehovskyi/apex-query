Query.Criterion whereCriterion = SqlQuery.ands(
    new List<Query.Criterion>{
        SqlQuery.COND.field('ssot__Name__c').isNotNull(),
        SqlQuery.ors(
            new List<Query.Criterion>{
                SqlQuery.COND.field('ssot__PrimaryIndustry__c').eq('Healthcare'),
                SqlQuery.COND.field('ssot__PrimaryIndustry__c').eq('Technology')
            }
        ),
        SqlQuery.notx(SqlQuery.COND.field('ssot__ExternalRecordId__c').eq('ACC__NEVER'))
    }
);

Query.Criterion havingCriterion = SqlQuery.ands(
    new List<Query.Criterion>{
        SqlQuery.HAV.countAll().gt(0),
        SqlQuery.ors(
            new List<Query.Criterion>{
                SqlQuery.COND.field('ssot__PrimaryIndustry__c').eq('Healthcare'),
                SqlQuery.COND.field('ssot__PrimaryIndustry__c').eq('Technology')
            }
        )
    }
);

CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm');
q.field('ssot__PrimaryIndustry__c', 'industry')
    .countAll('cnt')
    .wherex(whereCriterion)
    .groupBy('ssot__PrimaryIndustry__c')
    .havingx(havingCriterion)
    .orderBy('cnt', Query.SortOrder.DESCX)
    .lim(10)
    .debug();

String sql = q.toInlineString();
Assert.isTrue(sql.contains('WHERE'), 'Expected WHERE clause');
Assert.isTrue(sql.contains('HAVING'), 'Expected HAVING clause');
Assert.isTrue(sql.contains('GROUP BY ssot__PrimaryIndustry__c'), 'Expected GROUP BY clause');

List<Object> rows = q.fetch();
Assert.isTrue(!rows.isEmpty(), 'Expected grouped rows for nested WHERE/HAVING query');

Map<String, Object> firstRow = (Map<String, Object>) rows[0];
Assert.isTrue(firstRow.containsKey('industry'), 'Expected industry alias');
Assert.isTrue(firstRow.containsKey('cnt'), 'Expected cnt alias');

System.debug('E2E CDP Test 04 Passed');
