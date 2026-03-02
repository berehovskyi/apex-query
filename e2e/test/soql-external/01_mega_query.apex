// 01_mega_query.apex
Integer thisYear = Datetime.now().year();
SoqlQuery q = SoqlQuery.of(Account.SObjectType)
    .useDriver(new SoqlQuery.RestDriver('SelfREST'))
    .field(Account.Name)
    .field(Account.CreatedDate)
    .field('Industry')
    .field('Interests__c')
    .field('Owner.Name')
    .field('Owner.Profile.Name')
    .fields('BillingLatitude, BillingLongitude')
    .format('CreatedDate', 'createdAt')
    .subQuery(
        'Cases',
        SoqlQuery.of('Case')
            .field('CaseNumber')
            .field(Case.Origin)
            .addConditionEq('Status', 'Closed')
            .addCondition(SoqlQuery.COND.field('CreatedDate').gt(Datetime.newInstanceGmt(2020, 1, 1)))
    )
    .subQuery('Contacts', 'Contact', new Set<String>{ 'LastName', 'AccountId' })
    .subQuery(
        'Tasks',
        SoqlQuery.of(Task.SObjectType)
            .typeOf(
                new SoqlQuery.TypeOf('Who')
                    .when('Contact')
                    .then(Contact.LastName)
                    .when(Lead.SObjectType)
                    .then('FirstName')
                    .elsex('Name')
                    .end()
            )
            .subQuery(
                'Feeds',
                SoqlQuery.of('TaskFeed')
                    .fields('Title, Type, BestCommentId')
                    .addConditionNe('Type', 'Comment')
                    .addConditionNotIn('Id', SoqlQuery.of(FeedComment.SObjectType).field('FeedItemId'))
                    .orderBy('CommentCount', Query.SortOrder.DESCX)
                    .lim(5)
            )
    )
    .usingScope(SoqlQuery.Scope.EVERYTHING)
    .addCondition(
        SoqlQuery.ors(
            new SoqlQuery.Condition('Name LIKE \'Global%\''),
            SoqlQuery.notx(new SoqlQuery.Condition().field('Name').inx(new Set<String>{ 'Emerald Solutions 4' }))
        )
    )
    .addCondition(
        SoqlQuery.COND.field('Interests__c').includes(new Set<String>{ 'Consulting;Entertainment;Environmental' })
    )
    .addCondition(SoqlQuery.COND.field('Id').inx(SoqlQuery.of('Contact').field('AccountId')))
    .addCondition(
        SoqlQuery.COND.field('Id')
            .notIn(SoqlQuery.of('Case').field('AccountId').addConditionEq(Case.CaseNumber, '00001017'))
    )
    .addConditionIn(Account.Type, new Set<String>{ 'Customer', 'Partner' })
    .addConditionEq(SoqlQuery.DT.calendarYear(Account.CreatedDate), thisYear)
    .addConditionEq('LastModifiedDate', SoqlQuery.LIT.lastNDays(27))
    .addCondition(
        SoqlQuery.COND.field(
                SoqlQuery.GEO.distance(
                    'BillingAddress',
                    Location.newInstance(37.775, -122.418),
                    SoqlQuery.DistanceUnit.KM
                )
            )
            .lt(100)
    )
    .addCondition(SoqlQuery.COND.field(Account.AnnualRevenue).ge(SoqlQuery.CUR.of('EUR', 30000000)))
    .withStrip(AccessType.READABLE)
    .orderBy('Name')
    .orderBy('Industry', Query.SortOrder.DESCX)
    .orderBy('NumberOfEmployees', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST)
    .lim(4)
    .offset(2)
    .forView()
    .allRows()
    .debug();

Integer count = q.fetchCount();
List<Account> results = q.fetch();

System.debug('E2E Test 01: Mega Query');
System.debug('Count: ' + count);
Assert.isTrue(count > 0, 'Should return at least one account');
Assert.isTrue(!results.isEmpty(), 'Results list should not be empty');
System.debug('E2E Test 01 Passed');
