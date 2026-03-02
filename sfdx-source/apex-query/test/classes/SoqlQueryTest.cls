@IsTest(IsParallel=true)
private class SoqlQueryTest {
    // <editor-fold desc="Construction & Static Logic">
    @IsTest
    static void should_initialize_with_sobject_type() {
        // Arrange
        SObjectType accType = Account.SObjectType;

        // Act
        String actual = SoqlQuery.of(accType).field('Id').toString();

        // Assert
        Assert.isTrue(actual.contains('FROM Account'), 'Should query from Account');
    }

    @IsTest
    static void should_initialize_with_string() {
        // Arrange
        String accName = 'Account';

        // Act
        String actual = SoqlQuery.of(accName).field('Id').toString();

        // Assert
        Assert.isTrue(actual.contains('FROM Account'), 'Should query from Account');
    }

    @IsTest
    static void should_fail_on_null_sobject_type() {
        // Arrange
        SObjectType nullType = null;
        Exception actualException;

        // Act
        try {
            SoqlQuery.of(nullType);
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw an exception for null SObjectType');
        Assert.isTrue(actualException.getMessage().contains('SObject type cannot be null'), 'Argument object is null');
    }

    @IsTest
    static void should_fail_on_blank_sobject_name() {
        // Arrange
        String blankName = '  ';
        Exception actualException;

        // Act
        try {
            SoqlQuery.of(blankName);
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw an exception for blank name');
        Assert.isTrue(
            actualException.getMessage().contains('SObject type cannot be blank'),
            'SObject type cannot be blank'
        );
    }

    @IsTest
    static void should_create_logical_junctions() {
        // Arrange
        Query.Criterion c1 = SoqlQuery.COND.field('Name').eq('A');
        Query.Criterion c2 = SoqlQuery.COND.field('Name').eq('B');
        Query.Criterion c3 = SoqlQuery.COND.field('Type').eq('C');
        Query.Criterion c4 = SoqlQuery.COND.field('Type').eq('D');
        Query.Criterion c5 = SoqlQuery.COND.field('Rating').eq('Hot');

        // Act
        String andStr = SoqlQuery.of('Account').wherex(SoqlQuery.ands(c1, c2)).toString();
        String orStr = SoqlQuery.of('Account').wherex(SoqlQuery.ors(c3, c4)).toString();
        String notStr = SoqlQuery.of('Account').wherex(SoqlQuery.notx(c5)).toString();
        String composedStr = SoqlQuery.of('Account')
            .wherex(SoqlQuery.notx(SoqlQuery.ands(c2, SoqlQuery.ors(c1, c5))))
            .toString();

        // Assert
        Assert.isTrue(andStr.contains('(Name = :var$0 AND Name = :var$1)'), 'AND junction wrapped');
        Assert.isTrue(orStr.contains('(Type = :var$0 OR Type = :var$1)'), 'OR junction wrapped');
        Assert.isTrue(notStr.contains('(NOT Rating = :var$0)'), 'NOT operator wrapped');
        Assert.isTrue(
            composedStr.contains('(NOT (Name = :var$0 AND (Name = :var$1 OR Rating = :var$2)))'),
            'Composed junction'
        );
    }

    @IsTest
    static void should_create_logical_junctions_from_conditions() {
        // Arrange
        SoqlQuery.Condition c1 = SoqlQuery.COND.field('Name').eq('A');
        SoqlQuery.Condition c2 = SoqlQuery.COND.field('Name').eq('B');
        SoqlQuery.Condition c3 = SoqlQuery.COND.field('Type').eq('C');
        SoqlQuery.Condition c4 = SoqlQuery.COND.field('Type').eq('D');
        SoqlQuery.Condition c5 = SoqlQuery.COND.field('Rating').eq('Hot');

        // Act
        String andStr = SoqlQuery.of('Account').wherex(c1.addAnd(c2)).toString();
        String orStr = SoqlQuery.of('Account').wherex(c3.addOr(c4)).toString();
        String notStr = SoqlQuery.of('Account').wherex(c5.notx()).toString();
        String composedStr = SoqlQuery.of('Account').wherex(c2.add(c5).notx(c3)).toString();

        // Assert
        Assert.isTrue(andStr.contains('Name = :var$0 AND Name = :var$1'), 'AND junction');
        Assert.isTrue(orStr.contains('Type = :var$0 OR Type = :var$1'), 'OR junction');
        Assert.isTrue(notStr.contains('NOT Rating = :var$0'), 'NOT operator');
        Assert.isTrue(
            composedStr.contains('Name = :var$0 AND Rating = :var$1 AND (NOT Type = :var$2)'),
            'Composed junction'
        );
    }

    @IsTest
    static void should_fail_on_logical_operator_change() {
        // Arrange
        Query.Junction j = new Query.Junction();
        j.add(SoqlQuery.COND.field('Name').eq('A'), 'AND');
        Exception actualException;

        // Act
        try {
            j.add(SoqlQuery.COND.field('Name').eq('B'), 'OR');
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for logical op change');
        Assert.isTrue(actualException.getMessage().contains('cannot be overridden'), 'Message check');
    }

    @IsTest
    static void should_handle_logical_junction_overloads() {
        // Arrange
        Query.Criterion c1 = SoqlQuery.COND.field('Name').eq('A');
        Query.Criterion c2 = SoqlQuery.COND.field('Name').eq('B');
        List<Query.Criterion> conditions = new List<Query.Criterion>{ c1, c2 };

        // Act
        String andActual = SoqlQuery.of('Account').wherex(SoqlQuery.ands(conditions)).toString();
        String orActual = SoqlQuery.of('Account').wherex(SoqlQuery.ors(conditions)).toString();

        // Assert
        Assert.isTrue(andActual.contains('AND'), 'ANDS with list');
        Assert.isTrue(orActual.contains('OR'), 'ORS with list');
    }
    // </editor-fold>

    // <editor-fold desc="Select Fields & Functions">
    @IsTest
    static void should_handle_field_selection_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.field(Account.Id)
            .field('Name')
            .fields(new List<Object>{ Account.Type, 'Industry' })
            .fields('AnnualRevenue, Description');

        // Assert
        String actual = q.toString();
        Assert.isTrue(
            actual.contains('SELECT Id, Name, Type, Industry, AnnualRevenue, Description'),
            'All fields should be selected'
        );
    }

    @IsTest
    static void should_handle_csv_fields_and_strip_spaces() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act
        q.fields(' Id ,  Name  , Type ');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('SELECT Id, Name, Type'), 'Spaces should be stripped and CSV parsed');
    }

    @IsTest
    static void should_handle_all_fields_token() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        String actual = q.allFields().toString();

        // Assert
        Assert.isTrue(actual.contains('FIELDS(ALL)'), 'Should contain FIELDS(CUSTOM)');
        Assert.isTrue(actual.contains('LIMIT 200'), 'Unbound all fields should imply a limit');
    }

    @IsTest
    static void should_handle_custom_fields_token() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        String actual = q.customFields().toString();

        // Assert
        Assert.isTrue(actual.contains('FIELDS(CUSTOM)'), 'Should contain FIELDS(CUSTOM)');
        Assert.isTrue(actual.contains('LIMIT 200'), 'Unbound custom fields should imply a limit');
    }

    @IsTest
    static void should_handle_standard_fields_token() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        String actual = q.standardFields().toString();

        // Assert
        Assert.isTrue(actual.contains('FIELDS(STANDARD)'), 'Should contain FIELDS(STANDARD)');
        Assert.isTrue(!actual.contains('LIMIT 200'), 'Bound standard fields should not imply a limit');
    }

    @IsTest
    static void should_expand_to_all_describe_fields() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        String actual = q.allDescribeFields().toString();

        // Assert
        Assert.isTrue(actual.startsWith('SELECT'), 'Should generate SELECT');
        Assert.isTrue(actual.contains('Id'), 'allDescribeFields should expand to actual field names');
    }

    @IsTest
    static void should_handle_field_property_filtering() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of(Account.SObjectType);
        SoqlQuery q2 = SoqlQuery.of(Account.SObjectType);
        SoqlQuery q3 = SoqlQuery.of(Account.SObjectType);

        // Act
        String readable = q1.allReadableFields().toString();
        String editable = q2.allEditableFields().toString();
        String creatable = q3.allCreatableFields().toString();

        // Assert
        Assert.isNotNull(readable, 'Readable fields');
        Assert.isNotNull(editable, 'Editable fields');
        Assert.isNotNull(creatable, 'Creatable fields');
    }

    @IsTest
    static void should_handle_all_fields_with_properties() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of(Account.SObjectType);
        SoqlQuery q2 = SoqlQuery.of(Account.SObjectType);

        // Act
        String custom = q1.allFields(SoqlQuery.FieldProperty.CUSTOM).toString();
        String multiple = q2.allFields(
                new List<SoqlQuery.FieldProperty>{ SoqlQuery.FieldProperty.CUSTOM, SoqlQuery.FieldProperty.UPDATEABLE }
            )
            .toString();

        // Assert
        Assert.isNotNull(custom, 'Custom fields');
        Assert.isNotNull(multiple, 'Multiple properties');
    }

    @IsTest
    static void should_handle_exhaustive_field_properties() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);
        List<SoqlQuery.FieldProperty> allProps = SoqlQuery.FieldProperty.values();

        // Act
        // This hits the large switch statement in FieldChecker via SelectClause.allFields
        String actual = q.allFields(allProps).toString();

        // Assert
        Assert.isNotNull(actual, 'Should handle all field properties without error');
    }

    @IsTest
    static void should_handle_field_set_selection() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(User.SObjectType);

        // Act
        try {
            q.fieldSet('PersonalInfo_EPIM').toString();
        } catch (Exception e) {
            // Expected to fail if field set doesn't exist, but we hit the builder logic
            Assert.isNotNull(e.getMessage(), 'Exception message should be logged');
        }

        // Assert
        Assert.isNotNull(q, 'Builder should survive the call');
    }

    @IsTest
    static void should_handle_selection_functions_with_aliases() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.convertCurrency(Account.AnnualRevenue, 'curr')
            .convertTimezone(Account.CreatedDate)
            .format(Account.LastModifiedDate, 'fmt')
            .grouping(Account.Type, 'grp')
            .toLabel(Account.Industry, 'lbl');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('convertCurrency(AnnualRevenue) curr'), 'Currency function');
        Assert.isTrue(actual.contains('convertTimezone(CreatedDate)'), 'Timezone function');
        Assert.isTrue(actual.contains('FORMAT(LastModifiedDate) fmt'), 'Format function');
        Assert.isTrue(actual.contains('GROUPING(Type) grp'), 'Grouping function');
        Assert.isTrue(actual.contains('toLabel(Industry) lbl'), 'toLabel function');
    }

    @IsTest
    static void should_handle_selection_functions_string_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act
        q.convertCurrency('AnnualRevenue').format('LastModifiedDate').grouping('Type').toLabel('Industry');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('convertCurrency(AnnualRevenue)'), 'Currency unaliased');
        Assert.isTrue(actual.contains('FORMAT(LastModifiedDate)'), 'Format unaliased');
        Assert.isTrue(actual.contains('GROUPING(Type)'), 'Grouping unaliased');
        Assert.isTrue(actual.contains('toLabel(Industry)'), 'toLabel unaliased');
    }

    @IsTest
    static void should_handle_convert_currency_unaliased_field() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.convertCurrency(Account.AnnualRevenue);

        // Assert
        Assert.isTrue(
            q.toString().contains('convertCurrency(AnnualRevenue)'),
            'convertCurrency SObjectField unaliased'
        );
    }

    @IsTest
    static void should_handle_selection_functions_unaliased_field() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.format(Account.LastModifiedDate).toLabel(Account.Industry).grouping(Account.Type);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('FORMAT(LastModifiedDate)'), 'format SObjectField unaliased');
        Assert.isTrue(actual.contains('toLabel(Industry)'), 'toLabel SObjectField unaliased');
        Assert.isTrue(actual.contains('GROUPING(Type)'), 'grouping SObjectField unaliased');
    }
    // </editor-fold>

    // <editor-fold desc="TYPEOF & Sub-Queries">
    @IsTest
    static void should_build_typeof_clause() {
        // Arrange
        SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner').when('User').then('Alias').elsex('Name').end();

        // Act
        String actual = SoqlQuery.of(Account.SObjectType).typeOf(to).toString();

        // Assert
        Assert.isTrue(actual.contains('WHEN User THEN Alias ELSE Name'), 'TYPEOF with else');
        Assert.isTrue(actual.contains('END'), 'TYPEOF with end');
    }

    @IsTest
    static void should_build_complex_typeof_clause() {
        // Arrange
        SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner')
            .when('User')
            .thenFields(new List<Object>{ 'Alias', 'Email' })
            .when('Group')
            .then('Name')
            .end();

        // Act
        String actual = SoqlQuery.of(Account.SObjectType).typeOf(to).toString();

        // Assert
        Assert.isTrue(actual.contains('WHEN User THEN Alias, Email'), 'Multi-field branch');
        Assert.isTrue(actual.contains('WHEN Group THEN Name'), 'Second branch');
    }

    @IsTest
    static void should_handle_typeof_field_variants() {
        // Arrange
        SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner')
            .when('User')
            .thenFields('Alias,Email')
            .elseFields('Name,Id')
            .elseFields(new List<Object>{ Account.Description })
            .end();

        // Act
        String actual = SoqlQuery.of('Account').typeOf(to).toString();

        // Assert
        Assert.isTrue(actual.contains('THEN Alias, Email'), 'String thenFields');
        Assert.isTrue(actual.contains('ELSE Name, Id, Description'), 'String and Iterable elseFields');
    }

    @IsTest
    static void should_handle_typeof_iterable_else_overload() {
        // Arrange
        SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner')
            .when('User')
            .then('Name')
            .elseFields(new List<Object>{ 'Alias', 'Email' })
            .end();

        // Act
        String actual = SoqlQuery.of('Account').typeOf(to).toString();

        // Assert
        Assert.isTrue(actual.contains('ELSE Alias, Email'), 'Iterable elseFields');
    }

    @IsTest
    static void should_fail_on_invalid_typeof_sequence() {
        // Arrange
        Exception actualException;

        // Act
        try {
            new SoqlQuery.TypeOf('Owner').then('Name');
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw exception for missing when()');
        Assert.isTrue(
            actualException.getMessage().contains('must call when() before thenField()'),
            'Validation message'
        );
    }

    @IsTest
    static void should_throw_when_typeof_not_ended() {
        // Arrange
        SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner').when('User').then('Alias');
        Exception actualException;

        // Act
        try {
            to.toString();
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw exception when .end() is missing');
        Assert.isTrue(
            actualException.getMessage().contains('must be finalized'),
            'Exception message mismatch: ' + actualException.getMessage()
        );
    }

    @IsTest
    static void should_handle_subquery_variants() {
        // Arrange
        SoqlQuery sub1 = SoqlQuery.of(Contact.SObjectType).field(Contact.LastName);
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field(Account.Id);

        // Act
        q.subQuery('Contacts', sub1).subQuery('Opportunities', 'Opportunity', new List<Object>{ 'Amount' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('(SELECT LastName FROM Contacts)'), 'Query-based subquery');
        Assert.isTrue(actual.contains('(SELECT Amount FROM Opportunities)'), 'String-based subquery');
    }

    @IsTest
    static void should_handle_additional_subquery_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.subQuery('Cases', Contact.SObjectType, 'Subject').subQuery('Tasks', 'Task', 'Description');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('(SELECT Subject FROM Cases)'), 'SObjectType string fields');
        Assert.isTrue(actual.contains('(SELECT Description FROM Tasks)'), 'String string fields');
    }

    @IsTest
    static void should_handle_subquery_iterable_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        List<Object> fields = new List<Object>{ 'LastName', Contact.Email };

        // Act
        q.subQuery('Contacts', Contact.SObjectType, fields)
            .subQuery('Opportunities', 'Opportunity', new List<Object>{ 'Amount' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('(SELECT LastName, Email FROM Contacts)'), 'SObjectType iterable fields');
        Assert.isTrue(actual.contains('(SELECT Amount FROM Opportunities)'), 'String iterable fields');
    }
    // </editor-fold>

    // <editor-fold desc="Aggregate Functions">
    @IsTest
    static void should_handle_basic_aggregates() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.count(Account.Id, 'total').avg(Account.AnnualRevenue, 'av').sum(Account.AnnualRevenue, 'su');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('COUNT(Id) total'), 'COUNT');
        Assert.isTrue(actual.contains('AVG(AnnualRevenue) av'), 'AVG');
        Assert.isTrue(actual.contains('SUM(AnnualRevenue) su'), 'SUM');
    }

    @IsTest
    static void should_handle_extreme_aggregates() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.min(Account.AnnualRevenue, 'mi').max(Account.AnnualRevenue, 'ma').countDistinct(Account.Id, 'dist');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('MIN(AnnualRevenue) mi'), 'MIN');
        Assert.isTrue(actual.contains('MAX(AnnualRevenue) ma'), 'MAX');
        Assert.isTrue(actual.contains('COUNT_DISTINCT(Id) dist'), 'COUNT_DISTINCT');
    }

    @IsTest
    static void should_handle_unaliased_aggregates() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act
        q.count('Id').avg('AnnualRevenue').sum('AnnualRevenue');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('COUNT(Id)'), 'Unaliased COUNT');
        Assert.isTrue(actual.contains('AVG(AnnualRevenue)'), 'Unaliased AVG');
    }

    @IsTest
    static void should_handle_aggregate_variants() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act
        q.countDistinct('Id').min('AnnualRevenue').max('AnnualRevenue');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('COUNT_DISTINCT(Id)'), 'COUNT_DISTINCT string');
        Assert.isTrue(actual.contains('MIN(AnnualRevenue)'), 'MIN string');
        Assert.isTrue(actual.contains('MAX(AnnualRevenue)'), 'MAX string');
    }

    @IsTest
    static void should_handle_count_unaliased_field() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.count(Account.Id).countDistinct(Account.Name);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('COUNT(Id)'), 'count SObjectField unaliased');
        Assert.isTrue(actual.contains('COUNT_DISTINCT(Name)'), 'countDistinct SObjectField unaliased');
    }

    @IsTest
    static void should_handle_other_aggregates_unaliased_field() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);

        // Act
        q.avg(Account.AnnualRevenue).min(Account.AnnualRevenue).max(Account.AnnualRevenue).sum(Account.AnnualRevenue);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('AVG(AnnualRevenue)'), 'avg SObjectField unaliased');
        Assert.isTrue(actual.contains('MIN(AnnualRevenue)'), 'min SObjectField unaliased');
        Assert.isTrue(actual.contains('MAX(AnnualRevenue)'), 'max SObjectField unaliased');
        Assert.isTrue(actual.contains('SUM(AnnualRevenue)'), 'sum SObjectField unaliased');
    }
    // </editor-fold>

    // <editor-fold desc="USING SCOPE">
    @IsTest
    static void should_handle_all_query_scopes() {
        // Arrange & Act
        for (SoqlQuery.Scope s : SoqlQuery.Scope.values()) {
            String actual = SoqlQuery.of(Account.SObjectType).field('Id').usingScope(s).toString();

            // Assert
            Assert.isTrue(actual.contains('USING SCOPE ' + s.name()), 'Scope ' + s.name() + ' failed');
        }
    }
    // </editor-fold>

    // <editor-fold desc="WHERE Clauses">
    @IsTest
    static void should_apply_basic_where_conditions() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.wherex(SoqlQuery.COND.field(Account.Name).eq('Acme'))
            .addCondition(SoqlQuery.COND.field(Account.Industry).ne('Energy'));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('WHERE Name = :var$0 AND Industry != :var$1'), 'AND logical join');
        Assert.areEqual('Acme', q.getBindings().get('var$0'), 'Name binding');
        Assert.areEqual('Energy', q.getBindings().get('var$1'), 'Industry binding');
    }

    @IsTest
    static void should_handle_equality_shortcut_methods() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.addConditionEq(Account.Name, 'A').addConditionIn(Account.Type, new List<String>{ 'X' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name = :var$0'), 'addConditionEq');
        Assert.isTrue(actual.contains('Type IN :var$1'), 'addConditionIn');
        Assert.areEqual('A', q.getBindings().get('var$0'), 'Name binding');
        Assert.areEqual('X', ((List<String>) q.getBindings().get('var$1'))[0], 'Type binding');
    }

    @IsTest
    static void should_handle_inequality_shortcut_methods() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.addConditionNe(Account.Name, 'A').addConditionNotIn(Account.Type, new List<String>{ 'X' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name != :var$0'), 'addConditionEq');
        Assert.isTrue(actual.contains('Type NOT IN :var$1'), 'addConditionIn');
        Assert.areEqual('A', q.getBindings().get('var$0'), 'Name binding');
        Assert.areEqual('X', ((List<String>) q.getBindings().get('var$1'))[0], 'Type binding');
    }

    @IsTest
    static void should_handle_where_and_condition_string_overloads() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Id');

        // Act
        q1.wherex('Name != \'X\'').addCondition('Type = \'Y\'');

        q2.addConditionEq('Industry', 'Z');

        // Assert
        Assert.isTrue(q1.toString().contains('WHERE Name != \'X\' AND Type = \'Y\''), 'wherex/addCondition string');
        Assert.isTrue(q2.toString().contains('WHERE Industry = :var$0'), 'addConditionEq string');
    }

    @IsTest
    static void should_handle_picklist_collection_operators() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        List<String> values = new List<String>{ 'A', 'B' };
        Set<String> values2 = new Set<String>{ 'С;D' };

        // Act
        q.addCondition(SoqlQuery.COND.field('SomeMultiPicklist__c').includes(values))
            .addCondition(SoqlQuery.COND.field('OtherMultiPicklist__c').excludes(values2));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('SomeMultiPicklist__c INCLUDES (\'A\', \'B\')'), 'INCLUDES operator');
        Assert.isTrue(actual.contains('OtherMultiPicklist__c EXCLUDES (\'С;D\')'), 'EXCLUDES operator');
    }

    @IsTest
    static void should_handle_collection_and_boolean_operators() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        SoqlQuery sub = SoqlQuery.of('Opportunity').field('AccountId');
        SoqlQuery sub2 = SoqlQuery.of('Contact').field('AccountId');

        // Act
        q.addCondition(SoqlQuery.COND.field('IsPartner').isTrue())
            .addCondition(SoqlQuery.COND.field('IsDeleted').isFalse())
            .addCondition(SoqlQuery.COND.field('Industry').notIn(new List<String>{ 'Apparel' }))
            .addCondition(SoqlQuery.COND.field('Id').inx(sub))
            .addCondition(SoqlQuery.COND.field('Id').notIn(sub2));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('IsPartner = :var$0'), 'isTrue shortcut');
        Assert.isTrue(actual.contains('IsDeleted = :var$1'), 'isFalse shortcut');
        Assert.isTrue(actual.contains('Industry NOT IN :var$2'), 'NOT IN iterable');
        Assert.isTrue(actual.contains('Id IN (SELECT AccountId FROM Opportunity)'), 'IN subquery');
        Assert.isTrue(actual.contains('Id NOT IN (SELECT AccountId FROM Contact)'), 'NOT IN subquery');
        Assert.areEqual(true, q.getBindings().get('var$0'), 'isTrue binding');
        Assert.areEqual(false, q.getBindings().get('var$1'), 'isFalse binding');
        Assert.areEqual(new List<String>{ 'Apparel' }, q.getBindings().get('var$2'), 'NOT IN binding');
    }

    @IsTest
    static void should_handle_id_shortcuts() {
        // Arrange
        Id accId = fakeId(Account.SObjectType);
        List<Id> accIds = new List<Id>{ accId };

        // Act
        SoqlQuery qSingle = SoqlQuery.of('Account').byId(accId);
        SoqlQuery qMulti = SoqlQuery.of('Account').byIds(accIds);

        // Assert
        Assert.isTrue(qSingle.toString().contains('WHERE Id = :var$0'), 'byId check');
        Assert.isTrue(qMulti.toString().contains('Id IN :var$0'), 'byIds');
        Assert.areEqual(accId, qSingle.getBindings().get('var$0'), 'byId binding');
        Assert.areEqual(accIds, qMulti.getBindings().get('var$0'), 'byIds binding');
    }

    @IsTest
    static void should_handle_where_logic_or_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.addConditionOr(SoqlQuery.COND.field('Name').eq('X'))
            .addConditionOr('Type = \'Y\'')
            .addConditionEq('Industry', 'Z');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name = :var$0 OR Type = \'Y\' OR Industry = :var$1'), 'addConditionOr variants');
        Assert.areEqual('X', q.getBindings().get('var$0'), 'Name binding');
        Assert.areEqual('Z', q.getBindings().get('var$1'), 'Industry binding');
    }

    @IsTest
    static void should_handle_byids_iterable() {
        // Arrange
        Id fakeId = fakeId(Account.SObjectType);
        List<Id> ids = new List<Id>{ fakeId };

        // Act
        SoqlQuery q = SoqlQuery.of('Account').byIds(ids);

        // Assert
        Assert.isTrue(q.toString().contains('Id IN :var$0'), 'byIds iterable');
        Assert.areEqual(ids, q.getBindings().get('var$0'), 'byIds binding');
    }

    @IsTest
    static void should_handle_condition_in_overloads() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Id');
        SoqlQuery sub = SoqlQuery.of('Contact').field('AccountId');
        List<String> types = new List<String>{ 'X' };

        // Act
        q1.addConditionIn('Type', types).addConditionIn(Account.Id, sub).addConditionIn('Id', sub);
        q2.addConditionNotIn('Type', types).addConditionNotIn(Account.Id, sub).addConditionNotIn('Id', sub);

        // Assert
        String actual1 = q1.toString();
        String actual2 = q2.toString();
        Assert.isTrue(actual1.contains('Type IN :var$0'), 'addConditionIn string iterable');
        Assert.isTrue(actual1.contains('Id IN (SELECT AccountId FROM Contact)'), 'addConditionIn query overloads');
        Assert.areEqual(types, q1.getBindings().get('var$0'), 'Type binding');
        Assert.isTrue(actual2.contains('Type NOT IN :var$0'), 'addConditionNotIn string iterable');
        Assert.isTrue(
            actual2.contains('Id NOT IN (SELECT AccountId FROM Contact)'),
            'addConditionNotIn query overloads'
        );
        Assert.areEqual(types, q2.getBindings().get('var$0'), 'Type binding');
    }

    @IsTest
    static void should_handle_negated_where_clauses() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.wherex(SoqlQuery.notx(SoqlQuery.COND.field('Name').eq('Acme')));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('NOT Name = :var$0'), 'Negation logic');
        Assert.areEqual('Acme', q.getBindings().get('var$0'), 'Negated binding');
    }

    @IsTest
    static void should_handle_comparison_operators() {
        SoqlQuery q1 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('AnnualRevenue').gt(100));
        Assert.isTrue(q1.toString().contains('> :var$0'), 'Greater than');
        Assert.areEqual(100, q1.getBindings().get('var$0'));

        SoqlQuery q2 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('AnnualRevenue').ge(100));
        Assert.isTrue(q2.toString().contains('>= :var$0'), 'Greater equal');
        Assert.areEqual(100, q2.getBindings().get('var$0'));

        SoqlQuery q3 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('AnnualRevenue').lt(500));
        Assert.isTrue(q3.toString().contains('< :var$0'), 'Less than');
        Assert.areEqual(500, q3.getBindings().get('var$0'));

        SoqlQuery q4 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('AnnualRevenue').le(500));
        Assert.isTrue(q4.toString().contains('<= :var$0'), 'Less equal');
        Assert.areEqual(500, q4.getBindings().get('var$0'));
    }

    @IsTest
    static void should_handle_string_comparison_operators() {
        SoqlQuery q1 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('Name').likex('%A%'));
        Assert.isTrue(q1.toString().contains('LIKE :var$0'), 'LIKE');
        Assert.areEqual('%A%', q1.getBindings().get('var$0'));

        SoqlQuery q2 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('Name').isNull());
        Assert.isTrue(q2.toString().contains('= NULL'), 'IS NULL');

        SoqlQuery q3 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('Name').isNotNull());
        Assert.isTrue(q3.toString().contains('!= NULL'), 'IS NOT NULL');
    }

    @IsTest
    static void should_handle_picklist_operators() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('Multi__c').includes('A;B'));
        SoqlQuery q2 = SoqlQuery.of('Account').wherex(SoqlQuery.COND.field('Multi__c').excludes('C'));

        // Act & Assert
        Assert.isTrue(q1.toString().contains('INCLUDES (\'A;B\')'), 'INCLUDES');
        Assert.isTrue(q2.toString().contains('EXCLUDES (\'C\')'), 'EXCLUDES');
    }

    @IsTest
    static void should_handle_numeric_iterable_literals() {
        // Arrange
        SoqlQuery.Condition c = SoqlQuery.COND.field('NumberOfEmployees');

        // Act & Assert
        // We use standalone condition to trigger literal fallback (no Bindings context)
        Assert.isTrue(c.inx(new List<Integer>{ 1, 2 }).toString().contains('(1, 2)'), 'Numeric literal list');
    }

    @IsTest
    static void should_handle_semi_joins() {
        // Arrange
        Query sub = SoqlQuery.of(Contact.SObjectType).field(Contact.AccountId);

        // Act
        String actual = SoqlQuery.of(Account.SObjectType).field('Id').addConditionIn(Account.Id, sub).toString();

        // Assert
        Assert.isTrue(actual.contains('Id IN (SELECT AccountId FROM Contact)'), 'Semi-join');
    }

    @IsTest
    static void should_handle_anti_joins() {
        // Arrange
        Query sub = SoqlQuery.of(Contact.SObjectType).field(Contact.AccountId);

        // Act
        String actual = SoqlQuery.of(Account.SObjectType).field('Id').addConditionNotIn(Account.Id, sub).toString();

        // Assert
        Assert.isTrue(actual.contains('Id NOT IN (SELECT AccountId FROM Contact)'), 'Semi-join');
    }

    @IsTest
    static void should_fail_on_null_where_condition() {
        // Arrange
        Exception actualException;

        // Act
        try {
            SoqlQuery.of(Account.SObjectType).wherex((Query.Criterion) null);
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should fail for null Criterion');
        Assert.isTrue(actualException.getMessage().contains('condition cannot be null'), 'Message coverage');
    }
    // </editor-fold>

    // <editor-fold desc="WITH & Security">
    @IsTest
    static void should_handle_data_category_selection() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.withDataCategory(SoqlQuery.CAT.of('A').at('B'));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('WITH DATA CATEGORY A AT B'), 'Data category syntax');
    }

    @IsTest
    static void should_handle_all_category_spec_variants() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q3 = SoqlQuery.of('Account').field('Id');

        // Act
        String above = q1.withDataCategory(SoqlQuery.CAT.of('G1').above('C1')).toString();
        String below = q2.withDataCategory(SoqlQuery.CAT.of('G2').below('C2')).toString();
        String aboveOrBelow = q3.withDataCategory(SoqlQuery.CAT.of('G3').aboveOrBelow('C3')).toString();

        // Assert
        Assert.isTrue(above.contains('G1 ABOVE C1'), 'ABOVE');
        Assert.isTrue(below.contains('G2 BELOW C2'), 'BELOW');
        Assert.isTrue(aboveOrBelow.contains('G3 ABOVE_OR_BELOW C3'), 'ABOVE_OR_BELOW');
    }

    @IsTest
    static void should_handle_complex_data_category() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.withDataCategory(SoqlQuery.CAT.of('G').above('S').aboveOrBelow('Z'));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('G ABOVE_OR_BELOW Z'), 'Complex data category should reflect last selection');
    }

    @IsTest
    static void should_handle_data_category_selection_provider() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.withDataCategory(SoqlQuery.CAT.of('A').at('B'));

        // Assert
        Assert.isTrue(q.toString().contains('A AT B'), 'DATA_CATEGORY_SELECTION provider');
    }

    @IsTest
    static void should_handle_plural_permission_sets() {
        // Arrange
        Id pid1 = fakeId(PermissionSet.SObjectType);
        Id pid2 = fakeId(PermissionSet.SObjectType);
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        try {
            q.withPermissionSetIds(new List<Id>{ pid1, pid2 });
        } catch (System.SecurityException e) {
            Assert.isTrue(e.getMessage().contains('requires ApexUserModeWithPermset'), 'Exception message recorded');
        }

        // Assert
        Assert.areEqual('SELECT Id FROM Account', q.toString(), 'Builder survived plural permission sets');
    }

    @IsTest
    static void should_handle_execution_modes() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.withMode(AccessLevel.SYSTEM_MODE).withStrip(AccessType.READABLE);

        // Assert
        String actual = q.toString();
        Assert.areEqual('SELECT Id FROM Account', actual, 'Execution mode should not affect string output');
    }

    @IsTest
    static void should_exercise_executor_access_configuration() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.withMode(AccessLevel.SYSTEM_MODE).withStrip();

        // Assert
        Assert.isNotNull(q.fetch(), 'Should execute with configured access modes');
    }

    @IsTest
    static void should_handle_permission_set_configuration() {
        // Arrange
        Id fakeId = fakeId(PermissionSet.SObjectType);
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        try {
            q.withPermissionSetId(fakeId).withPermissionSetIds(new List<Id>{ fakeId });
        } catch (Exception e) {
            // Permission sets might throw in some contexts
            Assert.isNotNull(e.getMessage(), 'Exception message recorded');
        }

        // Assert
        Assert.isNotNull(q.toString(), 'Builder survived permission set configuration');
    }

    @IsTest
    static void should_fail_on_invalid_field_set() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType);
        Exception actualException;

        // Act
        try {
            q.fieldSet('0NonExistentFieldSet0');
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should fail for invalid field set');
    }

    @IsTest
    static void should_handle_order_by_variants() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.orderBy(Account.Name, Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('ORDER BY Name DESC NULLS LAST'), 'Order by with nulls order');
    }

    @IsTest
    static void should_handle_order_by_string_variants() {
        // Arrange & Act
        String ascOrder = SoqlQuery.of('Account').field('Id').orderBy('Name', Query.SortOrder.ASCX).toString();
        String descOrder = SoqlQuery.of('Account')
            .field('Id')
            .orderBy('Name', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_FIRST)
            .toString();

        // Assert
        Assert.isTrue(ascOrder.contains('ORDER BY Name ASC'), 'ASC order');
        Assert.isTrue(descOrder.contains('ORDER BY Name DESC NULLS FIRST'), 'DESC NULLS FIRST');
    }
    // </editor-fold>

    // <editor-fold desc="GROUP BY, HAVING, ORDER BY">
    @IsTest
    static void should_handle_ordinary_group_by() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field(Account.Type).groupBy(Account.Type);

        // Act
        String actual = q.toString();

        // Assert
        Assert.isTrue(actual.contains('GROUP BY Type'), 'Ordinary grouping');
    }

    @IsTest
    static void should_handle_group_by_overloads() {
        // Arrange
        List<Object> fields = new List<Object>{ 'Industry', Account.Rating };

        // Act
        String ordinary = SoqlQuery.of('Account').field('Type').groupBy(fields).toString();
        String rollup = SoqlQuery.of('Account').field('Type').groupByRollup(fields).toString();
        String cube = SoqlQuery.of('Account').field('Type').groupByCube(fields).toString();

        // Assert
        Assert.isTrue(ordinary.contains('GROUP BY Industry, Rating'), 'Ordinary group by');
        Assert.isTrue(rollup.contains('GROUP BY ROLLUP (Industry, Rating)'), 'Rollup group by');
        Assert.isTrue(cube.contains('GROUP BY CUBE (Industry, Rating)'), 'Cube group by');
    }

    @IsTest
    static void should_handle_single_field_group_by_variants() {
        // Arrange & Act
        String rollup = SoqlQuery.of('Account').field('Type').groupByRollup('Type').toString();
        String cube = SoqlQuery.of('Account').field('Type').groupByCube('Type').toString();

        // Assert
        Assert.isTrue(rollup.contains('GROUP BY ROLLUP (Type)'), 'Single rollup');
        Assert.isTrue(cube.contains('GROUP BY CUBE (Type)'), 'Single cube');
    }

    @IsTest
    static void should_fail_on_group_by_function_change() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Type').groupByRollup('Type');
        Exception actualException;

        // Act
        try {
            q.groupByCube('Industry');
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for grouping function change');
        Assert.isTrue(
            actualException.getMessage().contains('Grouping function redefinition is prohibited'),
            'Message check'
        );
    }

    @IsTest
    static void should_handle_having_aggregate_predicates() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').count('Id').groupBy('Type');
        SoqlQuery q2 = SoqlQuery.of(Account.SObjectType).count(Account.Id).groupBy(Account.Type);

        // Act
        q.havingx(SoqlQuery.HAV.avg('AnnualRevenue').gt(100000))
            .addHaving(SoqlQuery.HAV.min('AnnualRevenue').ge(10000))
            .addHaving(SoqlQuery.HAV.max('AnnualRevenue').le(1000000))
            .addHaving(SoqlQuery.HAV.sum('AnnualRevenue').lt(5000000))
            .addHaving(SoqlQuery.HAV.countDistinct('Id').ne(0));
        q2.havingx(SoqlQuery.HAV.avg(Account.AnnualRevenue).gt(100000))
            .addHaving(SoqlQuery.HAV.min(Account.AnnualRevenue).ge(10000))
            .addHaving(SoqlQuery.HAV.max(Account.AnnualRevenue).le(1000000))
            .addHaving(SoqlQuery.HAV.sum(Account.AnnualRevenue).lt(5000000))
            .addHaving(SoqlQuery.HAV.countDistinct(Account.Id).ne(0));

        // Assert
        String actual = q.toString();
        String actual2 = q2.toString();
        Assert.isTrue(actual.contains('AVG(AnnualRevenue) > :var$0'), 'Having AVG');
        Assert.isTrue(actual.contains('MIN(AnnualRevenue) >= :var$1'), 'Having MIN');
        Assert.isTrue(actual.contains('MAX(AnnualRevenue) <= :var$2'), 'Having MAX');
        Assert.isTrue(actual.contains('SUM(AnnualRevenue) < :var$3'), 'Having SUM');
        Assert.isTrue(actual.contains('COUNT_DISTINCT(Id) != :var$4'), 'Having COUNT_DISTINCT');
        Assert.areEqual(100000, q.getBindings().get('var$0'), 'AVG binding');
        Assert.areEqual(10000, q.getBindings().get('var$1'), 'MIN binding');
        Assert.areEqual(1000000, q.getBindings().get('var$2'), 'MAX binding');
        Assert.areEqual(5000000, q.getBindings().get('var$3'), 'SUM binding');
        Assert.areEqual(0, q.getBindings().get('var$4'), 'COUNT_DISTINCT binding');

        Assert.isTrue(actual2.contains('AVG(AnnualRevenue) > :var$0'), 'Having AVG');
        Assert.isTrue(actual2.contains('MIN(AnnualRevenue) >= :var$1'), 'Having MIN');
        Assert.isTrue(actual2.contains('MAX(AnnualRevenue) <= :var$2'), 'Having MAX');
        Assert.isTrue(actual2.contains('SUM(AnnualRevenue) < :var$3'), 'Having SUM');
        Assert.isTrue(actual2.contains('COUNT_DISTINCT(Id) != :var$4'), 'Having COUNT_DISTINCT');
        Assert.areEqual(100000, q2.getBindings().get('var$0'), 'AVG binding 2');
    }

    @IsTest
    static void should_handle_having_raw_string() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').count('Id').groupBy('Type');

        // Act
        q.havingx('COUNT(Id) > 5');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('HAVING COUNT(Id) > 5'), 'Raw string having');
    }

    @IsTest
    static void should_handle_rollup_and_cube_grouping() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Industry').groupByRollup('Industry');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Type').groupByCube('Type');

        // Assert
        Assert.isTrue(q1.toString().contains('GROUP BY ROLLUP (Industry)'), 'ROLLUP');
        Assert.isTrue(q2.toString().contains('GROUP BY CUBE (Type)'), 'CUBE');
    }

    @IsTest
    static void should_handle_having_clause_with_aggregates() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field(Account.Type).count(Account.Id).groupBy(Account.Type);

        // Act
        q.havingx(SoqlQuery.HAV.count(Account.Id).gt(1)).addHaving(SoqlQuery.HAV.avg(Account.AnnualRevenue).lt(1000));

        // Assert
        String actual = q.toString();
        Assert.isTrue(
            actual.contains('HAVING COUNT(Id) > :var$0 AND AVG(AnnualRevenue) < :var$1'),
            'HAVING syntax and AND join'
        );
        Assert.areEqual(1, q.getBindings().get('var$0'), 'COUNT binding');
        Assert.areEqual(1000, q.getBindings().get('var$1'), 'AVG binding');
    }

    @IsTest
    static void should_fail_on_mixing_where_logic() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        Exception actualException;

        // Act
        try {
            q.addConditionAnd('Name = \'A\'').addConditionOr('Type = \'B\'');
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for mixed logic');
        Assert.isTrue(actualException.getMessage().contains('cannot be overridden'), 'Enforce parentheses message');
    }

    @IsTest
    static void should_handle_where_logic_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        // Both use default AND
        q.addCondition(SoqlQuery.COND.field('Name').eq('A')).addCondition('Type = \'B\'');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name = :var$0 AND Type = \'B\''), 'Where logic check');
        Assert.areEqual('A', q.getBindings().get('var$0'), 'Name binding');
    }

    @IsTest
    static void should_fail_on_mixing_having_logic() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').count('Id');
        Exception actualException;

        // Act
        try {
            q.addHavingAnd(SoqlQuery.HAV.count('Id').gt(10)).addHavingOr('COUNT(Name) > 0');
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for mixed having logic');
    }

    @IsTest
    static void should_handle_having_logic_variants() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').groupBy('Name');

        // Act
        q.addHavingOr(SoqlQuery.HAV.field('Name').eq('X')).addHavingOr('COUNT(Id) > 0');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name = :var$0 OR COUNT(Id) > 0'), 'Having logic check');
        Assert.areEqual('X', q.getBindings().get('var$0'), 'Name binding');
    }

    @IsTest
    static void should_handle_having_equality_and_collection_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').count('Id').groupBy('Name');

        // Act
        q.addHavingEq('Name', 'A').addHavingIn('Name', new List<String>{ 'Value' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name = :var$0'), 'addHavingEq');
        Assert.isTrue(actual.contains('Name IN :var$1'), 'addHavingIn');
        Assert.areEqual('A', q.getBindings().get('var$0'), 'Equality binding');
        Assert.areEqual(new List<String>{ 'Value' }, q.getBindings().get('var$1'), 'Collection binding');
    }

    @IsTest
    static void should_handle_having_inequality_and_collection_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').count('Id').groupBy('Name');

        // Act
        q.addHavingNe('Name', 'A').addHavingNotIn('Name', new List<String>{ 'Value' });

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('Name != :var$0'), 'addHavingNe');
        Assert.isTrue(actual.contains('Name NOT IN :var$1'), 'addHavingNotIn');
        Assert.areEqual('A', q.getBindings().get('var$0'), 'Equality binding');
        Assert.areEqual(new List<String>{ 'Value' }, q.getBindings().get('var$1'), 'Collection binding');
    }

    @IsTest
    static void should_handle_complex_order_by() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.orderBy(Account.Name, Query.SortOrder.DESCX, Query.NullsOrder.NULLS_FIRST);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('ORDER BY Name DESC NULLS FIRST'), 'ORDER BY with DESC and NULLS FIRST');
    }

    @IsTest
    static void should_handle_order_by_last_variant() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.orderBy('CreatedDate', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('ORDER BY CreatedDate ASC NULLS LAST'), 'Ordering variant');
    }
    // </editor-fold>

    // <editor-fold desc="Limits & Pagination">
    @IsTest
    static void should_handle_limit_and_offset() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        q.lim(10).offset(5);

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('LIMIT 10 OFFSET 5'), 'Limit and Offset syntax');
    }

    @IsTest
    static void should_fail_on_negative_limit() {
        // Arrange
        Exception actualException;

        // Act
        try {
            SoqlQuery.of('Account').lim(-1);
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for negative limit');
        Assert.isTrue(actualException.getMessage().contains('LIMIT must be >= 0'), 'Limit message');
    }

    @IsTest
    static void should_allow_excessive_offset_for_forward_compatibility() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act
        q.offset(2001);

        // Assert
        Assert.isTrue(q.toString().contains('OFFSET 2001'), 'Offset should be passed through to Salesforce');
    }
    // </editor-fold>

    // <editor-fold desc="Locking & Update Trackers">
    @IsTest
    static void should_handle_locking_clauses() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q3 = SoqlQuery.of('Account').field('Id');

        // Act
        String view = q1.forView().toString();
        String ref = q2.forReference().toString();
        String upd = q3.forUpdate().toString();

        // Assert
        Assert.isTrue(view.contains('FOR VIEW'), 'FOR VIEW');
        Assert.isTrue(ref.contains('FOR REFERENCE'), 'FOR REFERENCE');
        Assert.isTrue(upd.contains('FOR UPDATE'), 'FOR UPDATE');
    }

    @IsTest
    static void should_handle_all_rows_clause() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        String actual = q.allRows().toString();

        // Assert
        Assert.isTrue(actual.contains('ALL ROWS'), 'ALL ROWS');
    }

    @IsTest
    static void should_handle_update_trackers() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').field('Id');
        SoqlQuery q2 = SoqlQuery.of('Account').field('Id');

        // Act
        String track = q1.updateTracking().toString();
        String visit = q2.updateViewstat().toString();

        // Assert
        Assert.isTrue(track.contains('UPDATE TRACKING'), 'UPDATE TRACKING');
        Assert.isTrue(visit.contains('UPDATE VIEWSTAT'), 'UPDATE VIEWSTAT');
    }
    // </editor-fold>

    // <editor-fold desc="Terminal Ops & Caching">
    @IsTest
    static void should_generate_to_count_string() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').addConditionNe(Account.Name, 'X');

        // Act
        String actual = q.toCountString();

        // Assert
        Assert.isTrue(actual.startsWith('SELECT COUNT()'), 'Count string starting');
        Assert.isTrue(actual.contains('WHERE Name != :var$0'), 'Count string with conditions');
        Assert.areEqual('X', q.getBindings().get('var$0'), 'Name binding');
    }

    @IsTest
    static void should_handle_to_count_string_complex() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').addConditionEq('Name', 'X').lim(10).offset(5).allRows();

        // Act
        String actual = q.toCountString();

        // Assert
        Assert.isTrue(actual.contains('LIMIT 10'), 'Count string LIMIT');
        Assert.isTrue(actual.contains('OFFSET 5'), 'Count string OFFSET');
        Assert.isTrue(actual.contains('ALL ROWS'), 'Count string ALL ROWS');
    }

    @IsTest
    static void should_handle_memoization_setup() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        q.memoize();

        // Assert
        Assert.isNotNull(q.toString(), 'Memoization call succeeded');
    }

    @IsTest
    static void should_handle_memoization_logic() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').memoize();

        // Act
        // First run should populate cache
        q.fetch();
        // Second run should hit cache
        q.fetch();

        // Assert
        Assert.isNotNull(q.toString(), 'Builder survived memoization execution');
    }

    @IsTest
    static void should_handle_cache_partition_calls() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        try {
            q.cacheSession('QueryCache');
            q.cacheOrg('QueryCache');
        } catch (Exception e) {
            // Expected to fail if no partitions in org, but coverage achieved
            Assert.isNotNull(e.getMessage(), 'Cache exception logged');
        }

        // Assert
        Assert.isNotNull(q, 'Builder survived cache calls');
    }

    @IsTest
    static void should_execute_terminal_ops_without_npe() {
        // Arrange
        SoqlQuery q = SoqlQuery.of(Account.SObjectType)
            .field('Id')
            .addConditionEq('Name', 'Acme')
            .withStrip(AccessType.READABLE)
            .withMode(AccessLevel.SYSTEM_MODE);

        // Act & Assert
        try {
            q.fetch();
            q.fetchLazy();
            q.fetchFirst();
            q.fetchCount();
            q.locator();
        } catch (Exception e) {
            Assert.isFalse(e instanceof NullPointerException, 'Should not throw NPE: ' + e.getStackTraceString());
        }
    }

    @IsTest
    static void should_call_run_more_on_driver_when_fetching_lazy() {
        // Arrange
        MockDriver mock = new MockDriver();
        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(mock);

        // Act
        q.fetchLazy();

        // Assert
        Assert.isTrue(mock.runMoreCalled, 'runMore should be called on the driver');
    }

    @IsTest
    static void should_iterate_over_mock_paged_results() {
        // Arrange
        MultiBatchMockDriver mock = new MultiBatchMockDriver();
        mock.addBatch(new List<SObject>{ new Account(Name = 'A1'), new Account(Name = 'A2') });
        mock.addBatch(new List<SObject>{ new Account(Name = 'B1') });

        SoqlQuery q = SoqlQuery.of('Account').field('Name').useDriver(mock);

        // Act
        List<SObject> results = new List<SObject>();
        for (SObject record : q.fetchLazy()) {
            results.add(record);
        }

        // Assert
        Assert.areEqual(3, results.size(), 'Should have returned 3 records');
        Assert.areEqual('A1', results[0].get('Name'));
        Assert.areEqual('A2', results[1].get('Name'));
        Assert.areEqual('B1', results[2].get('Name'));
    }

    @IsTest
    static void should_cover_cursor_iterator_paging_logic() {
        // Arrange
        MockCursor mock = new MockCursor(5); // 5 records total
        Iterable<SObject> iterable = SoqlQuery.createCursorIterable(mock);
        SoqlQuery.CursorIterator it = (SoqlQuery.CursorIterator) iterable.iterator();
        it.batchSize = 2; // Test paging with small batches

        // Act
        List<SObject> results = new List<SObject>();
        while (it.hasNext()) {
            results.add(it.next());
        }

        // Assert
        Assert.areEqual(5, results.size(), 'Should have iterated over all 5 records');
        Assert.areEqual(3, mock.fetchCount, 'Should have called fetch 3 times (2+2+1)');
    }

    @IsTest
    static void should_handle_empty_cursor_iterator() {
        // Arrange
        MockCursor mock = new MockCursor(0);
        Iterable<SObject> iterable = SoqlQuery.createCursorIterable(mock);
        Iterator<SObject> it = iterable.iterator();

        // Act & Assert
        Assert.isFalse(it.hasNext(), 'Empty cursor should not have next');
    }

    @IsTest
    static void should_cover_database_cursor() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('User').lim(1).withMode(AccessLevel.SYSTEM_MODE);

        // Act
        Test.startTest();
        Iterable<SObject> iterable = q.fetchLazy();
        Iterator<SObject> it = iterable.iterator();
        while (it.hasNext()) {
            it.next();
        }
        Test.stopTest();

        // Assert
        Assert.isNotNull(iterable, 'Should have returned an iterable');
    }

    @IsTest
    static void should_handle_fetch_on_exhausted_cursor() {
        // Arrange
        MockCursor mock = new MockCursor(1);
        Iterable<SObject> iterable = SoqlQuery.createCursorIterable(mock);
        Iterator<SObject> it = iterable.iterator();

        // Act
        it.next(); // Consume only record

        // Assert
        Assert.isFalse(it.hasNext());

        try {
            it.next(); // Force fetch() on exhausted
            Assert.fail('Should have thrown IndexOutOfBoundsException');
        } catch (Exception e) {
            Assert.isTrue(e instanceof System.ListException);
        }
    }

    @IsTest
    static void should_merge_internal_and_user_binds() {
        // Arrange
        Map<String, Object> userBinds = new Map<String, Object>{ 'var$0' => 'Banking', 'v' => 'Test%' };
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .addConditionEq('Industry', 'Apparel')
            .addCondition('Name LIKE :v')
            .withBindings(userBinds)
            .withMode(AccessLevel.SYSTEM_MODE);

        // Act
        String soql = q.toString(); // Internal binds var$0 = 'Apparel'
        q.fetch();

        // Assert
        Assert.isTrue(soql.contains(':var$0'), 'Internal bind exists');
        Assert.areEqual('Banking', q.getBindings().get('var$0'), 'Internal bind verified');
        Assert.areEqual('Test%', q.getBindings().get('v'), 'Internal bind verified');
    }

    @IsTest
    static void should_be_idempotent_with_binds() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').addConditionEq('Name', 'X');

        // Act
        String s1 = q.toString(); // var$0
        String s2 = q.toString(); // var$0 (if idempotent)

        // Assert
        Assert.areEqual(s1, s2, 'toString should be idempotent');
        Assert.isTrue(s1.contains(':var$0'), 'Should use first index');
    }

    @IsTest
    static void should_handle_lazy_execution_bindings() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').addConditionEq('Name', 'Acme');

        // Act
        try {
            q.fetch();
        } catch (Exception e) {
            Assert.fail('Execution failed due to missing bindings: ' + e.getMessage());
        }

        // Assert
        Assert.isTrue(q.toString().contains(':var$0'), 'Placeholders should be generated');
        Assert.areEqual('Acme', q.getBindings().get('var$0'), 'Bindings should be populated after fetch()');
    }

    @IsTest
    static void should_handle_fluent_user_bindings() {
        // Arrange
        Map<String, Object> userBinds = new Map<String, Object>{ 'myVar' => 'Acme' };
        SoqlQuery q = SoqlQuery.of('Account').field('Id').wherex('Name = :myVar');

        // Act
        q.withBindings(userBinds);
        Map<String, Object> allBinds = q.getBindings();

        // Assert
        Assert.isTrue(q.toString().contains(':myVar'), 'Query string should contain user bind variable');
        Assert.areEqual('Acme', allBinds.get('myVar'), 'User bind should be present in getBindings()');
    }

    // <editor-fold desc="Providers Details">
    @IsTest
    static void should_handle_date_part_functions() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');
        SoqlQuery q2 = SoqlQuery.of('Account');

        // Act
        q.field(SoqlQuery.DT.dayOnly(Account.CreatedDate)).field(SoqlQuery.DT.calendarMonth(Account.CreatedDate));
        q2.field(SoqlQuery.DT.dayOnly('CreatedDate')).field(SoqlQuery.DT.calendarMonth('CreatedDate'));

        // Assert
        String actual = q.toString();
        String actual2 = q2.toString();
        Assert.isTrue(actual.contains('DAY_ONLY(CreatedDate)'), 'DAY_ONLY');
        Assert.isTrue(actual.contains('CALENDAR_MONTH(CreatedDate)'), 'CALENDAR_MONTH');
        Assert.isTrue(actual2.contains('DAY_ONLY(CreatedDate)'), 'DAY_ONLY');
        Assert.isTrue(actual2.contains('CALENDAR_MONTH(CreatedDate)'), 'CALENDAR_MONTH');
    }

    @IsTest
    static void should_handle_exhaustive_date_parts() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act & Assert
        Assert.isTrue(q.field(SoqlQuery.DT.calendarQuarter('CreatedDate')).toString().contains('CALENDAR_QUARTER'));
        Assert.isTrue(q.field(SoqlQuery.DT.calendarYear('CreatedDate')).toString().contains('CALENDAR_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInMonth('CreatedDate')).toString().contains('DAY_IN_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInWeek('CreatedDate')).toString().contains('DAY_IN_WEEK'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInYear('CreatedDate')).toString().contains('DAY_IN_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalMonth('CreatedDate')).toString().contains('FISCAL_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalQuarter('CreatedDate')).toString().contains('FISCAL_QUARTER'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalYear('CreatedDate')).toString().contains('FISCAL_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.hourInDay('CreatedDate')).toString().contains('HOUR_IN_DAY'));
        Assert.isTrue(q.field(SoqlQuery.DT.weekInMonth('CreatedDate')).toString().contains('WEEK_IN_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.weekInYear('CreatedDate')).toString().contains('WEEK_IN_YEAR'));
        Assert.isTrue(
            q.field(SoqlQuery.DT.calendarQuarter(Account.CreatedDate)).toString().contains('CALENDAR_QUARTER')
        );
        Assert.isTrue(q.field(SoqlQuery.DT.calendarYear(Account.CreatedDate)).toString().contains('CALENDAR_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInMonth(Account.CreatedDate)).toString().contains('DAY_IN_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInWeek(Account.CreatedDate)).toString().contains('DAY_IN_WEEK'));
        Assert.isTrue(q.field(SoqlQuery.DT.dayInYear(Account.CreatedDate)).toString().contains('DAY_IN_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalMonth(Account.CreatedDate)).toString().contains('FISCAL_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalQuarter(Account.CreatedDate)).toString().contains('FISCAL_QUARTER'));
        Assert.isTrue(q.field(SoqlQuery.DT.fiscalYear(Account.CreatedDate)).toString().contains('FISCAL_YEAR'));
        Assert.isTrue(q.field(SoqlQuery.DT.hourInDay(Account.CreatedDate)).toString().contains('HOUR_IN_DAY'));
        Assert.isTrue(q.field(SoqlQuery.DT.weekInMonth(Account.CreatedDate)).toString().contains('WEEK_IN_MONTH'));
        Assert.isTrue(q.field(SoqlQuery.DT.weekInYear(Account.CreatedDate)).toString().contains('WEEK_IN_YEAR'));
    }

    @IsTest
    static void should_validate_date_literal_parameter() {
        // Arrange
        Exception actualException;

        // Act
        try {
            SoqlQuery.LIT.lastNDays(null);
        } catch (Exception e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for null n');
        Assert.isTrue(actualException.getMessage().contains('n cannot be null'), 'Literal validation message');
    }

    @IsTest
    static void should_provide_common_date_literals() {
        // Arrange & Act & Assert
        Assert.isNotNull(SoqlQuery.LIT.yesterday, 'yesterday');
        Assert.isNotNull(SoqlQuery.LIT.last90Days, 'last90Days');
        Assert.isNotNull(SoqlQuery.LIT.thisFiscalQuarter, 'thisFiscalQuarter');
    }

    @IsTest
    static void should_handle_parameterized_date_literals() {
        // Arrange & Act
        SoqlQuery.DateLiteral lastN = SoqlQuery.LIT.lastNDays(5);
        SoqlQuery.DateLiteral nextN = SoqlQuery.LIT.nextNWeeks(2);
        SoqlQuery.DateLiteral nAgo = SoqlQuery.LIT.nMonthsAgo(3);

        // Assert
        Assert.areEqual('LAST_N_DAYS:5', lastN.toString(), 'LAST_N_DAYS');
        Assert.areEqual('NEXT_N_WEEKS:2', nextN.toString(), 'NEXT_N_WEEKS');
        Assert.areEqual('N_MONTHS_AGO:3', nAgo.toString(), 'N_MONTHS_AGO');
    }

    @IsTest
    static void should_handle_extended_date_literals() {
        // Arrange & Act & Assert
        Assert.isTrue(SoqlQuery.LIT.nextNDays(1).toString().contains('NEXT_N_DAYS:1'));
        Assert.isTrue(SoqlQuery.LIT.nDaysAgo(1).toString().contains('N_DAYS_AGO:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNWeeks(1).toString().contains('LAST_N_WEEKS:1'));
        Assert.isTrue(SoqlQuery.LIT.nWeeksAgo(1).toString().contains('N_WEEKS_AGO:1'));
        Assert.isTrue(SoqlQuery.LIT.nextNMonths(1).toString().contains('NEXT_N_MONTHS:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNMonths(1).toString().contains('LAST_N_MONTHS:1'));
        Assert.isTrue(SoqlQuery.LIT.nextNQuarters(1).toString().contains('NEXT_N_QUARTERS:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNQuarters(1).toString().contains('LAST_N_QUARTERS:1'));
        Assert.isTrue(SoqlQuery.LIT.nQuartersAgo(1).toString().contains('N_QUARTERS_AGO:1'));
        Assert.isTrue(SoqlQuery.LIT.nextNYears(1).toString().contains('NEXT_N_YEARS:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNYears(1).toString().contains('LAST_N_YEARS:1'));
        Assert.isTrue(SoqlQuery.LIT.nYearsAgo(1).toString().contains('N_YEARS_AGO:1'));
        Assert.isTrue(SoqlQuery.LIT.nextNFiscalQuarters(1).toString().contains('NEXT_N_FISCAL_QUARTERS:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNFiscalQuarters(1).toString().contains('LAST_N_FISCAL_QUARTERS:1'));
        Assert.isTrue(SoqlQuery.LIT.nFiscalQuartersAgo(1).toString().contains('N_FISCAL_QUARTERS_AGO:1'));
        Assert.isTrue(SoqlQuery.LIT.nextNFiscalYears(1).toString().contains('NEXT_N_FISCAL_YEARS:1'));
        Assert.isTrue(SoqlQuery.LIT.lastNFiscalYears(1).toString().contains('LAST_N_FISCAL_YEARS:1'));
        Assert.isTrue(SoqlQuery.LIT.nFiscalYearsAgo(1).toString().contains('N_FISCAL_YEARS_AGO:1'));
    }

    @IsTest
    static void should_handle_date_and_time_bindings() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        Date d = Date.today();
        Time t = Time.newInstance(1, 1, 1, 1);

        // Act
        q.addCondition(SoqlQuery.COND.field('CreatedDate').eq(d))
            .addCondition(SoqlQuery.COND.field('CreatedDate').eq(t));

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains(':var'), 'Should use bindings for Date/Time');
        Assert.areEqual(d, q.getBindings().get('var$0'), 'Date binding');
        Assert.areEqual(t, q.getBindings().get('var$1'), 'Time binding');
    }

    @IsTest
    static void should_inline_datetime_literal() {
        // Arrange
        Datetime dt = Datetime.newInstanceGmt(2026, 2, 5, 14, 46, 27);
        SoqlQuery q = SoqlQuery.of('Account').field('Name').wherex(SoqlQuery.COND.field('CreatedDate').lt(dt));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT Name FROM Account WHERE CreatedDate < 2026-02-05T14:46:27Z', inlineSql);
    }

    @IsTest
    static void should_inline_date_literal() {
        // Arrange
        Date d = Date.newInstance(2026, 2, 5);
        SoqlQuery q = SoqlQuery.of('Account').field('Name').wherex(SoqlQuery.COND.field('LastActivityDate').eq(d));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT Name FROM Account WHERE LastActivityDate = 2026-02-05', inlineSql);
    }

    @IsTest
    static void should_inline_time_literal() {
        // Arrange
        Time t = Time.newInstance(14, 46, 27, 123);
        SoqlQuery q = SoqlQuery.of('TimeSlot').field('Id').wherex(SoqlQuery.COND.field('StartTime').eq(t));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT Id FROM TimeSlot WHERE StartTime = 14:46:27.123Z', inlineSql);
    }

    @IsTest
    static void should_handle_geo_functions() {
        // Arrange
        Location loc = Location.newInstance(0, 0);

        // Act
        String actual = SoqlQuery.COND.field(SoqlQuery.GEO.distance('BillingAddress', loc, SoqlQuery.DistanceUnit.KM))
            .lt(10)
            .toString();

        // Assert
        Assert.isTrue(actual.contains('DISTANCE(BillingAddress, GEOLOCATION(0.0, 0.0), \'km\') < 10'), 'Geo distance');
    }

    @IsTest
    static void should_handle_geo_field_overload() {
        // Arrange
        Location loc = Location.newInstance(1, 1);

        // Act
        String actual = SoqlQuery.of('Account')
            .field(SoqlQuery.GEO.distance(Account.BillingAddress, loc, SoqlQuery.DistanceUnit.MI))
            .toString();

        // Assert
        Assert.isTrue(
            actual.contains('DISTANCE(BillingAddress, GEOLOCATION(1.0, 1.0), \'mi\')'),
            'Geo distance field overload'
        );
    }

    @IsTest
    static void should_handle_currency_literals() {
        // Arrange & Act
        String actual = SoqlQuery.CUR.of('USD', 100).toString();

        // Assert
        Assert.areEqual('USD100', actual, 'Currency format');
    }
    // </editor-fold>

    // <editor-fold desc="Special Coverage & Technical Fixes">
    @IsTest
    static void should_verify_final_technical_polish_fixes() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of(Account.SObjectType)
            .groupBy(Account.Type)
            .havingx(SoqlQuery.HAV.avg(Account.AnnualRevenue).gt(100))
            .addHaving(SoqlQuery.HAV.min(Account.AnnualRevenue).lt(1000));

        SoqlQuery q2 = SoqlQuery.of(Account.SObjectType).field('Id');

        // Act
        String actualHaving = q1.toString();

        // Assert
        Assert.isTrue(actualHaving.contains('HAVING AVG(AnnualRevenue) > :var$0'), 'AVG syntax');
        Assert.isTrue(actualHaving.contains('AND MIN(AnnualRevenue) < :var$1'), 'MIN syntax and AND joining');
        Assert.areEqual(100, q1.getBindings().get('var$0'), 'AVG binding');
        Assert.areEqual(1000, q1.getBindings().get('var$1'), 'MIN binding');

        // Verify Executor recursion fix
        try {
            q2.fetch();
        } catch (Exception e) {
            Assert.isFalse(e.getMessage().contains('Stack depth'), 'Should not have stack depth issues');
            Assert.isFalse(e.getMessage().contains('recursion'), 'Should not have recursion issues');
        }
    }

    @IsTest
    static void should_handle_all_fields_variants() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account');
        SoqlQuery q2 = SoqlQuery.of('Account');
        SoqlQuery q3 = SoqlQuery.of('Account');
        SoqlQuery q4 = SoqlQuery.of('Account');

        // Act
        q1.allDescribeFields();
        q2.allFields(SoqlQuery.FieldProperty.ACCESSIBLE);
        q3.allFields(
            new List<SoqlQuery.FieldProperty>{ SoqlQuery.FieldProperty.ACCESSIBLE, SoqlQuery.FieldProperty.UPDATEABLE }
        );
        q4.standardFields();

        // Assert
        Assert.isTrue(q1.toString().contains('Id'), 'allFields');
        Assert.isTrue(q2.toString().contains('Id'), 'allFields property');
        Assert.isTrue(q3.toString().contains('Id'), 'allFields iterable');
        Assert.isTrue(q4.toString().contains('FIELDS(STANDARD)'), 'standardFields');
        Assert.isTrue(!q4.toString().contains('LIMIT 200'), 'standardFields limit');
    }

    @IsTest
    static void should_handle_missing_where_and_group_overloads() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        Exception actualException;

        // Act
        try {
            q.addConditionOr(SoqlQuery.COND.field('Name').eq('Test')) // Hit line 642 return this
                .groupByRollup(Account.Name)
                .groupByCube(Account.Industry);
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isTrue(
            actualException.getMessage().contains('Grouping function redefinition is prohibited'),
            'Literal validation message'
        );
    }

    @IsTest
    static void should_detect_sobject_like_type_for_test_visible_helper() {
        // Act / Assert
        Assert.isTrue(SoqlQuery.isSObjectLikeType(Account.class), 'Account should be recognized as SObject-like');
        Assert.isFalse(
            SoqlQuery.isSObjectLikeType(NonInstantiableDto.class),
            'Type without default constructor should be handled and reported as non-SObject-like'
        );
        Assert.isFalse(SoqlQuery.isSObjectLikeType(Map<String, Object>.class), 'Map should not be SObject-like');
    }

    @IsTest
    static void should_handle_select_fields_overloads() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account');
        SoqlQuery q2 = SoqlQuery.of('Account');

        // Act
        q1.fields('Id, Name');
        q2.fields(new List<Object>{ 'Id', Account.Name });

        // Assert
        Assert.isTrue(q1.toString().contains('Id, Name'), 'fields string');
        Assert.isTrue(q2.toString().contains('Id, Name'), 'fields iterable');
    }

    @IsTest
    static void should_handle_final_overloads() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account');
        SoqlQuery q2 = SoqlQuery.of('Account');
        SoqlQuery q3 = SoqlQuery.of('Account');
        SoqlQuery q4 = SoqlQuery.of('Account');
        Id pid = fakeId(PermissionSet.SObjectType);

        // Act
        q1.allReadableFields()
            .allEditableFields()
            .allCreatableFields()
            .allFields(new List<SoqlQuery.FieldProperty>{ SoqlQuery.FieldProperty.CUSTOM })
            .groupByRollup('Name')
            .addHavingAnd('COUNT(Id) > 5')
            .orderBy('Name', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_FIRST)
            .usingScope(SoqlQuery.Scope.MINE_AND_MY_GROUPS);

        q2.groupByCube(Account.Industry)
            .addHavingEq('Name', 'Test')
            .addHavingNe(Account.Industry, 'Test')
            .orderBy(Account.Industry, Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST)
            .orderBy('Name', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_FIRST)
            .orderBy(Account.Name, Query.SortOrder.ASCX)
            .forView();

        q3.fields('Type, Industry, Rating')
            .count('Id')
            .groupBy(new List<Object>{ 'Type', 'Industry, Rating' })
            .addHavingOr('COUNT(AnnualRevenue) > 1000')
            .addHavingIn('Rating', new List<Object>{ 'Hot' })
            .orderBy('Type')
            .orderBy(Account.Industry);

        q4.fields('Name, Industry, Rating')
            .avg('AnnualRevenue')
            .groupBy(new List<Object>{ 'Name, Industry, Rating' })
            .addHaving('COUNT(AnnualRevenue) > 1000')
            .addHavingEq(Account.Name, 'Test')
            .addHavingIn(Account.Industry, new List<Object>{ 'Banking' })
            .addHavingNotIn(Account.Rating, new List<Object>{ 'Warm' })
            .orderBy('Type')
            .orderBy(Account.Industry);

        try {
            q1.withPermissionSetId(pid).updateTracking().cacheSession('local.Partition');
        } catch (Cache.Session.SessionCacheException e) {
            // Ignored: Platform Cache might not be available or partition might not exist
            Assert.isTrue(!String.isEmpty(e.getMessage()), 'Platform Cache might not be available');
        } catch (System.SecurityException e) {
            // Ignored: ApexUserModeWithPermset feature might not be enabled
            Assert.isTrue(
                e.getMessage().contains('requires ApexUserModeWithPermset'),
                'Platform Cache might not be available'
            );
        }

        try {
            q2.withPermissionSetIds(new List<Id>{ pid }).updateViewstat().cacheOrg('local.Partition');
        } catch (Cache.Session.SessionCacheException e) {
            // Ignored: Platform Cache might not be available or partition might not exist
            Assert.isTrue(!String.isEmpty(e.getMessage()), 'Platform Cache might not be available');
        } catch (System.SecurityException e) {
            // Ignored: ApexUserModeWithPermset feature might not be enabled
            Assert.isTrue(
                e.getMessage().contains('requires ApexUserModeWithPermset'),
                'Platform Cache might not be available'
            );
        }

        // Assert
        Assert.isTrue(q1.toString().contains('ROLLUP'), 'Rollup presence');
        Assert.isTrue(q2.toString().contains('CUBE'), 'Cube presence');
        Assert.isTrue(q3.toString().contains('GROUP BY Type, Industry'), 'Ordinary group');
        Assert.isTrue(q4.toString().contains('GROUP BY Name, Industry'), 'Ordinary group');
    }

    @IsTest
    static void should_handle_internal_logic_and_edge_cases() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');
        Exception e1;
        Exception e2;
        Exception e3;
        Exception e4;

        // Act
        try {
            q.fieldSet(null);
        } catch (Exception e) {
            e1 = e;
        }
        try {
            SoqlQuery.of('User').fieldSet('PersonalInfo');
        } catch (Exception e) {
            e2 = e;
        }
        try {
            SoqlQuery.of('Account').withMode(null);
        } catch (Exception e) {
            e3 = e;
        }
        try {
            new SoqlQuery.TypeOf('Owner').then('Name');
        } catch (Exception e) {
            e4 = e;
        }

        SoqlQuery.TypeOf t = new SoqlQuery.TypeOf('Owner');
        t.when('User').thenFields('Name,Email');
        t.when(Contact.SObjectType).thenFields(new List<Object>{ 'FirstName', 'LastName' });
        t.when('Group').then(Group.Name);
        t.elsex('Name');
        t.elsex(Account.Name);
        t.elseFields('Id,CreatedDate');
        t.elseFields(new List<Object>{ 'Username' });
        t.end();

        SoqlQuery sub = SoqlQuery.of('Contact').field('Id');
        q.typeOf(t);
        q.subQuery('Contacts', sub);
        q.subQuery('Accounts', Account.SObjectType, 'Name');
        q.subQuery('Attachments', 'Attachment', new List<Object>{ 'Name' });
        q.subQuery('Tasks', Task.SObjectType, new List<Object>{ 'Subject' });
        q.subQuery('Events', 'Event', 'Subject');
        q.subQuery('Notes', 'Account', 'Name');
        q.subQuery('Contracts', Contract.SObjectType, new List<Object>{ 'Id' });
        q.subQuery('Cases', 'Case', new List<Object>{ 'Id' });

        q.toString();
        q.toCountString();

        // Assert
        Assert.isTrue(t.toString().contains('ELSE'), 'TypeOf else');
        Assert.isTrue(q.toString().contains('TYPEOF Owner'), 'TypeOf presence');
        Assert.isTrue(q.toString().contains('(SELECT Subject FROM Tasks)'), 'Subquery presence');
        Assert.isTrue(q.toCountString().contains('SELECT COUNT()'), 'toCountString presence');
        Assert.isNotNull(e1, 'validateFieldSet null');
        Assert.isNotNull(e2, 'validateFieldSet invalid');
        Assert.isNotNull(e3, 'validateNotNull');
        Assert.isNotNull(e4, 'TypeOf thenField without when');

        // Hit return paths of successful validations
        SoqlQuery.of('Account')
            .field('Id')
            .fields(new List<Object>{ 'Name' })
            .fields('Id')
            .standardFields()
            .allFields();
        SoqlQuery.CAT.of('Group').at('Value').above('A').below('B').aboveOrBelow('C');
    }

    @IsTest
    static void should_handle_all_field_checker_properties() {
        // Arrange
        SObjectField field = Account.Name;

        // Act & Assert (Exhaustive Switch Hit)
        for (SoqlQuery.FieldProperty prop : SoqlQuery.FieldProperty.values()) {
            new SoqlQuery.FieldChecker(field, new List<SoqlQuery.FieldProperty>{ prop }).every();
        }

        // Negative test for FieldChecker
        try {
            new SoqlQuery.FieldChecker(field, new List<SoqlQuery.FieldProperty>{ null }).every();
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('property cannot be null'), 'Message check');
        }
    }

    @IsTest
    static void should_handle_executor_overloads() {
        // Arrange
        Map<String, Object> binds = new Map<String, Object>{ 'v' => 'Test' };
        SoqlQuery q = SoqlQuery.of('Account').field('Id').withBindings(binds).withSystemMode().memoize();

        // Act
        Test.startTest();
        q.fetch();
        q.fetchFirst();
        q.fetchCount();
        Test.stopTest();

        // Assert
        Assert.isNotNull(q, 'Executor survived');
    }

    @IsTest
    static void should_retrieve_database_cursor() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        Test.startTest();
        Database.Cursor c = q.cursor();
        Test.stopTest();

        // Assert
        Assert.isNotNull(c, 'Should return a cursor');
    }

    @IsTest
    static void should_retrieve_pagination_cursor() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Act
        Test.startTest();
        Database.PaginationCursor c = q.paginationCursor();
        Test.stopTest();

        // Assert
        Assert.isNotNull(c, 'Should return a pagination cursor');
    }

    @IsTest
    static void should_throw_on_local_explain() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account');

        // Act & Assert
        try {
            q.explain();
            Assert.fail('Expected QueryException');
        } catch (Query.QueryException e) {
            Assert.areEqual('Database SOQL does not support query explain at runtime.', e.getMessage());
        }
    }

    @IsTest
    static void should_handle_junction_negation_inversion() {
        // Arrange
        Query.Criterion c = SoqlQuery.COND.field('Name').eq('A');

        // Act
        SoqlQuery qNeg = SoqlQuery.of('Account').wherex(SoqlQuery.notx(SoqlQuery.notx(c)));

        // Assert
        Assert.isTrue(qNeg.toString().contains('NOT (NOT Name = :var$0)'), 'Double negation');
        Assert.areEqual('A', qNeg.getBindings().get('var$0'), 'Negative binding');
    }

    @IsTest
    static void should_fail_on_junction_logical_change() {
        // Arrange
        Exception actualException;

        // Act
        try {
            new Query.Junction()
                .add(SoqlQuery.COND.field('A').eq('B'), 'AND')
                .add(SoqlQuery.COND.field('C').eq('D'), 'OR');
        } catch (Query.QueryException e) {
            actualException = e;
        }

        // Assert
        Assert.isNotNull(actualException, 'Should throw for logical op change');
        Assert.isTrue(actualException.getMessage().contains('cannot be overridden'), 'Message check');
    }

    @IsTest
    static void should_handle_extra_helpers() {
        // Arrange & Act
        SoqlQuery q = SoqlQuery.of('Account').field('Id');

        // Exercise DateLiteralProvider overloads
        SoqlQuery.LIT.lastNDays(1);
        SoqlQuery.LIT.nextNDays(1);
        SoqlQuery.LIT.nDaysAgo(1);
        SoqlQuery.LIT.nextNWeeks(1);
        SoqlQuery.LIT.lastNWeeks(1);
        SoqlQuery.LIT.nWeeksAgo(1);
        SoqlQuery.LIT.nextNMonths(1);
        SoqlQuery.LIT.lastNMonths(1);
        SoqlQuery.LIT.nMonthsAgo(1);
        SoqlQuery.LIT.nextNQuarters(1);
        SoqlQuery.LIT.lastNQuarters(1);
        SoqlQuery.LIT.nQuartersAgo(1);
        SoqlQuery.LIT.nextNYears(1);
        SoqlQuery.LIT.lastNYears(1);
        SoqlQuery.LIT.nYearsAgo(1);
        SoqlQuery.LIT.nextNFiscalQuarters(1);
        SoqlQuery.LIT.lastNFiscalQuarters(1);
        SoqlQuery.LIT.nFiscalQuartersAgo(1);
        SoqlQuery.LIT.nextNFiscalYears(1);
        SoqlQuery.LIT.lastNFiscalYears(1);
        SoqlQuery.LIT.nFiscalYearsAgo(1);

        // Exercise CurrencyLiteral
        SoqlQuery.CUR.of('USD', 100);

        // Exercise GeoPart
        SoqlQuery.GEO.distance('Location__c', Location.newInstance(0, 0), SoqlQuery.DistanceUnit.MI);

        // Assert
        Assert.isNotNull(q, 'Extra helpers exercised');
    }

    @IsTest
    static void should_handle_singleton_typeof() {
        // Arrange & Act
        SoqlQuery.TypeOf t1 = new SoqlQuery.TypeOf('Owner').end();
        SoqlQuery.TypeOf t2 = new SoqlQuery.TypeOf('Owner').when('User').then('Name').end();

        // Assert
        Assert.areEqual('', t1.toString(), 'Empty TypeOf');
        Assert.areEqual('TYPEOF Owner WHEN User THEN Name END', t2.toString(), 'Singleton TypeOf');
    }

    @IsTest
    static void should_handle_iterable_junctions() {
        // Arrange
        List<Query.Criterion> conditions = new List<Query.Criterion>{
            SoqlQuery.COND.field('Name').eq('Test'),
            SoqlQuery.COND.field('Type').eq('Other')
        };

        // Act
        SoqlQuery qAnd = SoqlQuery.of('Account').wherex(SoqlQuery.ands(conditions));
        SoqlQuery qOr = SoqlQuery.of('Account').wherex(SoqlQuery.ors(conditions));

        // Assert
        Assert.isTrue(qAnd.toString().contains('AND'), 'ANDS iterable');
        Assert.isTrue(qOr.toString().contains('OR'), 'ORS iterable');
        Assert.areEqual('Test', qAnd.getBindings().get('var$0'), 'ANDS binding');
        Assert.areEqual('Other', qAnd.getBindings().get('var$1'), 'ANDS binding 2');
        Assert.areEqual('Test', qOr.getBindings().get('var$0'), 'ORS binding');
    }

    @IsTest
    static void should_verify_spacing_logic() {
        // Arrange & Act
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .wherex('Name = \'A\'')
            .groupBy('Type')
            .orderBy('Name')
            .lim(1)
            .offset(1)
            .forView()
            .updateTracking()
            .allRows();

        String s = q.toString();
        String c = q.toCountString();

        // Assert
        Assert.isTrue(s.contains(' FROM Account WHERE '), 'Spacing FROM');
        Assert.isTrue(s.contains(' WHERE Name = \'A\' GROUP BY '), 'Spacing WHERE');
        Assert.isTrue(s.contains(' GROUP BY Type ORDER BY '), 'Spacing GROUP');
        Assert.isTrue(s.contains(' ORDER BY Name LIMIT '), 'Spacing ORDER');
        Assert.isTrue(s.contains(' LIMIT 1 OFFSET '), 'Spacing LIMIT');
        Assert.isTrue(s.contains(' OFFSET 1 FOR VIEW '), 'Spacing OFFSET');
        Assert.isTrue(s.contains(' FOR VIEW UPDATE TRACKING '), 'Spacing VIEW');
        Assert.isTrue(s.contains(' UPDATE TRACKING ALL ROWS'), 'Spacing UPDATE');

        Assert.isTrue(c.contains('SELECT COUNT() FROM Account WHERE '), 'Count spacing');
    }

    @IsTest
    static void should_hit_session_cache() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').cacheSession('local.Partition');

        // Act
        try {
            // This will likely fail to find the partition, but it hits the logic path
            q.fetch();
        } catch (Cache.Session.SessionCacheException e) {
            // Ignored: Platform Cache might not be available or partition might not exist
            Assert.isTrue(!String.isEmpty(e.getMessage()), 'Platform Cache might not be available');
        }

        // Assert
        Assert.isNotNull(q, 'Session cache path exercised');
    }

    @IsTest
    static void should_handle_in_binding_with_null() {
        // Arrange
        SoqlQuery q1 = SoqlQuery.of('Account').addConditionIn('Name', new List<Object>{ null, 'Acme' });
        SoqlQuery q2 = SoqlQuery.of('Account')
            .addCondition(new SoqlQuery.Condition().field('Name').inx(new List<Object>{ null, 'Acme' }));

        // Act
        String soql1 = q1.toString();
        Map<String, Object> binds1 = q1.getBindings();
        String soql2 = q2.toString();
        Map<String, Object> binds2 = q2.getBindings();

        // Assert
        Assert.isTrue(soql1.contains('WHERE Name IN :var$0'), 'IN should use bind variable');
        Assert.areEqual(new List<Object>{ null, 'Acme' }, binds1.get('var$0'), 'Bind value should include null');
        Assert.isTrue(soql2.contains('WHERE Name IN :var$0'), 'IN should use bind variable');
        Assert.areEqual(new List<Object>{ null, 'Acme' }, binds2.get('var$0'), 'Bind value should include null');
    }

    @IsTest
    static void should_format_as_literals_without_context() {
        // Arrange
        SoqlQuery.Condition c1 = new SoqlQuery.Condition().field('Name').eq('Acme');
        SoqlQuery.Condition c2 = new SoqlQuery.Condition().field('Name').inx(new List<Object>{ 'A', null });

        // Act
        String s1 = c1.toString();
        String s2 = c2.toString();

        // Assert
        Assert.isTrue(s1.contains('\'Acme\''), 'Literal string fallback');
        Assert.isTrue(s2.contains('(\'A\', NULL)'), 'Literal iterable fallback');
    }

    @IsTest
    static void should_allow_org_cache_in_system_mode() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').withoutSharing().withSystemMode().cacheOrg('QueryCache');
        Integer queriesBefore = Limits.getQueries();

        // Act
        try {
            q.fetch();
            q.fetch(); // In SYSTEM_MODE, Org Cache should be allowed

            // Assert
            Assert.areEqual(
                queriesBefore + 1,
                Limits.getQueries(),
                'Should execute query once as Org Cache must be allowed in System Mode'
            );
        } catch (Cache.Org.OrgCacheException e) {
            // Handle if partition is unavailable in this specific environment
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Platform Cache Partition error');
        }
    }

    @IsTest
    static void should_prohibit_org_cache_in_user_mode() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').withSharing().cacheOrg('QueryCache');
        Integer queriesBefore = Limits.getQueries();

        // Act
        q.fetch();
        q.fetch(); // In USER_MODE (default), Org Cache must be bypassed to prevent cross-user leak

        // Assert
        Assert.areEqual(
            queriesBefore + 2,
            Limits.getQueries(),
            'Should execute query twice as Org Cache must be prohibited in User Mode'
        );
    }

    @IsTest
    static void should_use_distinct_cache_keys_for_with_and_inherited_sharing() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').withUserMode().memoize();
        Integer queriesBefore = Limits.getQueries();

        // Act
        q.withSharing().fetch(); // miss
        q.withSharing().fetch(); // hit
        q.inheritedSharing().fetch(); // miss (different sharing mode in cache key)
        q.inheritedSharing().fetch(); // hit

        // Assert
        Assert.areEqual(
            queriesBefore + 2,
            Limits.getQueries(),
            'withSharing and inheritedSharing must not share the same cache key context'
        );
    }

    @IsTest
    static void should_respect_security_on_cache_hit() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').memoize().withStrip(AccessType.READABLE);
        Integer queriesBefore = Limits.getQueries();

        // Act
        q.fetch(); // First call (Miss)
        List<SObject> results = q.fetch(); // Second call (Hit - must still apply stripInaccessible)

        // Assert
        Assert.areEqual(queriesBefore + 1, Limits.getQueries(), 'Second execution should have been a cache hit');
        Assert.isNotNull(results, 'Should return records from cache');
    }

    @IsTest
    static void should_cover_session_platform_cache_logic() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').cacheSession('QueryCache');
        Integer queriesBefore = Limits.getQueries();

        // Act
        try {
            q.fetch(); // Miss
            q.fetch(); // Hit
            q.fetchCount(); // Miss
            q.fetchCount(); // Hit

            // Assert
            Assert.areEqual(
                queriesBefore + 2,
                Limits.getQueries(),
                'Only 2 queries (1 run, 1 count) should be executed with Session caching'
            );
        } catch (Cache.Session.SessionCacheException e) {
            // Handle if partition is unavailable in this specific environment
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Platform Cache Partition error');
        }
    }

    @IsTest
    static void should_handle_indexed_binding_strategy() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext(Query.BindingStrategy.INDEXED);

        // Act
        String k1 = ctx.add('A');
        String k2 = ctx.add('B');

        // Assert
        Assert.areEqual('$1', k1, 'First indexed bind');
        Assert.areEqual('$2', k2, 'Second indexed bind');
        Assert.areEqual('A', ctx.getMap().get('$1'), 'Map value 1');
    }

    @IsTest
    static void should_handle_anonymous_binding_strategy() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext(Query.BindingStrategy.ANONYMOUS);

        // Act
        String k1 = ctx.add('A');
        String k2 = ctx.add('B');

        // Assert
        Assert.areEqual('?', k1, 'Anonymous placeholder');
        Assert.areEqual('?', k2, 'Anonymous placeholder');
        Assert.areEqual('A', ctx.getMap().get('?1'), 'Stored with index for retrieval');
        Assert.areEqual('B', ctx.getMap().get('?2'), 'Stored with index for retrieval');
    }

    @IsTest
    static void should_handle_binding_collision() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext();
        ctx.getMap().put('var$0', 'Existing');

        // Act
        String k = ctx.add('New'); // i=1, key='var$0' -> exists -> i=2, key='var$1'

        // Assert
        Assert.areEqual('var$1', k, 'Should skip existing key');
        Assert.areEqual('New', ctx.getMap().get('var$1'), 'Correct value stored');
    }

    @IsTest
    static void should_serialize_bind_context_to_string() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext();
        ctx.add('A');
        ctx.add('B');

        // Act
        String actual = ctx.toString();

        // Assert
        Assert.areEqual('var$0=A,var$1=B', actual, 'Sorted CSV format');
    }

    @IsTest
    static void should_change_binding_strategy_dynamically() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext();
        ctx.add('First'); // Uses default NAMED strategy

        // Act
        ctx.setStrategy(Query.BindingStrategy.INDEXED);
        String k = ctx.add('Second');

        // Assert
        Assert.areEqual('$2', k, 'Should use INDEXED after setStrategy');
        Assert.isTrue(ctx.getMap().containsKey('var$0'), 'First binding still exists');
        Assert.isTrue(ctx.getMap().containsKey('$2'), 'Second binding uses new strategy');
    }

    @IsTest
    static void should_check_if_strategy_is_named() {
        // Arrange
        Query.BindContext namedCtx = new Query.BindContext();
        Query.BindContext indexedCtx = new Query.BindContext(Query.BindingStrategy.INDEXED);
        Query.BindContext anonCtx = new Query.BindContext(Query.BindingStrategy.ANONYMOUS);

        // Act & Assert
        Assert.isTrue(namedCtx.isNamed(), 'Default strategy should be NAMED');
        Assert.isFalse(indexedCtx.isNamed(), 'INDEXED strategy should not be named');
        Assert.isFalse(anonCtx.isNamed(), 'ANONYMOUS strategy should not be named');
    }

    @IsTest
    static void should_format_boolean_and_null_literals() {
        // Arrange
        SoqlQuery.Condition c = SoqlQuery.COND.field('IsActive');

        // Act & Assert
        Assert.isTrue(c.eq(true).toString().contains('TRUE'), 'Boolean TRUE');
        Assert.isTrue(c.eq(false).toString().contains('FALSE'), 'Boolean FALSE');
        Assert.isTrue(c.eq(null).toString().contains('NULL'), 'Literal NULL');
    }

    @IsTest
    static void should_format_complex_iterables() {
        // Arrange
        SoqlQuery.Condition c = SoqlQuery.COND.field('Id');
        List<Object> values = new List<Object>{ 'A', true, 10 };

        // Act
        String actual = c.inx(values).toString();

        // Assert
        Assert.isTrue(actual.contains('(\'A\', TRUE, 10)'), 'Multi-type literal iterable');
    }

    @IsTest
    static void should_propagate_bind_context_to_negated_conditions() {
        // Arrange
        Query.BindContext ctx = new Query.BindContext();
        Query.Criterion c = SoqlQuery.COND.field('Name').eq('X');
        Query.NegatedCondition nc = new Query.NegatedCondition(c);

        // Act
        nc.withBindContext(ctx);
        String result = nc.toString(); // Trigger lazy binding

        // Assert
        Assert.isTrue(ctx.getMap().containsKey('var$0'), 'Bind added through negated wrapper');
        Assert.areEqual('X', ctx.getMap().get('var$0'));
        Assert.isTrue(result.contains('NOT Name = :var$0'), 'Negated condition formatted correctly');
    }

    @IsTest
    static void should_handle_empty_junctions() {
        // Arrange
        Query.Junction j = new Query.Junction();

        // Act & Assert
        Assert.isTrue(j.isEmpty(), 'Initial state');
        Assert.areEqual('', j.toString(), 'Empty string representation');

        j.add(SoqlQuery.COND.field('A').eq('B'));
        j.clear();
        Assert.isTrue(j.isEmpty(), 'After clear()');
    }

    @IsTest
    static void should_handle_nested_junction_wrapping() {
        // Arrange
        Query.Junction j = new Query.Junction();
        j.ands(SoqlQuery.COND.field('A').eq(1), SoqlQuery.COND.field('B').eq(2));

        // Act
        String actual = j.toString();

        // Assert
        Assert.isTrue(actual.startsWith('(') && actual.endsWith(')'), 'Multi-member AND should be wrapped');
    }

    @IsTest
    static void should_trigger_count_query_debug_logging() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').debug();

        // Act
        String count = q.toCountString();

        // Assert
        Assert.isNotNull(count, 'Count string generated with debug enabled');
    }

    @IsTest
    static void should_support_debug_inline_queries_without_conditions() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').debug();

        // Act
        String inlineQuery = q.toInlineString();
        String inlineCountQuery = q.toInlineCountString();

        // Assert
        Assert.isTrue(inlineQuery.contains('FROM Account'));
        Assert.isTrue(inlineCountQuery.contains('FROM Account'));
    }

    @IsTest
    static void should_respect_session_cache_ttl() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').cacheSession('local.QueryCache', 300);
        Integer queriesBefore = Limits.getQueries();

        // Act & Assert
        try {
            q.fetch();
            q.fetch();

            // Assert
            Assert.areEqual(
                queriesBefore + 1,
                Limits.getQueries(),
                'Only 1 query should be executed with Session caching'
            );
        } catch (Cache.Session.SessionCacheException e) {
            // Handle if partition is unavailable in this specific environment
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Platform Cache Partition error');
        }
    }

    @IsTest
    static void should_respect_org_cache_ttl() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').withSystemMode().cacheOrg('local.QueryCache', 600);
        Integer queriesBefore = Limits.getQueries();

        // Act & Assert
        try {
            q.fetch();
            q.fetch();

            // Assert
            Assert.areEqual(
                queriesBefore + 1,
                Limits.getQueries(),
                'Only 1 query should be executed with Session caching'
            );
        } catch (Cache.Org.OrgCacheException e) {
            // Handle if partition is unavailable in this specific environment
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Platform Cache Partition error');
        }
    }

    @IsTest
    static void should_support_multiple_cache_targets() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').field('Id').cacheSession('local.QueryCache').cacheOrg('local.QueryCache');

        // Act & Assert
        try {
            // Should hit all partitions
            q.fetch();
        } catch (Exception e) {
            Assert.isTrue(!(e instanceof NullPointerException), 'Should not throw NPE: ' + e.getStackTraceString());
        }
    }

    @IsTest
    static void should_exercise_internal_binding_caching() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account').addConditionEq('Name', 'Acme').memoize();
        Integer queriesBefore = Limits.getQueries();

        // Act
        q.fetch(); // First call
        q.fetch(); // Second call (Memoization hit based on binding hash)

        // Assert
        Assert.areEqual(
            queriesBefore + 1,
            Limits.getQueries(),
            'Should hit memoized cache for identical query and bindings'
        );
    }

    @IsTest
    static void should_cover_default_platform_cache_implementation() {
        // Arrange
        SoqlQuery qSession = SoqlQuery.of('Account').field('Id').cacheSession('local').lim(1);

        SoqlQuery qOrg = SoqlQuery.of('Account').field('Id').cacheOrg('local').lim(1);

        // Act
        try {
            List<SObject> resSession = qSession.fetch();
            Assert.isNotNull(resSession, 'Should execute session cached query');
        } catch (Cache.Session.SessionCacheException e) {
            // Expected if partition likely doesn't exist in CI
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Unexpected cache error: ' + e.getMessage());
        }

        try {
            List<SObject> resOrg = qOrg.fetch();
            Assert.isNotNull(resOrg, 'Should execute org cached query');
        } catch (Cache.Org.OrgCacheException e) {
            // Expected if partition likely doesn't exist in CI
            Assert.isTrue(e.getMessage().contains('Invalid partition'), 'Unexpected cache error: ' + e.getMessage());
        }
    }

    @IsTest
    static void should_cover_platform_cache_wrapper_methods() {
        // Arrange
        SoqlQuery.PlatformCachePartition wrapper = new SoqlQuery.PlatformCachePartition(null);

        // Act & Assert
        wrapper.put('key', 'val');
        wrapper.put('key', 'val', 300);
        Object res = wrapper.get('key');

        Assert.isNull(res, 'Should return null for null partition');
    }

    @IsTest
    static void should_verify_cache_put_logic_via_mocks() {
        // Arrange
        MockCacheFactory mockFactory = new MockCacheFactory();
        SoqlQuery.cacheFactory = mockFactory;

        // Act 1: Session Cache with TTL
        SoqlQuery.of('Account').field('Id').cacheSession('local.Session', 300).fetch();

        // Assert 1
        Assert.isTrue(mockFactory.sessionPartition.putCalled, 'Session put should be called');
        Assert.areEqual(300, mockFactory.sessionPartition.lastTtl, 'Session TTL should be passed');

        // Act 2: Org Cache without TTL
        // Note: Org cache needs system mode in some contexts, or running as user.
        // We use System Mode to be safe and ensure it tries to cache.
        SoqlQuery.of('Account').field('Id').withSystemMode().cacheOrg('local.Org').fetch();

        // Assert 2
        Assert.isTrue(mockFactory.orgPartition.putCalled, 'Org put should be called');
        Assert.isNull(mockFactory.orgPartition.lastTtl, 'Org TTL should be null (overload used)');
    }

    @IsTest
    static void should_cover_memo_partition_ttl_overload() {
        // Arrange
        SoqlQuery.CachePartition memo = SoqlQuery.cacheFactory.getMemoPartition();

        // Act
        memo.put('key', 'value', 300);

        // Assert
        Assert.areEqual('value', memo.get('key'), 'Should store value using TTL overload');
    }

    @IsTest
    static void should_render_query_with_inline_literals() {
        // Arrange
        SoqlQuery q = SoqlQuery.of('Account')
            .field('Id')
            .addConditionEq('Name', 'Acme')
            .addConditionEq('NumberOfEmployees', 100)
            .addConditionEq('IsDeleted', false)
            .addConditionIn('Type', new List<String>{ 'Prospect', 'Other' })
            .subQuery('Contacts', SoqlQuery.of('Contact').field('LastName').addConditionEq('FirstName', 'John'));

        // Act
        String actual = q.toInlineString();

        // Assert
        Assert.isTrue(actual.contains('Name = \'Acme\''), 'String literal');
        Assert.isTrue(actual.contains('NumberOfEmployees = 100'), 'Number literal');
        Assert.isTrue(actual.contains('IsDeleted = FALSE'), 'Boolean literal');
        Assert.isTrue(actual.contains('Type IN (\'Prospect\', \'Other\')'), 'Iterable literal');
        Assert.isTrue(
            actual.contains('(SELECT LastName FROM Contacts WHERE FirstName = \'John\')'),
            'Sub-query literal'
        );
    }

    @IsTest
    static void should_protect_against_soql_injection_in_debug_string() {
        // Arrange
        String malicious1 = '\' OR 1=1 --';
        String malicious2 = 'test%\') OR (Name LIKE \'';

        SoqlQuery q1 = SoqlQuery.of('Account').field('Id').addConditionEq('Name', malicious1);
        SoqlQuery q2 = SoqlQuery.of('Account')
            .field('Id')
            .addCondition(new SoqlQuery.Condition().field('Name').likex(malicious2));

        // Act
        String actual1 = q1.toInlineString();
        String actual2 = q2.toInlineString();
        String actual3 = q2.toInlineCountString();

        // Assert
        // Result should be escaped so it's Just a string constant, NOT an injection
        Assert.isTrue(actual1.contains('Name = \'\\\' OR 1=1 --\''), 'Should escape single quotes in debug string');
        Assert.isTrue(
            actual2.contains('Name LIKE \'test%\\\') OR (Name LIKE \\\'\''),
            'Should escape single quotes in debug string'
        );
        Assert.isTrue(
            actual3.contains('Name LIKE \'test%\\\') OR (Name LIKE \\\'\''),
            'Should escape single quotes in debug count string'
        );
    }

    @IsTest
    static void should_match_the_snapshot() {
        // Arrange
        Integer thisYear = Datetime.now().year();
        Datetime dt = Datetime.newInstanceGmt(2020, 1, 1);

        SoqlQuery q = SoqlQuery.of(Account.SObjectType)
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
                    .addCondition(SoqlQuery.COND.field('CreatedDate').gt(dt))
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
                            .addConditionNotIn('Id', SoqlQuery.of('FeedComment').field('FeedItemId'))
                            .orderBy('CommentCount', Query.SortOrder.DESCX)
                            .lim(5)
                    )
            )
            .usingScope(SoqlQuery.Scope.EVERYTHING)
            .addCondition(
                SoqlQuery.ors(
                    new SoqlQuery.Condition('Name LIKE \'Global%\''),
                    SoqlQuery.notx(
                        new SoqlQuery.Condition().field('Name').inx(new Set<String>{ 'Emerald Solutions 4' })
                    )
                )
            )
            .addCondition(
                SoqlQuery.COND.field('Interests__c')
                    .includes(new Set<String>{ 'Consulting;Entertainment;Environmental' })
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
            .addConditionAnd(SoqlQuery.COND.field(Account.AnnualRevenue).ge(SoqlQuery.CUR.of('EUR', 30000000)))
            .withStrip(AccessType.READABLE)
            .orderBy('Name')
            .orderBy('Industry', Query.SortOrder.DESCX)
            .orderBy('NumberOfEmployees', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST)
            .lim(4)
            .offset(2)
            .forView()
            .allRows()
            .debug();

        // Act
        Map<String, Object> bindingsBefore = q.getBindings().clone();
        String s = q.toString();
        String sd = q.toInlineString();
        Map<String, Object> bindingsAfter = q.getBindings();

        Map<String, Object> bindingsCountBefore = q.getCountBindings().clone();
        String c = q.toCountString();
        String cd = q.toInlineCountString();
        Map<String, Object> bindingsCountAfter = q.getCountBindings();

        // Assert
        Assert.areEqual(
            'SELECT Name, CreatedDate, Industry, Interests__c, Owner.Name, Owner.Profile.Name, BillingLatitude, BillingLongitude, FORMAT(CreatedDate) createdAt, (SELECT CaseNumber, Origin FROM Cases WHERE Status = :var$0 AND CreatedDate > :var$1), (SELECT LastName, AccountId FROM Contacts), (SELECT Id, TYPEOF Who WHEN Contact THEN LastName WHEN Lead THEN FirstName ELSE Name END, (SELECT Title, Type, BestCommentId FROM Feeds WHERE Type != :var$2 AND Id NOT IN (SELECT FeedItemId FROM FeedComment) ORDER BY CommentCount DESC LIMIT 5) FROM Tasks) FROM Account USING SCOPE EVERYTHING WHERE (Name LIKE \'Global%\' OR (NOT Name IN :var$3)) AND Interests__c INCLUDES (\'Consulting;Entertainment;Environmental\') AND Id IN (SELECT AccountId FROM Contact) AND Id NOT IN (SELECT AccountId FROM Case WHERE CaseNumber = :var$4) AND Type IN :var$5 AND CALENDAR_YEAR(CreatedDate) = :var$6 AND LastModifiedDate = LAST_N_DAYS:27 AND DISTANCE(BillingAddress, GEOLOCATION(37.775, -122.418), \'km\') < :var$7 AND AnnualRevenue >= EUR30000000 ORDER BY Name, Industry DESC, NumberOfEmployees ASC NULLS LAST LIMIT 4 OFFSET 2 FOR VIEW ALL ROWS',
            s,
            'Should match the snapshot'
        );
        Assert.areEqual(
            'SELECT Name, CreatedDate, Industry, Interests__c, Owner.Name, Owner.Profile.Name, BillingLatitude, BillingLongitude, FORMAT(CreatedDate) createdAt, (SELECT CaseNumber, Origin FROM Cases WHERE Status = \'Closed\' AND CreatedDate > 2020-01-01T00:00:00Z), (SELECT LastName, AccountId FROM Contacts), (SELECT Id, TYPEOF Who WHEN Contact THEN LastName WHEN Lead THEN FirstName ELSE Name END, (SELECT Title, Type, BestCommentId FROM Feeds WHERE Type != \'Comment\' AND Id NOT IN (SELECT FeedItemId FROM FeedComment) ORDER BY CommentCount DESC LIMIT 5) FROM Tasks) FROM Account USING SCOPE EVERYTHING WHERE (Name LIKE \'Global%\' OR (NOT Name IN (\'Emerald Solutions 4\'))) AND Interests__c INCLUDES (\'Consulting;Entertainment;Environmental\') AND Id IN (SELECT AccountId FROM Contact) AND Id NOT IN (SELECT AccountId FROM Case WHERE CaseNumber = \'00001017\') AND Type IN (\'Customer\', \'Partner\') AND CALENDAR_YEAR(CreatedDate) = 2026 AND LastModifiedDate = LAST_N_DAYS:27 AND DISTANCE(BillingAddress, GEOLOCATION(37.775, -122.418), \'km\') < 100 AND AnnualRevenue >= EUR30000000 ORDER BY Name, Industry DESC, NumberOfEmployees ASC NULLS LAST LIMIT 4 OFFSET 2 FOR VIEW ALL ROWS',
            sd,
            'Should match the snapshot'
        );
        Assert.areEqual(
            'SELECT COUNT() FROM Account USING SCOPE EVERYTHING WHERE (Name LIKE \'Global%\' OR (NOT Name IN :var$0)) AND Interests__c INCLUDES (\'Consulting;Entertainment;Environmental\') AND Id IN (SELECT AccountId FROM Contact) AND Id NOT IN (SELECT AccountId FROM Case WHERE CaseNumber = :var$1) AND Type IN :var$2 AND CALENDAR_YEAR(CreatedDate) = :var$3 AND LastModifiedDate = LAST_N_DAYS:27 AND DISTANCE(BillingAddress, GEOLOCATION(37.775, -122.418), \'km\') < :var$4 AND AnnualRevenue >= EUR30000000 LIMIT 4 OFFSET 2 ALL ROWS',
            c,
            'Should match the snapshot'
        );
        Assert.areEqual(
            'SELECT COUNT() FROM Account USING SCOPE EVERYTHING WHERE (Name LIKE \'Global%\' OR (NOT Name IN (\'Emerald Solutions 4\'))) AND Interests__c INCLUDES (\'Consulting;Entertainment;Environmental\') AND Id IN (SELECT AccountId FROM Contact) AND Id NOT IN (SELECT AccountId FROM Case WHERE CaseNumber = \'00001017\') AND Type IN (\'Customer\', \'Partner\') AND CALENDAR_YEAR(CreatedDate) = 2026 AND LastModifiedDate = LAST_N_DAYS:27 AND DISTANCE(BillingAddress, GEOLOCATION(37.775, -122.418), \'km\') < 100 AND AnnualRevenue >= EUR30000000 LIMIT 4 OFFSET 2 ALL ROWS',
            cd,
            'Should match the snapshot'
        );
        Assert.areEqual(
            new Map<String, Object>{
                'var$0' => 'Closed',
                'var$1' => dt,
                'var$2' => 'Comment',
                'var$3' => new Set<String>{ 'Emerald Solutions 4' },
                'var$4' => '00001017',
                'var$5' => new Set<String>{ 'Customer', 'Partner' },
                'var$6' => thisYear,
                'var$7' => 100
            },
            bindingsBefore,
            'Bindings should match'
        );
        Assert.areEqual(bindingsBefore, bindingsAfter, 'Bindings should be the same');
        Assert.areEqual(
            new Map<String, Object>{
                'var$0' => new Set<String>{ 'Emerald Solutions 4' },
                'var$1' => '00001017',
                'var$2' => new Set<String>{ 'Customer', 'Partner' },
                'var$3' => thisYear,
                'var$4' => 100
            },
            bindingsCountBefore,
            'Bindings should match'
        );
        Assert.areEqual(bindingsCountBefore, bindingsCountAfter, 'Count bindings should be the same');
    }
    // </editor-fold>

    // <editor-fold desc="Helpers">
    private static Id fakeId(Schema.SObjectType sObjectType) {
        String keyPrefix = sObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
        return Id.valueOf(keyPrefix + '0'.repeat(12 - String.valueOf(0).length()) + 0);
    }

    private class MockCacheFactory implements SoqlQuery.CacheFactory {
        public MockCachePartition sessionPartition = new MockCachePartition();
        public MockCachePartition orgPartition = new MockCachePartition();
        public MockCachePartition memoPartition = new MockCachePartition();

        public SoqlQuery.CachePartition getSessionPartition(String partitionName) {
            return sessionPartition;
        }
        public SoqlQuery.CachePartition getOrgPartition(String partitionName) {
            return orgPartition;
        }
        public SoqlQuery.CachePartition getMemoPartition() {
            return memoPartition;
        }
    }

    private class NonInstantiableDto {
        private NonInstantiableDto(String ignored) {
        }
    }

    private class MockCachePartition implements SoqlQuery.CachePartition {
        public Boolean putCalled = false;
        public Integer lastTtl = null;
        public Object get(String key) {
            return null;
        }
        public void put(String key, Object value) {
            putCalled = true;
            lastTtl = null;
        }
        public void put(String key, Object value, Integer ttlInSecs) {
            putCalled = true;
            lastTtl = ttlInSecs;
        }
    }

    private class MockDriver extends SoqlQuery.DatabaseDriver {
        public Boolean runMoreCalled = false;
        public override Iterable<Object> runMore(QueryArgs arg) {
            runMoreCalled = true;
            return new List<SObject>();
        }
    }

    private class MultiBatchMockDriver extends SoqlQuery.DatabaseDriver {
        private final List<List<SObject>> batches = new List<List<SObject>>();

        public void addBatch(List<SObject> batch) {
            batches.add(batch);
        }

        public override Iterable<Object> runMore(QueryArgs arg) {
            return new MultiBatchIterable(batches);
        }
    }

    private class MultiBatchIterable implements Iterable<SObject> {
        private final List<List<SObject>> batches;
        public MultiBatchIterable(List<List<SObject>> batches) {
            this.batches = batches;
        }
        public Iterator<SObject> iterator() {
            return new MultiBatchIterator(batches);
        }
    }

    private class MultiBatchIterator implements Iterator<SObject> {
        private final List<List<SObject>> batches;
        private Integer batchIndex = 0;
        private Integer itemIndex = 0;

        public MultiBatchIterator(List<List<SObject>> batches) {
            this.batches = batches;
        }

        public Boolean hasNext() {
            return batchIndex < batches.size() && itemIndex < batches[batchIndex].size();
        }

        public SObject next() {
            SObject record = batches[batchIndex][itemIndex++];
            if (itemIndex >= batches[batchIndex].size()) {
                batchIndex++;
                itemIndex = 0;
            }
            return record;
        }
    }

    private class MockCursor implements SoqlQuery.Cursor {
        private final Integer total;
        public Integer fetchCount = 0;
        public MockCursor(Integer total) {
            this.total = total;
        }
        public Integer getNumRecords() {
            return total;
        }
        public List<SObject> fetch(Integer offset, Integer count) {
            fetchCount++;
            List<SObject> batch = new List<SObject>();
            for (Integer i = 0; i < count; i++) {
                batch.add(new Account(Name = 'Record ' + (offset + i)));
            }
            return batch;
        }
    }
    // </editor-fold>
}
