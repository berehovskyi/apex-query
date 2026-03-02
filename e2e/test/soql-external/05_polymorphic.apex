// 05_polymorphic.apex
SoqlQuery q = SoqlQuery.of(Task.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .fields('Subject, Priority')
    .typeOf(
        new SoqlQuery.TypeOf('What')
            .when(Account.SObjectType)
            .then(Account.Name)
            .then(Account.Industry)
            .when(Case.SObjectType)
            .then(Case.CaseNumber)
            .then(Case.Status)
            .end()
    )
    .addConditionIn('Status', new Set<String>{ 'Open', 'Normal', 'Not Started' })
    .debug();

Integer count = q.fetchCount();
List<Task> results = q.fetch();

System.debug('E2E Test 05: Polymorphic');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should find tasks linked to Accounts/Cases');
Assert.isTrue(!results.isEmpty(), 'Results should not be empty');
System.debug('E2E Test 05 Passed');
