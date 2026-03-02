@IsTest(IsParallel=true)
private class PostgresSqlQueryTest {
    // <editor-fold desc="DISTINCT ON">
    @IsTest
    static void should_render_distinct_on_with_ordering() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('weather_reports');
        q.distinctOn('location')
            .field('location')
            .field('time')
            .field('report')
            .orderBy('location')
            .orderBy('time', Query.SortOrder.DESCX);

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT DISTINCT ON (location) location, time, report FROM weather_reports ORDER BY location, time DESC',
            sql
        );
    }

    @IsTest
    static void should_wrap_count_query_when_distinct_on_is_used() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('weather_reports');
        q.distinctOn('location')
            .field('location')
            .wherex(new SqlQuery.Condition().field('region').eq('EMEA'))
            .orderBy('location');

        // Act
        String countSql = q.toCountString();
        String inlineCountSql = q.toInlineCountString();
        Map<String, Object> countBinds = q.getCountBindings();

        // Assert
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT DISTINCT ON (location) location FROM weather_reports WHERE region = $1 ORDER BY location) AS count_wrapper',
            countSql
        );
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT DISTINCT ON (location) location FROM weather_reports WHERE region = \'EMEA\' ORDER BY location) AS count_wrapper',
            inlineCountSql
        );
        Assert.areEqual(1, countBinds.size());
        Assert.areEqual('EMEA', countBinds.get('$1'));
    }

    @IsTest
    static void should_throw_exception_when_distinct_on_input_is_invalid() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('t');

        // Act & Assert
        try {
            q.distinctOn((Object) null);
            Assert.fail('Should have thrown QueryException for null expression');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('expression cannot be null'));
        }

        try {
            q.distinctOn(' ');
            Assert.fail('Should have thrown QueryException for blank expression');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('expression cannot be blank'));
        }

        try {
            q.distinctOn((List<Object>) null);
            Assert.fail('Should have thrown QueryException for null expressions');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('expressions cannot be null'));
        }

        try {
            q.distinctOn(new List<Object>());
            Assert.fail('Should have thrown QueryException for empty expressions');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('expressions cannot be empty'));
        }
    }

    @IsTest
    static void should_render_ilike_and_regex_operators_with_bindings() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('users');
        q.wherex(new PostgresSqlQuery.Condition().pgField('name').iLike('%john%'));
        q.addCondition(new PostgresSqlQuery.Condition().pgField('email').notILike('%spam%'));
        q.addCondition(new PostgresSqlQuery.Condition().pgField('name').regex('^J.*'));
        q.addCondition(new PostgresSqlQuery.Condition().pgField('city').iRegex('new.*'));
        q.addCondition(new PostgresSqlQuery.Condition().pgField('role').notRegex('admin|root'));
        q.addCondition(new PostgresSqlQuery.Condition().pgField('team').notIRegex('devops'));

        // Act
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual(
            'SELECT * FROM users WHERE name ILIKE $1 AND email NOT ILIKE $2 AND name ~ $3 AND city ~* $4 AND role !~ $5 AND team !~* $6',
            sql
        );
        Assert.areEqual('%john%', binds.get('$1'));
        Assert.areEqual('%spam%', binds.get('$2'));
        Assert.areEqual('^J.*', binds.get('$3'));
        Assert.areEqual('new.*', binds.get('$4'));
        Assert.areEqual('admin|root', binds.get('$5'));
        Assert.areEqual('devops', binds.get('$6'));
    }

    @IsTest
    static void should_render_cast_colon_helper() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('events');
        q.field(PostgresSqlQuery.castColon('42', 'int'), 'answer_int')
            .field(PostgresSqlQuery.castColon(SqlQuery.literal('created_at'), 'timestamp'), 'created_ts');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT \'42\'::int answer_int, created_at::timestamp created_ts FROM events', sql);
    }

    @IsTest
    static void should_throw_exception_when_cast_colon_inputs_are_invalid() {
        // Act & Assert
        try {
            PostgresSqlQuery.castColon(null, 'int');
            Assert.fail('Should have thrown QueryException for null value');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('value cannot be null'));
        }

        try {
            PostgresSqlQuery.castColon('42', ' ');
            Assert.fail('Should have thrown QueryException for blank type');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('type cannot be blank'));
        }
    }

    @IsTest
    static void should_render_plain_count_when_distinct_on_not_used() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('users');
        q.wherex(new SqlQuery.Condition().field('active').eq(true));

        // Act
        String countSql = q.toCountString();
        String inlineCountSql = q.toInlineCountString();
        Map<String, Object> countBinds = q.getCountBindings();

        // Assert
        Assert.areEqual('SELECT COUNT(*) FROM users WHERE active = $1', countSql);
        Assert.areEqual('SELECT COUNT(*) FROM users WHERE active = TRUE', inlineCountSql);
        Assert.areEqual(1, countBinds.size());
        Assert.areEqual(true, countBinds.get('$1'));
    }

    @IsTest
    static void should_render_distinct_on_when_base_select_is_distinct() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('weather_reports');
        q.distinct();
        q.distinctOn('location').field('location').field('time');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT DISTINCT ON (location) location, time FROM weather_reports', sql);
    }

    @IsTest
    static void should_apply_distinct_on_when_iterable_contains_mixed_expressions() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('weather_reports');
        q.distinctOn(new List<Object>{ 'location', SqlQuery.literal('date_trunc(\'day\', time)') })
            .field('location')
            .field('time');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT DISTINCT ON (location, date_trunc(\'day\', time)) location, time FROM weather_reports',
            sql
        );
    }

    @IsTest
    static void should_expose_distinct_on_state_when_accessed_from_subclass() {
        // Arrange
        PostgresSqlQueryProbe q = new PostgresSqlQueryProbe();
        q.distinctOn('location');

        // Act
        Boolean hasDistinctOn = q.hasDistinctOnProbe();
        List<Object> copiedExpressions = q.distinctOnExpressionsProbe();
        copiedExpressions.add('city');
        Integer originalSizeAfterMutation = q.distinctOnExpressionsProbe().size();

        // Assert
        Assert.isTrue(hasDistinctOn);
        Assert.areEqual(2, copiedExpressions.size());
        Assert.areEqual(1, originalSizeAfterMutation);
    }

    @IsTest
    static void should_support_condition_id_expression_field_and_raw_variants() {
        // Arrange
        PostgresSqlQuery byId = PostgresSqlQuery.of('users');
        byId.wherex(new PostgresSqlQuery.Condition().id().eq('u-1'));

        PostgresSqlQuery byObjectField = PostgresSqlQuery.of('users');
        byObjectField.wherex(new PostgresSqlQuery.Condition().pgField('LOWER(name)').iLike('%john%'));

        PostgresSqlQuery byRaw = PostgresSqlQuery.of('users');
        byRaw.wherex(new PostgresSqlQuery.Condition('1 = 1'));

        // Act
        String byIdSql = byId.toString();
        String byObjectFieldSql = byObjectField.toString();
        String byRawSql = byRaw.toString();

        // Assert
        Assert.areEqual('SELECT * FROM users WHERE id = $1', byIdSql);
        Assert.areEqual('u-1', byId.getBindings().get('$1'));
        Assert.areEqual('SELECT * FROM users WHERE LOWER(name) ILIKE $1', byObjectFieldSql);
        Assert.areEqual('%john%', byObjectField.getBindings().get('$1'));
        Assert.areEqual('SELECT * FROM users WHERE 1 = 1', byRawSql);
    }

    @IsTest
    static void should_build_queries_with_alias_when_using_factory_and_constructor() {
        // Arrange
        PostgresSqlQuery fromFactory = PostgresSqlQuery.of('users', 'u');
        fromFactory.field('u.id');

        PostgresSqlQuery fromCtor = new PostgresSqlQuery('users', 'u');
        fromCtor.field('u.id');

        // Act
        String factorySql = fromFactory.toString();
        String ctorSql = fromCtor.toString();

        // Assert
        Assert.areEqual('SELECT u.id FROM users u', factorySql);
        Assert.areEqual('SELECT u.id FROM users u', ctorSql);
    }

    @IsTest
    static void should_support_quoted_user_table_name() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('"user"', 'u');
        q.field('u.id').field('u.email');
        q.wherex(new PostgresSqlQuery.Condition().pgField('u.is_active').eq(true));

        // Act
        String sql = q.toString();
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT u.id, u.email FROM "user" u WHERE u.is_active = $1', sql);
        Assert.areEqual('SELECT u.id, u.email FROM "user" u WHERE u.is_active = TRUE', inlineSql);
        Assert.areEqual(true, q.getBindings().get('$1'));
    }

    @IsTest
    static void should_render_inner_join_lateral_with_on_clause() {
        // Arrange
        PostgresSqlQuery lateral = (PostgresSqlQuery) PostgresSqlQuery.of('line_items', 'li')
            .field('li.amount')
            .wherex(new SqlQuery.Condition().field('li.order_id').eq(SqlQuery.literal('o.id')))
            .orderBy('li.amount', Query.SortOrder.DESCX)
            .lim(1);

        PostgresSqlQuery q = PostgresSqlQuery.of('orders', 'o');
        q.field('o.id').field('li_last.amount', 'last_amount');
        q.innerJoinLateral(lateral, 'li_last').onx('TRUE');
        q.addConditionEq('o.status', 'paid');

        // Act
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual(
            'SELECT o.id, li_last.amount last_amount FROM orders o INNER JOIN LATERAL (SELECT li.amount FROM line_items li WHERE li.order_id = o.id ORDER BY li.amount DESC LIMIT 1) li_last ON TRUE WHERE o.status = $1',
            sql
        );
        Assert.areEqual(1, binds.size());
        Assert.areEqual('paid', binds.get('$1'));
    }

    @IsTest
    static void should_render_cross_join_lateral_without_on_clause() {
        // Arrange
        PostgresSqlQuery lateral = (PostgresSqlQuery) PostgresSqlQuery.of('line_items', 'li')
            .field('li.id')
            .wherex(new SqlQuery.Condition().field('li.order_id').eq(SqlQuery.literal('o.id')));

        PostgresSqlQuery q = PostgresSqlQuery.of('orders', 'o');
        q.field('o.id');
        q.crossJoinLateral(lateral, 'li_any');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT o.id FROM orders o CROSS JOIN LATERAL (SELECT li.id FROM line_items li WHERE li.order_id = o.id) li_any',
            sql
        );
    }

    @IsTest
    static void should_throw_exception_when_lateral_join_inputs_are_invalid() {
        // Arrange
        PostgresSqlQuery q = PostgresSqlQuery.of('orders', 'o');
        PostgresSqlQuery lateral = PostgresSqlQuery.of('line_items');
        lateral.field('id');

        // Act & Assert
        try {
            q.innerJoinLateral(null, 'x');
            Assert.fail('Should have thrown QueryException for null subquery');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('subquery cannot be null'));
        }

        try {
            q.leftJoinLateral(lateral, ' ');
            Assert.fail('Should have thrown QueryException for blank alias');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('alias cannot be blank'));
        }
    }

    @IsTest
    static void should_throw_exception_when_natural_used_after_lateral_join() {
        // Arrange
        PostgresSqlQuery lateral = PostgresSqlQuery.of('line_items');
        lateral.field('id');
        PostgresSqlQuery q = PostgresSqlQuery.of('orders');

        // Act & Assert
        try {
            q.joinLateral(lateral, 'li').natural();
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NATURAL JOIN cannot be used with subquery joins'));
        }
    }
    // </editor-fold>

    private class PostgresSqlQueryProbe extends PostgresSqlQuery {
        public PostgresSqlQueryProbe() {
            super('probe_table');
        }

        public Boolean hasDistinctOnProbe() {
            return hasDistinctOn();
        }

        public List<Object> distinctOnExpressionsProbe() {
            return getDistinctOnExpressions();
        }
    }
}
