/**
 * Fluent SQL query builder for Salesforce Apex.
 *
 * Provides a type-safe, chainable API for constructing ANSI SQL with support for:
 * - Field selection and aliases
 * - CTEs (`WITH`)
 * - Joins (`INNER`, `LEFT`, `RIGHT`, `FULL`, `CROSS`)
 * - Complex `WHERE` / `HAVING` logic with nested junctions
 * - Aggregates, `GROUP BY`, `ORDER BY`, set operators
 * - SQL:2008 row limiting (`FETCH FIRST/NEXT`) and `LIMIT/OFFSET`
 * - Window functions, `CASE`, `GROUPING SETS`, `VALUES`
 * - Pluggable execution drivers
 * - Configurable binding strategies (`:name`, `$1`, `?`)
 *
 * Helper providers for SQL-specific syntax:
 * - `WIN`: Window function builder factory
 * - `AGG`: Aggregate function builder factory
 * - `CASEX`: `CASE` expression builder factory
 * - `COND`: Condition builder factory for `WHERE`
 * - `HAV`: Condition builder factory for `HAVING`
 *
 * @example
 * List<Object> rows = SqlQuery.of('orders')
 *     .field('id')
 *     .field('total')
 *     .addConditionEq('status', 'PAID')
 *     .orderBy('created_at', Query.SortOrder.DESCX)
 *     .lim(50)
 *     .fetch();
 *
 * @example
 * String sql = SqlQuery.of('sales')
 *     .field('region')
 *     .sum('amount', 'total')
 *     .groupBy('region')
 *     .havingx(SqlQuery.HAV.sum('amount').gt(1000))
 *     .toString();
 */
@SuppressWarnings('PMD.ApexDoc')
public virtual inherited sharing class SqlQuery extends Query implements Builder {
    // <editor-fold desc="Query Clauses">
    private final WithClause withClause = new WithClause();
    private final SelectClause selects = new SelectClause();
    private final FromClause queriedTable;
    private final List<JoinClause> joins = new List<JoinClause>();
    private final WhereClause whereClause = new WhereClause();
    private final GroupByClause groupsBy = new GroupByClause();
    private final HavingClause havingClause = new HavingClause();
    private final OrderByClause ordersBy = new OrderByClause();
    private final SetOperatorsClause setOperators = new SetOperatorsClause();
    private final LimitClause lim = new LimitClause();
    private final OffsetClause offset = new OffsetClause();
    private final FetchClause fetchClause = new FetchClause();
    private final ValuesClause valuesList = new ValuesClause();
    private final Context ctx = new Context(this);
    // </editor-fold>
    @TestVisible
    protected Driver driver;

    // <editor-fold desc="Providers">
    /** Window function builder provider. */
    public static final WindowFunctionProvider WIN = new WindowFunctionProvider();
    /** Aggregate function builder provider. */
    public static final AggregateFunctionProvider AGG = new AggregateFunctionProvider();
    /** `CASE` expression builder provider. */
    public static final CaseFunctionProvider CASEX = new CaseFunctionProvider();
    /** Condition builder factory for `WHERE` clauses. Returns a new instance on each access. */
    public static final Condition COND {
        get {
            return new Condition();
        }
    }
    /** Condition builder factory for `HAVING` clauses. Returns a new instance on each access. */
    public static final HavingCondition HAV {
        get {
            return new HavingCondition();
        }
    }
    // </editor-fold>

    // <editor-fold desc="Construction and Configuration">
    /**
     * Creates a SQL query for a source table.
     * @param table source table name
     */
    public SqlQuery(final String table) {
        this.queriedTable = new FromClause(table, '');
    }

    /**
     * Creates a SQL query for a source table and alias.
     * @param table source table name
     * @param alias table alias
     */
    public SqlQuery(final String table, final String alias) {
        this.queriedTable = new FromClause(table, alias);
    }

    /**
     * Static factory for `SqlQuery(String)`.
     * @param table source table name
     * @return new query instance
     */
    public static SqlQuery of(final String table) {
        return new SqlQuery(table);
    }

    /**
     * Static factory for `SqlQuery(String, String)`.
     * @param table source table name
     * @param alias table alias
     * @return new query instance
     */
    public static SqlQuery of(final String table, final String alias) {
        return new SqlQuery(table, alias);
    }

    /**
     * Sets the execution driver for `fetch()` and `fetchCount()`.
     * @param driver execution driver implementation
     * @return this query
     */
    public SqlQuery useDriver(final Driver driver) {
        this.driver = driver;
        return this;
    }

    /**
     * Sets the bind placeholder style for generated SQL.
     * Supported strategies:
     * - `NAMED` -> `:var$0`
     * - `INDEXED` -> `$1`
     * - `ANONYMOUS` -> `?`
     * @param strategy placeholder strategy
     * @return this query
     *
     * @example
     * String sql = SqlQuery.of('users')
     *     .useBindingStrategy(Query.BindingStrategy.INDEXED)
     *     .wherex(new SqlQuery.Condition().field('id').eq('u-1'))
     *     .toString(); // ... WHERE id = $1
     */
    public SqlQuery useBindingStrategy(final BindingStrategy strategy) {
        bindContext.setStrategy(strategy);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="Static Logical Helpers">
    /**
     * Creates a grouped `AND` criterion to control logical precedence.
     * @param c1 First criterion
     * @param c2 Second criterion
     * @return Grouped `AND` junction: `(c1 AND c2)`
     * @example
     * Query.Criterion grouped = SqlQuery.ands(
     *     new SqlQuery.Condition().field('status').eq('active'),
     *     new SqlQuery.Condition().field('is_deleted').eq(false)
     * );
     * // result: (status = $1 AND is_deleted = $2)
     */
    public static Junction ands(final Query.Criterion c1, final Query.Criterion c2) {
        return new Junction().ands(c1, c2);
    }

    /**
     * Iterable overload of grouped `AND` for dynamic condition lists.
     * @param conditions Criteria to combine with `AND`
     * @return Grouped `AND` junction over all provided criteria
     * @example
     * List<Query.Criterion> parts = new List<Query.Criterion>{
     *     new SqlQuery.Condition().field('region').eq('EMEA'),
     *     new SqlQuery.Condition().field('plan').eq('pro')
     * };
     * Query.Criterion grouped = SqlQuery.ands(parts);
     * // result: (region = $1 AND plan = $2)
     */
    public static Junction ands(final Iterable<Query.Criterion> conditions) {
        return new Junction().ands(conditions);
    }

    /**
     * Creates a grouped `OR` criterion to control logical precedence.
     * @param c1 First criterion
     * @param c2 Second criterion
     * @return Grouped `OR` junction: `(c1 OR c2)`
     * @example
     * Query.Criterion grouped = SqlQuery.ors(
     *     new SqlQuery.Condition().field('tier').eq('gold'),
     *     new SqlQuery.Condition().field('tier').eq('platinum')
     * );
     * // result: (tier = $1 OR tier = $2)
     */
    public static Junction ors(final Query.Criterion c1, final Query.Criterion c2) {
        return new Junction().ors(c1, c2);
    }

    /**
     * Iterable overload of grouped `OR` for dynamic condition lists.
     * @param conditions Criteria to combine with `OR`
     * @return Grouped `OR` junction over all provided criteria
     * @example
     * List<Query.Criterion> parts = new List<Query.Criterion>{
     *     new SqlQuery.Condition().field('owner_id').eq('u1'),
     *     new SqlQuery.Condition().field('created_by').eq('u1')
     * };
     * Query.Criterion grouped = SqlQuery.ors(parts);
     * // result: (owner_id = $1 OR created_by = $2)
     */
    public static Junction ors(final Iterable<Query.Criterion> conditions) {
        return new Junction().ors(conditions);
    }

    /**
     * Negates a criterion as `(NOT <criterion>)`, preserving inner grouping.
     * @param condition Criterion to negate
     * @return Negated criterion: `(NOT condition)`
     * @example
     * Query.Criterion c = SqlQuery.notx(
     *     SqlQuery.ors(
     *         new SqlQuery.Condition().field('archived').eq(true),
     *         new SqlQuery.Condition().field('deleted').eq(true)
     *     )
     * );
     * // result: (NOT (archived = $1 OR deleted = $2))
     */
    public static Query.Criterion notx(final Query.Criterion condition) {
        return new NegatedCondition(condition);
    }
    // </editor-fold>

    // <editor-fold desc="SQL Functions">
    /**
     * Wraps a value to be treated as a verbatim literal (unquoted/raw) in SQL expressions.
     * Use this to reference columns in helpers or conditions where strings are otherwise auto-quoted.
     * @param value The value to wrap (e.g. 'MyColumn')
     * @return A wrapper object that renders the value consistently as-is
     * @example
     * .wherex(new Condition('status').eq(SqlQuery.literal('previous_status')))
     * // result: WHERE status = previous_status
     */
    public static Object literal(final Object value) {
        return new LiteralValue(value);
    }

    public static Object cast(final Object value, final String type) {
        validateNotNull(value, 'value');
        validateNotBlank(type, 'type');
        return new LiteralValue('CAST(' + Query.formatValue(value) + ' AS ' + type + ')');
    }

    public static Object dateTrunc(final String part, final Object value) {
        validateNotBlank(part, 'part');
        validateNotNull(value, 'value');
        return new LiteralValue('DATE_TRUNC(\'' + part + '\', ' + Query.formatValue(value) + ')');
    }

    public static Object coalesce(final Object val1, final Object val2) {
        validateNotNull(val1, 'val1');
        return new LiteralValue('COALESCE(' + Query.formatValue(val1) + ', ' + Query.formatValue(val2) + ')');
    }

    public static Object coalesce(final List<Object> values) {
        validateNotNull(values, 'values');
        validateIsTrue(!values.isEmpty(), 'values cannot be empty');
        List<String> args = new List<String>();
        for (Object value : values) {
            args.add(Query.formatValue(value));
        }
        return new LiteralValue('COALESCE(' + String.join(args, ', ') + ')');
    }

    public static Object upper(final Object value) {
        validateNotNull(value, 'value');
        return new LiteralValue('UPPER(' + Query.formatValue(value) + ')');
    }

    public static Object lower(final Object value) {
        validateNotNull(value, 'value');
        return new LiteralValue('LOWER(' + Query.formatValue(value) + ')');
    }

    public static Criterion exists(final SqlQuery subquery) {
        return new ExistsCondition(subquery);
    }

    public static Object any(final SqlQuery subquery) {
        return new QuantifiedSubquery('ANY', subquery);
    }

    public static Object some(final SqlQuery subquery) {
        return new QuantifiedSubquery('SOME', subquery);
    }

    public static Object all(final SqlQuery subquery) {
        return new QuantifiedSubquery('ALL', subquery);
    }
    // </editor-fold>

    // <editor-fold desc="GROUPING SETS">
    public static String groupingSets(final Iterable<Object> elements) {
        return 'GROUPING SETS (' + String.join(toStringList(elements), ', ') + ')';
    }

    public static String rollup(final Object element) {
        return 'ROLLUP (' + element + ')';
    }

    public static String rollup(final Iterable<Object> elements) {
        return 'ROLLUP (' + String.join(toStringList(elements), ', ') + ')';
    }

    public static String cube(final Object element) {
        return 'CUBE (' + element + ')';
    }

    public static String cube(final Iterable<Object> elements) {
        return 'CUBE (' + String.join(toStringList(elements), ', ') + ')';
    }
    // </editor-fold>

    // <editor-fold desc="Query Implementation">
    public SqlQuery distinct() {
        selects.distinct();
        return this;
    }

    public SqlQuery field(final String field) {
        selects.add(field);
        return this;
    }

    public SqlQuery field(final Object field) {
        selects.add(field);
        return this;
    }

    public SqlQuery field(final Object field, final String alias) {
        selects.add(field, alias);
        return this;
    }

    public SqlQuery field(final String field, final String alias) {
        selects.add(field, alias);
        return this;
    }

    public SqlQuery fields(final Iterable<Object> fields) {
        selects.addAll(fields);
        return this;
    }

    public SqlQuery fields(final String fields) {
        selects.addAll(fields);
        return this;
    }

    public SqlQuery allFields() {
        selects.add('*');
        return this;
    }

    public SqlQuery grouping(final String field) {
        selects.add('GROUPING(' + field + ')');
        return this;
    }

    public SqlQuery grouping(final String field, final String alias) {
        selects.add('GROUPING(' + field + ') ' + alias);
        return this;
    }

    public SqlQuery countAll() {
        return field(AGG.countAll());
    }

    public SqlQuery countAll(final String alias) {
        return field(AGG.countAll(), alias);
    }

    public SqlQuery count(final String field) {
        return field(AGG.count(field));
    }

    public SqlQuery count(final String field, final String alias) {
        return field(AGG.count(field), alias);
    }

    public SqlQuery countDistinct(final String field) {
        return field(AGG.countDistinct(field));
    }

    public SqlQuery countDistinct(final String field, final String alias) {
        return field(AGG.countDistinct(field), alias);
    }

    public SqlQuery avg(final String field) {
        return field(AGG.avg(field));
    }

    public SqlQuery avg(final String field, final String alias) {
        return field(AGG.avg(field), alias);
    }

    public SqlQuery min(final String field) {
        return field(AGG.min(field));
    }

    public SqlQuery min(final String field, final String alias) {
        return field(AGG.min(field), alias);
    }

    public SqlQuery max(final String field) {
        return field(AGG.max(field));
    }

    public SqlQuery max(final String field, final String alias) {
        return field(AGG.max(field), alias);
    }

    public SqlQuery sum(final String field) {
        return field(AGG.sum(field));
    }

    public SqlQuery sum(final String field, final String alias) {
        return field(AGG.sum(field), alias);
    }

    public SqlQuery wherex(final Query.Criterion condition) {
        whereClause.clear();
        whereClause.add(condition);
        return this;
    }

    public SqlQuery wherex(final String condition) {
        return wherex(new Condition(condition));
    }

    public SqlQuery addCondition(final Query.Criterion condition) {
        whereClause.add(condition);
        return this;
    }

    public SqlQuery addCondition(final String condition) {
        return addCondition(new Condition(condition));
    }

    public SqlQuery addConditionAnd(final Query.Criterion condition) {
        whereClause.addAnd(condition);
        return this;
    }

    public SqlQuery addConditionAnd(final String condition) {
        return addConditionAnd(new Condition(condition));
    }

    public SqlQuery addConditionOr(final Query.Criterion condition) {
        whereClause.addOr(condition);
        return this;
    }

    public SqlQuery addConditionOr(final String condition) {
        return addConditionOr(new Condition(condition));
    }

    public SqlQuery addConditionEq(final String field, final Object value) {
        return addCondition(new Condition().field(field).eq(value));
    }

    public SqlQuery addConditionNe(final String field, final Object value) {
        return addCondition(new Condition().field(field).ne(value));
    }

    public SqlQuery addConditionIn(final String field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).inx(iterable));
    }

    public SqlQuery addConditionIn(final String field, final Query.Builder semiJoinSubQuery) {
        return addCondition(new Condition().field(field).inx(semiJoinSubQuery));
    }

    public SqlQuery addConditionNotIn(final String field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).notIn(iterable));
    }

    public SqlQuery addConditionNotIn(final String field, final Query.Builder antiJoinSubQuery) {
        return addCondition(new Condition().field(field).notIn(antiJoinSubQuery));
    }

    public virtual SqlQuery byId(final String id) {
        return addConditionEq('Id', id);
    }

    public virtual SqlQuery byIds(final Iterable<String> ids) {
        return addConditionIn('Id', ids);
    }

    public SqlQuery groupBy(final Object element) {
        groupsBy.add(element);
        return this;
    }

    public SqlQuery groupBy(final Iterable<Object> elements) {
        groupsBy.addAll(elements);
        return this;
    }

    public SqlQuery groupByRollup(final Object element) {
        groupsBy.add(rollup(element));
        return this;
    }

    public SqlQuery groupByRollup(final Iterable<Object> elements) {
        groupsBy.add(rollup(elements));
        return this;
    }

    public SqlQuery groupByCube(final Object element) {
        groupsBy.add(cube(element));
        return this;
    }

    public SqlQuery groupByCube(final Iterable<Object> elements) {
        groupsBy.add(cube(elements));
        return this;
    }

    public SqlQuery groupByGroupingSets(final Iterable<Object> elements) {
        groupsBy.add(groupingSets(elements));
        return this;
    }

    public SqlQuery havingx(final Query.Criterion condition) {
        havingClause.clear();
        havingClause.add(condition);
        return this;
    }

    public SqlQuery havingx(final String condition) {
        return havingx(new Condition(condition));
    }

    public SqlQuery addHaving(final Query.Criterion condition) {
        havingClause.add(condition);
        return this;
    }

    public SqlQuery addHaving(final String condition) {
        return addHaving(new Condition(condition));
    }

    public SqlQuery addHavingAnd(final Query.Criterion condition) {
        havingClause.addAnd(condition);
        return this;
    }

    public SqlQuery addHavingAnd(final String condition) {
        return addHavingAnd(new Condition(condition));
    }

    public SqlQuery addHavingOr(final Query.Criterion condition) {
        havingClause.addOr(condition);
        return this;
    }

    public SqlQuery addHavingOr(final String condition) {
        return addHavingOr(new Condition(condition));
    }

    public SqlQuery addHavingEq(final String field, final Object value) {
        return addHaving(new Condition().field(field).eq(value));
    }

    public SqlQuery addHavingIn(final String field, final Iterable<Object> iterable) {
        return addHaving(new Condition().field(field).inx(iterable));
    }

    public SqlQuery union(final Query.Builder other) {
        setOperators.add('UNION', other);
        return this;
    }

    public SqlQuery unionAll(final Query.Builder other) {
        setOperators.add('UNION ALL', other);
        return this;
    }

    public SqlQuery intersect(final Query.Builder other) {
        setOperators.add('INTERSECT', other);
        return this;
    }

    public SqlQuery intersectAll(final Query.Builder other) {
        setOperators.add('INTERSECT ALL', other);
        return this;
    }

    public SqlQuery except(final Query.Builder other) {
        setOperators.add('EXCEPT', other);
        return this;
    }

    public SqlQuery exceptAll(final Query.Builder other) {
        setOperators.add('EXCEPT ALL', other);
        return this;
    }

    public SqlQuery orderBy(final Object element) {
        ordersBy.add(element, null, null);
        return this;
    }

    public SqlQuery orderBy(final Object element, final Query.SortOrder sortOrder) {
        ordersBy.add(element, sortOrder, null);
        return this;
    }

    public SqlQuery orderBy(final Object element, final Query.SortOrder sortOrder, final Query.NullsOrder nullsOrder) {
        ordersBy.add(element, sortOrder, nullsOrder);
        return this;
    }

    public SqlQuery lim(final Integer count) {
        lim.set(count);
        return this;
    }

    public SqlQuery offset(final Integer count) {
        offset.set(count);
        return this;
    }

    public SqlQuery fetchFirst(final Integer count) {
        fetchClause.set('FIRST', count, false);
        return this;
    }

    public SqlQuery fetchFirstWithTies(final Integer count) {
        fetchClause.set('FIRST', count, true);
        return this;
    }

    public SqlQuery fetchNext(final Integer count) {
        fetchClause.set('NEXT', count, false);
        return this;
    }

    public SqlQuery fetchNextWithTies(final Integer count) {
        fetchClause.set('NEXT', count, true);
        return this;
    }

    public SqlQuery withBindings(final Map<String, Object> bindings) {
        if (bindings != null) {
            userBindings.putAll(bindings);
        }
        return this;
    }

    public SqlQuery with(final String name, final Query.Builder subquery) {
        withClause.add(name, subquery);
        return this;
    }

    public SqlQuery values(final List<List<Object>> rows, final String alias, final List<String> columns) {
        valuesList.set(rows, alias, columns);
        return this;
    }

    public List<Object> fetch() {
        return ctx.run(List<Object>.class);
    }

    public List<Object> fetchInto(final Type listType) {
        return ctx.run(listType);
    }

    public Object fetchFirst() {
        List<Object> results = fetch();
        return results.isEmpty() ? null : results[0];
    }

    public Object fetchFirstAs(final Type elementType) {
        validateNotNull(elementType, 'elementType');
        List<Object> results = fetchInto(Type.forName('List<' + elementType + '>'));
        return results.isEmpty() ? null : results[0];
    }

    public Integer fetchCount() {
        return ctx.count();
    }

    public Object explain() {
        return ctx.explain();
    }
    // </editor-fold>

    // <editor-fold desc="SqlQuery Builder Specifics">
    public SqlQuery join(final String table) {
        return innerJoin(table);
    }

    public SqlQuery join(final String table, final String alias) {
        return innerJoin(table, alias);
    }

    public SqlQuery leftJoin(final String table) {
        return addJoin('LEFT JOIN', table, null);
    }

    public SqlQuery leftJoin(final String table, final String alias) {
        return addJoin('LEFT JOIN', table, alias);
    }

    public SqlQuery rightJoin(final String table) {
        return addJoin('RIGHT JOIN', table, null);
    }

    public SqlQuery rightJoin(final String table, final String alias) {
        return addJoin('RIGHT JOIN', table, alias);
    }

    public SqlQuery fullJoin(final String table) {
        return addJoin('FULL JOIN', table, null);
    }

    public SqlQuery fullJoin(final String table, final String alias) {
        return addJoin('FULL JOIN', table, alias);
    }

    public SqlQuery innerJoin(final String table) {
        return addJoin('INNER JOIN', table, null);
    }

    public SqlQuery innerJoin(final String table, final String alias) {
        return addJoin('INNER JOIN', table, alias);
    }

    public SqlQuery crossJoin(final String table) {
        return addJoin('CROSS JOIN', table, null);
    }

    public SqlQuery crossJoin(final String table, final String alias) {
        return addJoin('CROSS JOIN', table, alias);
    }

    public SqlQuery onx(final String condition) {
        return onx(new Condition(condition));
    }

    public SqlQuery onx(final Query.Criterion condition) {
        getLastJoinOrThrow('onx').onx(condition);
        return this;
    }

    public SqlQuery onEq(final String leftField, final String rightField) {
        validateNotBlank(rightField, 'rightField');
        getLastJoinOrThrow('onEq').onx(new Condition().field(leftField).eq(literal(rightField)));
        return this;
    }

    public SqlQuery usingx(final String column) {
        return usingx(new List<String>{ column });
    }

    public SqlQuery usingx(final List<String> columns) {
        getLastJoinOrThrow('usingx').usingx(columns);
        return this;
    }

    public SqlQuery natural() {
        getLastJoinOrThrow('natural').natural();
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="Build">
    public virtual SqlQuery debug() {
        isDebugEnabled = true;
        return this;
    }

    public virtual SqlQuery useTimer() {
        return useTimer(Query.Timer.SYS);
    }

    public virtual SqlQuery useTimer(final Query.Timer mode) {
        validateNotNull(mode, 'timer');
        isTimerEnabled = true;
        timerMode = mode;
        return this;
    }

    public override String toString() {
        return buildQueryString(bindContext);
    }

    public String toCountString() {
        return toCountString(bindContext);
    }

    public override String toInlineCountString() {
        return toCountString(null);
    }

    public override Map<String, Object> getCountBindings() {
        BindContext temp = new BindContext(bindContext.getStrategy());
        toCountString(temp);
        Map<String, Object> allBinds = temp.getMap().clone();
        allBinds.putAll(userBindings);
        return allBinds;
    }

    public virtual override String toCountString(final BindContext targetContext) {
        if (!shouldWrapCountQuery()) {
            return buildCountQueryString(targetContext);
        }
        // For SET operators, VALUES, and grouped queries (GROUP BY/HAVING), wrap the full query to count rows accurately.
        return 'SELECT ' + getCountSelectPart() + ' FROM (' + buildQueryString(targetContext) + ') AS count_wrapper';
    }

    public override String buildCountQueryString(final BindContext targetContext) {
        String mainQuery = super.buildCountQueryString(targetContext);
        if (!withClause.isEmpty()) {
            return withClause.toString() + ' ' + mainQuery;
        }
        return mainQuery;
    }

    protected override String getCountSelectPart() {
        return 'COUNT(*)';
    }

    protected virtual override List<Query.Part> build(final BindContext targetContext) {
        withClause.withBindContext(targetContext);
        selects.withBindContext(targetContext);
        whereClause.withBindContext(targetContext);
        havingClause.withBindContext(targetContext);
        for (JoinClause joinClause : joins) {
            joinClause.withBindContext(targetContext);
        }
        setOperators.withBindContext(targetContext);
        valuesList.withBindContext(targetContext);

        List<Query.Part> parts = new List<Query.Part>{ withClause, selects };
        if (!valuesList.isEmpty()) {
            parts.add(valuesList);
        } else {
            parts.add(queriedTable);
        }
        parts.addAll(joins);
        parts.add(whereClause);
        parts.add(groupsBy);
        parts.add(havingClause);
        parts.add(setOperators);
        parts.add(ordersBy);
        parts.add(lim);
        parts.add(offset);
        parts.add(fetchClause);
        return parts;
    }

    protected override List<Query.Part> buildCount(final BindContext targetContext) {
        withClause.withBindContext(targetContext);
        selects.withBindContext(targetContext);
        whereClause.withBindContext(targetContext);
        for (JoinClause joinClause : joins) {
            joinClause.withBindContext(targetContext);
        }
        valuesList.withBindContext(targetContext);

        List<Query.Part> parts;
        if (!valuesList.isEmpty()) {
            parts = new List<Query.Part>{ valuesList };
        } else {
            parts = new List<Query.Part>{ queriedTable };
        }
        parts.addAll(joins);
        parts.add(whereClause);
        parts.add(lim);
        parts.add(offset);
        return parts;
    }
    // </editor-fold>

    // <editor-fold desc="Helpers">
    private static void validateField(String field) {
        validateNotBlank(field, 'field');
    }

    private static void validateFields(Iterable<Object> fields) {
        validateIsTrue(fields != null, 'fields cannot be null');
        validateIsTrue(fields.iterator().hasNext(), 'fields cannot be empty');
    }

    private static String formatOrder(Object element, Query.SortOrder sortOrder, Query.NullsOrder nullsOrder) {
        validateNotNull(element, 'element');
        String order = String.valueOf(element);
        validateNotBlank(order, 'element');
        if (sortOrder == Query.SortOrder.ASCX) {
            order += ' ASC';
        } else if (sortOrder == Query.SortOrder.DESCX) {
            order += ' DESC';
        }
        if (nullsOrder == Query.NullsOrder.NULLS_FIRST) {
            order += ' NULLS FIRST';
        } else if (nullsOrder == Query.NullsOrder.NULLS_LAST) {
            order += ' NULLS LAST';
        }
        return order;
    }

    private static List<String> toStringList(Iterable<Object> items) {
        List<String> result = new List<String>();
        for (Object item : items) {
            result.add(String.valueOf(item));
        }
        return result;
    }

    private SqlQuery addJoin(String type, String table, String alias) {
        joins.add(new JoinClause(type, table, alias));
        return this;
    }

    protected SqlQuery addLateralJoin(String type, Query.Builder subquery, String alias) {
        joins.add(new JoinClause(type, (SqlQuery) subquery, alias, true));
        return this;
    }

    private JoinClause getLastJoinOrThrow(String methodName) {
        if (joins.isEmpty()) {
            throw new QueryException(methodName + '() requires a prior join() call');
        }
        return joins[joins.size() - 1];
    }

    private BindingStrategy getBindingStrategy() {
        return bindContext.getStrategy();
    }

    private Boolean shouldWrapCountQuery() {
        return selects.hasDistinct() ||
            !setOperators.isEmpty() ||
            !valuesList.isEmpty() ||
            !groupsBy.isEmpty() ||
            !havingClause.isEmpty();
    }
    // </editor-fold>

    // <editor-fold desc="API">
    public interface Builder extends Query.Builder {
        // CTE
        Query.Builder with(String name, Query.Builder subquery);
        // SELECT Aggregate Functions
        Query.Builder countAll();
        Query.Builder countAll(String alias);
        // SQL-specific extensions to the generic Query interface
        Query.Builder field(String field, String alias);
        Query.Builder join(String table);
        Query.Builder join(String table, String alias);
        Query.Builder leftJoin(String table);
        Query.Builder leftJoin(String table, String alias);
        Query.Builder rightJoin(String table);
        Query.Builder rightJoin(String table, String alias);
        Query.Builder fullJoin(String table);
        Query.Builder fullJoin(String table, String alias);
        Query.Builder innerJoin(String table);
        Query.Builder innerJoin(String table, String alias);
        Query.Builder onx(String condition);
        Query.Builder onx(Query.Criterion condition);
        Query.Builder onEq(String leftField, String rightField);
        Query.Builder usingx(String column);
        Query.Builder usingx(List<String> columns);
        Query.Builder natural();
        Query.Builder crossJoin(String table);
        Query.Builder crossJoin(String table, String alias);
        // GROUP BY
        Query.Builder groupBy(Object element);
        Query.Builder groupByRollup(Object element);
        Query.Builder groupByCube(Object element);
        Query.Builder groupByGroupingSets(Iterable<Object> elements);
        // SET OPERATORS
        Query.Builder union(Query.Builder other);
        Query.Builder unionAll(Query.Builder other);
        Query.Builder intersect(Query.Builder other);
        Query.Builder intersectAll(Query.Builder other);
        Query.Builder except(Query.Builder other);
        Query.Builder exceptAll(Query.Builder other);
        // VALUES
        Query.Builder values(List<List<Object>> rows, String alias, List<String> columns);
        // WHERE
        Query.Builder byId(String id);
        Query.Builder byIds(Iterable<String> ids);
        // ROW LIMITING
        Query.Builder fetchFirst(Integer count);
        Query.Builder fetchFirstWithTies(Integer count);
        Query.Builder fetchNext(Integer count);
        Query.Builder fetchNextWithTies(Integer count);
        // Terminal Operations
        List<Object> fetch();
        List<Object> fetchInto(Type listType);
        Object fetchFirst();
        Object fetchFirstAs(Type elementType);
        Integer fetchCount();
    }

    public class QueryArgs {
        public final String query;
        public final String inlineQuery;
        public final Map<String, Object> bindings;
        public Boolean isDebugEnabled;
        public Boolean isTimerEnabled;
        public Query.Timer timerMode;

        public QueryArgs(String query, String inlineQuery, Map<String, Object> bindings) {
            validateNotBlank(query, 'query');
            validateNotBlank(inlineQuery, 'inlineQuery');
            this.query = query;
            this.inlineQuery = inlineQuery;
            this.bindings = bindings;
        }
    }

    public interface Driver {
        List<Object> run(QueryArgs args);
        Integer count(QueryArgs args);
        Object explain(QueryArgs args);
    }

    public virtual class Condition extends BindableCondition {
        private final String raw;
        private Object field;
        private String operator;
        private Object value;
        private Object value2;

        public Condition() {
        }

        public Condition(final String raw) {
            validateNotBlank(raw, 'raw');
            this.raw = raw;
        }

        public virtual override void withBindContext(final BindContext context) {
            super.withBindContext(context);
            if (field instanceof Bindable) {
                ((Bindable) field).withBindContext(context);
            }
        }

        public virtual Query.Junction add(final Query.Criterion condition) {
            return new Query.Junction().add(this).add(condition);
        }

        public virtual Query.Junction addAnd(final Query.Criterion condition) {
            return new Query.Junction().add(this).addAnd(condition);
        }

        public virtual Query.Junction addOr(final Query.Criterion condition) {
            return new Query.Junction().add(this).addOr(condition);
        }

        public virtual Condition id() {
            return field('Id');
        }

        public virtual Condition field(final Object field) {
            this.field = field;
            return this;
        }

        public virtual Condition field(final String field) {
            validateField(field);
            this.field = field;
            return this;
        }

        public virtual Condition comparand(final String operator, final Object value) {
            validateNotBlank(operator, 'operator');
            this.operator = operator;
            this.value = value;
            return this;
        }

        public Condition isNull() {
            return eq(null);
        }

        public Condition isNotNull() {
            return ne(null);
        }

        public Condition isTrue() {
            return eq(true);
        }

        public Condition isFalse() {
            return eq(false);
        }

        public Condition eq(final Object value) {
            return comparand('=', value);
        }

        public Condition ne(final Object value) {
            return comparand('!=', value);
        }

        public Condition gt(final Object value) {
            return comparand('>', value);
        }

        public Condition ge(final Object value) {
            return comparand('>=', value);
        }

        public Condition lt(final Object value) {
            return comparand('<', value);
        }

        public Condition le(final Object value) {
            return comparand('<=', value);
        }

        public Condition likex(final String value) {
            return comparand('LIKE', value);
        }

        public Condition notLike(final String value) {
            return comparand('NOT LIKE', value);
        }

        public Condition inx(final Object value) {
            validateIsTrue(!isEmptyIterable(value), 'IN values cannot be empty');
            return comparand('IN', value);
        }

        public Condition notIn(final Object value) {
            validateIsTrue(!isEmptyIterable(value), 'NOT IN values cannot be empty');
            return comparand('NOT IN', value);
        }

        public Condition between(final Object val1, final Object val2) {
            this.operator = 'BETWEEN';
            this.value = val1;
            this.value2 = val2;
            return this;
        }

        public override String toString() {
            if (String.isNotBlank(raw)) {
                return raw;
            }
            String result;
            if (value == null) {
                result = 'NULL';
                if (operator == '=') {
                    operator = 'IS';
                } else if (operator == '!=') {
                    operator = 'IS NOT';
                }
            } else if (value instanceof SqlQuery) {
                prepareSubQuery((SqlQuery) value, boundContext);
                result = '(' + this.value.toString() + ')';
            } else if (value instanceof QuantifiedSubquery) {
                prepareSubQuery(((QuantifiedSubquery) value).query, boundContext);
                result = value.toString();
            } else if (value instanceof LiteralValue) {
                result = value.toString();
            } else if (boundContext != null) {
                result = (boundContext.isNamed() ? ':' : '') + boundContext.add(value);
            } else {
                result = formatValue(value);
            }
            if (operator == 'BETWEEN') {
                String result2 =
                    (boundContext != null && boundContext.isNamed() ? ':' : '') +
                    (boundContext != null ? boundContext.add(value2) : formatValue(value2));
                return field + ' BETWEEN ' + result + ' AND ' + result2;
            }
            return field + ' ' + operator + ' ' + result;
        }

        private Boolean isEmptyIterable(Object value) {
            return value instanceof Iterable<Object> && !((Iterable<Object>) value).iterator().hasNext();
        }
    }

    // prettier-ignore
    public class HavingCondition extends Condition {
        public HavingCondition() {}
        public HavingCondition(final String raw) { super(raw); }
        public HavingCondition count(final Object element) { return set('COUNT({0})', element); }
        public HavingCondition countDistinct(final Object element) { return set('COUNT(DISTINCT {0})', element); }
        public HavingCondition countAll() { return set('COUNT({0})', '*'); }
        public HavingCondition sum(final Object element) { return set('SUM({0})', element); }
        public HavingCondition avg(final Object element) { return set('AVG({0})', element); }
        public HavingCondition min(final Object element) { return set('MIN({0})', element); }
        public HavingCondition max(final Object element) { return set('MAX({0})', element); }
        private HavingCondition set(String placeholder, Object arg) {
            field = String.format(placeholder, new List<String>{ String.valueOf(arg) });
            return this;
        }
    }
    private class ExistsCondition extends BindableCondition {
        private final SqlQuery subquery;

        public ExistsCondition(final SqlQuery subquery) {
            validateNotNull(subquery, 'subquery');
            this.subquery = subquery;
        }

        public override String toString() {
            prepareSubQuery(subquery, boundContext);
            return 'EXISTS (' + subquery.toString() + ')';
        }
    }

    private class QuantifiedSubquery {
        private final String type;
        private final SqlQuery query;

        public QuantifiedSubquery(final String type, final SqlQuery query) {
            validateNotNull(query, 'subquery');
            this.type = type;
            this.query = query;
        }

        public override String toString() {
            return type + ' (' + query.toString() + ')';
        }
    }

    private class LiteralValue {
        private final Object value;
        public LiteralValue(final Object value) {
            this.value = value;
        }
        public override String toString() {
            return String.valueOf(value ?? 'NULL');
        }
    }
    // </editor-fold>

    // <editor-fold desc="Window Functions">
    // prettier-ignore
    public class WindowFunctionProvider {
        public WindowBuilder rank() { return new WindowBuilder('RANK()'); }
        public WindowBuilder rowNumber() { return new WindowBuilder('ROW_NUMBER()'); }
        public WindowBuilder denseRank() { return new WindowBuilder('DENSE_RANK()'); }
        public WindowBuilder percentRank() { return new WindowBuilder('PERCENT_RANK()'); }
        public WindowBuilder cumeDist() { return new WindowBuilder('CUME_DIST()'); }
        public WindowBuilder lead(final Object element) { return new WindowBuilder('LEAD', element); }
        public WindowBuilder lead(final Object element, Integer offset) { return new WindowBuilder('LEAD', element, offset); }
        public WindowBuilder lag(final Object element) { return new WindowBuilder('LAG', element); }
        public WindowBuilder lag(final Object element, Integer offset) { return new WindowBuilder('LAG', element, offset); }
        public WindowBuilder ntile(final Integer n) { return new WindowBuilder('NTILE(' + n + ')'); }
        public WindowBuilder nthValue(final Object element, Integer n) { return new WindowBuilder('NTH_VALUE(' + element + ', ' + n + ')'); }
        public WindowBuilder firstValue(final Object element) { return new WindowBuilder('FIRST_VALUE', element); }
        public WindowBuilder lastValue(final Object element) { return new WindowBuilder('LAST_VALUE', element); }
        public WindowBuilder avg(final Object element) { return new WindowBuilder('AVG', element); }
        public WindowBuilder count(final Object element) { return new WindowBuilder('COUNT', element); }
        public WindowBuilder min(final Object element) { return new WindowBuilder('MIN', element); }
        public WindowBuilder max(final Object element) { return new WindowBuilder('MAX', element); }
        public WindowBuilder sum(final Object element) { return new WindowBuilder('SUM', element); }
        public WindowBuilder raw(final String functionName) { validateNotBlank(functionName, 'functionName'); return new WindowBuilder(functionName); }
    }
    public class WindowBuilder {
        private final String function;
        private final List<Object> partitions = new List<Object>();
        private final List<String> orders = new List<String>();
        private String frame;

        private WindowBuilder(String function) {
            this.function = function;
        }

        private WindowBuilder(String functionName, Object field) {
            this.function = functionName + '(' + String.valueOf(field) + ')';
        }

        private WindowBuilder(String functionName, Object field, Object literal) {
            this.function = functionName + '(' + String.valueOf(field) + ', ' + literal + ')';
        }

        public WindowBuilder partitionBy(final String field) {
            validateNotNull(field, 'field');
            partitions.add(field);
            return this;
        }

        public WindowBuilder partitionBy(final Iterable<Object> fields) {
            validateFields(fields);
            for (Object field : fields) {
                partitions.add(field);
            }
            return this;
        }

        public WindowBuilder orderBy(final String field) {
            orders.add(formatOrder(field, null, null));
            return this;
        }

        public WindowBuilder orderBy(final String field, final Query.SortOrder sortOrder) {
            orders.add(formatOrder(field, sortOrder, null));
            return this;
        }

        public WindowBuilder orderBy(
            final String field,
            final Query.SortOrder sortOrder,
            final Query.NullsOrder nullsOrder
        ) {
            orders.add(formatOrder(field, sortOrder, nullsOrder));
            return this;
        }

        public WindowBuilder rowsBetween(final Object start, final Object frameEnd) {
            this.frame = 'ROWS BETWEEN ' + formatFrameBound(start) + ' AND ' + formatFrameBound(frameEnd);
            return this;
        }

        public WindowBuilder rangeBetween(final Object start, final Object frameEnd) {
            this.frame = 'RANGE BETWEEN ' + formatFrameBound(start) + ' AND ' + formatFrameBound(frameEnd);
            return this;
        }

        public WindowBuilder rowsUnboundedPreceding() {
            this.frame = 'ROWS UNBOUNDED PRECEDING';
            return this;
        }

        public WindowBuilder rowsCurrentRow() {
            this.frame = 'ROWS CURRENT ROW';
            return this;
        }

        private String formatFrameBound(Object bound) {
            if (bound instanceof Integer) {
                Integer i = (Integer) bound;
                if (i == 0) {
                    return 'CURRENT ROW';
                }
                return (i > 0 ? i + ' FOLLOWING' : Math.abs(i) + ' PRECEDING');
            }
            return String.valueOf(bound); // UNBOUNDED PRECEDING, etc.
        }

        public override String toString() {
            String result = function + ' OVER (';
            List<String> parts = new List<String>();
            if (!partitions.isEmpty()) {
                parts.add('PARTITION BY ' + String.join(toStringList(partitions), ', '));
            }
            if (!orders.isEmpty()) {
                parts.add('ORDER BY ' + String.join(orders, ', '));
            }
            if (String.isNotBlank(frame)) {
                parts.add(frame);
            }
            result += String.join(parts, ' ') + ')';
            return result;
        }
    }
    // </editor-fold>

    // <editor-fold desc="Aggregate Functions">
    // prettier-ignore
    public class AggregateFunctionProvider {
        public AggregateBuilder count(final Object element) { return new AggregateBuilder('COUNT', element); }
        public AggregateBuilder countDistinct(final Object element) { return new AggregateBuilder('COUNT', element).distinct(); }
        public AggregateBuilder countAll() { return new AggregateBuilder('COUNT', '*'); }
        public AggregateBuilder sum(final Object element) { return new AggregateBuilder('SUM', element); }
        public AggregateBuilder avg(final Object element) { return new AggregateBuilder('AVG', element); }
        public AggregateBuilder min(final Object element) { return new AggregateBuilder('MIN', element); }
        public AggregateBuilder max(final Object element) { return new AggregateBuilder('MAX', element); }
    }
    public class CaseFunctionProvider {
        public CaseBuilder when(final String condition) {
            return new CaseBuilder().when(condition);
        }

        public CaseBuilder when(final Query.Criterion condition) {
            return new CaseBuilder().when(condition);
        }

        public CaseBuilder match(final String field) {
            return new CaseBuilder(field);
        }
    }

    public class CaseExpression implements Bindable {
        private final String matchExpression;
        private final List<Object> whens;
        private final List<Object> thens;
        private final Object elseResult;
        private BindContext boundContext;

        private CaseExpression(String matchExpression, List<Object> whens, List<Object> thens, Object elseResult) {
            this.matchExpression = matchExpression;
            this.whens = whens;
            this.thens = thens;
            this.elseResult = elseResult;
        }

        public void withBindContext(final BindContext context) {
            this.boundContext = context;
            for (Object w : whens) {
                if (w instanceof Bindable) {
                    ((Bindable) w).withBindContext(context);
                }
            }
            for (Object t : thens) {
                if (t instanceof Bindable) {
                    ((Bindable) t).withBindContext(context);
                }
            }
            if (elseResult instanceof Bindable) {
                ((Bindable) elseResult).withBindContext(context);
            }
        }

        public override String toString() {
            String sql = 'CASE';
            if (matchExpression != null) {
                sql += ' ' + matchExpression;
            }
            for (Integer i = 0; i < whens.size(); i++) {
                Object w = whens[i];
                String whenStr;
                if (w instanceof Query.Criterion) {
                    whenStr = w.toString();
                } else if (matchExpression != null) {
                    // Simple case: WHEN value
                    whenStr = bindOrLiteral(w);
                } else {
                    whenStr = String.valueOf(w);
                }
                sql += ' WHEN ' + whenStr + ' THEN ' + bindOrLiteral(thens[i]);
            }
            if (elseResult != null) {
                sql += ' ELSE ' + bindOrLiteral(elseResult);
            }
            sql += ' END';
            return sql;
        }

        private String bindOrLiteral(Object value) {
            if (value instanceof Bindable || value instanceof Query.Criterion) {
                return value.toString();
            }
            if (value instanceof LiteralValue) {
                return value.toString();
            }
            if (boundContext != null) {
                return (boundContext.isNamed() ? ':' : '') + boundContext.add(value);
            }
            return Query.formatValue(value);
        }
    }

    public class CaseBuilder {
        private final String matchExpression;
        private final List<Object> whens = new List<Object>();
        private final List<Object> thens = new List<Object>();
        private Object elseResult;

        private CaseBuilder() {
        }

        private CaseBuilder(String matchExpression) {
            validateNotBlank(matchExpression, 'matchExpression');
            this.matchExpression = matchExpression;
        }

        public CaseBuilder when(final String condition) {
            validateNotBlank(condition, 'condition');
            whens.add(condition);
            return this;
        }

        public CaseBuilder when(final Query.Criterion condition) {
            validateNotNull(condition, 'condition');
            whens.add(condition);
            return this;
        }

        public CaseBuilder when(final Object value) {
            validateNotNull(value, 'value');
            if (matchExpression == null) {
                throw new QueryException(
                    'Cannot use value matching in a searched CASE statement. Use .match(field) to start a simple CASE statement.'
                );
            }
            whens.add(value);
            return this;
        }

        public CaseBuilder then(final Object result) {
            validateNotNull(result, 'result');
            thens.add(result);
            return this;
        }

        public CaseBuilder elsex(final Object result) {
            validateNotNull(result, 'result');
            elseResult = result;
            return this;
        }

        public CaseExpression end() {
            if (whens.isEmpty() || whens.size() != thens.size()) {
                throw new QueryException('CASE statement must have matching WHEN and THEN clauses');
            }
            return new CaseExpression(matchExpression, new List<Object>(whens), new List<Object>(thens), elseResult);
        }
    }

    public class AggregateBuilder implements Bindable {
        private final String name;
        private final Object arg;
        private Boolean isDistinct = false;
        private final Query.Junction filter = new Query.Junction();

        private AggregateBuilder(String name, Object arg) {
            validateNotNull(arg, 'element');
            this.name = name;
            this.arg = arg;
        }

        public AggregateBuilder distinct() {
            isDistinct = true;
            return this;
        }

        public AggregateBuilder filter(final Query.Criterion condition) {
            filter.add(condition);
            return this;
        }

        public AggregateBuilder filter(final String condition) {
            filter.add(new Condition(condition));
            return this;
        }

        public void withBindContext(final BindContext context) {
            filter.withBindContext(context);
        }

        public override String toString() {
            String result = name + '(' + (isDistinct ? 'DISTINCT ' : '') + String.valueOf(arg) + ')';
            if (!filter.isEmpty()) {
                result += ' FILTER (WHERE ' + filter.toString() + ')';
            }
            return result;
        }
    }
    // </editor-fold>

    private class WithClause implements Query.Part, Bindable {
        private final Map<String, SqlQuery> expressions = new Map<String, SqlQuery>();

        public void add(final String name, final Query.Builder q) {
            validateNotBlank(name, 'name');
            validateNotNull(q, 'subquery');
            expressions.put(name, (SqlQuery) q);
        }

        public Boolean isEmpty() {
            return expressions.isEmpty();
        }

        public void withBindContext(final BindContext context) {
            for (SqlQuery query : expressions.values()) {
                prepareSubQuery(query, context);
            }
        }

        public override String toString() {
            List<String> parts = new List<String>();
            for (String name : expressions.keySet()) {
                parts.add(name + ' AS (' + expressions.get(name).toString() + ')');
            }
            return 'WITH ' + String.join(parts, ', ');
        }
    }

    private class SelectClause implements Query.Part, Bindable {
        private final List<Object> selections = new List<Object>();
        private Boolean isDistinct = false;

        public void distinct() {
            this.isDistinct = true;
        }

        public Boolean hasDistinct() {
            return isDistinct;
        }

        public Boolean isEmpty() {
            return false;
        }

        public void add(final Object field) {
            validateSelection(field);
            selections.add(field);
        }

        public void add(final Object field, final String alias) {
            validateSelection(field);
            if (String.isBlank(alias)) {
                add(field);
            } else {
                selections.add(new Aliased(field, alias));
            }
        }

        public void addAll(final Iterable<Object> fields) {
            validateFields(fields);
            for (Object selection : fields) {
                add(selection);
            }
        }

        public void addAll(final String fields) {
            validateNotBlank(fields, 'fields');
            for (String selection : fields.split(',')) {
                add(selection.trim());
            }
        }

        public void withBindContext(final BindContext context) {
            for (Object selection : selections) {
                if (selection instanceof Bindable) {
                    ((Bindable) selection).withBindContext(context);
                }
            }
        }

        public override String toString() {
            if (selections.isEmpty()) {
                return 'SELECT *';
            }
            List<String> parts = new List<String>();
            for (Object selection : selections) {
                if (selection instanceof SqlQuery) {
                    parts.add('(' + selection.toString() + ')');
                } else {
                    parts.add(String.valueOf(selection));
                }
            }
            return 'SELECT ' + (isDistinct ? 'DISTINCT ' : '') + String.join(parts, ', ');
        }

        private void validateSelection(Object field) {
            validateNotNull(field, 'selection');
            if (field instanceof String) {
                validateField((String) field);
            } else if (
                !(field instanceof AggregateBuilder ||
                field instanceof WindowBuilder ||
                field instanceof CaseExpression ||
                field instanceof SqlQuery ||
                field instanceof LiteralValue)
            ) {
                throw new QueryException('Unsupported selection type');
            }
        }
    }

    private class Aliased implements Bindable {
        private final Object selection;
        private final String alias;

        public Aliased(final Object selection, final String alias) {
            this.selection = selection;
            this.alias = alias;
        }

        public void withBindContext(final BindContext context) {
            if (selection instanceof Bindable) {
                ((Bindable) selection).withBindContext(context);
            }
        }

        public override String toString() {
            return String.valueOf(selection) + ' ' + alias;
        }
    }

    private class FromClause implements Query.Part {
        private final String table;
        private final String alias;

        public FromClause(final String table, final String alias) {
            validateNotBlank(table, 'table');
            this.table = table;
            this.alias = alias;
        }

        public Boolean isEmpty() {
            return false;
        }

        public override String toString() {
            String result = 'FROM ' + table;
            if (String.isNotBlank(alias)) {
                result += ' ' + alias;
            }
            return result;
        }
    }

    private class JoinClause implements Query.Part, Bindable {
        private final String type;
        private final String table;
        private final String alias;
        private final SqlQuery subquery;
        private final Boolean isLateral;
        private Query.Criterion condition;
        private List<String> usingColumns;
        private Boolean isNatural = false;
        private BindContext boundContext;

        public JoinClause(final String type, final String table, final String alias) {
            validateNotBlank(type, 'type');
            validateNotBlank(table, 'table');
            this.type = type;
            this.table = table;
            this.alias = alias;
            this.subquery = null;
            this.isLateral = false;
        }

        public JoinClause(final String type, final SqlQuery subquery, final String alias, final Boolean isLateral) {
            validateNotBlank(type, 'type');
            validateNotNull(subquery, 'subquery');
            validateNotBlank(alias, 'alias');
            this.type = type;
            this.table = null;
            this.alias = alias;
            this.subquery = subquery;
            this.isLateral = isLateral ?? false;
        }

        public Boolean isEmpty() {
            return false;
        }

        public void onx(final Query.Criterion condition) {
            validateIsTrue(!isNatural, 'NATURAL JOIN cannot be combined with ON');
            validateNotNull(condition, 'condition');
            this.condition = condition;
        }

        public void usingx(final List<String> columns) {
            validateIsTrue(!isNatural, 'NATURAL JOIN cannot be combined with USING');
            validateNotNull(columns, 'columns');
            validateIsTrue(!columns.isEmpty(), 'columns cannot be empty');
            for (String column : columns) {
                validateNotBlank(column, 'column');
            }
            usingColumns = columns;
        }

        public void natural() {
            validateIsTrue(subquery == null, 'NATURAL JOIN cannot be used with subquery joins');
            validateIsTrue(condition == null, 'NATURAL JOIN cannot be combined with ON');
            validateIsTrue(usingColumns?.isEmpty() ?? true, 'NATURAL JOIN cannot be combined with USING');
            isNatural = true;
        }

        public void withBindContext(final BindContext context) {
            this.boundContext = context;
            prepareSubQuery(subquery, context);
            if (condition instanceof Bindable) {
                ((Bindable) condition).withBindContext(context);
            }
        }

        public override String toString() {
            String target = subquery != null ? '(' + subquery.buildQueryString(boundContext) + ')' : table;
            String result = (isNatural ? 'NATURAL ' : '') + type + (isLateral ? ' LATERAL ' : ' ') + target;
            if (String.isNotBlank(alias)) {
                result += ' ' + alias;
            }
            if (condition != null) {
                result += ' ON ' + condition.toString();
            } else if (usingColumns != null && !usingColumns.isEmpty()) {
                result += ' USING (' + String.join(usingColumns, ', ') + ')';
            }
            return result;
        }
    }

    private class WhereClause extends Junction implements Query.Part {
        public override String toString() {
            String result = super.toString();
            return String.isNotBlank(result) ? 'WHERE ' + result : '';
        }
    }

    private class GroupByClause implements Query.Part {
        private final List<Object> elements = new List<Object>();

        public Boolean isEmpty() {
            return elements.isEmpty();
        }

        public void add(final Object element) {
            validateNotNull(element, 'grouping element');
            elements.add(element);
        }

        public void addAll(final Iterable<Object> items) {
            for (Object item : items) {
                add(item);
            }
        }

        public override String toString() {
            return 'GROUP BY ' + String.join(toStringList(elements), ', ');
        }
    }

    private class HavingClause extends Junction implements Query.Part {
        public override String toString() {
            String result = super.toString();
            return String.isNotBlank(result) ? 'HAVING ' + result : '';
        }
    }

    private class SetOperatorsClause implements Query.Part, Query.Bindable {
        private final List<SetOperator> operators = new List<SetOperator>();
        private BindContext boundContext;

        public void add(final String type, final Query.Builder other) {
            validateNotBlank(type, 'type');
            validateNotNull(other, 'other');
            this.operators.add(new SetOperator(type, (SqlQuery) other));
        }

        public void withBindContext(final BindContext context) {
            this.boundContext = context;
        }

        public Boolean isEmpty() {
            return operators.isEmpty();
        }

        public override String toString() {
            List<String> result = new List<String>();
            for (SetOperator operator : operators) {
                prepareSubQuery(operator.query, boundContext);
                result.add(operator.type + ' ' + operator.query.buildQueryString(boundContext));
            }
            return String.join(result, ' ');
        }
    }

    private static void prepareSubQuery(SqlQuery query, BindContext context) {
        if (query != null) {
            query.withBindContext(context);
        }
    }

    private class SetOperator {
        private final String type;
        private final SqlQuery query;

        public SetOperator(String type, SqlQuery query) {
            this.type = type;
            this.query = query;
        }
    }

    private class OrderByClause implements Query.Part {
        private final List<String> orders = new List<String>();

        public Boolean isEmpty() {
            return orders.isEmpty();
        }

        public void add(final Object element, final Query.SortOrder sortOrder, final Query.NullsOrder nullsOrder) {
            orders.add(formatOrder(element, sortOrder, nullsOrder));
        }

        public override String toString() {
            return orders.isEmpty() ? '' : 'ORDER BY ' + String.join(orders, ', ');
        }
    }

    private class LimitClause implements Query.Part {
        private Integer value;

        public Boolean isEmpty() {
            return value == null;
        }

        private void set(Integer value) {
            validateNotNull(value, 'limit');
            validateIsTrue(value >= 0, 'LIMIT must be >= 0');
            this.value = value;
        }

        public override String toString() {
            return value == null ? '' : 'LIMIT ' + value;
        }
    }

    private class OffsetClause implements Query.Part {
        private Integer value;

        public Boolean isEmpty() {
            return value == null;
        }

        private void set(Integer value) {
            validateNotNull(value, 'offset');
            validateIsTrue(value >= 0, 'OFFSET must be >= 0');
            this.value = value;
        }

        public override String toString() {
            return value == null ? '' : 'OFFSET ' + value;
        }
    }

    private class FetchClause implements Query.Part {
        private String type; // FIRST | NEXT
        private Integer count;
        private Boolean withTies = false;

        public Boolean isEmpty() {
            return type == null;
        }

        private void set(String type, Integer count, Boolean withTies) {
            validateNotBlank(type, 'type');
            validateIsTrue(count >= 0, 'FETCH count must be >= 0. Value: ' + count);
            this.type = type;
            this.count = count;
            this.withTies = withTies;
        }

        public override String toString() {
            String result = 'FETCH ' + type;
            if (count != null) {
                result += ' ' + count;
            }
            result += (count == 1 ? ' ROW' : ' ROWS');
            result += (withTies ? ' WITH TIES' : ' ONLY');
            return result;
        }
    }
    // </editor-fold>

    private class Context {
        private final SqlQuery query;

        private Context(SqlQuery query) {
            this.query = query;
        }

        private Compiled compile(Boolean isCount) {
            BindContext context = new BindContext(query.getBindingStrategy());
            String queryString = isCount ? query.toCountString(context) : query.buildQueryString(context);
            String inlineQuery = isCount ? query.toInlineCountString() : query.toInlineString();
            Map<String, Object> bindings = context.getMap().clone();
            bindings.putAll(query.getUserBindings());
            return new Compiled(queryString, inlineQuery, bindings);
        }

        private List<Object> run(Type listType) {
            validateDriver();
            validateNotNull(listType, 'listType');
            QueryArgs args = getArgs(false);
            Long start = timerStart(query.getTimer());
            List<Object> results = query.driver.run(args);
            logTimer(query.isTimerEnabled(), query.getTimer(), 'sql.run', start);

            Type elementType = elementType(listType);
            validateIsTrue(
                elementType != null,
                'Unable to resolve element type from listType ' + listType + '. Ensure the DTO class is visible.'
            );
            Boolean isUntyped =
                listType == List<Object>.class ||
                listType == List<Map<String, Object>>.class ||
                isUntyped(elementType);
            if (isUntyped) {
                return results;
            }

            Boolean sObjectLike = elementType == SObject.class;
            if (!sObjectLike) {
                try {
                    sObjectLike = elementType.newInstance() instanceof SObject;
                } catch (Exception ignored) {
                    sObjectLike = false;
                }
            }
            Boolean requiresNormalization = !sObjectLike;
            return projectRowsByElementType(results, listType, false, requiresNormalization);
        }

        private Integer count() {
            validateDriver();
            QueryArgs args = getArgs(true);
            Long start = timerStart(query.getTimer());
            Integer result = query.driver.count(args);
            logTimer(query.isTimerEnabled(), query.getTimer(), 'sql.count', start);
            return result;
        }

        private Object explain() {
            validateDriver();
            QueryArgs args = getArgs(false);
            Long start = timerStart(query.getTimer());
            Object result = query.driver.explain(args);
            logTimer(query.isTimerEnabled(), query.getTimer(), 'sql.explain', start);
            return result;
        }

        private QueryArgs getArgs(Boolean isCount) {
            Compiled compiled = compile(isCount);
            QueryArgs args = new QueryArgs(compiled.query, compiled.inlineQuery, compiled.bindings);
            args.isDebugEnabled = query.isDebugEnabled();
            args.isTimerEnabled = query.isTimerEnabled();
            args.timerMode = query.getTimer();
            return args;
        }

        private void validateDriver() {
            if (query.driver == null) {
                throw new Query.QueryException(
                    'No driver configured. Use useDriver() or extend SqlQuery with a preconfigured driver.'
                );
            }
        }
    }

    private class Compiled {
        final String query;
        final String inlineQuery;
        final Map<String, Object> bindings;
        private Compiled(String query, String inlineQuery, Map<String, Object> bindings) {
            this.query = query;
            this.inlineQuery = inlineQuery;
            this.bindings = bindings;
        }
    }

    private class ValuesClause implements Query.Part, Bindable {
        private final List<List<Object>> rows = new List<List<Object>>();
        private String alias;
        private List<String> columns;
        private BindContext boundContext;

        public Boolean isEmpty() {
            return rows.isEmpty();
        }

        private void set(List<List<Object>> rows, String alias, List<String> columns) {
            validateNotNull(rows, 'rows');
            validateNotBlank(alias, 'alias');
            validateNotNull(columns, 'columns');
            validateIsTrue(!rows.isEmpty(), 'rows cannot be empty');
            validateIsTrue(!columns.isEmpty(), 'columns cannot be empty');
            for (String column : columns) {
                validateNotBlank(column, 'column');
            }
            // Validate all rows have same size as columns
            for (List<Object> row : rows) {
                validateIsTrue(row != null && row.size() == columns.size(), 'Row size must match column count');
            }
            this.rows.clear();
            this.rows.addAll(rows);
            this.alias = alias;
            this.columns = columns;
        }

        public void withBindContext(final BindContext context) {
            this.boundContext = context;
        }

        public override String toString() {
            List<String> result = new List<String>();
            for (List<Object> row : rows) {
                List<String> valStrings = new List<String>();
                for (Object value : row) {
                    if (boundContext != null) {
                        valStrings.add((boundContext.isNamed() ? ':' : '') + boundContext.add(value));
                    } else {
                        valStrings.add(Query.formatValue(value));
                    }
                }
                result.add('(' + String.join(valStrings, ', ') + ')');
            }
            String results = String.join(result, ', ');
            String cols = String.join(columns, ', ');
            return 'FROM (VALUES ' + results + ') AS ' + alias + ' (' + cols + ')';
        }
    }
}
