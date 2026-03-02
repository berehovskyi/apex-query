// 06_logical_logic.apex
SoqlQuery q = SoqlQuery.of(Contact.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('FirstName, LastName, Email')
    .addCondition(
        SoqlQuery.ors(
            SoqlQuery.ands(
                new SoqlQuery.Condition().field('FirstName').likex('%a%'),
                new SoqlQuery.Condition().field('LastName').likex('%b%')
            ),
            SoqlQuery.notx(new SoqlQuery.Condition().field('Email').likex('%@acc-%'))
        )
    )
    .debug();

Integer count = q.fetchCount();
List<Contact> results = q.fetch();

System.debug('E2E Test 06: Logic');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Logic should match some contacts');
Assert.isTrue(!results.isEmpty(), 'Logic should match some contacts');
System.debug('E2E Test 06 Passed');
