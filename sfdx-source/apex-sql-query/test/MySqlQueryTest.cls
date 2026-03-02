@IsTest(IsParallel=true)
private class MySqlQueryTest {
    // <editor-fold desc="MySQL Dialect">
    @IsTest
    static void should_render_anonymous_bindings_when_default_strategy_is_used() {
        // Arrange
        MySqlQuery q = MySqlQuery.of('users');
        q.wherex(new SqlQuery.Condition().field('name').eq('John'));
        q.addCondition(new SqlQuery.Condition().field('age').gt(18));

        // Act
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual('SELECT * FROM users WHERE name = ? AND age > ?', sql);
        Assert.areEqual(2, binds.size());
        Assert.areEqual('John', binds.get('?1'));
        Assert.areEqual(18, binds.get('?2'));
    }

    @IsTest
    static void should_render_mysql_condition_operators_when_using_mysql_condition() {
        // Arrange
        MySqlQuery q = MySqlQuery.of('users');
        q.wherex(new MySqlQuery.Condition().mySqlField('email').regexp('.*@gmail\\.com'));
        q.addCondition(new MySqlQuery.Condition().mySqlField('email').notRegexp('.*spam.*'));
        q.addCondition(new MySqlQuery.Condition().mySqlField('status').nullSafeEq('active'));
        q.addCondition(new MySqlQuery.Condition().id().eq('u-1'));

        // Act
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual(
            'SELECT * FROM users WHERE email REGEXP ? AND email NOT REGEXP ? AND status <=> ? AND id = ?',
            sql
        );
        Assert.areEqual(4, binds.size());
        Assert.areEqual('.*@gmail\\.com', binds.get('?1'));
        Assert.areEqual('.*spam.*', binds.get('?2'));
        Assert.areEqual('active', binds.get('?3'));
        Assert.areEqual('u-1', binds.get('?4'));
    }

    @IsTest
    static void should_render_mysql_function_helpers_when_used_in_select() {
        // Arrange
        MySqlQuery q = MySqlQuery.of('orders');
        q.field(MySqlQuery.groupConcat(SqlQuery.literal('customer_id')), 'customers');
        q.field(MySqlQuery.groupConcat(SqlQuery.literal('status'), '|'), 'statuses');
        q.field(MySqlQuery.dateFormat(SqlQuery.literal('created_at'), '%Y-%m-%d'), 'created_day');
        q.field(MySqlQuery.jsonExtract(SqlQuery.literal('payload'), '$.amount'), 'amount');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT GROUP_CONCAT(customer_id) customers, GROUP_CONCAT(status SEPARATOR \'|\') statuses, DATE_FORMAT(created_at, \'%Y-%m-%d\') created_day, JSON_EXTRACT(payload, \'$.amount\') amount FROM orders',
            sql
        );
    }

    @IsTest
    static void should_throw_exception_when_mysql_helper_inputs_are_invalid() {
        // Act & Assert
        try {
            MySqlQuery.groupConcat(null);
            Assert.fail('Should have thrown QueryException for null value');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('value cannot be null'));
        }

        try {
            MySqlQuery.groupConcat('name', null);
            Assert.fail('Should have thrown QueryException for null separator');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('separator cannot be null'));
        }

        try {
            MySqlQuery.dateFormat(SqlQuery.literal('created_at'), ' ');
            Assert.fail('Should have thrown QueryException for blank format');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('format cannot be blank'));
        }

        try {
            MySqlQuery.jsonExtract(SqlQuery.literal('payload'), ' ');
            Assert.fail('Should have thrown QueryException for blank path');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('path cannot be blank'));
        }
    }

    @IsTest
    static void should_build_queries_with_alias_when_using_factory_and_constructor() {
        // Arrange
        MySqlQuery fromFactory = MySqlQuery.of('users', 'u');
        fromFactory.field('u.id');

        MySqlQuery fromCtor = new MySqlQuery('users', 'u');
        fromCtor.field('u.id');

        // Act
        String factorySql = fromFactory.toString();
        String ctorSql = fromCtor.toString();

        // Assert
        Assert.areEqual('SELECT u.id FROM users u', factorySql);
        Assert.areEqual('SELECT u.id FROM users u', ctorSql);
    }

    @IsTest
    static void should_support_backtick_quoted_user_table_name() {
        // Arrange
        MySqlQuery q = MySqlQuery.of('`user`', 'u');
        q.field('u.id');
        q.addCondition(new SqlQuery.Condition().field('u.is_active').eq(true));

        // Act
        String sql = q.toString();
        String inlineSql = q.toInlineString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual('SELECT u.id FROM `user` u WHERE u.is_active = ?', sql);
        Assert.areEqual('SELECT u.id FROM `user` u WHERE u.is_active = TRUE', inlineSql);
        Assert.areEqual(1, binds.size());
        Assert.areEqual(true, binds.get('?1'));
    }

    @IsTest
    static void should_support_condition_expression_field_and_raw_variants_when_building_where_clause() {
        // Arrange
        MySqlQuery byObjectField = MySqlQuery.of('users');
        byObjectField.wherex(new MySqlQuery.Condition().mySqlField('LOWER(name)').regexp('^john'));

        MySqlQuery byRaw = MySqlQuery.of('users');
        byRaw.wherex(new MySqlQuery.Condition('1 = 1'));

        // Act
        String byObjectFieldSql = byObjectField.toString();
        String byRawSql = byRaw.toString();

        // Assert
        Assert.areEqual('SELECT * FROM users WHERE LOWER(name) REGEXP ?', byObjectFieldSql);
        Assert.areEqual('^john', byObjectField.getBindings().get('?1'));
        Assert.areEqual('SELECT * FROM users WHERE 1 = 1', byRawSql);
    }
    // </editor-fold>
}
