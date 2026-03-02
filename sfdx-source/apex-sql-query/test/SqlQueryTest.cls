@IsTest(IsParallel=true)
private class SqlQueryTest {
    private static Integer count = 0;

    // <editor-fold desc="WITH (Common Table Expressions)">
    @IsTest
    static void should_generate_simple_cte() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');
        SqlQuery cte = new TestSqlQuery('dept');
        cte.field('Id').field('Name');

        // Act
        q.with('dept_cte', cte)
            .field('e.Name')
            .join('dept_cte', 'd')
            .onx('e.DeptId = d.Id')
            .wherex('d.Name = \'Sales\'');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.startsWith('WITH dept_cte AS (SELECT Id, Name FROM dept) SELECT'));
        Assert.isTrue(sql.contains('JOIN dept_cte d'));
    }

    @IsTest
    static void should_handle_multiple_ctes_with_ordering() {
        // Arrange
        SqlQuery q = new TestSqlQuery('final');
        SqlQuery q1 = new TestSqlQuery('t1');
        SqlQuery q2 = new TestSqlQuery('t2');

        // Act
        q.with('cte1', q1).with('cte2', q2);

        // Assert
        String sql = q.toString();
        // Verify order: cte1 then cte2
        Assert.isTrue(sql.startsWith('WITH cte1 AS (SELECT * FROM t1), cte2 AS (SELECT * FROM t2)'));
    }

    @IsTest
    static void should_propagate_bindings_from_cte() {
        // Arrange
        SqlQuery q = new TestSqlQuery('main');
        SqlQuery cte = new TestSqlQuery('sub');
        cte.addConditionEq('Val', 'test_bind'); // var$0

        // Act
        q.with('my_cte', cte).addConditionEq('MainVal', 'main_bind'); // var$1

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains(':var$0'));
        Assert.isTrue(sql.contains(':var$1'));

        // Verify bindings map
        Map<String, Object> binds = q.getBindings();
        Assert.areEqual('test_bind', binds.get('var$0'));
        Assert.areEqual('main_bind', binds.get('var$1'));
    }

    @IsTest
    static void should_generate_cte_count_query() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');
        SqlQuery cte = new TestSqlQuery('dept');

        // Act
        q.with('d', cte);

        // Assert
        String countSql = q.toCountString();
        Assert.isTrue(countSql.startsWith('WITH d AS (SELECT * FROM dept) SELECT COUNT(*) FROM emp'));
    }

    @IsTest
    static void should_handle_complex_multiple_ctes() {
        // Arrange
        // CTE 1: Regional Sales
        SqlQuery regionalSales = new TestSqlQuery('Sales');
        regionalSales.field('Region').sum('Amount', 'Total').wherex(new SqlQuery.Condition().field('Year').eq(2023)); // bind var$0

        // CTE 2: Top Regions (using regional_sales)
        SqlQuery topRegions = new TestSqlQuery('regional_sales');
        topRegions.field('Region').wherex(new SqlQuery.Condition().field('Total').gt(100000)); // bind var$1

        // Main Query
        SqlQuery q = new TestSqlQuery('Employees', 'e');
        q.with('regional_sales', regionalSales)
            .with('top_regions', topRegions)
            .field('e.Name')
            .join('top_regions', 'tr')
            .onx('e.Region = tr.Region')
            .wherex(new SqlQuery.Condition().field('e.Status').eq('Active')); // bind var$2

        // Act
        String sql = q.toString();
        Map<String, Object> bindings = q.getBindings();

        // Assert
        String expectedStart = 'WITH regional_sales AS (SELECT Region, SUM(Amount) Total FROM Sales WHERE Year = :var$0), top_regions AS (SELECT Region FROM regional_sales WHERE Total > :var$1) SELECT e.Name FROM Employees e';
        Assert.isTrue(sql.startsWith(expectedStart), 'SQL should start with correct WITH clauses');
        Assert.isTrue(sql.contains('INNER JOIN top_regions tr ON e.Region = tr.Region'));
        Assert.isTrue(sql.contains('WHERE e.Status = :var$2'));

        // 2. Bindings
        Assert.areEqual(3, bindings.size(), 'Should have 3 bindings total');
        Assert.areEqual(2023, bindings.get('var$0'));
        Assert.areEqual(100000, bindings.get('var$1'));
        Assert.areEqual('Active', bindings.get('var$2'));
    }

    @IsTest
    static void should_handle_count_with_cte() {
        // Arrange
        SqlQuery cte = new TestSqlQuery('t1').field('A');
        SqlQuery q = new TestSqlQuery('t2').with('cte', cte).field('*');

        // Act
        String sql = q.toCountString();

        // Assert
        Assert.areEqual('WITH cte AS (SELECT A FROM t1) SELECT COUNT(*) FROM t2', sql);
    }

    @IsTest
    static void should_handle_with_clause_cte() {
        // Arrange
        SqlQuery cte = new TestSqlQuery('orders').field('Id').wherex(new SqlQuery.Condition().field('Total').gt(100));
        SqlQuery q = new TestSqlQuery('recent_orders').with('recent_orders', cte).field('Id');

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(
            sql.startsWith(
                'WITH recent_orders AS (SELECT Id FROM orders WHERE Total > :var$0) SELECT Id FROM recent_orders'
            )
        );
        Assert.areEqual(100, q.getBindings().get('var$0'));
    }

    @IsTest
    static void should_handle_multiple_ctes() {
        // Arrange
        SqlQuery cte1 = new TestSqlQuery('table1').field('Id').wherex(new SqlQuery.Condition().field('A').eq(1));
        SqlQuery cte2 = new TestSqlQuery('table2').field('Id').wherex(new SqlQuery.Condition().field('B').eq(2));

        SqlQuery q = new TestSqlQuery('result').with('t1', cte1).with('t2', cte2).field('*');

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('t1 AS (SELECT Id FROM table1 WHERE A = :var$0)'));
        Assert.isTrue(sql.contains('t2 AS (SELECT Id FROM table2 WHERE B = :var$1)'));
        Assert.areEqual(1, q.getBindings().get('var$0'));
        Assert.areEqual(2, q.getBindings().get('var$1'));
    }
    // </editor-fold>

    // <editor-fold desc="SELECT Clause">
    @IsTest
    static void should_generate_basic_sql() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.field('Name')
            .field('Id')
            .fields('AccountNumber, Description')
            .fields(new List<String>{ 'Phone', 'Website' })
            .allFields();

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT Name, Id, AccountNumber, Description, Phone, Website, * FROM account';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_aliased_fields_and_complex_selections() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .field('Name', 'n')
            .field('Industry', 'i')
            .fields(new List<String>{ 'Type', 'Status' })
            .allFields();

        // Act
        String actual = q.toString();

        // Assert
        Assert.isTrue(actual.contains('SELECT Name n, Industry i, Type, Status, * FROM account'));
    }

    @IsTest
    static void should_handle_distinct_selection() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').distinct().field('Industry').field('Type');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT DISTINCT Industry, Type FROM account', sql);
    }

    @IsTest
    static void should_wrap_count_query_when_select_is_distinct() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .distinct()
            .field('Industry')
            .wherex(new SqlQuery.Condition().field('Type').eq('Customer'));

        // Act
        String countSql = q.toCountString();
        String inlineCountSql = q.toInlineCountString();
        Map<String, Object> countBinds = q.getCountBindings();

        // Assert
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT DISTINCT Industry FROM account WHERE Type = :var$0) AS count_wrapper',
            countSql
        );
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT DISTINCT Industry FROM account WHERE Type = \'Customer\') AS count_wrapper',
            inlineCountSql
        );
        Assert.areEqual(1, countBinds.size());
        Assert.areEqual('Customer', countBinds.get('var$0'));
    }

    @IsTest
    static void should_handle_select_aggregates() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.count('Id')
            .count('Id', 'cnt')
            .countDistinct('Name')
            .countDistinct('Name', 'cntDist')
            .avg('AnnualRevenue', 'avgRev')
            .min('NumberOfEmployees', 'minEmp')
            .max('LastModifiedDate', 'maxMod')
            .sum('AnnualRevenue', 'sumRev');

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT COUNT(Id), COUNT(Id) cnt, COUNT(DISTINCT Name), COUNT(DISTINCT Name) cntDist, AVG(AnnualRevenue) avgRev, MIN(NumberOfEmployees) minEmp, MAX(LastModifiedDate) maxMod, SUM(AnnualRevenue) sumRev FROM account';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_all_aggregate_facades_without_aliases() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');

        // Act
        q.avg('Amount').min('Price').max('Price').sum('Revenue');
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT AVG(Amount), MIN(Price), MAX(Price), SUM(Revenue) FROM sales', sql);
    }

    // <editor-fold desc="SQL Functions">
    @IsTest
    static void should_handle_complex_sql_function_combinations() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');

        // Act
        q.field(SqlQuery.cast(SqlQuery.coalesce(SqlQuery.literal('discount'), 0), 'DECIMAL'))
            .field(SqlQuery.upper(SqlQuery.cast(SqlQuery.literal('status'), 'VARCHAR')))
            .field(SqlQuery.dateTrunc('month', SqlQuery.literal('created_date')))
            .wherex(new SqlQuery.Condition().field(SqlQuery.lower(SqlQuery.literal('email'))).eq('test@example.com'));

        String actual = q.toString();

        // Assert
        String expected = 'SELECT CAST(COALESCE(discount, 0) AS DECIMAL), UPPER(CAST(status AS VARCHAR)), DATE_TRUNC(\'month\', created_date) FROM orders WHERE LOWER(email) = :var$0';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_generate_cast_function() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act
        q.field(SqlQuery.cast(SqlQuery.literal('age'), 'VARCHAR'));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT CAST(age AS VARCHAR) FROM users', actual);
    }

    @IsTest
    static void should_generate_date_trunc_function() {
        // Arrange
        SqlQuery q = new TestSqlQuery('events');

        // Act
        q.field(SqlQuery.dateTrunc('day', SqlQuery.literal('event_time')));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT DATE_TRUNC(\'day\', event_time) FROM events', actual);
    }

    @IsTest
    static void should_generate_coalesce_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        q.field(SqlQuery.coalesce(SqlQuery.literal('description'), 'No Description'))
            .field(SqlQuery.coalesce(new List<Object>{ SqlQuery.literal('price'), SqlQuery.literal('list_price'), 0 }));
        String actual = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT COALESCE(description, \'No Description\'), COALESCE(price, list_price, 0) FROM products',
            actual
        );
    }

    @IsTest
    static void should_generate_string_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('contacts');

        // Act
        q.field(SqlQuery.upper(SqlQuery.literal('lastname'))).field(SqlQuery.lower(SqlQuery.literal('email')));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT UPPER(lastname), LOWER(email) FROM contacts', actual);
    }

    @IsTest
    static void should_handle_deeply_nested_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        // COALESCE(UPPER(CAST(price AS VARCHAR)), 'N/A')
        q.field(SqlQuery.coalesce(SqlQuery.upper(SqlQuery.cast(SqlQuery.literal('price'), 'VARCHAR')), 'N/A'));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT COALESCE(UPPER(CAST(price AS VARCHAR)), \'N/A\') FROM products', actual);
    }

    @IsTest
    static void should_handle_nested_cast_and_coalesce_combinations() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        q.field(SqlQuery.upper(SqlQuery.coalesce(SqlQuery.cast(SqlQuery.literal('id'), 'VARCHAR'), 'NONE')));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT UPPER(COALESCE(CAST(id AS VARCHAR), \'NONE\')) FROM products', actual);
    }

    @IsTest
    static void should_throw_exception_when_cast_params_are_invalid() {
        // Act & Assert 1: Null field
        try {
            SqlQuery.cast(null, 'INT');
            Assert.fail('Should have thrown QueryException for null field');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('value cannot be null'));
        }

        // Act & Assert 2: Blank type
        try {
            SqlQuery.cast('id', ' ');
            Assert.fail('Should have thrown QueryException for blank type');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('type cannot be blank'));
        }
    }

    @IsTest
    static void should_throw_exception_when_coalesce_list_is_empty() {
        // Arrange
        List<Object> emptyList = new List<Object>();

        // Act & Assert
        try {
            SqlQuery.coalesce(emptyList);
            Assert.fail('Should have thrown QueryException for empty list');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('values cannot be empty'));
        }
    }

    @IsTest
    static void should_inline_datetime_literal() {
        // Arrange
        Datetime dt = Datetime.newInstanceGmt(2026, 2, 5, 14, 46, 27);
        SqlQuery q = new TestSqlQuery('orders').field('id').wherex(SqlQuery.COND.field('created_at').lt(dt));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT id FROM orders WHERE created_at < \'2026-02-05T14:46:27Z\'', inlineSql);
    }

    @IsTest
    static void should_inline_date_literal() {
        // Arrange
        Date d = Date.newInstance(2026, 2, 5);
        SqlQuery q = new TestSqlQuery('orders').field('id').wherex(SqlQuery.COND.field('order_date').eq(d));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT id FROM orders WHERE order_date = \'2026-02-05\'', inlineSql);
    }

    @IsTest
    static void should_inline_time_literal() {
        // Arrange
        Time t = Time.newInstance(14, 46, 27, 123);
        SqlQuery q = new TestSqlQuery('orders').field('id').wherex(SqlQuery.COND.field('delivery_time').eq(t));

        // Act
        String inlineSql = q.toInlineString();

        // Assert
        Assert.areEqual('SELECT id FROM orders WHERE delivery_time = \'14:46:27.123Z\'', inlineSql);
    }

    @IsTest
    static void should_handle_aggregate_convenience_methods() {
        // Arrange & Act
        SqlQuery q1 = new TestSqlQuery('orders').countAll();
        SqlQuery q2 = new TestSqlQuery('orders').countAll('total');
        SqlQuery q3 = new TestSqlQuery('sales').avg('Amount');
        SqlQuery q4 = new TestSqlQuery('sales').avg('Amount', 'AvgAmount');
        SqlQuery q5 = new TestSqlQuery('products').min('Price');
        SqlQuery q6 = new TestSqlQuery('products').min('Price', 'MinPrice');
        SqlQuery q7 = new TestSqlQuery('products').max('Price');
        SqlQuery q8 = new TestSqlQuery('products').max('Price', 'MaxPrice');
        SqlQuery q9 = new TestSqlQuery('revenue').sum('Total');
        SqlQuery q10 = new TestSqlQuery('revenue').sum('Total', 'GrandTotal');

        // Assert
        Assert.areEqual('SELECT COUNT(*) FROM orders', q1.toString());
        Assert.areEqual('SELECT COUNT(*) total FROM orders', q2.toString());
        Assert.areEqual('SELECT AVG(Amount) FROM sales', q3.toString());
        Assert.areEqual('SELECT AVG(Amount) AvgAmount FROM sales', q4.toString());
        Assert.areEqual('SELECT MIN(Price) FROM products', q5.toString());
        Assert.areEqual('SELECT MIN(Price) MinPrice FROM products', q6.toString());
        Assert.areEqual('SELECT MAX(Price) FROM products', q7.toString());
        Assert.areEqual('SELECT MAX(Price) MaxPrice FROM products', q8.toString());
        Assert.areEqual('SELECT SUM(Total) FROM revenue', q9.toString());
        Assert.areEqual('SELECT SUM(Total) GrandTotal FROM revenue', q10.toString());
    }

    @IsTest
    static void should_handle_allFields_shorthand() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').allFields();

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account', sql);
    }

    @IsTest
    static void should_use_literal_in_aggregates() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        // Strings are treated as column names directly - no literal() needed
        q.field(SqlQuery.AGG.sum('AnnualRevenue'), 'total').field(SqlQuery.AGG.countDistinct('Name'), 'cnt');

        // Assert
        String sql = q.toString();
        Assert.areEqual('SELECT SUM(AnnualRevenue) total, COUNT(DISTINCT Name) cnt FROM account', sql);
        Assert.isTrue(q.getBindings().isEmpty());
    }
    // </editor-fold>

    // <editor-fold desc="CASE Expressions">
    @IsTest
    static void should_handle_case_expressions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');
        q.field(
            SqlQuery.CASEX.match('status').when('New').then('Draft').when('Shipped').then('Sent').elsex('Other').end(),
            'StatusLabel'
        );

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT CASE status WHEN :var$0 THEN :var$1 WHEN :var$2 THEN :var$3 ELSE :var$4 END StatusLabel FROM orders';
        Assert.areEqual(expected, actual);
        Assert.areEqual('New', binds.get('var$0'));
        Assert.areEqual('Draft', binds.get('var$1'));
        Assert.areEqual('Shipped', binds.get('var$2'));
        Assert.areEqual('Sent', binds.get('var$3'));
        Assert.areEqual('Other', binds.get('var$4'));
    }

    @IsTest
    static void should_handle_searched_case_expressions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');
        q.field('name')
            .field(
                SqlQuery.CASEX.when(new SqlQuery.Condition().field('price').gt(100))
                    .then('Expensive')
                    .when(new SqlQuery.Condition().field('price').lt(20))
                    .then('Cheap')
                    .elsex('Moderate')
                    .end(),
                'PriceCategory'
            );

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT name, CASE WHEN price > :var$0 THEN :var$1 WHEN price < :var$2 THEN :var$3 ELSE :var$4 END PriceCategory FROM products';
        Assert.areEqual(expected, actual);
        Assert.areEqual(100, binds.get('var$0'));
        Assert.areEqual('Expensive', binds.get('var$1'));
        Assert.areEqual(20, binds.get('var$2'));
        Assert.areEqual('Cheap', binds.get('var$3'));
        Assert.areEqual('Moderate', binds.get('var$4'));
    }

    @IsTest
    static void should_handle_complex_case_variations() {
        // Arrange
        SqlQuery q = new TestSqlQuery('leads');
        q.field('name')
            .field(
                SqlQuery.CASEX
                    // Nested CASE in THEN
                    .when(new SqlQuery.Condition().field('score').gt(80))
                    .then(
                        SqlQuery.CASEX
                            .when(new SqlQuery.Condition().field('country').eq('US'))
                            .then('Priority US')
                            .elsex('Priority Global')
                            .end()
                    )
                    // Nested condition logic
                    .when(
                        new Query.Junction()
                            .add(new SqlQuery.Condition().field('dnb_rating').eq('A'))
                            .add(new SqlQuery.Condition().field('revenue').gt(1000000))
                    )
                    .then('High Potential')
                    .elsex('Standard')
                    .end(),
                'LeadSegment'
            );

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        // Nested structure:
        // CASE
        //   WHEN score > :v0 THEN
        //     CASE WHEN country = :v1 THEN :v2 ELSE :v3 END
        //   WHEN dnb_rating = :v4 AND revenue > :v5 THEN :v6
        //   ELSE :v7
        // END

        String expected = 'SELECT name, CASE WHEN score > :var$0 THEN CASE WHEN country = :var$1 THEN :var$2 ELSE :var$3 END WHEN dnb_rating = :var$4 AND revenue > :var$5 THEN :var$6 ELSE :var$7 END LeadSegment FROM leads';

        Assert.areEqual(expected, actual);
        Assert.areEqual(80, binds.get('var$0'));
        Assert.areEqual('US', binds.get('var$1'));
        Assert.areEqual('Priority US', binds.get('var$2'));
        Assert.areEqual('Priority Global', binds.get('var$3'));
        Assert.areEqual('A', binds.get('var$4'));
        Assert.areEqual(1000000, binds.get('var$5'));
        Assert.areEqual('High Potential', binds.get('var$6'));
        Assert.areEqual('Standard', binds.get('var$7'));
    }

    @IsTest
    static void should_cover_corner_cases_and_raw_strings() {
        // Arrange
        SqlQuery q = new TestSqlQuery('logs');
        q.field(
            SqlQuery.CASEX
                .when(new SqlQuery.Condition('level = "ERROR"'))
                .then('Critical')
                .elsex(SqlQuery.CASEX.match('source').when('API').then('External').elsex('Internal').end())
                .end(),
            'Severity'
        );

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT CASE WHEN level = "ERROR" THEN :var$0 ELSE CASE source WHEN :var$1 THEN :var$2 ELSE :var$3 END END Severity FROM logs';

        Assert.areEqual(expected, actual);
        Assert.areEqual('Critical', binds.get('var$0'));
        Assert.areEqual('API', binds.get('var$1'));
        Assert.areEqual('External', binds.get('var$2'));
        Assert.areEqual('Internal', binds.get('var$3'));
    }

    @IsTest
    static void should_cover_case_internals() {
        // Arrange
        SqlQuery.CaseExpression expr = SqlQuery.CASEX
            .match('status')
            .when(10)
            .then('Ten')
            .when('20')
            .then(SqlQuery.literal('OtherColumn'))
            .elsex(new SqlQuery.Condition().field('x').eq('y'))
            .end();

        SqlQuery.CaseExpression rawWhenExpr = SqlQuery.CASEX.when('raw_condition > 5')
            .then(SqlQuery.literal('Raw'))
            .end();

        // Act & Assert 1: bindOrLiteral with null context
        String rawSql = expr.toString();
        Assert.areEqual('CASE status WHEN 10 THEN \'Ten\' WHEN \'20\' THEN OtherColumn ELSE x = \'y\' END', rawSql);

        // Act & Assert 2: raw match expression
        String rawWhenSql = rawWhenExpr.toString();
        Assert.areEqual('CASE WHEN raw_condition > 5 THEN Raw END', rawWhenSql);

        // Act & Assert 3: Exception handling
        try {
            SqlQuery.CASEX.when('condition').when(123);
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Cannot use value matching'));
        }
    }

    @IsTest
    static void should_handle_case_expression_in_where_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');
        Query.Criterion caseCond = new SqlQuery.Condition()
            .field(SqlQuery.CASEX.match('status').when('New').then(1).elsex(0).end())
            .eq(1);

        // Act
        q.wherex(caseCond);
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('WHERE CASE status WHEN :var$1 THEN :var$2 ELSE :var$3 END = :var$0'));
        Assert.areEqual(1, q.getBindings().get('var$0'));
        Assert.areEqual('New', q.getBindings().get('var$1'));
        Assert.areEqual(1, q.getBindings().get('var$2'));
        Assert.areEqual(0, q.getBindings().get('var$3'));
    }

    @IsTest
    static void should_handle_case_nesting() {
        // Act
        SqlQuery.CaseExpression innr = SqlQuery.CASEX.match('inner_val')
            .when(1)
            .then('Inner1')
            .elsex('InnerElse')
            .end();
        SqlQuery.CaseExpression outr = SqlQuery.CASEX.match('outer_val').when(1).then(innr).elsex('OuterElse').end();

        // Assert
        String sql = outr.toString();
        Assert.isTrue(
            sql.contains(
                'CASE outer_val WHEN 1 THEN CASE inner_val WHEN 1 THEN \'Inner1\' ELSE \'InnerElse\' END ELSE \'OuterElse\' END'
            )
        );
    }
    // </editor-fold>

    // <editor-fold desc="FROM Clause">
    @IsTest
    static void should_handle_basic_from() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account', sql);
    }
    // </editor-fold>

    // <editor-fold desc="JOINS">
    @IsTest
    static void should_handle_joins_rigorously() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account', 'a');
        q.field('a.Name').field('c.LastName').leftJoin('contact', 'c').onx('a.Id = c.AccountId');

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT a.Name, c.LastName FROM account a LEFT JOIN contact c ON a.Id = c.AccountId';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_all_join_types() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account', 'a');
        q.field('a.Name')
            .innerJoin('contact', 'c')
            .onx('a.Id = c.AccountId')
            .leftJoin('lead', 'l')
            .onx('a.Name = l.Company')
            .rightJoin('opportunity', 'o')
            .onx('a.Id = o.AccountId')
            .fullJoin('task', 't')
            .onx('a.Id = t.WhatId');

        // Act
        String actual = q.toString();

        // Assert
        Assert.isTrue(actual.contains('INNER JOIN contact c ON a.Id = c.AccountId'));
        Assert.isTrue(actual.contains('LEFT JOIN lead l ON a.Name = l.Company'));
        Assert.isTrue(actual.contains('RIGHT JOIN opportunity o ON a.Id = o.AccountId'));
        Assert.isTrue(actual.contains('FULL JOIN task t ON a.Id = t.WhatId'));
    }

    @IsTest
    static void should_handle_join_with_using() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account', 'a');

        // Act
        q.field('a.Name').field('c.LastName').innerJoin('contact', 'c').usingx('AccountId');
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT a.Name, c.LastName FROM account a INNER JOIN contact c USING (AccountId)', sql);
    }

    @IsTest
    static void should_handle_natural_joins() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.innerJoin('contact').natural();
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account NATURAL INNER JOIN contact', sql);
    }

    @IsTest
    static void should_handle_joins_without_aliases() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act
        q.join('t2').leftJoin('t3').rightJoin('t4').fullJoin('t5').crossJoin('t6');
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('INNER JOIN t2'));
        Assert.isTrue(sql.contains('LEFT JOIN t3'));
        Assert.isTrue(sql.contains('RIGHT JOIN t4'));
        Assert.isTrue(sql.contains('FULL JOIN t5'));
        Assert.isTrue(sql.contains('CROSS JOIN t6'));
    }

    @IsTest
    static void should_handle_raw_on_condition() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act
        q.join('t2').onx('t1.id = t2.id');

        // Assert
        Assert.areEqual('SELECT * FROM t1 INNER JOIN t2 ON t1.id = t2.id', q.toString());
    }

    @IsTest
    static void should_handle_on_eq_shortcut() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders', 'o');

        // Act
        q.innerJoin('customers', 'c').onEq('o.customer_id', 'c.id');

        // Assert
        Assert.areEqual('SELECT * FROM orders o INNER JOIN customers c ON o.customer_id = c.id', q.toString());
    }

    @IsTest
    static void should_handle_single_column_using() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act
        q.join('t2').usingx('id');

        // Assert
        Assert.areEqual('SELECT * FROM t1 INNER JOIN t2 USING (id)', q.toString());
    }

    @IsTest
    static void should_handle_multiple_natural_joins() {
        // Arrange
        SqlQuery q = new TestSqlQuery('a');

        // Act
        q.innerJoin('b').natural().leftJoin('c').natural();
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM a NATURAL INNER JOIN b NATURAL LEFT JOIN c', sql);
    }

    @IsTest
    static void should_handle_complex_mixed_joins() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders', 'o');

        // Act
        q.field('o.Id')
            .field('c.Name')
            .field('p.Price')
            .innerJoin('customers', 'c')
            .usingx('CustomerId')
            .leftJoin('payments', 'p')
            .onx('o.Id = p.OrderId')
            .crossJoin('currencies', 'curr');

        String sql = q.toString();

        // Assert
        String expected = 'SELECT o.Id, c.Name, p.Price FROM orders o INNER JOIN customers c USING (CustomerId) LEFT JOIN payments p ON o.Id = p.OrderId CROSS JOIN currencies curr';
        Assert.areEqual(expected, sql);
    }

    @IsTest
    static void should_handle_using_with_multiple_columns() {
        // Arrange
        SqlQuery q = new TestSqlQuery('table1', 't1');

        // Act
        q.innerJoin('table2', 't2').usingx(new List<String>{ 'id', 'name' });
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM table1 t1 INNER JOIN table2 t2 USING (id, name)', sql);
    }

    @IsTest
    static void should_handle_cross_join_without_alias() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act
        q.crossJoin('t2');
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM t1 CROSS JOIN t2', sql);
    }

    @IsTest
    static void should_throw_exception_when_onx_called_without_join() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.onx('t1.id = t2.id');
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('onx() requires a prior join() call'));
        }
    }

    @IsTest
    static void should_throw_exception_when_on_eq_called_without_join() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.onEq('t1.id', 't2.id');
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('onEq() requires a prior join() call'));
        }
    }

    @IsTest
    static void should_throw_exception_when_usingx_called_without_join() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.usingx('id');
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('usingx() requires a prior join() call'));
        }
    }

    @IsTest
    static void should_throw_exception_when_natural_called_without_join() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.natural();
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('natural() requires a prior join() call'));
        }
    }

    @IsTest
    static void should_throw_exception_when_usingx_columns_are_invalid() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1').join('t2');

        // Act & Assert
        try {
            q.usingx((List<String>) null);
            Assert.fail('Should have thrown QueryException for null columns');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('columns cannot be null'));
        }

        try {
            q.usingx(new List<String>());
            Assert.fail('Should have thrown QueryException for empty columns');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('columns cannot be empty'));
        }

        try {
            q.usingx(new List<String>{ ' ' });
            Assert.fail('Should have thrown QueryException for blank column');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('column cannot be blank'));
        }
    }

    @IsTest
    static void should_throw_exception_when_natural_join_is_combined_with_on() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('t1').join('t2');
        SqlQuery q2 = new TestSqlQuery('t1').join('t2').natural();

        // Act & Assert
        try {
            q1.onx('t1.id = t2.id').natural();
            Assert.fail('Should have thrown QueryException for NATURAL + ON');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NATURAL JOIN cannot be combined with ON'));
        }

        try {
            q2.onx('t1.id = t2.id');
            Assert.fail('Should have thrown QueryException for NATURAL + ON');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NATURAL JOIN cannot be combined with ON'));
        }
    }

    @IsTest
    static void should_throw_exception_when_natural_join_is_combined_with_using() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('t1').join('t2');
        SqlQuery q2 = new TestSqlQuery('t1').join('t2').natural();

        // Act & Assert
        try {
            q1.usingx('id').natural();
            Assert.fail('Should have thrown QueryException for NATURAL + USING');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NATURAL JOIN cannot be combined with USING'));
        }

        try {
            q2.usingx('id');
            Assert.fail('Should have thrown QueryException for NATURAL + USING');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NATURAL JOIN cannot be combined with USING'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="VALUES">
    @IsTest
    static void should_generate_values_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy'); // Table ignored when VALUES is present
        List<List<Object>> rows = new List<List<Object>>{
            new List<Object>{ 1, 'Admin' },
            new List<Object>{ 2, 'User' }
        };
        List<String> cols = new List<String>{ 'Id', 'Role' };

        // Act
        q.values(rows, 'UserRoles', cols);

        // Assert
        // Should select * from values ...
        String expected = 'SELECT * FROM (VALUES (:var$0, :var$1), (:var$2, :var$3)) AS UserRoles (Id, Role)';
        Assert.areEqual(expected, q.toString());

        Map<String, Object> binds = q.getBindings();
        Assert.areEqual(1, binds.get('var$0'));
        Assert.areEqual('Admin', binds.get('var$1'));
        Assert.areEqual(2, binds.get('var$2'));
        Assert.areEqual('User', binds.get('var$3'));
    }

    @IsTest
    static void should_count_values_rows() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');
        List<List<Object>> rows = new List<List<Object>>{ new List<Object>{ 1 }, new List<Object>{ 2 } };
        q.values(rows, 't', new List<String>{ 'val' });

        // Act
        // For VALUES, count should wrap it: SELECT COUNT(*) FROM (SELECT * FROM (VALUES ...) AS t(val)) AS count_wrapper
        // OR simply SELECT COUNT(*) FROM (VALUES ...) AS t(val) is also valid SQL usually.
        // Current implementation wraps it if VALUES is present.
        String expectedStart = 'SELECT COUNT(*) FROM (SELECT * FROM (VALUES (:var$0), (:var$1)) AS t (val)) AS count_wrapper';
        Assert.areEqual(expectedStart, q.toCountString());
    }

    @IsTest
    static void should_replace_values_rows_when_values_called_multiple_times() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');
        q.values(new List<List<Object>>{ new List<Object>{ 1 } }, 'v', new List<String>{ 'c' });

        // Act
        q.values(new List<List<Object>>{ new List<Object>{ 2 } }, 'v', new List<String>{ 'c' });
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual('SELECT * FROM (VALUES (:var$0)) AS v (c)', sql);
        Assert.areEqual(1, binds.size());
        Assert.areEqual(2, binds.get('var$0'));
    }

    @IsTest
    static void should_validate_values_dimensions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');
        List<List<Object>> rows = new List<List<Object>>{ new List<Object>{ 1, 'Too', 'Many' } };

        // Act
        Exception capturedException;
        try {
            q.values(rows, 'Bad', new List<String>{ 'One', 'Two' }); // 3 vals vs 2 cols
        } catch (Query.QueryException e) {
            capturedException = e;
        }

        // Assert
        Assert.isTrue(
            capturedException.getMessage().contains('Row size must match'),
            'Unexpected error: ' + capturedException.getMessage()
        );
    }

    @IsTest
    static void should_throw_exception_when_values_rows_null() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');

        // Act & Assert
        try {
            q.values(null, 't', new List<String>{ 'c' });
            Assert.fail('Should have thrown QueryException for null rows');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('rows cannot be null'));
        }
    }

    @IsTest
    static void should_throw_exception_when_values_columns_contain_blank_name() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');
        List<List<Object>> rows = new List<List<Object>>{ new List<Object>{ 1 } };

        // Act & Assert
        try {
            q.values(rows, 'v', new List<String>{ ' ' });
            Assert.fail('Should have thrown QueryException for blank column');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('column cannot be blank'));
        }
    }

    @IsTest
    static void should_cover_internal_tostringlist_helper() {
        // Arrange
        List<Object> items = new List<Object>{ 1, 'Two', 3.0 };

        // Act
        SqlQuery q = new TestSqlQuery('t');
        q.groupByRollup(items);
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('GROUP BY ROLLUP (1, Two, 3.0)'));
    }

    @IsTest
    static void should_handle_complex_values_and_filtering() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');
        Date testDate = Date.newInstance(2023, 5, 20);
        List<List<Object>> rows = new List<List<Object>>{
            new List<Object>{ 1, true, testDate },
            new List<Object>{ 2, false, null }
        };
        List<String> cols = new List<String>{ 'Id', 'IsActive', 'CreatedDate' };

        // Act
        // Use values(), select specific fields (overriding implicit *), filter, and order
        q.values(rows, 'Users', cols)
            .field('Id')
            .field('CreatedDate')
            .addCondition('IsActive = true')
            .orderBy('CreatedDate', Query.SortOrder.DESCX);

        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.isTrue(sql.startsWith('SELECT Id, CreatedDate FROM (VALUES'));
        Assert.isTrue(sql.contains('AS Users (Id, IsActive, CreatedDate)'));
        Assert.isTrue(sql.contains('WHERE IsActive = true'));
        Assert.isTrue(sql.contains('ORDER BY CreatedDate DESC'));
        Assert.areEqual(1, binds.get('var$0'));
        Assert.areEqual(true, binds.get('var$1'));
        Assert.areEqual(testDate, binds.get('var$2'));
        Assert.areEqual(2, binds.get('var$3'));
        Assert.areEqual(false, binds.get('var$4'));
        Assert.areEqual(null, binds.get('var$5'));
    }

    @IsTest
    static void should_handle_values_with_set_operators() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('dummy');
        q1.values(new List<List<Object>>{ new List<Object>{ 1, 'v1' } }, 't1', new List<String>{ 'id', 'val' });

        SqlQuery q2 = new TestSqlQuery('dummy');
        q2.values(new List<List<Object>>{ new List<Object>{ 2, 'v2' } }, 't2', new List<String>{ 'id', 'val' });

        // Act
        String sql = q1.unionAll(q2).toString();

        // Assert
        Assert.areEqual(
            'SELECT * FROM (VALUES (:var$0, :var$1)) AS t1 (id, val) UNION ALL SELECT * FROM (VALUES (:var$2, :var$3)) AS t2 (id, val)',
            sql
        );
    }
    // </editor-fold>

    // <editor-fold desc="WHERE Clause">
    @IsTest
    static void should_handle_complex_where_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.wherex(
            new Query.Junction()
                .addOr(new SqlQuery.Condition().field('Name').eq('Test'))
                .addOr(
                    new Query.Junction()
                        .ands(
                            new SqlQuery.Condition().field('Type').eq('Other'),
                            new SqlQuery.Condition().field('Industry').eq('Banking')
                        )
                )
        );

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT * FROM account WHERE Name = :var$0 OR (Type = :var$1 AND Industry = :var$2)';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_nested_junctions_rigorously() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.wherex(
                SqlQuery.ors(
                    new SqlQuery.Condition().field('Name').eq('test'),
                    SqlQuery.ands(
                        new SqlQuery.Condition().field('Type').eq('other'),
                        new SqlQuery.Condition().field('Industry').eq('banking')
                    )
                )
            )
            .addCondition(
                SqlQuery.ors(
                    new SqlQuery.Condition().field('IsActive').isTrue(),
                    new SqlQuery.Condition().field('Status').eq('active')
                )
            );

        // Act
        String actual = q.toString();

        // Assert
        Assert.isTrue(
            actual.contains(
                'WHERE (Name = :var$0 OR (Type = :var$1 AND Industry = :var$2)) AND (IsActive = :var$3 OR Status = :var$4)'
            )
        );
    }

    @IsTest
    static void should_handle_null_operators_and_boolean_sugar() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.wherex(new SqlQuery.Condition().field('Name').isNull())
            .addCondition(new SqlQuery.Condition().field('Type').isNotNull())
            .addCondition(new SqlQuery.Condition().field('IsActive').isTrue())
            .addCondition(new SqlQuery.Condition().field('IsPartner').isFalse())
            .addCondition(new SqlQuery.Condition().id().isNotNull());

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT * FROM account WHERE Name IS NULL AND Type IS NOT NULL AND IsActive = :var$0 AND IsPartner = :var$1 AND Id IS NOT NULL';
        Assert.areEqual(expected, actual);
        Assert.areEqual(true, binds.get('var$0'));
        Assert.areEqual(false, binds.get('var$1'));
    }

    @IsTest
    static void should_handle_all_condition_operators() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.wherex(new SqlQuery.Condition().field('Name').ne('Test'))
            .addCondition(new SqlQuery.Condition().field('NumberOfEmployees').gt(10))
            .addCondition(new SqlQuery.Condition().field('NumberOfEmployees').ge(5))
            .addCondition(new SqlQuery.Condition().field('NumberOfEmployees').lt(100))
            .addCondition(new SqlQuery.Condition().field('NumberOfEmployees').le(200))
            .addCondition(new SqlQuery.Condition().field('Industry').likex('Bank%'))
            .addCondition(new SqlQuery.Condition().field('BillingCity').notLike('%York%'))
            .addCondition(new SqlQuery.Condition().field('Type').notIn(new List<String>{ 'Other', 'Prospect' }));

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT * FROM account WHERE Name != :var$0 AND NumberOfEmployees > :var$1 AND NumberOfEmployees >= :var$2 AND NumberOfEmployees < :var$3 AND NumberOfEmployees <= :var$4 AND Industry LIKE :var$5 AND BillingCity NOT LIKE :var$6 AND Type NOT IN :var$7';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_between_condition() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        q.wherex(new SqlQuery.Condition().field('price').between(10, 50));
        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual('SELECT * FROM products WHERE price BETWEEN :var$0 AND :var$1', sql);
        Assert.areEqual(10, binds.get('var$0'));
        Assert.areEqual(50, binds.get('var$1'));
    }

    @IsTest
    static void should_handle_collection_bindings() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');
        List<String> names = new List<String>{ 'Alice', 'Bob' };
        Set<Integer> ages = new Set<Integer>{ 25, 30 };

        // Act
        q.wherex(new SqlQuery.Condition().field('Name').inx(names))
            .addCondition(new SqlQuery.Condition().field('Age').notIn(ages));

        String sql = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual('SELECT * FROM users WHERE Name IN :var$0 AND Age NOT IN :var$1', sql);
        Assert.areEqual(names, binds.get('var$0'));
        Assert.areEqual(ages, binds.get('var$1'));
    }

    @IsTest
    static void should_throw_exception_when_in_values_are_empty() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act & Assert
        try {
            q.wherex(new SqlQuery.Condition().field('Name').inx(new List<String>()));
            Assert.fail('Should have thrown QueryException for empty IN values');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('IN values cannot be empty'));
        }
    }

    @IsTest
    static void should_throw_exception_when_not_in_values_are_empty() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act & Assert
        try {
            q.wherex(new SqlQuery.Condition().field('Age').notIn(new Set<Integer>()));
            Assert.fail('Should have thrown QueryException for empty NOT IN values');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('NOT IN values cannot be empty'));
        }
    }

    @IsTest
    static void should_use_static_logic_helpers() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');
        q.useBindingStrategy(Query.BindingStrategy.INDEXED)
            .field('name')
            .wherex(
                SqlQuery.ors(
                    new SqlQuery.Condition().field('category').eq('Electronics'),
                    SqlQuery.ands(
                        new SqlQuery.Condition().field('price').lt(100),
                        SqlQuery.notx(new SqlQuery.Condition().field('in_stock').eq(false))
                    )
                )
            );

        // Act
        String sql = q.toString();

        // Assert
        String expected = 'SELECT name FROM products WHERE (category = $1 OR (price < $2 AND (NOT in_stock = $3)))';
        Assert.areEqual(expected, sql);
    }

    @IsTest
    static void should_handle_collect_bindings_recursively() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('contact')
            .field('AccountId')
            .wherex(new SqlQuery.Condition().field('LastName').eq('doe'));

        SqlQuery q = new TestSqlQuery('account')
            .wherex(new SqlQuery.Condition().field('Id').inx(sub))
            .addCondition(new SqlQuery.Condition().field('Type').eq('customer'));

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT * FROM account WHERE Id IN (SELECT AccountId FROM contact WHERE LastName = :var$0) AND Type = :var$1';
        Assert.areEqual(expected, actual);
        Assert.areEqual('doe', binds.get('var$0'));
        Assert.areEqual('customer', binds.get('var$1'));
    }

    @IsTest
    static void should_handle_binding_strategies() {
        // Arrange
        SqlQuery qIndexed = new TestSqlQuery('users');
        SqlQuery qAnon = new TestSqlQuery('users');
        SqlQuery qNamed = new TestSqlQuery('users');

        qIndexed.useBindingStrategy(Query.BindingStrategy.INDEXED)
            .field('id')
            .addCondition(new SqlQuery.Condition().field('name').eq('Alice'))
            .addCondition(new SqlQuery.Condition().field('age').gt(30));

        qAnon.useBindingStrategy(Query.BindingStrategy.ANONYMOUS)
            .field('id')
            .wherex(new SqlQuery.Condition().field('name').eq('Bob'))
            .addCondition(new SqlQuery.Condition().field('age').lt(50));

        qNamed.field('id').wherex(new SqlQuery.Condition().field('x').eq(100));

        // Act
        String indexedSql = qIndexed.toString();
        String anonSql = qAnon.toString();
        String namedSql = qNamed.toString();

        Map<String, Object> iBinds = qIndexed.getBindings();
        Map<String, Object> aBinds = qAnon.getBindings();

        // Assert
        Assert.areEqual('SELECT id FROM users WHERE name = $1 AND age > $2', indexedSql);
        Assert.areEqual('Alice', iBinds.get('$1'));
        Assert.areEqual(30, iBinds.get('$2'));

        Assert.areEqual('SELECT id FROM users WHERE name = ? AND age < ?', anonSql);
        Assert.areEqual('Bob', aBinds.get('?1'));
        Assert.areEqual(50, aBinds.get('?2'));

        Assert.areEqual('SELECT id FROM users WHERE x = :var$0', namedSql);
    }

    @IsTest
    static void should_use_configured_binding_strategy_when_executing_via_driver() {
        // Arrange
        TestSqlQuery qIndexed = new TestSqlQuery('users');
        qIndexed
            .useBindingStrategy(Query.BindingStrategy.INDEXED)
            .field('id')
            .wherex(new SqlQuery.Condition().field('name').eq('Alice'))
            .addCondition(new SqlQuery.Condition().field('age').gt(30));
        MockDriver indexedDriver = (MockDriver) qIndexed.driver;

        TestSqlQuery qAnonymous = new TestSqlQuery('users');
        qAnonymous
            .useBindingStrategy(Query.BindingStrategy.ANONYMOUS)
            .field('id')
            .wherex(new SqlQuery.Condition().field('name').eq('Bob'))
            .addCondition(new SqlQuery.Condition().field('age').lt(50));
        MockDriver anonymousDriver = (MockDriver) qAnonymous.driver;

        // Act
        qIndexed.fetch();
        String indexedFetchSql = indexedDriver.lastQuery;
        Map<String, Object> indexedFetchBinds = indexedDriver.lastBindings;

        qIndexed.fetchCount();
        String indexedCountSql = indexedDriver.lastQuery;
        Map<String, Object> indexedCountBinds = indexedDriver.lastBindings;

        qAnonymous.fetch();
        String anonymousFetchSql = anonymousDriver.lastQuery;
        Map<String, Object> anonymousFetchBinds = anonymousDriver.lastBindings;

        // Assert
        Assert.areEqual('SELECT id FROM users WHERE name = $1 AND age > $2', indexedFetchSql);
        Assert.areEqual('Alice', indexedFetchBinds.get('$1'));
        Assert.areEqual(30, indexedFetchBinds.get('$2'));

        Assert.areEqual('SELECT COUNT(*) FROM users WHERE name = $1 AND age > $2', indexedCountSql);
        Assert.areEqual('Alice', indexedCountBinds.get('$1'));
        Assert.areEqual(30, indexedCountBinds.get('$2'));

        Assert.areEqual('SELECT id FROM users WHERE name = ? AND age < ?', anonymousFetchSql);
        Assert.areEqual('Bob', anonymousFetchBinds.get('?1'));
        Assert.areEqual(50, anonymousFetchBinds.get('?2'));
    }

    // <editor-fold desc="Subquery Operators">
    @IsTest
    static void should_generate_exists_condition() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('orders').field('id').wherex(new SqlQuery.Condition().field('total').gt(100));
        SqlQuery q = new TestSqlQuery('customers');

        // Act
        q.wherex(SqlQuery.exists(sub));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM customers WHERE EXISTS (SELECT id FROM orders WHERE total > :var$0)', actual);
        Assert.areEqual(100, q.getBindings().get('var$0'));
    }

    @IsTest
    static void should_generate_any_condition() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('orders').field('id');
        SqlQuery q = new TestSqlQuery('customers');

        // Act
        q.wherex(new SqlQuery.Condition().field('status').eq(SqlQuery.any(sub)));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM customers WHERE status = ANY (SELECT id FROM orders)', actual);
    }

    @IsTest
    static void should_generate_some_condition() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('orders').field('id');
        SqlQuery q = new TestSqlQuery('customers');

        // Act
        q.wherex(new SqlQuery.Condition().field('status').ne(SqlQuery.some(sub)));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM customers WHERE status != SOME (SELECT id FROM orders)', actual);
    }

    @IsTest
    static void should_generate_all_condition() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('products').field('price');
        SqlQuery q = new TestSqlQuery('orders');

        // Act
        q.wherex(new SqlQuery.Condition().field('total').gt(SqlQuery.all(sub)));
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM orders WHERE total > ALL (SELECT price FROM products)', actual);
    }

    @IsTest
    static void should_handle_complex_subquery_combinations() {
        // Arrange
        SqlQuery subOrders = new TestSqlQuery('orders')
            .field('id')
            .wherex(new SqlQuery.Condition().field('total').gt(500));
        SqlQuery subProducts = new TestSqlQuery('products')
            .field('price')
            .wherex(new SqlQuery.Condition().field('type').eq('premium'));

        SqlQuery q = new TestSqlQuery('customers');
        q.wherex(
                new Query.Junction()
                    .ors(
                        SqlQuery.exists(subOrders),
                        new SqlQuery.Condition().field('credit_score').gt(SqlQuery.all(subProducts))
                    )
            )
            .addCondition(new SqlQuery.Condition().field('status').ne(SqlQuery.any(subOrders)));

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT * FROM customers WHERE (EXISTS (SELECT id FROM orders WHERE total > :var$0) OR credit_score > ALL (SELECT price FROM products WHERE type = :var$1)) AND status != ANY (SELECT id FROM orders WHERE total > :var$2)';
        Assert.areEqual(expected, actual);
        Assert.areEqual(500, binds.get('var$0'));
        Assert.areEqual('premium', binds.get('var$1'));
        Assert.areEqual(500, binds.get('var$2'));
    }

    @IsTest
    static void should_handle_quantified_subqueries_with_complex_filters() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('logs')
            .field('level')
            .wherex(new SqlQuery.Condition().field('type').eq('internal'))
            .lim(10);

        SqlQuery q = new TestSqlQuery('audit');

        // Act
        q.wherex(new SqlQuery.Condition().field('severity').eq(SqlQuery.any(sub)));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('WHERE severity = ANY (SELECT level FROM logs WHERE type = :var$0 LIMIT 10)'));
        Assert.areEqual('internal', q.getBindings().get('var$0'));
    }

    @IsTest
    static void should_throw_exception_when_with_subquery_is_null() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.with('cte', null);
            Assert.fail('Should have thrown QueryException for null subquery');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('subquery cannot be null'));
        }
    }

    @IsTest
    static void should_handle_subquery_operators() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('orders', 'o').field('o.Id').wherex('o.CustId = c.Id');
        SqlQuery q = new TestSqlQuery('customers', 'c');

        // Act
        q.wherex(SqlQuery.exists(sub))
            .addCondition(
                new SqlQuery.Condition().field('Rating').gt(SqlQuery.any(new TestSqlQuery('ratings').field('val')))
            )
            .addCondition(
                new SqlQuery.Condition().field('Score').lt(SqlQuery.all(new TestSqlQuery('scores').field('s')))
            )
            .addCondition(
                new SqlQuery.Condition().field('Type').eq(SqlQuery.some(new TestSqlQuery('types').field('t')))
            );

        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('WHERE EXISTS (SELECT o.Id FROM orders o WHERE o.CustId = c.Id)'));
        Assert.isTrue(sql.contains('AND Rating > ANY (SELECT val FROM ratings)'));
        Assert.isTrue(sql.contains('AND Score < ALL (SELECT s FROM scores)'));
        Assert.isTrue(sql.contains('AND Type = SOME (SELECT t FROM types)'));
    }

    @IsTest
    static void should_handle_negated_exists() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('orders').field('Id').wherex('CustId = c.Id');
        SqlQuery q = new TestSqlQuery('customers', 'c').wherex(SqlQuery.notx(SqlQuery.exists(sub)));

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT * FROM customers c WHERE (NOT EXISTS (SELECT Id FROM orders WHERE CustId = c.Id))',
            sql
        );
    }

    @IsTest
    static void should_handle_byId_and_byIds() {
        // Arrange
        String testId1 = '00000001';
        String testId2 = '00000002';
        List<String> testIds = new List<String>{ testId1, testId2 };

        // Act
        SqlQuery q1 = new TestSqlQuery('account').byId(testId1);
        SqlQuery q2 = new TestSqlQuery('contact').byIds(testIds);

        // Assert
        Assert.areEqual('SELECT * FROM account WHERE Id = :var$0', q1.toString());
        Assert.areEqual(testId1, q1.getBindings().get('var$0'));
        Assert.areEqual('SELECT * FROM contact WHERE Id IN :var$0', q2.toString());
        Assert.areEqual(testIds, q2.getBindings().get('var$0'));
    }

    @IsTest
    static void should_handle_where_condition_chaining_and_or() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('products')
            .wherex(new SqlQuery.Condition().field('Category').eq('Electronics'))
            .addConditionAnd(new SqlQuery.Condition().field('Price').lt(1000));

        SqlQuery q2 = new TestSqlQuery('orders')
            .wherex(new SqlQuery.Condition().field('Status').eq('New'))
            .addConditionOr('Priority = \'High\'');

        // Act
        String sql1 = q1.toString();
        String sql2 = q2.toString();

        // Assert
        Assert.isTrue(sql1.contains('WHERE Category = :var$0 AND Price < :var$1'));
        Assert.isTrue(sql2.contains('WHERE Status = :var$0 OR Priority = \'High\''));

        // Additional raw string overloads
        SqlQuery q3 = new TestSqlQuery('t')
            .wherex(SqlQuery.ands(SqlQuery.COND.field('a').eq(1), SqlQuery.COND.field('b').eq(2)))
            .addConditionOr('c=3');

        Assert.areEqual('SELECT * FROM t WHERE (a = :var$0 AND b = :var$1) OR c=3', q3.toString());

        Map<String, Object> binds = q3.getBindings();
        Assert.areEqual(1, binds.get('var$0'));
        Assert.areEqual(2, binds.get('var$1'));

        // Raw string AND overload
        SqlQuery q4 = new TestSqlQuery('t').wherex('a=1').addConditionAnd('b=2');
        Assert.areEqual('SELECT * FROM t WHERE a=1 AND b=2', q4.toString());
    }

    @IsTest
    static void should_handle_where_convenience_methods() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('orders').addConditionNe('Status', 'Cancelled');
        SqlQuery q2 = new TestSqlQuery('users').addConditionNotIn('Role', new List<String>{ 'Admin', 'SuperUser' });
        SqlQuery q3 = new TestSqlQuery('accounts')
            .addConditionNotIn('Id', new TestSqlQuery('blacklist').field('AccountId'));

        // Act & Assert
        Assert.areEqual('SELECT * FROM orders WHERE Status != :var$0', q1.toString());
        Assert.areEqual('SELECT * FROM users WHERE Role NOT IN :var$0', q2.toString());
        Assert.areEqual('SELECT * FROM accounts WHERE Id NOT IN (SELECT AccountId FROM blacklist)', q3.toString());
    }
    // </editor-fold>

    // <editor-fold desc="GROUP BY Clause">
    @IsTest
    static void should_handle_grouping_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');
        q.grouping('Type').grouping('Industry', 'indGrouping');

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT GROUPING(Type), GROUPING(Industry) indGrouping FROM account';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_grouping_variants() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .field('Type')
            .field('Industry')
            .field('Status')
            .groupByRollup(new List<String>{ 'Type', 'Industry' })
            .groupByCube('Status');

        // Act
        String actual = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT Type, Industry, Status FROM account GROUP BY ROLLUP (Type, Industry), CUBE (Status)',
            actual
        );
    }

    @IsTest
    static void should_handle_grouping_sets_2() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .field('Region')
            .field('Product')
            .field(SqlQuery.AGG.sum('Amount'))
            .groupByGroupingSets(
                new List<Object>{
                    new List<String>{ 'Region', 'Product' },
                    new List<String>{ 'Region' },
                    new List<String>{}
                }
            );

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('GROUP BY GROUPING SETS ((Region, Product), (Region), ())'));
    }

    @IsTest
    static void should_handle_grouping_function() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .field('Region')
            .field('Product')
            .field(SqlQuery.AGG.sum('Amount'), 'Total')
            .grouping('Region')
            .groupBy(new List<String>{ 'Region', 'Product' });

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('SELECT Region, Product, SUM(Amount) Total, GROUPING(Region) FROM sales'));
    }

    @IsTest
    static void should_handle_grouping_sets() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');
        q.field('Region')
            .field('Year')
            .field(SqlQuery.AGG.sum('Amount'), 'Total')
            .groupByGroupingSets(new List<Object>{ new List<String>{ 'Region', 'Year' }, 'Region', '()' });

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT Region, Year, SUM(Amount) Total FROM sales GROUP BY GROUPING SETS ((Region, Year), Region, ())';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_complex_grouping_elements() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');
        q.groupBy('a')
            .groupByRollup(new List<String>{ 'b', 'c' })
            .groupByCube('d')
            .groupByGroupingSets(new List<Object>{ 'e', '()' });

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT * FROM sales GROUP BY a, ROLLUP (b, c), CUBE (d), GROUPING SETS (e, ())';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_grouping_facades_with_single_elements() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.groupByRollup('Type').groupByCube('Status').groupBy(new List<String>{ 'Industry' });
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('GROUP BY ROLLUP (Type), CUBE (Status), Industry'));
    }

    @IsTest
    static void should_handle_iterable_grouping_overloads() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');
        List<Object> rollupElements = new List<Object>{ 'a', 'b' };
        List<Object> cubeElements = new List<Object>{ 'c', 'd' };

        // Act
        q.groupByRollup(rollupElements).groupByCube(cubeElements);
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('GROUP BY ROLLUP (a, b), CUBE (c, d)'));
    }

    @IsTest
    static void should_handle_grouping_sets_rollup_cube() {
        // Act & Assert
        Assert.areEqual('GROUPING SETS (a, b)', SqlQuery.groupingSets(new List<Object>{ 'a', 'b' }));
        Assert.areEqual('ROLLUP (a)', SqlQuery.rollup('a'));
        Assert.areEqual('ROLLUP (a, b)', SqlQuery.rollup(new List<Object>{ 'a', 'b' }));
        Assert.areEqual('CUBE (a)', SqlQuery.cube('a'));
        Assert.areEqual('CUBE (a, b)', SqlQuery.cube(new List<Object>{ 'a', 'b' }));
    }
    // </editor-fold>

    // <editor-fold desc="LIMIT / OFFSET">
    @IsTest
    static void should_handle_limit() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').lim(10);

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account LIMIT 10', sql);
    }

    @IsTest
    static void should_handle_offset() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').offset(20);

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account OFFSET 20', sql);
    }

    @IsTest
    static void should_throw_exception_on_negative_limit() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act & Assert
        try {
            q.lim(-1);
            Assert.fail('Should have thrown exception');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('LIMIT must be >= 0'));
        }
    }

    @IsTest
    static void should_throw_exception_on_negative_offset() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act & Assert
        try {
            q.offset(-1);
            Assert.fail('Should have thrown exception');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('OFFSET must be >= 0'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="HAVING Clause">
    @IsTest
    static void should_handle_having_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .field('Type')
            .field('COUNT(Id)', 'cnt')
            .groupBy('Type')
            .havingx(new SqlQuery.Condition().field('COUNT(Id)').gt(5));

        // Act
        String actual = q.toString();

        // Assert
        Assert.areEqual('SELECT Type, COUNT(Id) cnt FROM account GROUP BY Type HAVING COUNT(Id) > :var$0', actual);
        Assert.areEqual(5, q.getBindings().get('var$0'));
    }

    @IsTest
    static void should_handle_having_without_group_by() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .field('SUM(AnnualRevenue)')
            .havingx(new SqlQuery.Condition().field('SUM(AnnualRevenue)').gt(1000000));

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT SUM(AnnualRevenue) FROM account HAVING SUM(AnnualRevenue) > :var$0', sql);
    }

    @IsTest
    static void should_handle_multiple_having_conditions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders')
            .groupBy('CustomerId')
            .havingx(new SqlQuery.Condition().field('COUNT(Id)').gt(5))
            .addHaving(new SqlQuery.Condition().field('SUM(Total)').lt(10000));

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT * FROM orders GROUP BY CustomerId HAVING COUNT(Id) > :var$0 AND SUM(Total) < :var$1',
            sql
        );
        Assert.areEqual(5, q.getBindings().get('var$0'));
        Assert.areEqual(10000, q.getBindings().get('var$1'));

        // Additional raw string overloads
        SqlQuery q2 = new TestSqlQuery('t')
            .havingx(SqlQuery.ands(SqlQuery.COND.field('a').gt(1), SqlQuery.COND.field('b').eq(2)))
            .addHavingOr('c < 3');
        Assert.areEqual('SELECT * FROM t HAVING (a > :var$0 AND b = :var$1) OR c < 3', q2.toString());
        Assert.areEqual(1, q2.getBindings().get('var$0'));
        Assert.areEqual(2, q2.getBindings().get('var$1'));

        // Raw string overloads
        SqlQuery q3 = new TestSqlQuery('t').groupBy('g').havingx('a > 1').addHavingAnd('b = 2').addHaving('c=3');
        Assert.areEqual('SELECT * FROM t GROUP BY g HAVING a > 1 AND b = 2 AND c=3', q3.toString());
    }

    @IsTest
    static void should_handle_complex_having_logic() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .groupBy('Region')
            .havingx(
                SqlQuery.ors(
                    new SqlQuery.Condition().field('SUM(Profit)').gt(1000),
                    SqlQuery.ands(
                        new SqlQuery.Condition().field('AVG(Margin)').gt(0.2),
                        new SqlQuery.Condition().field('COUNT(Id)').ge(10)
                    )
                )
            );

        // Act
        String sql = q.toString();

        // Assert
        String expected = 'SELECT * FROM sales GROUP BY Region HAVING (SUM(Profit) > :var$0 OR (AVG(Margin) > :var$1 AND COUNT(Id) >= :var$2))';
        Assert.areEqual(expected, sql);
    }

    @IsTest
    static void should_handle_having_with_subqueries() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('targets').field('TargetAmount').wherex('Year = 2023');
        SqlQuery q = new TestSqlQuery('sales')
            .groupBy('RepId')
            .havingx(SqlQuery.COND.field('SUM(Amount)').gt(SqlQuery.any(sub)));

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual(
            'SELECT * FROM sales GROUP BY RepId HAVING SUM(Amount) > ANY (SELECT TargetAmount FROM targets WHERE Year = 2023)',
            sql
        );
    }

    @IsTest
    static void should_handle_having_binds() {
        // Arrange
        SqlQuery q = new TestSqlQuery('logs')
            .groupBy('Level')
            .havingx(new SqlQuery.Condition().field('COUNT(Id)').gt(100))
            .addHavingEq('MAX(Severity)', 'High');

        // Act
        Map<String, Object> binds = q.getBindings();

        // Assert
        Assert.areEqual(100, binds.get('var$0'));
        Assert.areEqual('High', binds.get('var$1'));
    }

    @IsTest
    static void should_handle_having_condition_chaining_and_or() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('transactions')
            .groupBy('AccountId')
            .havingx(new SqlQuery.Condition().field('COUNT(Id)').gt(10))
            .addHavingAnd(new SqlQuery.Condition().field('SUM(Amount)').gt(5000));

        SqlQuery q2 = new TestSqlQuery('sales')
            .groupBy('Region')
            .havingx('SUM(Total) > 1000')
            .addHavingAnd('COUNT(Id) > 5');

        // Act
        String sql1 = q1.toString();
        String sql2 = q2.toString();

        // Assert
        Assert.isTrue(sql1.contains('HAVING COUNT(Id) > :var$0 AND SUM(Amount) > :var$1'));
        Assert.isTrue(sql2.contains('HAVING SUM(Total) > 1000 AND COUNT(Id) > 5'));
    }

    @IsTest
    static void should_handle_having_in_convenience() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .groupBy('Region')
            .havingx('SUM(Total) > 1000')
            .addHavingIn('Region', new List<String>{ 'North', 'South', 'East' });

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM sales GROUP BY Region HAVING SUM(Total) > 1000 AND Region IN :var$0', sql);
        Assert.areEqual(new List<String>{ 'North', 'South', 'East' }, q.getBindings().get('var$0'));
    }

    @IsTest
    static void should_cover_having_condition_aggregate_methods() {
        // Arrange & Act
        SqlQuery q1 = new TestSqlQuery('orders')
            .groupBy('Status')
            .havingx(new SqlQuery.HavingCondition('raw_agg > 10'));
        Assert.areEqual('SELECT * FROM orders GROUP BY Status HAVING raw_agg > 10', q1.toString());

        // Arrange & Act
        SqlQuery q2 = new TestSqlQuery('sales')
            .groupBy('Region')
            .havingx(new SqlQuery.HavingCondition().countDistinct('CustomerId').gt(5));
        Assert.areEqual(
            'SELECT * FROM sales GROUP BY Region HAVING COUNT(DISTINCT CustomerId) > :var$0',
            q2.toString()
        );
        Assert.areEqual(5, q2.getBindings().get('var$0'));

        // Arrange & Act
        SqlQuery q3 = new TestSqlQuery('logs')
            .groupBy('Level')
            .havingx(new SqlQuery.HavingCondition().countAll().ge(100));
        Assert.areEqual('SELECT * FROM logs GROUP BY Level HAVING COUNT(*) >= :var$0', q3.toString());

        // Arrange & Act
        SqlQuery q4 = new TestSqlQuery('products')
            .groupBy('Category')
            .havingx(new SqlQuery.HavingCondition().avg('Price').gt(50))
            .addHaving(new SqlQuery.HavingCondition().min('Stock').ge(10))
            .addHaving(new SqlQuery.HavingCondition().max('Rating').le(5));
        String sql4 = q4.toString();
        Assert.isTrue(sql4.contains('HAVING AVG(Price) > :var$0'));
        Assert.isTrue(sql4.contains('AND MIN(Stock) >= :var$1'));
        Assert.isTrue(sql4.contains('AND MAX(Rating) <= :var$2'));
    }
    // </editor-fold>

    // <editor-fold desc="WINDOW Clause">
    @IsTest
    static void should_generate_rank_and_row_number() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field('Name')
            .field(SqlQuery.WIN.rank().orderBy('Salary', Query.SortOrder.DESCX).toString(), 'rnk')
            .field(SqlQuery.WIN.rowNumber().orderBy('Id').toString(), 'row_num');

        // Assert
        String actual = q.toString();
        String expected = 'SELECT Name, RANK() OVER (ORDER BY Salary DESC) rnk, ROW_NUMBER() OVER (ORDER BY Id) row_num FROM emp';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_partition_and_ordering() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(
            SqlQuery.WIN.avg('Salary').partitionBy('Department').orderBy('Salary', Query.SortOrder.DESCX).toString(),
            'avg_sal'
        );

        // Assert
        String actual = q.toString();
        String expected = 'SELECT AVG(Salary) OVER (PARTITION BY Department ORDER BY Salary DESC) avg_sal FROM emp';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_window_specification_overloads() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');

        // Act
        q.field(
            SqlQuery.WIN.sum('Amount')
                .partitionBy(new List<String>{ 'Region', 'Year' })
                .orderBy('Amount', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_FIRST)
                .toString(),
            'total'
        );
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('PARTITION BY Region, Year'));
        Assert.isTrue(sql.contains('ORDER BY Amount DESC NULLS FIRST'));
    }

    @IsTest
    static void should_handle_window_frames_with_offsets() {
        // Arrange
        SqlQuery q = new TestSqlQuery('logs');

        // Act
        q.field(SqlQuery.WIN.count('Id').orderBy('CreatedDate').rowsBetween(-1, 0).toString(), 'prev_and_current');
        q.field(SqlQuery.WIN.count('Id').orderBy('CreatedDate').rowsBetween(0, 1).toString(), 'current_and_next');
        q.field(SqlQuery.WIN.count('Id').orderBy('CreatedDate').rowsBetween(-5, 5).toString(), 'range_window');
        q.field(SqlQuery.WIN.count('Id').orderBy('CreatedDate').rowsUnboundedPreceding().toString(), 'running_total');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('ROWS BETWEEN 1 PRECEDING AND CURRENT ROW'));
        Assert.isTrue(sql.contains('ROWS BETWEEN CURRENT ROW AND 1 FOLLOWING'));
        Assert.isTrue(sql.contains('ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING'));
        Assert.isTrue(sql.contains('ROWS UNBOUNDED PRECEDING'));

        // Current row bound
        SqlQuery q2 = new TestSqlQuery('t')
            .field(SqlQuery.WIN.count('*').orderBy('id').rowsBetween(0, 5).toString(), 'f');
        Assert.isTrue(q2.toString().contains('ROWS BETWEEN CURRENT ROW AND 5 FOLLOWING'));

        // ROWS CURRENT ROW
        SqlQuery q3 = new TestSqlQuery('t').field(SqlQuery.WIN.sum('x').rowsCurrentRow().toString(), 'r');
        Assert.areEqual('SELECT SUM(x) OVER (ROWS CURRENT ROW) r FROM t', q3.toString());
    }

    @IsTest
    static void should_construct_via_of() {
        Assert.isNotNull(SqlQuery.of('accounts'));
        Assert.isNotNull(SqlQuery.of('accounts', 'a'));
    }

    @IsTest
    static void should_ignore_blank_field_aliases() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t');

        // Act
        q.field('f', ' ').field('f2', '');

        // Assert
        Assert.areEqual('SELECT f, f2 FROM t', q.toString());
    }

    @IsTest
    static void should_support_subqueries_in_select_clause() {
        // Arrange
        SqlQuery sub = new TestSqlQuery('sub');
        SqlQuery q = new TestSqlQuery('t');

        // Act
        q.field(sub);

        // Assert
        Assert.areEqual('SELECT (SELECT * FROM sub) FROM t', q.toString());
    }

    @IsTest
    static void should_generate_lead_lag_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.lead('Salary', 1).orderBy('Id').toString(), 'next_sal')
            .field(SqlQuery.WIN.lag('Salary', 2).orderBy('Id').toString(), 'prev_sal');

        // Assert
        String actual = q.toString();
        Assert.isTrue(actual.contains('LEAD(Salary, 1) OVER (ORDER BY Id) next_sal'));
        Assert.isTrue(actual.contains('LAG(Salary, 2) OVER (ORDER BY Id) prev_sal'));
    }

    @IsTest
    static void should_handle_empty_over_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.count('Id').toString(), 'total_count');

        // Assert
        Assert.isTrue(q.toString().contains('COUNT(Id) OVER () total_count'));
    }

    @IsTest
    static void should_handle_window_partition_iterable() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');
        List<String> parts = new List<String>{ 'Dep', 'Region' };

        // Act
        q.field(SqlQuery.WIN.sum('Sales').partitionBy(parts).toString(), 'total_sales');

        // Assert
        Assert.isTrue(q.toString().contains('SUM(Sales) OVER (PARTITION BY Dep, Region) total_sales'));
    }

    @IsTest
    static void should_handle_raw_window_function() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.raw('NTILE(4)').orderBy('Salary').toString(), 'quartile');

        // Assert
        Assert.areEqual('SELECT NTILE(4) OVER (ORDER BY Salary) quartile FROM emp', q.toString());
    }

    @IsTest
    static void should_generate_dense_rank() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.denseRank().orderBy('Score').toString(), 'd_rnk');

        // Assert
        Assert.areEqual('SELECT DENSE_RANK() OVER (ORDER BY Score) d_rnk FROM emp', q.toString());
    }

    @IsTest
    static void should_handle_percent_rank_and_cume_dist() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.percentRank().orderBy('Salary').toString(), 'pct_rnk')
            .field(SqlQuery.WIN.cumeDist().orderBy('Salary').toString(), 'cume_dst');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('PERCENT_RANK() OVER (ORDER BY Salary) pct_rnk'));
        Assert.isTrue(sql.contains('CUME_DIST() OVER (ORDER BY Salary) cume_dst'));
    }

    @IsTest
    static void should_handle_ntile_and_nth_value() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.ntile(4).orderBy('Salary').toString(), 'quartile')
            .field(SqlQuery.WIN.nthValue('Salary', 2).orderBy('Salary').toString(), 'second_val');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('NTILE(4) OVER (ORDER BY Salary) quartile'));
        Assert.isTrue(sql.contains('NTH_VALUE(Salary, 2) OVER (ORDER BY Salary) second_val'));
    }

    @IsTest
    static void should_handle_window_frames() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        // ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        q.field(SqlQuery.WIN.sum('Salary').orderBy('Salary').rowsBetween(-3, 0).toString(), 'moving_sum');
        // ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING
        q.field(SqlQuery.WIN.avg('Salary').orderBy('Salary').rowsBetween(0, 3).toString(), 'future_avg');
        // RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        q.field(
            SqlQuery.WIN.count('*').orderBy('Salary').rangeBetween('UNBOUNDED PRECEDING', 'CURRENT ROW').toString(),
            'running_count'
        );
        // ROWS UNBOUNDED PRECEDING
        q.field(SqlQuery.WIN.max('Salary').orderBy('Salary').rowsUnboundedPreceding().toString(), 'max_so_far');

        // Assert
        String sql = q.toString();
        Assert.isTrue(
            sql.contains('SUM(Salary) OVER (ORDER BY Salary ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) moving_sum')
        );
        Assert.isTrue(
            sql.contains('AVG(Salary) OVER (ORDER BY Salary ROWS BETWEEN CURRENT ROW AND 3 FOLLOWING) future_avg')
        );
        Assert.isTrue(
            sql.contains(
                'COUNT(*) OVER (ORDER BY Salary RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) running_count'
            )
        );
        Assert.isTrue(sql.contains('MAX(Salary) OVER (ORDER BY Salary ROWS UNBOUNDED PRECEDING) max_so_far'));
    }

    @IsTest
    static void should_handle_over_clause_with_multiple_parameters() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(
            SqlQuery.WIN.sum('Salary')
                .partitionBy('Dept')
                .partitionBy('Region')
                .orderBy('Salary', Query.SortOrder.DESCX)
                .toString(),
            'total_sal'
        );

        // Assert
        Assert.isTrue(
            q.toString().contains('SUM(Salary) OVER (PARTITION BY Dept, Region ORDER BY Salary DESC) total_sal')
        );
    }

    @IsTest
    static void should_generate_lead_lag_defaults() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.lead('NextVal').orderBy('Id').toString(), 'lead_val')
            .field(SqlQuery.WIN.lag('PrevVal').orderBy('Id').toString(), 'lag_val');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('LEAD(NextVal) OVER (ORDER BY Id) lead_val'));
        Assert.isTrue(sql.contains('LAG(PrevVal) OVER (ORDER BY Id) lag_val'));
    }

    @IsTest
    static void should_generate_first_last_value() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.firstValue('First').orderBy('Id').toString(), 'fv')
            .field(SqlQuery.WIN.lastValue('Last').orderBy('Id').toString(), 'lv');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('FIRST_VALUE(First) OVER (ORDER BY Id) fv'));
        Assert.isTrue(sql.contains('LAST_VALUE(Last) OVER (ORDER BY Id) lv'));
    }

    @IsTest
    static void should_generate_windowed_min_max() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(SqlQuery.WIN.min('MinVal').partitionBy('Group').toString(), 'min_v')
            .field(SqlQuery.WIN.max('MaxVal').partitionBy('Group').toString(), 'max_v');

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('MIN(MinVal) OVER (PARTITION BY Group) min_v'));
        Assert.isTrue(sql.contains('MAX(MaxVal) OVER (PARTITION BY Group) max_v'));
    }

    @IsTest
    static void should_handle_advanced_ordering_options() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field(
            SqlQuery.WIN.rank().orderBy('Nulls', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST).toString(),
            'ord_nulls'
        );

        // Assert
        Assert.areEqual('SELECT RANK() OVER (ORDER BY Nulls ASC NULLS LAST) ord_nulls FROM emp', q.toString());
    }

    @IsTest
    static void should_handle_multiple_window_functions_same_query() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        q.field('Name')
            .field(SqlQuery.WIN.rowNumber().partitionBy('Dept').orderBy('Salary').toString(), 'row_num')
            .field(SqlQuery.WIN.avg('Salary').partitionBy('Dept').toString(), 'avg_sal');

        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('ROW_NUMBER() OVER (PARTITION BY Dept ORDER BY Salary) row_num'));
        Assert.isTrue(sql.contains('AVG(Salary) OVER (PARTITION BY Dept) avg_sal'));
    }

    @IsTest
    static void should_use_literal_in_window_functions() {
        // Arrange
        SqlQuery q = new TestSqlQuery('emp');

        // Act
        // Strings are treated as column names directly - no literal() needed
        q.field(SqlQuery.WIN.lead('Salary', 1).partitionBy('Department').orderBy('Salary').toString(), 'next_sal');

        // Assert
        String sql = q.toString();
        Assert.areEqual('SELECT LEAD(Salary, 1) OVER (PARTITION BY Department ORDER BY Salary) next_sal FROM emp', sql);
        Assert.isTrue(q.getBindings().isEmpty(), 'Should have no bindings for column names');
    }
    // </editor-fold>

    // <editor-fold desc="Set Operations">
    @IsTest
    static void should_render_union_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.union(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 UNION SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_union_all_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.unionAll(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 UNION ALL SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_intersect_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.intersect(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 INTERSECT SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_intersect_all_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.intersectAll(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 INTERSECT ALL SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_except_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.except(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 EXCEPT SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_except_all_query() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');

        // Act
        String result = q1.exceptAll(q2).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 EXCEPT ALL SELECT Id FROM table2', result);
    }

    @IsTest
    static void should_render_multiple_set_operators() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id');
        SqlQuery q3 = new TestSqlQuery('table3').field('Id');

        // Act
        String result = q1.union(q2).intersect(q3).toString();

        // Assert
        Assert.areEqual('SELECT Id FROM table1 UNION SELECT Id FROM table2 INTERSECT SELECT Id FROM table3', result);
    }

    @IsTest
    static void should_collect_binds_from_union_queries() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id').addConditionEq('Name', 'Alpha');
        SqlQuery q2 = new TestSqlQuery('table2').field('Id').addConditionEq('Name', 'Beta');

        // Act
        q1.union(q2);
        String result = q1.toString();
        Map<String, Object> binds = q1.getBindings();

        // Assert
        Assert.areEqual(
            'SELECT Id FROM table1 WHERE Name = :var$0 UNION SELECT Id FROM table2 WHERE Name = :var$1',
            result
        );
        Assert.areEqual('Alpha', binds.get('var$0'));
        Assert.areEqual('Beta', binds.get('var$1'));
    }

    @IsTest
    static void should_handle_nested_union_with_binds() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Id').addConditionEq('A', 1);
        SqlQuery q2 = new TestSqlQuery('table2').field('Id').addConditionEq('B', 2);
        SqlQuery q3 = new TestSqlQuery('table3').field('Id').addConditionEq('C', 3);

        // Act
        q1.union(q2.union(q3));
        String result = q1.toString();
        Map<String, Object> binds = q1.getBindings();

        // Assert
        String expected = 'SELECT Id FROM table1 WHERE A = :var$0 UNION SELECT Id FROM table2 WHERE B = :var$1 UNION SELECT Id FROM table3 WHERE C = :var$2';
        Assert.areEqual(expected, result);
        Assert.areEqual(1, binds.get('var$0'));
        Assert.areEqual(2, binds.get('var$1'));
        Assert.areEqual(3, binds.get('var$2'));
    }

    @IsTest
    static void should_handle_set_operator_in_where_subquery() {
        // Arrange
        SqlQuery sub1 = new TestSqlQuery('table_sub1').field('Id').addConditionEq('Status', 'active');
        SqlQuery sub2 = new TestSqlQuery('table_sub2').field('Id').addConditionEq('Status', 'pending');
        sub1.union(sub2);

        SqlQuery main = new TestSqlQuery('main_table').field('Name').addConditionIn('Id', sub1);

        // Act
        String result = main.toString();
        Map<String, Object> binds = main.getBindings();

        // Assert
        String expected = 'SELECT Name FROM main_table WHERE Id IN (SELECT Id FROM table_sub1 WHERE Status = :var$0 UNION SELECT Id FROM table_sub2 WHERE Status = :var$1)';
        Assert.areEqual(expected, result);
        Assert.areEqual('active', binds.get('var$0'));
        Assert.areEqual('pending', binds.get('var$1'));
    }

    @IsTest
    static void should_apply_order_and_limit_to_entire_set_operation() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('Val');
        SqlQuery q2 = new TestSqlQuery('table2').field('Val');

        // Act
        q1.union(q2).orderBy('Val').lim(5);
        String result = q1.toString();

        // Assert
        Assert.areEqual('SELECT Val FROM table1 UNION SELECT Val FROM table2 ORDER BY Val LIMIT 5', result);
    }

    @IsTest
    static void should_propagate_user_bindings_from_union_subqueries() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').withBindings(new Map<String, Object>{ 'k1' => 'v1' });
        SqlQuery q2 = new TestSqlQuery('table2').withBindings(new Map<String, Object>{ 'k2' => 'v2' });

        // Act
        q1.union(q2);
        Map<String, Object> binds = q1.getBindings();

        // Assert
        Assert.areEqual('v1', binds.get('k1'), 'Parent user bindings should be present');
        Assert.areEqual('v2', binds.get('k2'), 'Subquery user bindings should be propagated to parent');
    }

    @IsTest
    static void should_correctly_render_count_query_for_union() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('table1').field('id');
        SqlQuery q2 = new TestSqlQuery('table2').field('id');
        q1.union(q2);

        // Act
        String countSql = q1.toCountString();

        // Assert
        // Most common: SELECT COUNT(*) FROM (SELECT id FROM table1 UNION SELECT id FROM table2) [as t]
        Assert.isTrue(countSql.contains('UNION'), 'Count query must include the UNION operator');
        Assert.isTrue(countSql.contains('table2'), 'Count query must include all components of the union');
    }

    @IsTest
    static void should_handle_multiple_set_operators_complex_order() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('t1').field('f');
        SqlQuery q2 = new TestSqlQuery('t2').field('f');
        SqlQuery q3 = new TestSqlQuery('t3').field('f');

        // Act
        q1.union(q2).intersect(q3);
        String sql = q1.toString();

        // Assert
        Assert.areEqual('SELECT f FROM t1 UNION SELECT f FROM t2 INTERSECT SELECT f FROM t3', sql);
    }

    @IsTest
    static void should_handle_union_with_complex_components() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('account', 'a')
            .field('a.Name')
            .innerJoin('contact', 'c')
            .onx('a.Id = c.AccountId')
            .groupBy('a.Name')
            .havingx(new SqlQuery.Condition().field('COUNT(c.Id)').gt(1));

        SqlQuery q2 = new TestSqlQuery('lead', 'l')
            .field('l.Name')
            .wherex(new SqlQuery.Condition().field('l.Status').eq('open'));

        // Act
        q1.unionAll(q2);
        String result = q1.toString();

        // Assert
        Assert.isTrue(
            result.contains(
                'GROUP BY a.Name HAVING COUNT(c.Id) > :var$0 UNION ALL SELECT l.Name FROM lead l WHERE l.Status = :var$1'
            )
        );
    }

    @IsTest
    static void should_handle_complex_set_operator_bindings() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('t1').field('A').wherex(new SqlQuery.Condition().field('X').eq('v1'));
        SqlQuery q2 = new TestSqlQuery('t2').field('A').wherex(new SqlQuery.Condition().field('Y').eq('v2'));

        SqlQuery parent = q1.unionAll(q2);

        // Act
        String sql = parent.toString();
        Map<String, Object> binds = parent.getBindings();

        // Assert
        Assert.isTrue(sql.contains('SELECT A FROM t1 WHERE X = :var$0'));
        Assert.isTrue(sql.contains('UNION ALL SELECT A FROM t2 WHERE Y = :var$1'));
        Assert.areEqual('v1', binds.get('var$0'));
        Assert.areEqual('v2', binds.get('var$1'));
    }

    @IsTest
    static void should_print_values_clause_with_bind_context() {
        // Arrange
        List<List<Object>> rows = new List<List<Object>>{
            new List<Object>{ 'Alice', 100 },
            new List<Object>{ 'Bob', 200 }
        };
        List<String> columns = new List<String>{ 'Name', 'Score' };
        SqlQuery q = new TestSqlQuery('dummy').values(rows, 't', columns);

        // Act
        String result = q.toString();
        String inline = q.toInlineString();

        // Assert
        Assert.areEqual(
            'SELECT * FROM (VALUES (:var$0, :var$1), (:var$2, :var$3)) AS t (Name, Score)',
            result,
            'Should format Values clause with bindings when no context is present'
        );
        Assert.areEqual(
            'SELECT * FROM (VALUES (\'Alice\', 100), (\'Bob\', 200)) AS t (Name, Score)',
            inline,
            'Should format Values clause inline when no context is present (toInlineString)'
        );
    }

    @IsTest
    static void should_handle_except_and_intersect() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t2').field('A');

        // Act & Assert
        Assert.isTrue(new TestSqlQuery('t1').field('A').except(q).toString().contains('EXCEPT'));
        Assert.isTrue(new TestSqlQuery('t1').field('A').exceptAll(q).toString().contains('EXCEPT ALL'));
        Assert.isTrue(new TestSqlQuery('t1').field('A').intersect(q).toString().contains('INTERSECT'));
        Assert.isTrue(new TestSqlQuery('t1').field('A').intersectAll(q).toString().contains('INTERSECT ALL'));
    }

    @IsTest
    static void should_handle_count_wrapper_for_set_operators() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('t1').field('A');
        SqlQuery q2 = new TestSqlQuery('t2').field('A');
        SqlQuery parent = q1.union(q2);

        // Act
        String sql = parent.toCountString();

        // Assert
        Assert.areEqual('SELECT COUNT(*) FROM (SELECT A FROM t1 UNION SELECT A FROM t2) AS count_wrapper', sql);
    }

    @IsTest
    static void should_wrap_count_query_when_grouping_and_having_are_present() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .field('Region')
            .sum('Amount', 'Total')
            .groupBy('Region')
            .havingx(SqlQuery.HAV.sum('Amount').gt(100));

        // Act
        String countSql = q.toCountString();
        q.fetchCount();
        MockDriver drv = (MockDriver) q.driver;

        // Assert
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT Region, SUM(Amount) Total FROM sales GROUP BY Region HAVING SUM(Amount) > :var$0) AS count_wrapper',
            countSql
        );
        Assert.areEqual(countSql, drv.lastQuery);
        Assert.areEqual(100, drv.lastBindings.get('var$0'));
    }

    @IsTest
    static void should_align_count_helpers_when_count_query_is_wrapped() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .field('Region')
            .sum('Amount', 'Total')
            .groupBy('Region')
            .havingx(SqlQuery.HAV.sum('Amount').gt(100));

        // Act
        String countSql = q.toCountString();
        String inlineCountSql = q.toInlineCountString();
        Map<String, Object> countBinds = q.getCountBindings();

        // Assert
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT Region, SUM(Amount) Total FROM sales GROUP BY Region HAVING SUM(Amount) > :var$0) AS count_wrapper',
            countSql
        );
        Assert.areEqual(
            'SELECT COUNT(*) FROM (SELECT Region, SUM(Amount) Total FROM sales GROUP BY Region HAVING SUM(Amount) > 100) AS count_wrapper',
            inlineCountSql
        );
        Assert.areEqual(1, countBinds.size());
        Assert.areEqual(100, countBinds.get('var$0'));
    }
    // </editor-fold>

    // <editor-fold desc="ORDER BY">
    @IsTest
    static void should_handle_pagination_and_ordering() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account')
            .orderBy('Name', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_FIRST)
            .orderBy('CreatedDate', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_LAST)
            .lim(10)
            .offset(20);

        // Act
        String actual = q.toString();

        // Assert
        String expected = 'SELECT * FROM account ORDER BY Name DESC NULLS FIRST, CreatedDate ASC NULLS LAST LIMIT 10 OFFSET 20';
        Assert.areEqual(expected, actual);
    }
    // </editor-fold>

    // <editor-fold desc="FETCH / Pagination">
    @IsTest
    static void should_handle_fetch_clause() {
        // Arrange
        SqlQuery q1 = new TestSqlQuery('account').orderBy('Name').fetchFirst(1);
        SqlQuery q2 = new TestSqlQuery('account').orderBy('Name').fetchFirst(10);
        SqlQuery q3 = new TestSqlQuery('account').orderBy('Name').offset(5).fetchNext(5);
        SqlQuery q4 = new TestSqlQuery('account').orderBy('Name').fetchFirstWithTies(10);
        SqlQuery q5 = new TestSqlQuery('account').orderBy('Name').fetchNextWithTies(5);

        // Act & Assert
        Assert.areEqual('SELECT * FROM account ORDER BY Name FETCH FIRST 1 ROW ONLY', q1.toString());
        Assert.areEqual('SELECT * FROM account ORDER BY Name FETCH FIRST 10 ROWS ONLY', q2.toString());
        Assert.areEqual('SELECT * FROM account ORDER BY Name OFFSET 5 FETCH NEXT 5 ROWS ONLY', q3.toString());
        Assert.areEqual('SELECT * FROM account ORDER BY Name FETCH FIRST 10 ROWS WITH TIES', q4.toString());
        Assert.areEqual('SELECT * FROM account ORDER BY Name FETCH NEXT 5 ROWS WITH TIES', q5.toString());
    }

    @IsTest
    static void should_handle_fetch_with_ties() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products').orderBy('Price').fetchNextWithTies(10);

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM products ORDER BY Price FETCH NEXT 10 ROWS WITH TIES', sql);
    }

    @IsTest
    static void should_handle_fetch_first_variations() {
        // Act & Assert
        Assert.areEqual(
            'SELECT * FROM t1 ORDER BY Id FETCH FIRST 1 ROW ONLY',
            new TestSqlQuery('t1').orderBy('Id').fetchFirst(1).toString()
        );
        Assert.areEqual(
            'SELECT * FROM t1 ORDER BY Id FETCH FIRST 5 ROWS ONLY',
            new TestSqlQuery('t1').orderBy('Id').fetchFirst(5).toString()
        );
        Assert.areEqual(
            'SELECT * FROM t1 ORDER BY Id FETCH FIRST 5 ROWS WITH TIES',
            new TestSqlQuery('t1').orderBy('Id').fetchFirstWithTies(5).toString()
        );
    }

    @IsTest
    static void should_throw_exception_when_fetch_count_is_invalid() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products').orderBy('Price');

        // Act & Assert
        try {
            q.fetchFirst((Integer) null);
            Assert.fail('Should have thrown QueryException for null fetch count');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('FETCH count must be >= 0. Value: null'));
        }

        try {
            q.fetchNext(-1);
            Assert.fail('Should have thrown QueryException for negative fetch count');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('FETCH count must be >= 0. Value: -1'));
        }
    }
    // </editor-fold>

    // <editor-fold desc="Aggregate Filters">
    @IsTest
    static void should_handle_aggregate_filters() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');
        q.field(SqlQuery.AGG.sum('Amount').filter(new SqlQuery.Condition().field('Year').eq(2023)), 'Total2023')
            .field(SqlQuery.AGG.sum('Amount').filter(new SqlQuery.Condition().field('Year').eq(2024)), 'Total2024')
            .field(SqlQuery.AGG.countDistinct('CustomerId').filter('Amount > 1000'), 'BigCustomers');

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT SUM(Amount) FILTER (WHERE Year = :var$0) Total2023, SUM(Amount) FILTER (WHERE Year = :var$1) Total2024, COUNT(DISTINCT CustomerId) FILTER (WHERE Amount > 1000) BigCustomers FROM sales';
        Assert.areEqual(expected, actual);
        Assert.areEqual(2023, binds.get('var$0'));
        Assert.areEqual(2024, binds.get('var$1'));
    }

    @IsTest
    static void should_handle_unbound_aggregate_filters_in_debug() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales');
        q.field(SqlQuery.AGG.sum('Amount').filter(new SqlQuery.Condition().field('Year').eq(2023)), 'T23')
            .field(SqlQuery.AGG.sum('Amount').filter(new SqlQuery.Condition().field('IsClosed').eq(true)));

        // Act
        String actual = q.toInlineString();

        // Assert
        String expected = 'SELECT SUM(Amount) FILTER (WHERE Year = 2023) T23, SUM(Amount) FILTER (WHERE IsClosed = TRUE) FROM sales';
        Assert.areEqual(expected, actual);
    }

    @IsTest
    static void should_handle_complex_aggregate_filters() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');
        q.field(SqlQuery.AGG.countAll().filter('Status = \'Completed\''), 'TotalDone')
            .field(
                SqlQuery.AGG.sum('Total').distinct().filter(new SqlQuery.Condition().field('Priority').eq('High')),
                'HighPriorityTotal'
            )
            .field(
                SqlQuery.AGG.avg('Total')
                    .filter(
                        new SqlQuery.Condition()
                            .field('DaysToShip')
                            .gt(5)
                            .add(new SqlQuery.Condition().field('Rush').eq(false))
                    ),
                'SlowNonRushAvg'
            );

        // Act
        String actual = q.toString();
        Map<String, Object> binds = q.getBindings();

        // Assert
        String expected = 'SELECT COUNT(*) FILTER (WHERE Status = \'Completed\') TotalDone, SUM(DISTINCT Total) FILTER (WHERE Priority = :var$0) HighPriorityTotal, AVG(Total) FILTER (WHERE DaysToShip > :var$1 AND Rush = :var$2) SlowNonRushAvg FROM orders';
        Assert.areEqual(expected, actual);
        Assert.areEqual('High', binds.get('var$0'));
        Assert.areEqual(5, binds.get('var$1'));
        Assert.areEqual(false, binds.get('var$2'));
    }

    @IsTest
    static void should_handle_aggregate_filter_with_binds() {
        // Arrange
        SqlQuery q = new TestSqlQuery('sales')
            .field(SqlQuery.AGG.sum('Amount').filter(new SqlQuery.Condition().field('Year').eq(2023)), 'Total2023');

        // Act
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT SUM(Amount) FILTER (WHERE Year = :var$0) Total2023 FROM sales', sql);
        Assert.areEqual(2023, q.getBindings().get('var$0'));
    }
    // </editor-fold>

    // <editor-fold desc="Utilities">
    @IsTest
    static void should_verify_debug_string_generation() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').wherex(new SqlQuery.Condition().field('Name').eq('test value'));

        // Act
        String debugString = q.toInlineString();
        String actualString = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM account WHERE Name = :var$0', actualString);
        Assert.areEqual('SELECT * FROM account WHERE Name = \'test value\'', debugString);
    }

    @IsTest
    static void should_use_iterable_logical_helpers() {
        // Arrange
        List<Query.Criterion> conds = new List<Query.Criterion>{
            new SqlQuery.Condition('a = 1'),
            new SqlQuery.Condition('b = 2')
        };

        // Act & Assert
        Assert.areEqual('(a = 1 AND b = 2)', SqlQuery.ands(conds).toString());
        Assert.areEqual('(a = 1 OR b = 2)', SqlQuery.ors(conds).toString());
    }

    @IsTest
    static void should_use_mock_runner() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').field('Name');
        MockDriver mock = new MockDriver();
        q.useDriver(mock);

        // Act
        q.fetch();
        q.fetchCount();
        q.fetchFirst();
        q.explain();

        // Assert
        Assert.areEqual(4, mock.callCount);
        Assert.isTrue(mock.lastQuery.contains('SELECT Name FROM account'));
    }

    @IsTest
    static void should_propagate_execution_flags_to_query_args() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account').field('Name').debug().useTimer(Query.Timer.CPU);
        MockDriver mock = new MockDriver();
        q.useDriver(mock);

        // Act
        q.fetch();
        q.fetchCount();
        q.explain();

        // Assert
        Assert.isTrue(mock.lastDebugEnabled);
        Assert.isTrue(mock.lastIsTimerEnabled);
        Assert.areEqual(Query.Timer.CPU, mock.lastTimerMode);
    }

    @IsTest
    static void should_keep_untyped_rows_for_null_object_and_map_list_types() {
        // Arrange
        List<Object> payload = new List<Object>{
            new Map<String, Object>{ 'ssot__ExternalRecordId__c' => 'ACC_001', 'ssot__Name__c' => 'Acme' }
        };
        SqlQuery q = new SqlQuery('ssot__Account__dlm');
        q.useDriver(new PayloadDriver(payload));

        // Act
        List<Object> defaultRows = q.fetch();
        List<Object> objectRows = q.fetchInto(List<Object>.class);
        List<Object> mapRows = q.fetchInto(List<Map<String, Object>>.class);

        // Assert
        Map<String, Object> defaultRow = (Map<String, Object>) defaultRows[0];
        Map<String, Object> objectRow = (Map<String, Object>) objectRows[0];
        Map<String, Object> mapRow = (Map<String, Object>) mapRows[0];

        Assert.areEqual('ACC_001', defaultRow.get('ssot__ExternalRecordId__c'));
        Assert.areEqual('ACC_001', objectRow.get('ssot__ExternalRecordId__c'));
        Assert.areEqual('ACC_001', mapRow.get('ssot__ExternalRecordId__c'));
    }

    @IsTest
    static void should_project_into_dto_and_normalize_double_underscore_keys() {
        // Arrange
        List<Object> payload = new List<Object>{
            new Map<String, Object>{ 'ssot__ExternalRecordId__c' => 'ACC_777', 'ssot__Name__c' => 'Example Corp' }
        };
        SqlQuery q = new SqlQuery('ssot__Account__dlm');
        q.useDriver(new PayloadDriver(payload));

        // Act
        List<Object> rows = q.fetchInto(List<AccountProjectionDto>.class);
        AccountProjectionDto first = (AccountProjectionDto) rows[0];

        // Assert
        Assert.areEqual(1, rows.size());
        Assert.areEqual('ACC_777', first.ssot_ExternalRecordId_c);
        Assert.areEqual('Example Corp', first.ssot_Name_c);
    }

    @IsTest
    static void should_return_null_when_fetch_first_as_has_no_results() {
        // Arrange
        SqlQuery q = new SqlQuery('ssot__Account__dlm');
        q.useDriver(new PayloadDriver(new List<Object>()));

        // Act
        Object first = q.fetchFirstAs(Object.class);

        // Assert
        Assert.areEqual(null, first);
    }

    @IsTest
    static void should_return_first_row_when_fetch_first_as_has_results() {
        // Arrange
        List<Object> payload = new List<Object>{
            new Map<String, Object>{ 'ssot__ExternalRecordId__c' => 'ACC_101' },
            new Map<String, Object>{ 'ssot__ExternalRecordId__c' => 'ACC_102' }
        };
        SqlQuery q = new SqlQuery('ssot__Account__dlm');
        q.useDriver(new PayloadDriver(payload));

        // Act
        Map<String, Object> first = (Map<String, Object>) q.fetchFirstAs(Object.class);

        // Assert
        Assert.areEqual('ACC_101', first.get('ssot__ExternalRecordId__c'));
    }

    @IsTest
    static void should_ignore_new_instance_failures_when_detecting_sobject_like_type() {
        // Arrange
        count = 0;
        List<Object> payload = new List<Object>{
            new Map<String, Object>{ 'ssot__ExternalRecordId__c' => 'ACC_778', 'ssot__Name__c' => 'Ctor Edge Corp' }
        };
        SqlQuery q = new SqlQuery('ssot__Account__dlm');
        q.useDriver(new PayloadDriver(payload));

        // Act
        List<Object> rows = q.fetchInto(List<ThrowingCtorDto>.class);
        ThrowingCtorDto first = (ThrowingCtorDto) rows[0];

        // Assert
        Assert.areEqual(1, rows.size());
        Assert.isTrue(count >= 1, 'Expected constructor to be invoked during type detection');
        Assert.areEqual('ACC_778', first.ssot_ExternalRecordId_c);
        Assert.areEqual('Ctor Edge Corp', first.ssot_Name_c);
    }

    @IsTest
    static void should_project_into_sobject_types() {
        // Arrange
        String id = '1';
        SqlQuery q = new SqlQuery('Account');
        q.useDriver(new PayloadDriver(new List<Object>{ new Map<String, Object>{ 'Id' => id, 'Name' => 'Acme' } }));

        // Act
        List<Object> rows = q.fetchInto(List<Account>.class);

        // Assert
        Assert.areEqual(1, rows.size());
        Account first = (Account) rows[0];
        Assert.areEqual(id, first.Id);
        Assert.areEqual('Acme', first.Name);
    }

    @IsTest
    static void should_project_sobject_type_for_fetch_first_as() {
        // Arrange
        String id = '2';
        SqlQuery q = new SqlQuery('Account');
        q.useDriver(
            new PayloadDriver(new List<Object>{ new Map<String, Object>{ 'Id' => id, 'Name' => 'Global Corp' } })
        );

        // Act
        Account first = (Account) q.fetchFirstAs(Account.class);

        // Assert
        Assert.areEqual(id, first.Id);
        Assert.areEqual('Global Corp', first.Name);
    }

    @IsTest
    static void should_bubble_typed_projection_deserialization_errors() {
        // Arrange
        String id = '3';
        SqlQuery q = new SqlQuery('Account');
        q.useDriver(
            new PayloadDriver(
                new List<Object>{
                    new Map<String, Object>{
                        'Id' => id,
                        'Name' => 'Date Edge Corp',
                        'CreatedDate' => '2025-01-31 06:00:00.000 UTC'
                    }
                }
            )
        );

        // Act & Assert
        try {
            q.fetchInto(List<Account>.class);
            Assert.fail('Expected deserialization failure for invalid datetime shape');
        } catch (Exception e) {
            Assert.isTrue(e.getMessage().contains('Cannot deserialize instance of datetime'));
        }
    }

    @IsTest
    static void should_throw_exception_when_no_driver_configured() {
        // Arrange
        SqlQuery q1 = SqlQuery.of('account');
        SqlQuery q2 = SqlQuery.of('account', 'a');

        // Act & Assert
        try {
            q1.fetch();
            Assert.fail('Should have thrown exception');
        } catch (Query.QueryException e) {
            Assert.isTrue(
                e.getMessage().contains('No driver configured'),
                'Exception message should mention missing driver'
            );
        }

        try {
            q2.fetchCount();
            Assert.fail('Should have thrown exception');
        } catch (Query.QueryException e) {
            Assert.isTrue(
                e.getMessage().contains('No driver configured'),
                'Exception message should mention missing driver'
            );
        }
    }

    @IsTest
    static void should_enable_sys_timer_when_use_timer_without_mode_called() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.useTimer();

        // Assert
        Assert.isTrue(q.isTimerEnabled(), 'Timer should be enabled');
        Assert.areEqual(Query.Timer.SYS, q.getTimer(), 'Default timer mode should be SYS');
    }

    @IsTest
    static void should_enable_selected_timer_mode_when_use_timer_called_with_explicit_mode() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.useTimer(Query.Timer.CPU);

        // Assert
        Assert.isTrue(q.isTimerEnabled(), 'Timer should be enabled');
        Assert.areEqual(Query.Timer.CPU, q.getTimer(), 'Timer mode should match explicit value');
    }

    @IsTest
    static void should_throw_exception_when_use_timer_called_with_null_mode() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act & Assert
        try {
            q.useTimer((Query.Timer) null);
            Assert.fail('Should have thrown QueryException for null timer');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('timer cannot be null'));
        }
    }

    // <editor-fold desc="Validation / Exceptions">
    @IsTest
    static void should_throw_exception_on_invalid_sql_function_inputs() {
        // Act & Assert
        try {
            SqlQuery.cast(null, 'VARCHAR');
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('value cannot be null'));
        }

        try {
            SqlQuery.dateTrunc('', 'field');
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('part cannot be blank'));
        }

        try {
            SqlQuery.WIN.raw('');
            Assert.fail('Should have thrown QueryException for blank raw function');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('functionName cannot be blank'));
        }
    }

    @IsTest
    static void should_throw_exception_on_invalid_builder_inputs() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act & Assert
        try {
            q.with('', new TestSqlQuery('sub'));
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('name cannot be blank'));
        }

        try {
            q.union(null);
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('other cannot be null'));
        }
    }

    @IsTest
    static void should_throw_exception_on_invalid_values_inputs() {
        // Arrange
        SqlQuery q = new TestSqlQuery('dummy');

        // Act & Assert
        try {
            q.values(null, 't', new List<String>{ 'c' });
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('rows cannot be null'));
        }

        try {
            q.values(new List<List<Object>>(), 't', new List<String>{ 'c' });
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('rows cannot be empty'));
        }
    }

    @IsTest
    static void should_throw_exception_on_invalid_values_null_rows() {
        // Arrange
        SqlQuery q = new SqlQuery('sales');

        // Act & Assert
        try {
            q.values((List<List<Object>>) null, null, null);
            Assert.fail('Should have thrown QueryException for null rows');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('rows cannot be null'));
        }
    }

    @IsTest
    static void should_throw_exception_on_unsupported_selection() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t1');

        // Act & Assert
        try {
            q.field(123); // Integer not supported as direct selection
            Assert.fail('Should have thrown QueryException');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Unsupported selection type'));
        }
    }

    @IsTest
    static void should_throw_exception_when_fetching_without_driver() {
        // Arrange
        SqlQuery q = new SqlQuery('account');

        // Act & Assert
        try {
            q.fetch();
            Assert.fail('Should have thrown QueryException for missing driver');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('No driver configured. Use useDriver()'));
        }
    }

    @IsTest
    static void should_throw_when_value_matching_without_match_field() {
        // Act & Assert
        try {
            SqlQuery.CASEX.when('a=1').when(1);
            Assert.fail('Should have thrown QueryException for value matching without match()');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('Cannot use value matching in a searched CASE statement'));
        }
    }

    @IsTest
    static void should_throw_when_case_statement_incomplete() {
        // Act & Assert
        try {
            SqlQuery.CASEX.when('a=1').end();
            Assert.fail('Should have thrown QueryException for missing THEN');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('matching WHEN and THEN clauses'));
        }
    }

    @IsTest
    static void should_debug_query_defaults_to_select_star() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t');

        // Act
        q.debug();

        // Assert
        Assert.isTrue(q.toString().contains('SELECT * FROM t'));
    }

    @IsTest
    static void should_values_clause_imply_select_star() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t');

        // Act
        q.values(new List<List<Object>>{ new List<Object>{ 1 } }, 'v', new List<String>{ 'c' });

        // Assert
        Assert.isTrue(q.toString().contains('SELECT * FROM (VALUES'));
    }

    @IsTest
    static void should_include_cte_in_count_query() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t').with('cte', new TestSqlQuery('t2')).field('f');

        // Act
        String sql = q.toCountString();

        // Assert
        Assert.isTrue(sql.contains('WITH cte AS'));
    }

    @IsTest
    static void should_build_count_query_with_joins() {
        // Arrange
        TestSqlQuery q = new TestSqlQuery('t1');
        q.join('t2').onx('a=b');

        // Act
        String sql = q.callBuildCountQueryString(new Query.BindContext());

        // Assert
        Assert.isTrue(sql.contains('INNER JOIN'), 'Count with joins should contain JOIN');
    }

    @IsTest
    static void should_build_count_query_with_values() {
        // Arrange
        TestSqlQuery q = new TestSqlQuery('t');
        q.values(new List<List<Object>>{ new List<Object>{ 1 } }, 'v', new List<String>{ 'c' });

        // Act
        String sql = q.callBuildCountQueryString(new Query.BindContext());

        // Assert
        Assert.isTrue(sql.contains('FROM (VALUES'), 'Count with values should contain VALUES');
    }

    @IsTest
    static void should_format_junctions_correctly() {
        // Arrange
        SqlQuery.Condition cond = new SqlQuery.Condition().field('a').eq(1);

        // Act
        Query.Junction juncAnd = cond.addAnd(new SqlQuery.Condition().field('b').eq(2));
        Query.Junction juncOr = cond.addOr(new SqlQuery.Condition().field('c').eq(3));

        // Assert
        Assert.isTrue(juncAnd.toString().contains('a = 1 AND b = 2'));
        Assert.isTrue(juncOr.toString().contains('a = 1 OR c = 3'));
    }

    @IsTest
    static void should_support_natural_joins_and_having_clause_formatting() {
        // Arrange
        SqlQuery q = new TestSqlQuery('t')
            .join('t2')
            .natural()
            .groupBy('a')
            .havingx('h=1')
            .addHaving('h2=2')
            .addHavingAnd('h3=3')
            .addHaving('h4=4');

        // Act
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('NATURAL INNER JOIN'), 'Should be natural join');
        Assert.isTrue(sql.contains('HAVING h=1 AND h2=2 AND h3=3 AND h4=4'), 'Should have all having conditions');
    }

    @IsTest
    static void should_throw_when_case_condition_is_blank() {
        // Act & Assert
        try {
            SqlQuery.CASEX.when('');
            Assert.fail('Should have failed for blank condition');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('condition cannot be blank'));
        }
    }

    @IsTest
    static void should_throw_when_case_criterion_is_null() {
        // Act & Assert
        try {
            SqlQuery.CASEX.when((Query.Criterion) null);
            Assert.fail('Should have failed for null criterion');
        } catch (Query.QueryException e) {
            Assert.isTrue(e.getMessage().contains('condition cannot be null'));
        }
    }

    @IsTest
    static void should_execute_fetch_via_driver_mock() {
        // Arrange
        TestSqlQuery q = new TestSqlQuery('account');

        // Act
        q.fetch();
        q.fetchFirst();

        // Assert
        MockDriver drv = (MockDriver) q.driver;
        Assert.areEqual(2, drv.callCount);
        Assert.areEqual('SELECT * FROM account', drv.lastQuery);
    }

    @IsTest
    static void should_execute_count_via_driver_mock() {
        // Arrange
        TestSqlQuery q = new TestSqlQuery('account');

        // Act
        q.fetchCount();

        // Assert
        MockDriver drv = (MockDriver) q.driver;
        Assert.areEqual(1, drv.callCount);
        Assert.areEqual('SELECT COUNT(*) FROM account', drv.lastQuery);
    }

    @IsTest
    static void should_handle_with_bindings_null() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.withBindings(null);

        // Assert
        Assert.isTrue(q.getUserBindings().isEmpty());
    }

    @IsTest
    static void should_handle_order_by_with_nulls_logic() {
        // Arrange
        SqlQuery q = new TestSqlQuery('account');

        // Act
        q.orderBy('Name', Query.SortOrder.ASCX, Query.NullsOrder.NULLS_FIRST);
        q.orderBy('Id', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST);

        // Assert
        String sql = q.toString();
        Assert.isTrue(sql.contains('ORDER BY Name ASC NULLS FIRST, Id DESC NULLS LAST'));
    }
    // </editor-fold>

    // <editor-fold desc="Verbatim / Literal Values">
    @IsTest
    static void should_allow_raw_column_comparison() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');

        // Act
        q.wherex(new SqlQuery.Condition().field('status').eq(SqlQuery.literal('previous_status')));
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT * FROM orders WHERE status = previous_status', sql);
    }

    @IsTest
    static void should_use_literal_in_select_fields() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act
        q.field(SqlQuery.literal('1'), 'constant_one').field(SqlQuery.literal('NOW()'), 'current_time');
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT 1 constant_one, NOW() current_time FROM users', sql);
    }

    @IsTest
    static void should_use_literal_in_joins() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders', 'o');

        // Act
        q.innerJoin('customers', 'c').onx(new SqlQuery.Condition().field('o.customer_id').eq(SqlQuery.literal('c.id')));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('ON o.customer_id = c.id'), 'Join condition should use literal column');
    }

    @IsTest
    static void should_use_literal_in_having() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');

        // Act
        q.groupBy('customer_id').havingx(SqlQuery.HAV.sum('amount').gt(SqlQuery.literal('total_limit')));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('HAVING SUM(amount) > total_limit'), 'Having clause should use literal column');
    }

    @IsTest
    static void should_handle_nested_literals_in_helpers() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        q.field(SqlQuery.upper(SqlQuery.cast(SqlQuery.literal('code'), 'VARCHAR')));
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT UPPER(CAST(code AS VARCHAR)) FROM products', sql);
    }

    @IsTest
    static void should_bypass_binding_context_with_literal() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');
        q.addConditionEq('status', 'active'); // var$0

        // Act
        // literal should NOT create var$1
        q.addCondition(new SqlQuery.Condition().field('id').eq(SqlQuery.literal('external_id')));

        String sql = q.toString();
        Map<String, Object> bindings = q.getBindings();

        // Assert
        Assert.isTrue(sql.contains('id = external_id'), 'Should render verbatim');
        Assert.areEqual(1, bindings.size(), 'Should only have 1 binding for "active"');
        Assert.areEqual('active', bindings.get('var$0'));
    }

    @IsTest
    static void should_handle_complex_expressions_with_literal() {
        // Arrange
        SqlQuery q = new TestSqlQuery('products');

        // Act
        // WHERE price + tax > 100
        q.wherex(new SqlQuery.Condition().field(SqlQuery.literal('price + tax')).gt(100));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('WHERE price + tax > :var$0'));
    }

    @IsTest
    static void should_use_literal_in_group_by() {
        // Arrange
        SqlQuery q = new TestSqlQuery('orders');

        // Act
        q.field('customer_id').sum('amount').groupBy(SqlQuery.literal('DATE_TRUNC(\'month\', order_date)'));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('GROUP BY DATE_TRUNC(\'month\', order_date)'));
    }

    @IsTest
    static void should_use_literal_in_order_by() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act
        q.field('*').orderBy(SqlQuery.literal('LENGTH(username)'), Query.SortOrder.DESCX);
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('ORDER BY LENGTH(username) DESC'));
    }

    @IsTest
    static void should_use_literal_in_in_clause() {
        // Arrange
        SqlQuery q = new TestSqlQuery('employees');

        // Act
        // WHERE dept_id IN (1, 2, 3)
        q.wherex(new SqlQuery.Condition().field('dept_id').inx(SqlQuery.literal('(1, 2, 3)')));
        String sql = q.toString();

        // Assert
        Assert.isTrue(sql.contains('WHERE dept_id IN (1, 2, 3)'));
    }

    @IsTest
    static void should_handle_multiple_literals_in_coalesce() {
        // Arrange
        SqlQuery q = new TestSqlQuery('users');

        // Act
        q.field(
            SqlQuery.coalesce(
                new List<Object>{ SqlQuery.literal('phone_work'), SqlQuery.literal('phone_mobile'), 'N/A' }
            ),
            'contact_phone'
        );
        String sql = q.toString();

        // Assert
        Assert.areEqual('SELECT COALESCE(phone_work, phone_mobile, \'N/A\') contact_phone FROM users', sql);
    }
    // </editor-fold>

    // <editor-fold desc="SNAPSHOT">
    @IsTest
    static void should_match_snapshot() {
        // Arrange
        // CTE: Get top customers by revenue
        SqlQuery topCustomers = new TestSqlQuery('orders')
            .field('customer_id')
            .sum('amount', 'total_revenue')
            .groupBy('customer_id')
            .havingx(SqlQuery.HAV.sum('amount').gt(10000));

        // Main query using the CTE
        SqlQuery q = new TestSqlQuery('customers', 'c')
            .with('top_customers', topCustomers)
            // SELECT with various features
            .field('c.id')
            .field('c.name', 'customer_name')
            .field(SqlQuery.upper(SqlQuery.literal('c.email')), 'email_upper')
            .field(SqlQuery.coalesce(SqlQuery.literal('c.phone'), 'N/A'), 'phone')
            .field(
                SqlQuery.CASEX
                    .when(SqlQuery.COND.field('c.status').eq('active'))
                    .then('Active')
                    .when(SqlQuery.COND.field('c.status').eq('pending'))
                    .then('Pending')
                    .elsex('Inactive')
                    .end(),
                'status_label'
            )
            .field(
                SqlQuery.WIN.rowNumber().partitionBy('c.region').orderBy('c.created_at', Query.SortOrder.DESCX),
                'row_num'
            )
            .sum('o.amount', 'total_spent')
            // JOINS
            .innerJoin('top_customers', 'tc')
            .onx('c.id = tc.customer_id')
            .leftJoin('orders', 'o')
            .onx('c.id = o.customer_id')
            // WHERE
            .wherex(
                SqlQuery.ands(
                    SqlQuery.COND.field('c.country').inx(new List<String>{ 'US', 'UK', 'DE' }),
                    SqlQuery.ors(
                        SqlQuery.COND.field('c.tier').eq('premium'),
                        SqlQuery.COND.field('tc.total_revenue').gt(50000)
                    )
                )
            )
            .addCondition(SqlQuery.COND.field('c.status').eq(SqlQuery.literal('c.previous_status')))
            .addCondition(SqlQuery.COND.field('c.updated_at').gt(Datetime.newInstanceGmt(2023, 10, 1, 12, 0, 0)))
            .addCondition(SqlQuery.COND.field('c.deleted_at').isNull())
            // GROUP BY
            .groupBy('c.id')
            .groupBy('c.name')
            .groupBy('c.email')
            .groupBy('c.phone')
            .groupBy('c.status')
            .groupBy('c.previous_status')
            .groupBy('c.region')
            .groupBy('c.created_at')
            .groupBy('c.updated_at')
            .groupBy('c.country')
            .groupBy('c.tier')
            .groupBy('tc.total_revenue')
            // HAVING
            .havingx(SqlQuery.HAV.count('o.id').ge(5))
            // ORDER BY
            .orderBy('total_spent', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST)
            .orderBy('c.name')
            // FETCH
            .debug()
            .fetchFirst(100);

        // Act
        String sql = q.toString();
        Map<String, Object> bindings = q.getBindings();

        // Assert - Snapshot of expected SQL
        String expected =
            'WITH top_customers AS (' +
            'SELECT customer_id, SUM(amount) total_revenue FROM orders ' +
            'GROUP BY customer_id HAVING SUM(amount) > :var$0' +
            ') ' +
            'SELECT c.id, c.name customer_name, UPPER(c.email) email_upper, COALESCE(c.phone, \'N/A\') phone, ' +
            'CASE WHEN c.status = :var$1 THEN :var$2 WHEN c.status = :var$3 THEN :var$4 ELSE :var$5 END status_label, ' +
            'ROW_NUMBER() OVER (PARTITION BY c.region ORDER BY c.created_at DESC) row_num, ' +
            'SUM(o.amount) total_spent ' +
            'FROM customers c ' +
            'INNER JOIN top_customers tc ON c.id = tc.customer_id ' +
            'LEFT JOIN orders o ON c.id = o.customer_id ' +
            'WHERE (c.country IN :var$6 AND (c.tier = :var$7 OR tc.total_revenue > :var$8)) ' +
            'AND c.status = c.previous_status AND c.updated_at > :var$9 AND c.deleted_at IS NULL ' +
            'GROUP BY c.id, c.name, c.email, c.phone, c.status, c.previous_status, c.region, c.created_at, c.updated_at, c.country, c.tier, tc.total_revenue ' +
            'HAVING COUNT(o.id) >= :var$10 ' +
            'ORDER BY total_spent DESC NULLS LAST, c.name ' +
            'FETCH FIRST 100 ROWS ONLY';

        Assert.areEqual(expected, sql, 'SQL snapshot mismatch');

        // Assert bindings
        Assert.areEqual(11, bindings.size(), 'Expected 11 bindings');
        Assert.areEqual(10000, bindings.get('var$0'), 'CTE HAVING binding');
        Assert.areEqual('active', bindings.get('var$1'), 'CASE WHEN 1 binding');
        Assert.areEqual('Active', bindings.get('var$2'), 'CASE THEN 1 binding');
        Assert.areEqual('pending', bindings.get('var$3'), 'CASE WHEN 2 binding');
        Assert.areEqual('Pending', bindings.get('var$4'), 'CASE THEN 2 binding');
        Assert.areEqual('Inactive', bindings.get('var$5'), 'CASE ELSE binding');
        Assert.areEqual(new List<String>{ 'US', 'UK', 'DE' }, bindings.get('var$6'), 'IN binding');
        Assert.areEqual('premium', bindings.get('var$7'), 'tier binding');
        Assert.areEqual(50000, bindings.get('var$8'), 'revenue binding');
        Assert.areEqual(Datetime.newInstanceGmt(2023, 10, 1, 12, 0, 0), bindings.get('var$9'), 'updated_at binding');
        Assert.areEqual(5, bindings.get('var$10'), 'HAVING COUNT binding');
    }
    // </editor-fold>

    // <editor-fold desc="Helpers">
    private class TestSqlQuery extends SqlQuery {
        public TestSqlQuery(String table, String alias) {
            super(table, alias);
            useDriver(new MockDriver());
        }
        public TestSqlQuery(String table) {
            super(table);
            useDriver(new MockDriver());
        }
        public String callBuildCountQueryString(Query.BindContext context) {
            return super.buildCountQueryString(context);
        }
    }

    public class AccountProjectionDto {
        public String ssot_ExternalRecordId_c;
        public String ssot_Name_c;
    }

    public class ThrowingCtorDto {
        public String ssot_ExternalRecordId_c;
        public String ssot_Name_c;

        public ThrowingCtorDto() {
            count++;
            if (count == 1) {
                throw new ThrowingCtorException('intentional ctor failure');
            }
        }
    }

    private class ThrowingCtorException extends Exception {
    }

    private class PayloadDriver implements SqlQuery.Driver {
        private final List<Object> payload;

        private PayloadDriver(List<Object> payload) {
            this.payload = payload ?? new List<Object>();
        }

        public List<Object> run(SqlQuery.QueryArgs args) {
            return payload;
        }

        public Integer count(SqlQuery.QueryArgs args) {
            return payload.size();
        }

        public Object explain(SqlQuery.QueryArgs args) {
            return null;
        }
    }

    private class MockDriver implements SqlQuery.Driver {
        public Integer callCount = 0;
        public String lastQuery;
        public String lastInlineQuery;
        public Map<String, Object> lastBindings;
        public Boolean lastDebugEnabled;
        public Boolean lastIsTimerEnabled;
        public Query.Timer lastTimerMode;
        public List<Object> run(SqlQuery.QueryArgs args) {
            callCount++;
            lastQuery = args?.query;
            lastInlineQuery = args?.inlineQuery;
            lastBindings = args?.bindings == null ? null : new Map<String, Object>(args.bindings);
            lastDebugEnabled = args?.isDebugEnabled;
            lastIsTimerEnabled = args?.isTimerEnabled;
            lastTimerMode = args?.timerMode;
            return new List<Object>();
        }
        public Integer count(SqlQuery.QueryArgs args) {
            callCount++;
            lastQuery = args?.query;
            lastInlineQuery = args?.inlineQuery;
            lastBindings = args?.bindings == null ? null : new Map<String, Object>(args.bindings);
            lastDebugEnabled = args?.isDebugEnabled;
            lastIsTimerEnabled = args?.isTimerEnabled;
            lastTimerMode = args?.timerMode;
            return 0;
        }
        public Object explain(SqlQuery.QueryArgs args) {
            callCount++;
            lastQuery = args?.query;
            lastInlineQuery = args?.inlineQuery;
            lastBindings = args?.bindings == null ? null : new Map<String, Object>(args.bindings);
            lastDebugEnabled = args?.isDebugEnabled;
            lastIsTimerEnabled = args?.isTimerEnabled;
            lastTimerMode = args?.timerMode;
            return null;
        }
    }
    // </editor-fold>
}
