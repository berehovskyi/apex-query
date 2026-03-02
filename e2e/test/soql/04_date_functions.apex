// 04_date_functions.apex
SoqlQuery q = SoqlQuery.of(Case.SObjectType)
    .fields('CaseNumber, CreatedDate, ClosedDate')
    .addConditionEq(SoqlQuery.DT.calendarMonth(Case.CreatedDate), Datetime.now().month())
    .addCondition(SoqlQuery.COND.field('CreatedDate').gt(SoqlQuery.LIT.lastNMonths(6)))
    .addCondition(SoqlQuery.COND.field('ClosedDate').eq(SoqlQuery.LIT.today))
    .addCondition(SoqlQuery.COND.field('LastModifiedDate').ge(Datetime.newInstanceGmt(2020, 1, 1)))
    .allRows()
    .debug();

Integer count = q.fetchCount();
List<Case> results = q.fetch();

System.debug('E2E Test 04: Date Functions');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should return at least one case');
Assert.isTrue(!results.isEmpty(), 'Results should not be empty');
System.debug('E2E Test 04 Passed');
