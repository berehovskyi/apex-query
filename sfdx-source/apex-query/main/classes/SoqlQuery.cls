/**
 * Fluent SOQL query builder for Salesforce Apex.
 *
 * Provides a type-safe, chainable API for constructing SOQL queries with support for:
 * - Field selection (individual, FieldSets, FIELDS(ALL/CUSTOM/STANDARD))
 * - Polymorphic TYPEOF clauses
 * - Sub-queries and relationship queries
 * - Complex WHERE conditions with AND/OR/NOT junctions
 * - Aggregates, GROUP BY, HAVING, ORDER BY
 * - Caching (memoization, Platform Cache)
 * - Multiple execution drivers (DatabaseDriver, RestDriver)
 * - Security policies (USER_MODE, SYSTEM_MODE, sharing controls)
 *
 * Helper providers for SOQL-specific syntax:
 * - DT: Date functions (calendarMonth, dayOnly, fiscalYear, etc.)
 * - LIT: Date literals (today, lastNDays(n), thisQuarter, etc.)
 * - GEO: Geolocation functions (distance, GEOLOCATION)
 * - CUR: Currency literals for multi-currency orgs
 * - COND: Condition builder factory for WHERE clauses
 * - HAV: Condition builder factory for HAVING clauses
 * - CAT: Data Category specification for WITH DATA CATEGORY
 *
 * @example
 * List<Account> accounts = SoqlQuery.of(Account.SObjectType)
 *     .field(Account.Name)
 *     .addConditionEq(Account.Type, 'Customer')
 *     .orderBy(Account.Name)
 *     .fetch();
 *
 * List<AggregateResult> results = SoqlQuery.of('Opportunity')
 *     .field('StageName')
 *     .count('Id', 'Total')
 *     .groupBy('StageName')
 *     .havingx(SoqlQuery.HAV.count('Id').gt(10))
 *     .fetch();
 *
 * List<AccountDto> externalAccounts = (List<AccountDto>) SoqlQuery.of('Account')
 *     .useDriver(new SoqlQuery.RestDriver('MyNamedCredential'))
 *     .field('Id')
 *     .field('Name')
 *     .fetchInto(List<AccountDto>.class);
 */
public virtual inherited sharing class SoqlQuery extends Query implements Builder {
    @TestVisible
    private static CacheFactory cacheFactory = new DefaultCacheFactory();

    // <editor-fold desc="Query Clauses">
    protected final FromClause queriedSObject;
    protected final TypeOfClause typesOf = new TypeOfClause();
    protected final SubQueriesClause subQueries = new SubQueriesClause();
    protected final UsingScopeClause filterScope = new UsingScopeClause();
    protected final WhereClause whereClause = new WhereClause();
    protected final WithClause withDataCategoryClause = new WithClause();
    protected final GroupByClause groupsBy = new GroupByClause();
    protected final HavingClause havingClause = new HavingClause();
    protected final OrderByClause ordersBy = new OrderByClause();
    protected final LimitClause lim = new LimitClause();
    protected final OffsetClause offset = new OffsetClause();
    protected final ForViewRefClause forViewRef = new ForViewRefClause();
    protected final UpdateClause updateStatement = new UpdateClause();
    protected final ForUpdateClause forUpdate = new ForUpdateClause();
    protected final AllRowsClause allRows = new AllRowsClause();
    // </editor-fold>

    // <editor-fold desc="Providers">
    /** Date function provider for date parts like CALENDAR_MONTH, DAY_ONLY, etc. */
    public static final DatePartProvider DT = new DatePartProvider();
    /** Date literal provider for TODAY, LAST_N_DAYS(n), etc. */
    public static final DateLiteralProvider LIT = new DateLiteralProvider();
    /** Geolocation function provider for DISTANCE calculations. */
    public static final GeoPartProvider GEO = new GeoPartProvider();
    /** Currency literal provider for multi-currency ISO codes. */
    public static final CurrencyLiteralProvider CUR = new CurrencyLiteralProvider();
    // </editor-fold>

    // <editor-fold desc="Helper Static Properties">
    private static final ComparisonOperator COMP_OP = new ComparisonOperator();
    // </editor-fold>

    // <editor-fold desc="Query Clauses">
    private final SelectClause selects {
        get {
            if (selects == null) {
                selects = new SelectClause(queriedSObject.sObjType);
            }
            return selects;
        }
        set;
    }
    // </editor-fold>

    // <editor-fold desc="Getter Providers">
    /** Condition builder factory for WHERE clauses. Returns a new instance on each access. */
    public static final Condition COND {
        get {
            return new Condition();
        }
    }

    /** Data Category specification builder for WITH DATA CATEGORY clauses. */
    public static final CategorySpec CAT {
        get {
            return new CategorySpec();
        }
    }

    /** Condition builder factory for HAVING clauses. Returns a new instance on each access. */
    public static final HavingCondition HAV {
        get {
            return new HavingCondition();
        }
    }
    // </editor-fold>

    // <editor-fold desc="Helper Properties">
    private final CacheConfig caching {
        get {
            if (caching == null) {
                caching = new CacheConfig();
            }
            return caching;
        }
        set;
    }

    private final Context ctx {
        get {
            if (ctx == null) {
                ctx = new Context(this);
            }
            return ctx;
        }
        set;
    }
    // </editor-fold>

    // <editor-fold desc="Construction and Configuration">
    public SoqlQuery(final SObjectType sObjType) {
        this(sObjType?.toString());
    }

    public SoqlQuery(final String sObjType) {
        queriedSObject = new FromClause(sObjType);
    }

    public static SoqlQuery of(final SObjectType sObjType) {
        return new SoqlQuery(sObjType);
    }

    public static SoqlQuery of(final String sObjType) {
        return new SoqlQuery(sObjType);
    }

    /**
     * Sets a custom execution driver.
     * @param driver Driver implementation to use for terminal operations
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .useDriver(new CustomDriver());
     */
    public SoqlQuery useDriver(final Driver driver) {
        ctx.setDriver(driver);
        return this;
    }

    /**
     * Shortcut for configuring the Salesforce REST driver with a Named Credential.
     * @param namedCredential Named Credential endpoint name (for example `MyNC`)
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .useRestDriver('MyNC');
     * // result: query executes through REST API using `callout:MyNC/services/data/...` endpoints
     */
    public SoqlQuery useRestDriver(final String namedCredential) {
        return useDriver(new RestDriver(namedCredential));
    }
    // </editor-fold>

    // <editor-fold desc="Fluent Static Logic">
    /**
     * Creates a grouped `AND` criterion to control logical precedence.
     * @param c1 First criterion
     * @param c2 Second criterion
     * @return Grouped `AND` junction: `(c1 AND c2)`
     * @example
     * Query.Criterion grouped = SoqlQuery.ands(
     *     SoqlQuery.COND.field('Type').eq('Customer'),
     *     SoqlQuery.COND.field('IsActive').isTrue()
     * );
     * // result: (Type = 'Customer' AND IsActive = TRUE)
     */
    public static Junction ands(final Query.Criterion c1, final Query.Criterion c2) {
        return new Junction().ands(c1, c2);
    }

    /**
     * Iterable overload of grouped `AND` for dynamic condition lists.
     * @param conditions Criteria to combine with `AND`
     * @return Grouped `AND` junction over all provided criteria
     * @example
     * List<Query.Criterion> parts = new List<SoqlQuery.Criterion>{
     *     SoqlQuery.COND.field('Industry').eq('Tech'),
     *     SoqlQuery.COND.field('BillingCountry').eq('US')
     * };
     * SoqlQuery.Criterion grouped = SoqlQuery.ands(parts);
     * // result: (Industry = 'Tech' AND BillingCountry = 'US')
     */
    public static Junction ands(final Iterable<Criterion> conditions) {
        return new Junction().ands(conditions);
    }

    /**
     * Creates a grouped `OR` criterion to control logical precedence.
     * @param c1 First criterion
     * @param c2 Second criterion
     * @return Grouped `OR` junction: `(c1 OR c2)`
     * @example
     * Query.Criterion grouped = SoqlQuery.ors(
     *     SoqlQuery.COND.field('StageName').eq('Closed Won'),
     *     SoqlQuery.COND.field('StageName').eq('Closed Lost')
     * );
     * // result: (StageName = 'Closed Won' OR StageName = 'Closed Lost')
     */
    public static Junction ors(final Query.Criterion c1, final Query.Criterion c2) {
        return new Junction().ors(c1, c2);
    }

    /**
     * Iterable overload of grouped `OR` for dynamic condition lists.
     * @param conditions Criteria to combine with `OR`
     * @return Grouped `OR` junction over all provided criteria
     * @example
     * List<Query.Criterion> parts = new List<SoqlQuery.Criterion>{
     *     SoqlQuery.COND.field('OwnerId').eq('005...'),
     *     SoqlQuery.COND.field('CreatedById').eq('005...')
     * };
     * SoqlQuery.Criterion grouped = SoqlQuery.ors(parts);
     * // result: (OwnerId = '005...' OR CreatedById = '005...')
     */
    public static Junction ors(final Iterable<Criterion> conditions) {
        return new Junction().ors(conditions);
    }

    /**
     * Negates a criterion as `(NOT <criterion>)`, preserving inner grouping.
     * @param condition Criterion to negate
     * @return Negated criterion: `(NOT condition)`
     * @example
     * Query.Criterion c = SoqlQuery.notx(
     *     SoqlQuery.ors(
     *         SoqlQuery.COND.field('IsDeleted').eq(true),
     *         SoqlQuery.COND.field('IsArchived').isTrue()
     *     )
     * );
     * // result: (NOT (IsDeleted = TRUE OR IsArchived = TRUE))
     */
    public static Query.Criterion notx(final Query.Criterion condition) {
        return new Junction().notx(condition);
    }
    // </editor-fold>

    // <editor-fold desc="Select Fields">
    public SoqlQuery field(final SObjectField field) {
        return field(field?.toString());
    }

    public SoqlQuery field(final String field) {
        selects.add(field);
        return this;
    }

    public SoqlQuery fields(final Iterable<Object> fields) {
        selects.addAll(fields);
        return this;
    }

    public SoqlQuery fields(final String fields) {
        selects.addAll(fields);
        return this;
    }

    /**
     * Selects all fields from the specified FieldSet.
     * Warning: This method involves schema describe operations and can impact performance.
     * @param fieldSet name of the FieldSet to include
     * @return this query
     */
    public SoqlQuery fieldSet(final String fieldSet) {
        selects.addAllFromFieldSet(fieldSet, ctx.getDescribeProvider().describeSObject(queriedSObject.sObjType));
        return this;
    }

    /**
     * Selects all fields using SOQL's FIELDS(ALL) syntax.
     * Note: Automatically sets LIMIT to 200 as required by Salesforce for FIELDS(ALL) queries.
     * @return this query
     */
    public SoqlQuery allFields() {
        selects.add('FIELDS(ALL)');
        lim.set(200);
        return this;
    }

    /**
     * Selects all custom fields using SOQL's FIELDS(CUSTOM) syntax.
     * Note: Automatically sets LIMIT to 200 as required by Salesforce for FIELDS() queries.
     * @return this query
     */
    public SoqlQuery customFields() {
        selects.add('FIELDS(CUSTOM)');
        lim.set(200);
        return this;
    }

    public SoqlQuery standardFields() {
        selects.add('FIELDS(STANDARD)');
        return this;
    }

    /**
     * Selects all fields by performing a schema describe call.
     * Warning: This method involves schema describe operations and can impact performance.
     * Consider using allFields() with FIELDS(ALL) for better performance when possible.
     * @return this query
     */
    public SoqlQuery allDescribeFields() {
        return allFields(new Set<FieldProperty>());
    }

    /**
     * Selects all fields matching the specified field property (e.g., ACCESSIBLE, UPDATEABLE).
     * Warning: This method involves schema describe operations and can impact performance.
     * @param property field property to filter by
     * @return this query
     */
    public SoqlQuery allFields(final FieldProperty property) {
        return allFields(new Set<FieldProperty>{ property });
    }

    /**
     * Selects all fields matching the specified field properties (e.g., ACCESSIBLE, UPDATEABLE).
     * Warning: This method involves schema describe operations and can impact performance.
     * @param properties field properties to filter by
     * @return this query
     */
    public SoqlQuery allFields(final Iterable<FieldProperty> properties) {
        final Object describe = ctx.getDescribeProvider().describeSObject(queriedSObject.sObjType);
        List<Object> allFields;
        if (describe instanceof DescribeSObjectResponse) {
            allFields = ((DescribeSObjectResponse) describe).fields;
        } else {
            allFields = ((DescribeSObjectResult) describe).fields.getMap().values();
        }
        selects.allFields(allFields, properties);
        return this;
    }

    /**
     * Selects all readable (accessible) fields.
     * Warning: This method involves schema describe operations and can impact performance.
     * @return this query
     */
    public SoqlQuery allReadableFields() {
        return allFields(FieldProperty.ACCESSIBLE);
    }

    /**
     * Selects all editable (updateable) fields.
     * Warning: This method involves schema describe operations and can impact performance.
     * @return this query
     */
    public SoqlQuery allEditableFields() {
        return allFields(FieldProperty.UPDATEABLE);
    }

    /**
     * Selects all creatable fields.
     * Warning: This method involves schema describe operations and can impact performance.
     * @return this query
     */
    public SoqlQuery allCreatableFields() {
        return allFields(FieldProperty.CREATABLE);
    }
    // </editor-fold>

    // <editor-fold desc="Select Functions">
    public SoqlQuery convertCurrency(final SObjectField field) {
        return convertCurrency(field, '');
    }

    public SoqlQuery convertCurrency(final String field) {
        return convertCurrency(field, '');
    }

    public SoqlQuery convertCurrency(final SObjectField field, final String alias) {
        return convertCurrency(field?.toString(), alias);
    }

    public SoqlQuery convertCurrency(final String field, final String alias) {
        selects.addSelectFunction('convertCurrency', field, alias);
        return this;
    }

    public SoqlQuery convertTimezone(final SObjectField field) {
        return convertTimezone(field?.toString());
    }

    public SoqlQuery convertTimezone(final String field) {
        selects.addSelectFunction('convertTimezone', field, '');
        return this;
    }

    public SoqlQuery format(final SObjectField field) {
        return format(field, '');
    }

    public SoqlQuery format(final String field) {
        return format(field, '');
    }

    public SoqlQuery format(final SObjectField field, final String alias) {
        return format(field?.toString(), alias);
    }

    public SoqlQuery format(final String field, final String alias) {
        selects.addSelectFunction('FORMAT', field, alias);
        return this;
    }

    public SoqlQuery grouping(final SObjectField field) {
        return grouping(field, '');
    }

    public SoqlQuery grouping(final String field) {
        return grouping(field, '');
    }

    public SoqlQuery grouping(final SObjectField field, final String alias) {
        return grouping(field?.toString(), alias);
    }

    public SoqlQuery grouping(final String field, final String alias) {
        selects.addSelectFunction('GROUPING', field, alias);
        return this;
    }

    public SoqlQuery toLabel(final SObjectField field) {
        return toLabel(field, '');
    }

    public SoqlQuery toLabel(final String field) {
        return toLabel(field, '');
    }

    public SoqlQuery toLabel(final SObjectField field, final String alias) {
        return toLabel(field?.toString(), alias);
    }

    public SoqlQuery toLabel(final String field, final String alias) {
        selects.addSelectFunction('toLabel', field, alias);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="TYPEOF">
    /**
     * Adds a prebuilt `TYPEOF` clause to the SELECT projection.
     * @param typeOf Completed `TypeOf` builder (must be finalized with `.end()`)
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery.TypeOf ownerType = new SoqlQuery.TypeOf('Owner')
     *     .when('User').then('Alias')
     *     .when('Group').then('Name')
     *     .elsex('Subject')
     *     .end();
     * SoqlQuery q = SoqlQuery.of('Task').field('Id').typeOf(ownerType);
     * // result: SELECT Id, TYPEOF Owner WHEN User THEN Alias WHEN Group THEN Name ELSE Subject END FROM Task
     */
    public SoqlQuery typeOf(final TypeOf typeOf) {
        typesOf.add(typeOf);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="Sub-Queries">
    /**
     * Adds a relationship subquery to the SELECT projection.
     * @param relationshipName Child relationship API name (for example `Contacts`)
     * @param subQuery Child query builder (must be a `SoqlQuery` instance)
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .field('Id')
     *     .subQuery('Contacts', SoqlQuery.of('Contact').field('LastName'));
     * // result: SELECT Id, (SELECT LastName FROM Contacts) FROM Account
     */
    public SoqlQuery subQuery(final String relationshipName, final Query.Builder subQuery) {
        subQueries.add(relationshipName, (SoqlQuery) subQuery);
        return this;
    }

    public SoqlQuery subQuery(
        final String relationshipName,
        final SObjectType sObjType,
        final Iterable<Object> fields
    ) {
        return subQuery(relationshipName, new SoqlQuery(sObjType).fields(fields));
    }

    public SoqlQuery subQuery(final String relationshipName, final String sObjType, final Iterable<Object> fields) {
        return subQuery(relationshipName, new SoqlQuery(sObjType).fields(fields));
    }

    public SoqlQuery subQuery(final String relationshipName, final SObjectType sObjType, final String fields) {
        return subQuery(relationshipName, new SoqlQuery(sObjType).fields(fields));
    }

    public SoqlQuery subQuery(final String relationshipName, final String sObjType, final String fields) {
        return subQuery(relationshipName, new SoqlQuery(sObjType).fields(fields));
    }

    public Map<String, Set<String>> getSubQueryHierarchy() {
        return subQueries.getHierarchy();
    }
    // </editor-fold>

    // <editor-fold desc="Aggregate Functions">
    public SoqlQuery count(final SObjectField field) {
        return count(field, '');
    }

    public SoqlQuery count(final String field) {
        return count(field, '');
    }

    public SoqlQuery count(final SObjectField field, final String alias) {
        return count(field?.toString(), alias);
    }

    public SoqlQuery count(final String field, final String alias) {
        selects.addSelectFunction('COUNT', field, alias);
        return this;
    }

    public SoqlQuery countDistinct(final SObjectField field) {
        return countDistinct(field, '');
    }

    public SoqlQuery countDistinct(final String field) {
        return countDistinct(field, '');
    }

    public SoqlQuery countDistinct(final SObjectField field, final String alias) {
        return countDistinct(field?.toString(), alias);
    }

    public SoqlQuery countDistinct(final String field, final String alias) {
        selects.addSelectFunction('COUNT_DISTINCT', field, alias);
        return this;
    }

    public SoqlQuery avg(final SObjectField field) {
        return avg(field, '');
    }

    public SoqlQuery avg(final String field) {
        return avg(field, '');
    }

    public SoqlQuery avg(final SObjectField field, final String alias) {
        return avg(field?.toString(), alias);
    }

    public SoqlQuery avg(final String field, final String alias) {
        selects.addSelectFunction('AVG', field, alias);
        return this;
    }

    public SoqlQuery min(final SObjectField field) {
        return min(field, '');
    }

    public SoqlQuery min(final String field) {
        return min(field, '');
    }

    public SoqlQuery min(final SObjectField field, final String alias) {
        return min(field?.toString(), alias);
    }

    public SoqlQuery min(final String field, final String alias) {
        selects.addSelectFunction('MIN', field, alias);
        return this;
    }

    public SoqlQuery max(final SObjectField field) {
        return max(field, '');
    }

    public SoqlQuery max(final String field) {
        return max(field, '');
    }

    public SoqlQuery max(final SObjectField field, final String alias) {
        return max(field?.toString(), alias);
    }

    public SoqlQuery max(final String field, final String alias) {
        selects.addSelectFunction('MAX', field, alias);
        return this;
    }

    public SoqlQuery sum(final SObjectField field) {
        return sum(field, '');
    }

    public SoqlQuery sum(final String field) {
        return sum(field, '');
    }

    public SoqlQuery sum(final SObjectField field, final String alias) {
        return sum(field?.toString(), alias);
    }

    public SoqlQuery sum(final String field, final String alias) {
        selects.addSelectFunction('SUM', field, alias);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="USING SCOPE">
    /**
     * Adds `USING SCOPE` to restrict result context (for example `MINE`, `TEAM`).
     * @param scope Scope enum value to apply
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Task')
     *     .field('Id')
     *     .usingScope(SoqlQuery.Scope.MINE);
     * // result: SELECT Id FROM Task USING SCOPE MINE
     */
    public SoqlQuery usingScope(final Scope scope) {
        filterScope.set(scope);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="WHERE">
    /**
     * Replaces the entire WHERE clause with a single root condition.
     *
     * This method clears previously added WHERE criteria before adding `condition`.
     * Use `addCondition*` methods to append without overriding existing filters.
     *
     * @param condition root WHERE condition
     * @return this query
     */
    public SoqlQuery wherex(final Query.Criterion condition) {
        whereClause.clear();
        whereClause.add(condition);
        return this;
    }

    /**
     * String overload of {@link #wherex(Query.Criterion)}.
     * Replaces the entire WHERE clause.
     *
     * @param condition raw WHERE condition string
     * @return this query
     */
    public SoqlQuery wherex(final String condition) {
        return wherex(new Condition(condition));
    }

    /**
     * Appends a condition to the current WHERE clause.
     *
     * Unlike `wherex(...)`, this method does not clear previously added criteria.
     *
     * @param condition condition to append
     * @return this query
     */
    public SoqlQuery addCondition(final Query.Criterion condition) {
        whereClause.add(condition);
        return this;
    }

    /**
     * String overload of {@link #addCondition(Query.Criterion)}.
     * Appends to existing WHERE criteria.
     *
     * @param condition raw WHERE condition string
     * @return this query
     */
    public SoqlQuery addCondition(final String condition) {
        return addCondition(new Condition(condition));
    }

    public SoqlQuery addConditionAnd(final Query.Criterion condition) {
        whereClause.add(condition, 'AND');
        return this;
    }

    public SoqlQuery addConditionAnd(final String condition) {
        return addConditionAnd(new Condition(condition));
    }

    public SoqlQuery addConditionOr(final Query.Criterion condition) {
        whereClause.add(condition, 'OR');
        return this;
    }

    public SoqlQuery addConditionOr(final String condition) {
        return addConditionOr(new Condition(condition));
    }

    public SoqlQuery addConditionEq(final SObjectField field, final Object value) {
        return addCondition(new Condition().field(field).eq(value));
    }

    public SoqlQuery addConditionEq(final String field, final Object value) {
        return addCondition(new Condition().field(field).eq(value));
    }

    public SoqlQuery addConditionNe(final SObjectField field, final Object value) {
        return addCondition(new Condition().field(field).ne(value));
    }

    public SoqlQuery addConditionNe(final String field, final Object value) {
        return addCondition(new Condition().field(field).ne(value));
    }

    public SoqlQuery addConditionIn(final SObjectField field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).inx(iterable));
    }

    public SoqlQuery addConditionIn(final String field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).inx(iterable));
    }

    /**
     * Adds a semi-join filter using `IN (subquery)`.
     * @param field Parent-side field to compare (for example `Account.Id`)
     * @param semiJoinSubQuery Child-side subquery selecting comparable values
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .field('Name')
     *     .addConditionIn(Account.Id, SoqlQuery.of('Contact').field('AccountId'));
     * // result: SELECT Name FROM Account WHERE Id IN (SELECT AccountId FROM Contact)
     */
    public SoqlQuery addConditionIn(final SObjectField field, final Query.Builder semiJoinSubQuery) {
        return addCondition(new Condition().field(field).inx(semiJoinSubQuery));
    }

    /**
     * Adds a semi-join filter using `IN (subquery)`.
     * @param field Parent-side field API name
     * @param semiJoinSubQuery Child-side subquery selecting comparable values
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .field('Name')
     *     .addConditionIn('Id', SoqlQuery.of('Contact').field('AccountId'));
     * // result: SELECT Name FROM Account WHERE Id IN (SELECT AccountId FROM Contact)
     */
    public SoqlQuery addConditionIn(final String field, final Query.Builder semiJoinSubQuery) {
        return addCondition(new Condition().field(field).inx(semiJoinSubQuery));
    }

    public SoqlQuery addConditionNotIn(final SObjectField field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).notIn(iterable));
    }

    public SoqlQuery addConditionNotIn(final String field, final Iterable<Object> iterable) {
        return addCondition(new Condition().field(field).notIn(iterable));
    }

    /**
     * Adds an anti-join filter using `NOT IN (subquery)`.
     * @param field Parent-side field to compare (for example `Account.Id`)
     * @param antiJoinSubQuery Child-side subquery selecting values to exclude
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .field('Name')
     *     .addConditionNotIn(Account.Id, SoqlQuery.of('Contact').field('AccountId'));
     * // result: SELECT Name FROM Account WHERE Id NOT IN (SELECT AccountId FROM Contact)
     */
    public SoqlQuery addConditionNotIn(final SObjectField field, final Query.Builder antiJoinSubQuery) {
        return addCondition(new Condition().field(field).notIn(antiJoinSubQuery));
    }

    /**
     * Adds an anti-join filter using `NOT IN (subquery)`.
     * @param field Parent-side field API name
     * @param antiJoinSubQuery Child-side subquery selecting values to exclude
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Account')
     *     .field('Name')
     *     .addConditionNotIn('Id', SoqlQuery.of('Contact').field('AccountId'));
     * // result: SELECT Name FROM Account WHERE Id NOT IN (SELECT AccountId FROM Contact)
     */
    public SoqlQuery addConditionNotIn(final String field, final Query.Builder antiJoinSubQuery) {
        return addCondition(new Condition().field(field).notIn(antiJoinSubQuery));
    }

    public SoqlQuery byId(final Id id) {
        return addCondition(new Condition().id().eq(id));
    }

    public SoqlQuery byIds(final Iterable<Id> ids) {
        return addCondition(new Condition().id().inx(ids));
    }
    // </editor-fold>

    // <editor-fold desc="WITH">
    /**
     * Adds a `WITH DATA CATEGORY` selector to the query.
     * @param selection Category selector built via `CategorySpec`
     * @return Current query instance for fluent chaining
     * @example
     * SoqlQuery q = SoqlQuery.of('Knowledge__kav')
     *     .field('Id')
     *     .withDataCategory(SoqlQuery.CAT.of('Geography').at('EMEA'));
     * // result: SELECT Id FROM Knowledge__kav WITH DATA CATEGORY Geography AT EMEA
     */
    public SoqlQuery withDataCategory(final CategorySpec selection) {
        withDataCategoryClause.add(selection);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="GROUP BY">
    public SoqlQuery groupBy(final SObjectField field) {
        return groupBy(field?.toString());
    }

    public SoqlQuery groupBy(final String field) {
        groupsBy.ordinary(field);
        return this;
    }

    public SoqlQuery groupBy(final Iterable<Object> fields) {
        groupsBy.ordinary(fields);
        return this;
    }

    public SoqlQuery groupByRollup(final SObjectField field) {
        return groupByRollup(field?.toString());
    }

    public SoqlQuery groupByRollup(final String field) {
        groupsBy.rollup(field);
        return this;
    }

    public SoqlQuery groupByRollup(final Iterable<Object> fields) {
        groupsBy.rollup(fields);
        return this;
    }

    public SoqlQuery groupByCube(final SObjectField field) {
        return groupByCube(field?.toString());
    }

    public SoqlQuery groupByCube(final String field) {
        groupsBy.cube(field);
        return this;
    }

    public SoqlQuery groupByCube(final Iterable<Object> fields) {
        groupsBy.cube(fields);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="HAVING">
    /**
     * Replaces the entire HAVING clause with a single root condition.
     *
     * This method clears previously added HAVING criteria before adding `condition`.
     * Use `addHaving*` methods to append without overriding existing filters.
     *
     * @param condition root HAVING condition
     * @return this query
     */
    public SoqlQuery havingx(final Query.Criterion condition) {
        havingClause.clear();
        havingClause.add(condition);
        return this;
    }

    /**
     * String overload of {@link #havingx(Query.Criterion)}.
     * Replaces the entire HAVING clause.
     *
     * @param condition raw HAVING condition string
     * @return this query
     */
    public SoqlQuery havingx(final String condition) {
        return havingx(new HavingCondition(condition));
    }

    /**
     * Appends a condition to the current HAVING clause.
     *
     * Unlike `havingx(...)`, this method does not clear previously added criteria.
     *
     * @param condition condition to append
     * @return this query
     */
    public SoqlQuery addHaving(final Query.Criterion condition) {
        havingClause.add(condition);
        return this;
    }

    /**
     * String overload of {@link #addHaving(Query.Criterion)}.
     * Appends to existing HAVING criteria.
     *
     * @param condition raw HAVING condition string
     * @return this query
     */
    public SoqlQuery addHaving(final String condition) {
        return addHaving(new HavingCondition(condition));
    }

    public SoqlQuery addHavingAnd(final Query.Criterion condition) {
        havingClause.add(condition, 'AND');
        return this;
    }

    public SoqlQuery addHavingAnd(final String condition) {
        return addHavingAnd(new HavingCondition(condition));
    }

    public SoqlQuery addHavingOr(final Query.Criterion condition) {
        havingClause.add(condition, 'OR');
        return this;
    }

    public SoqlQuery addHavingOr(final String condition) {
        return addHavingOr(new HavingCondition(condition));
    }

    public SoqlQuery addHavingEq(final SObjectField field, final Object value) {
        return addHavingEq(field?.toString(), value);
    }

    public SoqlQuery addHavingEq(final String field, final Object value) {
        return addHaving(new HavingCondition().field(field).eq(value));
    }

    public SoqlQuery addHavingNe(final SObjectField field, final Object value) {
        return addHavingNe(field?.toString(), value);
    }

    public SoqlQuery addHavingNe(final String field, final Object value) {
        return addHaving(new HavingCondition().field(field).ne(value));
    }

    public SoqlQuery addHavingIn(final SObjectField field, final Iterable<Object> iterable) {
        return addHavingIn(field?.toString(), iterable);
    }

    public SoqlQuery addHavingIn(final String field, final Iterable<Object> iterable) {
        return addHaving(new HavingCondition().field(field).inx(iterable));
    }

    public SoqlQuery addHavingNotIn(final SObjectField field, final Iterable<Object> iterable) {
        return addHavingIn(field?.toString(), iterable);
    }

    public SoqlQuery addHavingNotIn(final String field, final Iterable<Object> iterable) {
        return addHaving(new HavingCondition().field(field).notIn(iterable));
    }
    // </editor-fold>

    // <editor-fold desc="ORDER BY">
    public SoqlQuery orderBy(final SObjectField field) {
        return orderBy(field?.toString());
    }

    public SoqlQuery orderBy(final String field) {
        ordersBy.add(new SortField(field, null, null));
        return this;
    }

    public SoqlQuery orderBy(final SObjectField field, final Query.SortOrder sortOrder) {
        return orderBy(field?.toString(), sortOrder);
    }

    public SoqlQuery orderBy(final String field, final Query.SortOrder sortOrder) {
        ordersBy.add(new SortField(field, sortOrder, null));
        return this;
    }

    public SoqlQuery orderBy(
        final SObjectField field,
        final Query.SortOrder sortOrder,
        final Query.NullsOrder nullsOrder
    ) {
        return orderBy(field?.toString(), sortOrder, nullsOrder);
    }

    public SoqlQuery orderBy(final String field, final Query.SortOrder sortOrder, final Query.NullsOrder nullsOrder) {
        ordersBy.add(new SortField(field, sortOrder, nullsOrder));
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="LIMIT">
    public SoqlQuery lim(final Integer count) {
        lim.set(count);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="OFFSET">
    /**
     * Sets SOQL `OFFSET` clause.
     *
     * Typically, Salesforce enforces a maximum offset of 2000 at runtime.
     * This builder intentionally doesn't hard-cap the upper bound so platform-side
     * limits can evolve without requiring a package change.
     *
     * @param count number of rows to skip; must be >= 0
     * @return this query
     */
    public SoqlQuery offset(final Integer count) {
        offset.set(count);
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="FOR VIEW | REFERENCE">
    public SoqlQuery forView() {
        forViewRef.forView();
        return this;
    }

    public SoqlQuery forReference() {
        forViewRef.forReference();
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="UPDATE">
    public SoqlQuery updateTracking() {
        updateStatement.updateTracking();
        return this;
    }

    public SoqlQuery updateViewstat() {
        updateStatement.updateViewstat();
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="FOR UPDATE">
    public SoqlQuery forUpdate() {
        forUpdate.set();
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="ALL ROWS">
    public SoqlQuery allRows() {
        allRows.set();
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="Security">
    public SoqlQuery withMode(final AccessLevel accessLevel) {
        ctx.setMode(accessLevel);
        return this;
    }

    public SoqlQuery withSystemMode() {
        return withMode(AccessLevel.SYSTEM_MODE);
    }

    public SoqlQuery withUserMode() {
        return withMode(AccessLevel.USER_MODE);
    }

    public SoqlQuery withPermissionSetId(final Id permissionSetId) {
        return withPermissionSetIds(new List<Id>{ permissionSetId });
    }

    // prettier-ignore
    public SoqlQuery withPermissionSetIds(final Iterable<Id> permissionSetIds) {
        ctx.addPermissionSetIds(permissionSetIds); return this;
    }
    /**
     * Executes query operations using `with sharing` semantics.
     *
     * @return this query
     */
    public SoqlQuery withSharing() {
        ctx.setDriver(new WithSharingDriver());
        return this;
    }

    /**
     * Executes query operations using `inherited sharing` semantics.
     *
     * @return this query
     */
    public SoqlQuery inheritedSharing() {
        ctx.setDriver(new InheritedSharingDriver());
        return this;
    }

    /**
     * Executes query operations using `without sharing` semantics.
     *
     * @return this query
     */
    public SoqlQuery withoutSharing() {
        ctx.setDriver(new WithoutSharingDriver());
        return this;
    }

    public SoqlQuery withStrip(final AccessType type) {
        ctx.setAccessType(type);
        return this;
    }

    public SoqlQuery withStrip() {
        return withStrip(AccessType.READABLE);
    }
    // </editor-fold>

    // <editor-fold desc="Caching">
    public SoqlQuery memoize() {
        caching.add(CachingStrategy.MEMO);
        return this;
    }

    public SoqlQuery cacheSession(final String partition) {
        caching.add(CachingStrategy.SESSION, partition);
        return this;
    }

    public SoqlQuery cacheSession(final String partition, final Integer ttlInSecs) {
        caching.add(CachingStrategy.SESSION, partition, ttlInSecs);
        return this;
    }

    public SoqlQuery cacheOrg(final String partition) {
        caching.add(CachingStrategy.ORG, partition);
        return this;
    }

    public SoqlQuery cacheOrg(final String partition, final Integer ttlInSecs) {
        caching.add(CachingStrategy.ORG, partition, ttlInSecs);
        return this;
    }

    public SoqlQuery withBindings(final Map<String, Object> binds) {
        if (binds != null) {
            userBindings.putAll(binds);
        }
        return this;
    }
    // </editor-fold>

    // <editor-fold desc="Terminal Operations">
    public List<SObject> fetch() {
        return (List<SObject>) ctx.run(List<SObject>.class);
    }

    /**
     * Executes query and projects records into the provided list type.
     * Requires a list token, for example: `List<Account>.class`, `List<MyDto>.class`,
     * or `List<Map<String, Object>>.class`.
     * @param listType target list type token in form `List<T>.class`
     * @return projected query results as `List<Object>` (castable to `List<T>`)
     */
    public List<Object> fetchInto(final Type listType) {
        return ctx.run(listType);
    }

    /**
     * Executes the query and returns an iterable for lazy, cursor-based retrieval.
     * Note: Uses Database.Cursor for memory-efficient iteration over large result sets.
     * Results are fetched in batches of 2000 records to minimize heap usage.
     * @return iterable of SObjects for lazy iteration
     */
    public Iterable<SObject> fetchLazy() {
        return (Iterable<SObject>) ctx.runMore(List<SObject>.class);
    }

    /**
     * Lazy variant of fetchInto. Requires a list token, for example `List<Account>.class`.
     * @param listType target list type token in form `List<T>.class`
     * @return iterable of projected records as `Iterable<Object>` (castable to `Iterable<T>`)
     */
    public Iterable<Object> fetchLazyInto(final Type listType) {
        return ctx.runMore(listType);
    }

    public SObject fetchFirst() {
        List<SObject> results = fetch();
        return results.isEmpty() ? null : results[0];
    }

    /**
     * Returns first projected row or null. Requires a type token, for example `Dto.class`.
     * @param elementType target type
     * @return first projected record or null
     */
    public Object fetchFirstAs(final Type elementType) {
        List<Object> results = fetchInto(Type.forName('List<' + elementType + '>'));
        return results.isEmpty() ? null : results[0];
    }

    public Integer fetchCount() {
        return ctx.count();
    }

    public Database.QueryLocator locator() {
        return ctx.locator();
    }

    public Database.Cursor cursor() {
        return ctx.cursor();
    }

    public Database.PaginationCursor paginationCursor() {
        return ctx.paginationCursor();
    }

    public Object explain() {
        return ctx.explain();
    }
    // </editor-fold>

    // <editor-fold desc="Build">
    public virtual SoqlQuery debug() {
        isDebugEnabled = true;
        return this;
    }

    public virtual SoqlQuery useTimer() {
        return useTimer(Query.Timer.CPU);
    }

    public virtual SoqlQuery useTimer(final Query.Timer mode) {
        validateNotNull(mode, 'timer');
        isTimerEnabled = true;
        timerMode = mode;
        return this;
    }

    public String toCountString() {
        return toCountString(bindContext);
    }

    public override String toCountString(final BindContext targetContext) {
        return buildCountQueryString(targetContext);
    }

    protected override String getCountSelectPart() {
        return 'COUNT()';
    }

    public override String toString() {
        return buildQueryString(bindContext);
    }

    protected override List<Query.Part> build(final BindContext targetContext) {
        whereClause.withBindContext(targetContext);
        havingClause.withBindContext(targetContext);
        subQueries.withBindContext(targetContext);
        return new List<Query.Part>{
            selects,
            typesOf,
            subQueries,
            queriedSObject,
            filterScope,
            whereClause,
            withDataCategoryClause,
            groupsBy,
            havingClause,
            ordersBy,
            lim,
            offset,
            forViewRef,
            updateStatement,
            forUpdate,
            allRows
        };
    }

    protected override List<Query.Part> buildCount(final BindContext targetContext) {
        whereClause.withBindContext(targetContext);
        return new List<Query.Part>{
            queriedSObject,
            filterScope,
            whereClause,
            withDataCategoryClause,
            lim,
            offset,
            allRows
        };
    }
    // </editor-fold>

    // <editor-fold desc="Private Methods">
    private static void validateSObjectType(final String sObjType) {
        validateNotBlank(sObjType, 'SObject type');
    }

    private static void validateField(final String field) {
        validateNotBlank(field, 'field');
    }

    private static void validateFields(final String fields) {
        validateNotBlank(fields, 'fields');
    }

    private static void validateField(final Object field) {
        validateIsTrue(field != null, 'field cannot be null');
        validateIsTrue(
            field instanceof String || field instanceof SObjectField,
            'field should be String or SObjectField'
        );
    }

    private static void validateFields(final Iterable<Object> fields) {
        validateIsTrue(fields != null, 'fields cannot be null');
        validateIsTrue(fields.iterator().hasNext(), 'fields cannot be empty');
    }

    private static void validateFieldSet(final String fieldSet) {
        validateIsTrue(fieldSet != null, 'FieldSet ' + fieldSet + ' not found');
    }

    private static void validateFunction(final String function) {
        validateNotBlank(function, 'function');
    }

    private static String formatFunction(final String function, final String field, final String alias) {
        validateFunction(function);
        validateField(field);
        return String.format('{0}({1}) {2}', new List<String>{ function, field, alias });
    }

    private static String rewriteCountQueryToId(final String query) {
        return query.replaceFirst('(?is)^\\s*SELECT\\s+COUNT\\s*\\(\\s*\\)\\s+FROM\\s+', 'SELECT Id FROM ');
    }

    @TestVisible
    private static Boolean isSObjectLikeType(final Type candidateType) {
        if (isUntyped(candidateType)) {
            return false;
        }
        if (candidateType == SObject.class) {
            return true;
        }
        try {
            Object instance = candidateType.newInstance();
            return instance instanceof SObject;
        } catch (Exception e) {
            return false;
        }
    }

    @TestVisible
    private static Iterable<SObject> createCursorIterable(final Cursor cursor) {
        return new CursorIterable(cursor);
    }

    private SoqlQuery setRelationshipName(final String relationshipName) {
        queriedSObject.setRelationshipName(relationshipName);
        return this;
    }

    private String getRelationshipName() {
        return queriedSObject.getRelationshipName();
    }
    // </editor-fold>

    // <editor-fold desc="API Classes">
    public interface Builder extends Query.Builder {
        // Drivers
        Query.Builder useDriver(Driver driver);
        // SELECT Fields
        Query.Builder field(SObjectField field);
        Query.Builder fieldSet(String fieldSet);
        Query.Builder allFields();
        Query.Builder customFields();
        Query.Builder standardFields();
        Query.Builder allDescribeFields();
        Query.Builder allFields(Iterable<FieldProperty> properties);
        Query.Builder allFields(FieldProperty property);
        Query.Builder allReadableFields();
        Query.Builder allEditableFields();
        Query.Builder allCreatableFields();
        // SELECT Functions
        Query.Builder convertCurrency(SObjectField field);
        Query.Builder convertCurrency(String field);
        Query.Builder convertCurrency(SObjectField field, String alias);
        Query.Builder convertCurrency(String field, String alias);
        Query.Builder convertTimezone(SObjectField field);
        Query.Builder convertTimezone(String field);
        Query.Builder format(SObjectField field);
        Query.Builder format(String field);
        Query.Builder format(SObjectField field, String alias);
        Query.Builder format(String field, String alias);
        Query.Builder grouping(SObjectField field);
        Query.Builder grouping(SObjectField field, String alias);
        Query.Builder toLabel(SObjectField field);
        Query.Builder toLabel(String field);
        Query.Builder toLabel(SObjectField field, String alias);
        Query.Builder toLabel(String field, String alias);
        // SELECT TYPEOF
        Query.Builder typeOf(TypeOf typeOf);
        // SELECT SubQuery
        Query.Builder subQuery(String relationshipName, Query.Builder subQuery);
        Query.Builder subQuery(String relationshipName, SObjectType sObjType, Iterable<Object> fields);
        Query.Builder subQuery(String relationshipName, String sObjType, Iterable<Object> fields);
        Query.Builder subQuery(String relationshipName, SObjectType sObjType, String fields);
        Query.Builder subQuery(String relationshipName, String sObjType, String fields);
        // SELECT Aggregate Functions
        Query.Builder count(SObjectField field);
        Query.Builder count(SObjectField field, String alias);
        Query.Builder countDistinct(SObjectField field);
        Query.Builder countDistinct(SObjectField field, String alias);
        Query.Builder avg(SObjectField field);
        Query.Builder avg(SObjectField field, String alias);
        Query.Builder min(SObjectField field);
        Query.Builder min(SObjectField field, String alias);
        Query.Builder max(SObjectField field);
        Query.Builder max(SObjectField field, String alias);
        Query.Builder sum(SObjectField field);
        Query.Builder sum(SObjectField field, String alias);
        // USING SCOPE
        Query.Builder usingScope(Scope scope);
        // WHERE
        Query.Builder addConditionEq(SObjectField field, Object value);
        Query.Builder addConditionNe(SObjectField field, Object value);
        Query.Builder addConditionIn(SObjectField field, Iterable<Object> iterable);
        Query.Builder addConditionIn(SObjectField field, Query.Builder semiJoinSubQuery);
        Query.Builder addConditionNotIn(SObjectField field, Iterable<Object> iterable);
        Query.Builder addConditionNotIn(SObjectField field, Query.Builder antiJoinSubQuery);
        Query.Builder byId(Id id);
        Query.Builder byIds(Iterable<Id> ids);
        // WITH
        Query.Builder withDataCategory(CategorySpec selection);
        // GROUP BY
        Query.Builder groupBy(SObjectField field);
        Query.Builder groupBy(String field);
        Query.Builder groupByRollup(SObjectField field);
        Query.Builder groupByRollup(String field);
        Query.Builder groupByCube(SObjectField field);
        Query.Builder groupByCube(String field);
        // HAVING
        Query.Builder havingx(Query.Criterion condition);
        Query.Builder addHaving(Query.Criterion condition);
        Query.Builder addHavingAnd(Query.Criterion condition);
        Query.Builder addHavingOr(Query.Criterion condition);
        Query.Builder addHavingEq(SObjectField field, Object value);
        Query.Builder addHavingNe(SObjectField field, Object value);
        Query.Builder addHavingIn(SObjectField field, Iterable<Object> iterable);
        Query.Builder addHavingIn(String field, Iterable<Object> iterable);
        Query.Builder addHavingNotIn(SObjectField field, Iterable<Object> iterable);
        Query.Builder addHavingNotIn(String field, Iterable<Object> iterable);
        // ORDER BY
        Query.Builder orderBy(SObjectField field);
        Query.Builder orderBy(SObjectField field, Query.SortOrder sortOrder);
        Query.Builder orderBy(SObjectField field, Query.SortOrder sortOrder, Query.NullsOrder nullsOrder);
        // UPDATE { TRACKING | VIEWSTAT }
        Query.Builder updateTracking();
        Query.Builder updateViewstat();
        // FOR { VIEW | REFERENCE }
        Query.Builder forView();
        Query.Builder forReference();
        // FOR UPDATE
        Query.Builder forUpdate();
        // ALL ROWS
        Query.Builder allRows();
        // Security
        Query.Builder withMode(AccessLevel accessLevel);
        Query.Builder withSystemMode();
        Query.Builder withPermissionSetId(Id permissionSetId);
        Query.Builder withPermissionSetIds(Iterable<Id> permissionSetIds);
        Query.Builder withSharing();
        Query.Builder inheritedSharing();
        Query.Builder withoutSharing();
        Query.Builder withStrip(AccessType type);
        Query.Builder withStrip();
        // CACHE
        Query.Builder memoize();
        Query.Builder cacheSession(String partition);
        Query.Builder cacheSession(String partition, Integer ttlInSecs);
        Query.Builder cacheOrg(String partition);
        Query.Builder cacheOrg(String partition, Integer ttlInSecs);
        // Custom Bindings
        Query.Builder withBindings(Map<String, Object> binds);
        Map<String, Object> getBindings();
        // Terminal Operations
        List<SObject> fetch();
        Object fetchInto(Type listType);
        Iterable<SObject> fetchLazy();
        Iterable<Object> fetchLazyInto(Type listType);
        SObject fetchFirst();
        Object fetchFirstAs(Type elementType);
        Integer fetchCount();
        Database.QueryLocator locator();
        Database.Cursor cursor();
        Database.PaginationCursor paginationCursor();
    }

    /**
     * Builder for SOQL TYPEOF polymorphic field queries.
     * Note: Must call .end() to finalize the TYPEOF clause before using it in a query.
     * @example
     * SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner')
     *     .when('User').then('Alias')
     *     .when('Group').then('Name')
     *     .elsex('Id')
     *     .end(); // Required
     * SoqlQuery.of('Account').typeOf(to);
     */
    public class TypeOf {
        private final String polymorphicField;
        private Boolean isEnded = false;
        private final Map<String, Set<String>> fieldsBySObjType = new Map<String, Set<String>>{
            null => new Set<String>()
        };
        private String sObjType;
        public TypeOf(final String polymorphicField) {
            this.polymorphicField = polymorphicField;
        }

        public TypeOf when(final SObjectType sObjType) {
            return when(sObjType?.toString());
        }

        public TypeOf when(final String sObjType) {
            validateSObjectType(sObjType);
            this.sObjType = sObjType;
            if (!fieldsBySObjType.containsKey(sObjType)) {
                fieldsBySObjType.put(sObjType, new Set<String>());
            }
            return this;
        }

        public TypeOf then(final SObjectField field) {
            return then(field?.toString());
        }

        public TypeOf then(final String field) {
            validateField(field);
            validateNotNull(sObjType, 'must call when() before thenField()');
            fieldsBySObjType.get(sObjType).add(field);
            return this;
        }

        public TypeOf thenFields(final Iterable<Object> fields) {
            validateFields(fields);
            validateNotNull(sObjType, 'must call when() before thenFields()');
            for (Object field : fields) {
                validateField(field);
                then(field instanceof String ? (String) field : field.toString());
            }
            return this;
        }

        public TypeOf thenFields(final String fields) {
            validateFields(fields);
            for (String field : fields.split(',')) {
                then(field);
            }
            return this;
        }

        public TypeOf elsex(final SObjectField field) {
            return elsex(field?.toString());
        }

        public TypeOf elsex(final String field) {
            validateField(field);
            fieldsBySObjType.get(null).add(field);
            return this;
        }

        public TypeOf elseFields(final Iterable<Object> fields) {
            return addAll(fields);
        }

        public TypeOf elseFields(final String fields) {
            validateFields(fields);
            for (String field : fields.split(',')) {
                elsex(field.trim());
            }
            return this;
        }

        private TypeOf addAll(final Iterable<Object> fields) {
            validateFields(fields);
            for (Object field : fields) {
                validateField(field);
                elsex(field instanceof String ? (String) field : field.toString());
            }
            return this;
        }

        public TypeOf end() {
            isEnded = true;
            return this;
        }

        public override String toString() {
            if (!isEnded) {
                throw new QueryException('TYPEOF clause must be finalized with .end()');
            }
            if (fieldsBySObjType.size() < 2) {
                return '';
            }
            List<String> result = new List<String>();
            result.add('TYPEOF ' + polymorphicField);
            for (String sObjType : fieldsBySObjType.keySet()) {
                if (sObjType == null || (fieldsBySObjType.get(sObjType)?.isEmpty() ?? true)) {
                    continue;
                }
                result.add(' WHEN ' + sObjType + ' THEN ' + String.join(fieldsBySObjType.get(sObjType), ', '));
            }
            if (!fieldsBySObjType.get(null).isEmpty()) {
                result.add(' ELSE ' + String.join(fieldsBySObjType.get(null), ', '));
            }
            result.add(' END');
            return String.join(result, '');
        }
    }

    public virtual class Condition extends BindableCondition {
        private final String rawCondition;
        private String field;
        private Object value;
        private String operator;

        public Condition() {
        }

        public Condition(final String rawCondition) {
            validateNotBlank(rawCondition, 'rawCondition');
            this.rawCondition = rawCondition;
        }

        public Junction add(final Query.Criterion condition) {
            return new Junction().add(this).add(condition);
        }

        public Junction addAnd(final Query.Criterion condition) {
            return new Junction().add(this).addAnd(condition);
        }

        public Junction addOr(final Query.Criterion condition) {
            return new Junction().add(this).addOr(condition);
        }

        public NegatedCondition notx() {
            return new NegatedCondition(this);
        }

        public Condition id() {
            return field('Id');
        }

        public Condition field(final SObjectField field) {
            return field(field?.toString());
        }

        public Condition field(final String field) {
            validateField(field);
            this.field = field;
            return this;
        }

        public Condition comparand(final String operator, final Object value) {
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
            return comparand(COMP_OP.EQ, value);
        }

        public Condition ne(final Object value) {
            return comparand(COMP_OP.NE, value);
        }

        public Condition lt(final Object value) {
            return comparand(COMP_OP.LT, value);
        }

        public Condition le(final Object value) {
            return comparand(COMP_OP.LE, value);
        }

        public Condition gt(final Object value) {
            return comparand(COMP_OP.GT, value);
        }

        public Condition ge(final Object value) {
            return comparand(COMP_OP.GE, value);
        }

        public Condition likex(final String value) {
            return comparand(COMP_OP.LIKEX, value);
        }

        public Condition inx(final Iterable<Object> iterable) {
            return comparand(COMP_OP.INX, iterable);
        }

        public Condition inx(final Query.Builder semiJoinSubQuery) {
            return comparand(COMP_OP.INX, semiJoinSubQuery);
        }

        public Condition notIn(final Iterable<Object> iterable) {
            return comparand(COMP_OP.NOT_IN, iterable);
        }

        public Condition notIn(final Query.Builder antiJoinSubQuery) {
            return comparand(COMP_OP.NOT_IN, antiJoinSubQuery);
        }

        public Condition includes(final Iterable<Object> iterable) {
            return comparand(COMP_OP.INCLUDES, iterable);
        }

        public Condition includes(final String value) {
            return includes(new List<Object>{ value });
        }

        public Condition excludes(final Iterable<Object> iterable) {
            return comparand(COMP_OP.EXCLUDES, iterable);
        }

        public Condition excludes(final String value) {
            return excludes(new List<Object>{ value });
        }

        protected override String formatValue(final Object value) {
            if (value instanceof Date) {
                return ((Datetime) value).formatGmt('yyyy-MM-dd');
            }
            if (value instanceof Datetime) {
                return ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            }
            if (value instanceof Time) {
                return String.valueOf(value);
            }
            return super.formatValue(value);
        }

        private String formatConditionValue() {
            if (value == null) {
                return 'NULL';
            }
            if (value instanceof SoqlQuery) {
                ((SoqlQuery) value).withBindContext(boundContext);
                return '(' + value + ')';
            }
            if (value instanceof DateLiteral || value instanceof GeoPart || value instanceof CurrencyLiteral) {
                return String.valueOf(value);
            }
            if (operator == COMP_OP.INCLUDES || operator == COMP_OP.EXCLUDES) {
                return formatValue(
                    value instanceof Iterable<Object> ? (Iterable<Object>) value : new List<Object>{ value }
                );
            }
            if (boundContext != null) {
                return ':' + boundContext.add(value);
            }
            return formatValue(value);
        }

        public override String toString() {
            if (rawCondition != null) {
                return rawCondition;
            }
            String result = formatConditionValue();
            return String.format('{0} {1} {2}', new List<Object>{ field, operator, result });
        }
    }

    // prettier-ignore
    public class DatePartProvider {
        public String calendarMonth(final SObjectField field) { return new DatePart('CALENDAR_MONTH', field).toString(); }
        public String calendarMonth(final String field) { return new DatePart('CALENDAR_MONTH', field).toString(); }
        public String calendarQuarter(final SObjectField field) { return new DatePart('CALENDAR_QUARTER', field).toString(); }
        public String calendarQuarter(final String field) { return new DatePart('CALENDAR_QUARTER', field).toString(); }
        public String calendarYear(final SObjectField field) { return new DatePart('CALENDAR_YEAR', field).toString(); }
        public String calendarYear(final String field) { return new DatePart('CALENDAR_YEAR', field).toString(); }
        public String dayInMonth(final SObjectField field) { return new DatePart('DAY_IN_MONTH', field).toString(); }
        public String dayInMonth(final String field) { return new DatePart('DAY_IN_MONTH', field).toString(); }
        public String dayInWeek(final SObjectField field) { return new DatePart('DAY_IN_WEEK', field).toString(); }
        public String dayInWeek(final String field) { return new DatePart('DAY_IN_WEEK', field).toString(); }
        public String dayInYear(final SObjectField field) { return new DatePart('DAY_IN_YEAR', field).toString(); }
        public String dayInYear(final String field) { return new DatePart('DAY_IN_YEAR', field).toString(); }
        public String dayOnly(final SObjectField field) { return new DatePart('DAY_ONLY', field).toString(); }
        public String dayOnly(final String field) { return new DatePart('DAY_ONLY', field).toString(); }
        public String fiscalMonth(final SObjectField field) { return new DatePart('FISCAL_MONTH', field).toString(); }
        public String fiscalMonth(final String field) { return new DatePart('FISCAL_MONTH', field).toString(); }
        public String fiscalQuarter(final SObjectField field) { return new DatePart('FISCAL_QUARTER', field).toString(); }
        public String fiscalQuarter(final String field) { return new DatePart('FISCAL_QUARTER', field).toString(); }
        public String fiscalYear(final SObjectField field) { return new DatePart('FISCAL_YEAR', field).toString(); }
        public String fiscalYear(final String field) { return new DatePart('FISCAL_YEAR', field).toString(); }
        public String hourInDay(final SObjectField field) { return new DatePart('HOUR_IN_DAY', field).toString(); }
        public String hourInDay(final String field) { return new DatePart('HOUR_IN_DAY', field).toString(); }
        public String weekInMonth(final SObjectField field) { return new DatePart('WEEK_IN_MONTH', field).toString(); }
        public String weekInMonth(final String field) { return new DatePart('WEEK_IN_MONTH', field).toString(); }
        public String weekInYear(final SObjectField field) { return new DatePart('WEEK_IN_YEAR', field).toString(); }
        public String weekInYear(final String field) { return new DatePart('WEEK_IN_YEAR', field).toString(); }
    }
    // prettier-ignore
    public class DateLiteralProvider {
        public final DateLiteral yesterday = new DateLiteral('YESTERDAY');
        public final DateLiteral today = new DateLiteral('TODAY');
        public final DateLiteral tomorrow = new DateLiteral('TOMORROW');
        public final DateLiteral lastWeek = new DateLiteral('LAST_WEEK');
        public final DateLiteral thisWeek = new DateLiteral('THIS_WEEK');
        public final DateLiteral nextWeek = new DateLiteral('NEXT_WEEK');
        public final DateLiteral lastMonth = new DateLiteral('LAST_MONTH');
        public final DateLiteral thisMonth = new DateLiteral('THIS_MONTH');
        public final DateLiteral nextMonth = new DateLiteral('NEXT_MONTH');
        public final DateLiteral last90Days = new DateLiteral('LAST_90_DAYS');
        public final DateLiteral next90Days = new DateLiteral('NEXT_90_DAYS');
        public final DateLiteral thisQuarter = new DateLiteral('THIS_QUARTER');
        public final DateLiteral lastQuarter = new DateLiteral('LAST_QUARTER');
        public final DateLiteral nextQuarter = new DateLiteral('NEXT_QUARTER');
        public final DateLiteral thisYear = new DateLiteral('THIS_YEAR');
        public final DateLiteral lastYear = new DateLiteral('LAST_YEAR');
        public final DateLiteral nextYear = new DateLiteral('NEXT_YEAR');
        public final DateLiteral thisFiscalQuarter = new DateLiteral('THIS_FISCAL_QUARTER');
        public final DateLiteral lastFiscalQuarter = new DateLiteral('LAST_FISCAL_QUARTER');
        public final DateLiteral nextFiscalQuarter = new DateLiteral('NEXT_FISCAL_QUARTER');
        public final DateLiteral thisFiscalYear = new DateLiteral('THIS_FISCAL_YEAR');
        public final DateLiteral lastFiscalYear = new DateLiteral('LAST_FISCAL_YEAR');
        public final DateLiteral nextFiscalYear = new DateLiteral('NEXT_FISCAL_YEAR');

        public DateLiteral lastNDays(final Integer n) { return new DateLiteral('LAST_N_DAYS:', n); }
        public DateLiteral nextNDays(final Integer n) { return new DateLiteral('NEXT_N_DAYS:', n); }
        public DateLiteral nDaysAgo(final Integer n) { return new DateLiteral('N_DAYS_AGO:', n); }
        public DateLiteral nextNWeeks(final Integer n) { return new DateLiteral('NEXT_N_WEEKS:', n); }
        public DateLiteral lastNWeeks(final Integer n) { return new DateLiteral('LAST_N_WEEKS:', n); }
        public DateLiteral nWeeksAgo(final Integer n) { return new DateLiteral('N_WEEKS_AGO:', n); }
        public DateLiteral nextNMonths(final Integer n) { return new DateLiteral('NEXT_N_MONTHS:', n); }
        public DateLiteral lastNMonths(final Integer n) { return new DateLiteral('LAST_N_MONTHS:', n); }
        public DateLiteral nMonthsAgo(final Integer n) { return new DateLiteral('N_MONTHS_AGO:', n); }
        public DateLiteral nextNQuarters(final Integer n) { return new DateLiteral('NEXT_N_QUARTERS:', n); }
        public DateLiteral lastNQuarters(final Integer n) { return new DateLiteral('LAST_N_QUARTERS:', n); }
        public DateLiteral nQuartersAgo(final Integer n) { return new DateLiteral('N_QUARTERS_AGO:', n); }
        public DateLiteral nextNYears(final Integer n) { return new DateLiteral('NEXT_N_YEARS:', n); }
        public DateLiteral lastNYears(final Integer n) { return new DateLiteral('LAST_N_YEARS:', n); }
        public DateLiteral nYearsAgo(final Integer n) { return new DateLiteral('N_YEARS_AGO:', n); }
        public DateLiteral nextNFiscalQuarters(final Integer n) { return new DateLiteral('NEXT_N_FISCAL_QUARTERS:', n); }
        public DateLiteral lastNFiscalQuarters(final Integer n) { return new DateLiteral('LAST_N_FISCAL_QUARTERS:', n); }
        public DateLiteral nFiscalQuartersAgo(final Integer n) { return new DateLiteral('N_FISCAL_QUARTERS_AGO:', n); }
        public DateLiteral nextNFiscalYears(final Integer n) { return new DateLiteral('NEXT_N_FISCAL_YEARS:', n); }
        public DateLiteral lastNFiscalYears(final Integer n) { return new DateLiteral('LAST_N_FISCAL_YEARS:', n); }
        public DateLiteral nFiscalYearsAgo(final Integer n) { return new DateLiteral('N_FISCAL_YEARS_AGO:', n); }
    }
    public class DateLiteral {
        private final String name;
        private final Integer value;
        private DateLiteral(final String name) {
            this.value = value;
        }
        private DateLiteral(final String name, final Integer value) {
            validateNotNull(value, 'n');
            this.name = name;
            this.value = value;
        }
        public override String toString() {
            return name + (value?.toString() ?? '');
        }
    }

    public class GeoPartProvider {
        public String distance(final SObjectField field, final Location loc, final DistanceUnit unit) {
            return new GeoPart(field, loc, unit).toString();
        }
        public String distance(final String field, final Location loc, final DistanceUnit unit) {
            return new GeoPart(field, loc, unit).toString();
        }
    }

    public class GeoPart {
        private final String field;
        private final Location loc;
        private final String unit;
        private GeoPart(SObjectField field, Location loc, DistanceUnit unit) {
            this(field.toString(), loc, unit);
        }
        private GeoPart(String field, Location loc, DistanceUnit unit) {
            validateNotNull(unit, 'unit');
            this.field = field;
            this.loc = loc;
            this.unit = unit.name().toLowerCase();
        }
        public override String toString() {
            return String.format(
                'DISTANCE({0}, GEOLOCATION({1}, {2}), {3})',
                new List<Object>{ field, loc.latitude, loc.longitude, '\'' + unit + '\'' }
            );
        }
    }

    public class CurrencyLiteralProvider {
        public CurrencyLiteral of(final String code, final Decimal value) {
            return new CurrencyLiteral(code, value);
        }
    }

    public class CurrencyLiteral {
        private final String code;
        private final Decimal value;
        private CurrencyLiteral(String code, Decimal value) {
            this.code = code;
            this.value = value;
        }
        public override String toString() {
            return code + value;
        }
    }

    // prettier-ignore
    public class CategorySpec {
        private String dataCategoryGroup;
        private String filteringSelector;
        private String dataCategory;
        public CategorySpec of(final String dataCategoryGroup) {
            validateNotBlank(dataCategoryGroup, 'dataCategoryGroup');
            this.dataCategoryGroup = dataCategoryGroup;
            return this;
        }
        public CategorySpec at(final String dataCategory) { return set('AT', dataCategory); }
        public CategorySpec above(final String dataCategory) { return set('ABOVE', dataCategory); }
        public CategorySpec below(final String dataCategory) { return set('BELOW', dataCategory); }
        public CategorySpec aboveOrBelow(final String dataCategory) { return set('ABOVE_OR_BELOW', dataCategory); }
        private CategorySpec set(String filteringSelector, String dataCategory) {
            validateNotBlank(filteringSelector, 'filteringSelector');
            validateNotBlank(dataCategory, 'dataCategory');
            this.filteringSelector = filteringSelector;
            this.dataCategory = dataCategory;
            return this;
        }
        public override String toString() {
            return String.format('{0} {1} {2}', new List<Object>{ dataCategoryGroup, filteringSelector, dataCategory });
        }
    }
    // prettier-ignore
    public class HavingCondition extends Condition {
        public HavingCondition() {}
        public HavingCondition(final String rawCondition) { super(rawCondition); }
        public HavingCondition avg(final SObjectField field) { return avg(field?.toString()); }
        public HavingCondition avg(final String field) { validateField(field); return set('AVG(' + field + ')'); }
        public HavingCondition count(final SObjectField field) { return count(field?.toString()); }
        public HavingCondition count(final String field) { return set('COUNT(' + field + ')'); }
        public HavingCondition countDistinct(final SObjectField field) { return countDistinct(field?.toString()); }
        public HavingCondition countDistinct(final String field) { return set('COUNT_DISTINCT(' + field + ')'); }
        public HavingCondition min(final SObjectField field) { return min(field?.toString()); }
        public HavingCondition min(final String field) { validateField(field); return set('MIN(' + field + ')'); }
        public HavingCondition max(final SObjectField field) { return max(field?.toString()); }
        public HavingCondition max(final String field) { validateField(field); return set('MAX(' + field + ')'); }
        public HavingCondition sum(final SObjectField field) { return sum(field?.toString()); }
        public HavingCondition sum(final String field) { validateField(field); return set('SUM(' + field + ')'); }
        private HavingCondition set(final String aggregateFunction) {
            field = aggregateFunction;
            return this;
        }
    }
    public enum FieldProperty {
        ACCESSIBLE,
        AGGREGATABLE,
        CALCULATED,
        CREATABLE,
        CUSTOM,
        ENCRYPTED,
        EXTERNAL_ID,
        FILTERABLE,
        GROUPABLE,
        ID_LOOKUP,
        NILLABLE,
        SORTABLE,
        UNIQUE,
        UPDATEABLE
    }

    public class FieldChecker {
        private final Set<FieldProperty> properties;
        private final Map<FieldProperty, Boolean> flags;

        public FieldChecker(final Object field, final Iterable<FieldProperty> properties) {
            validateNotNull(field, 'field');
            validateNotNull(properties, 'properties');
            this.properties = new Set<FieldProperty>();
            for (FieldProperty property : properties) {
                validateNotNull(property, 'property');
                this.properties.add(property);
            }
            flags = buildFlags(field);
        }

        public Boolean every() {
            for (FieldProperty property : properties) {
                if (!test(property)) {
                    return false;
                }
            }
            return true;
        }

        private Boolean test(FieldProperty property) {
            return flags.get(property) == true;
        }

        private Map<FieldProperty, Boolean> buildFlags(Object field) {
            if (field instanceof SObjectField) {
                return buildFlagsFromDescribe(((SObjectField) field).getDescribe());
            }
            return buildFlagsFromDto((FieldDto) field);
        }

        private Map<FieldProperty, Boolean> buildFlagsFromDescribe(DescribeFieldResult result) {
            return new Map<FieldProperty, Boolean>{
                FieldProperty.ACCESSIBLE => result.isAccessible(),
                FieldProperty.AGGREGATABLE => result.isAggregatable(),
                FieldProperty.CALCULATED => result.isCalculated(),
                FieldProperty.CREATABLE => result.isCreateable(),
                FieldProperty.CUSTOM => result.isCustom(),
                FieldProperty.ENCRYPTED => result.isEncrypted(),
                FieldProperty.EXTERNAL_ID => result.isExternalId(),
                FieldProperty.FILTERABLE => result.isFilterable(),
                FieldProperty.GROUPABLE => result.isGroupable(),
                FieldProperty.ID_LOOKUP => result.isIdLookup(),
                FieldProperty.NILLABLE => result.isNillable(),
                FieldProperty.SORTABLE => result.isSortable(),
                FieldProperty.UNIQUE => result.isUnique(),
                FieldProperty.UPDATEABLE => result.isUpdateable()
            };
        }

        private Map<FieldProperty, Boolean> buildFlagsFromDto(FieldDto result) {
            return new Map<FieldProperty, Boolean>{
                FieldProperty.ACCESSIBLE => true,
                FieldProperty.AGGREGATABLE => result.aggregatable == true,
                FieldProperty.CALCULATED => result.calculated == true,
                FieldProperty.CREATABLE => result.createable == true,
                FieldProperty.CUSTOM => result.custom == true,
                FieldProperty.ENCRYPTED => result.encrypted == true,
                FieldProperty.EXTERNAL_ID => result.externalId == true,
                FieldProperty.FILTERABLE => result.filterable == true,
                FieldProperty.GROUPABLE => result.groupable == true,
                FieldProperty.ID_LOOKUP => result.idLookup == true,
                FieldProperty.NILLABLE => result.nillable == true,
                FieldProperty.SORTABLE => result.sortable == true,
                FieldProperty.UNIQUE => result.unique == true,
                FieldProperty.UPDATEABLE => result.updateable == true
            };
        }
    }

    public enum DistanceUnit {
        KM,
        MI
    }

    public enum Scope {
        DELEGATED,
        EVERYTHING,
        MINE,
        MINE_AND_MY_GROUPS,
        MY_TERRITORY,
        MY_TEAM_TERRITORY,
        SCOPING_RULE,
        TEAM
    }
    // </editor-fold>

    // <editor-fold desc="Query Parts">
    private class SelectClause implements Query.Part {
        private final String sObjType;
        private final Set<String> fields = new Set<String>();

        private SelectClause(String sObjType) {
            this.sObjType = sObjType;
        }

        public Boolean isEmpty() {
            return false;
        }

        private void add(String field) {
            validateField(field);
            fields.add(field.trim());
        }

        private void addAll(Iterable<Object> fields) {
            validateFields(fields);
            for (Object field : fields) {
                validateField(field);
                add(field instanceof String ? (String) field : field.toString());
            }
            return;
        }

        private void addAll(String fields) {
            validateFields(fields);
            for (String field : fields.split(',')) {
                add(field);
            }
        }

        private void addAllFromFieldSet(String fieldSet, Object describe) {
            if (describe instanceof DescribeSObjectResponse) {
                throw new QueryException(
                    'Schema-based discovery (fieldSet) is not supported for remote drivers. ' +
                    'FieldSets are only available for local schema-based queries.'
                );
            }
            FieldSet fs = ((DescribeSObjectResult) describe).fieldSets.getMap().get(fieldSet);
            validateFieldSet(fieldSet);
            for (FieldSetMember field : fs.getFields()) {
                add(field.getFieldPath());
            }
        }

        private void allFields(Iterable<Object> fields, Iterable<FieldProperty> properties) {
            for (Object field : fields) {
                if (new FieldChecker(field, properties).every()) {
                    add(field?.toString());
                }
            }
        }

        private void addSelectFunction(String selectFunction, String field, String alias) {
            add(formatFunction(selectFunction, field, alias));
        }

        public override String toString() {
            if (fields.isEmpty()) {
                fields.add('Id');
            }
            return 'SELECT ' + String.join(fields, ', ');
        }
    }

    private class TypeOfClause implements Query.Part {
        private final Set<TypeOf> typesOf = new Set<TypeOf>();

        public Boolean isEmpty() {
            return typesOf.isEmpty();
        }

        private void add(TypeOf typeOf) {
            validateNotNull(typeOf, 'typeOf');
            typesOf.add(typeOf);
        }

        public override String toString() {
            List<String> args = new List<String>();
            for (TypeOf typeOf : typesOf) {
                args.add(typeOf.toString());
            }
            return ', ' + String.join(args, ', ');
        }
    }

    private class SubQueriesClause implements Query.Part {
        private final Set<SoqlQuery> subQueries = new Set<SoqlQuery>();
        private BindContext sharedContext;

        public Boolean isEmpty() {
            return subQueries.isEmpty();
        }

        private void add(String relationshipName, SoqlQuery query) {
            validateNotBlank(relationshipName, 'relationshipName');
            validateNotNull(query, 'query');
            subQueries.add(query.setRelationshipName(relationshipName));
        }

        private void withBindContext(BindContext context) {
            sharedContext = context;
        }

        public override String toString() {
            return buildQueryString(sharedContext);
        }

        private String buildQueryString(BindContext targetContext) {
            List<String> args = new List<String>();
            for (SoqlQuery subQuery : subQueries) {
                if (targetContext != null) {
                    subQuery.withBindContext(targetContext);
                }
                args.add('(' + subQuery.buildQueryString(targetContext) + ')');
            }
            return ', ' + String.join(args, ', ');
        }

        public Map<String, Set<String>> getHierarchy() {
            Map<String, Set<String>> hierarchy = new Map<String, Set<String>>();
            Set<String> rootNames = new Set<String>();
            for (SoqlQuery subQuery : subQueries) {
                String relName = subQuery.getRelationshipName();
                rootNames.add(relName);
                Map<String, Set<String>> subHierarchy = subQuery.getSubQueryHierarchy();
                for (String subRel : subHierarchy?.keySet() ?? new Set<String>()) {
                    Set<String> subChildren = subHierarchy.get(subRel);
                    String fullPath = relName + (String.isBlank(subRel) ? '' : '.' + subRel);
                    hierarchy.put(fullPath, subChildren);
                }
            }
            hierarchy.put('', rootNames); // Root entry
            return hierarchy;
        }
    }

    private class FromClause implements Query.Part {
        private final String sObjType;
        private String relationshipName;

        private FromClause(String sObjType) {
            validateSObjectType(sObjType);
            this.sObjType = sObjType;
        }

        private void setRelationshipName(String relationshipName) {
            validateSObjectType(relationshipName);
            this.relationshipName = relationshipName;
        }

        private String getRelationshipName() {
            return relationshipName;
        }

        public Boolean isEmpty() {
            return false;
        }

        public override String toString() {
            return 'FROM ' + (relationshipName ?? sObjType);
        }
    }

    private class UsingScopeClause implements Query.Part {
        private Scope sc;

        public Boolean isEmpty() {
            return sc == null;
        }

        private void set(Scope sc) {
            validateNotNull(sc, 'scope');
            this.sc = sc;
        }

        public override String toString() {
            return 'USING SCOPE ' + sc;
        }
    }

    private class WhereClause extends Junction implements Query.Part {
        public override String toString() {
            String result = super.toString();
            return String.isBlank(result) ? '' : 'WHERE ' + result;
        }
    }

    private class WithClause implements Query.Part {
        private final List<CategorySpec> selections = new List<CategorySpec>();
        public Boolean isEmpty() {
            return selections.isEmpty();
        }
        private WithClause add(CategorySpec dataCategorySelection) {
            validateNotNull(dataCategorySelection, 'dataCategorySelection');
            selections.add(dataCategorySelection);
            return this;
        }
        @SuppressWarnings('PMD.OneDeclarationPerLine')
        public override String toString() {
            List<String> args = new List<String>();
            for (Integer i = 0, size = selections.size(); i < size; i++) {
                args.add('{' + i + '}');
            }
            String template = String.join(args, ' ' + 'AND' + ' ');
            return ' WITH DATA CATEGORY ' + String.format(template, selections);
        }
    }

    private class GroupByClause implements Query.Part {
        private final Set<String> fields = new Set<String>();

        public Boolean isEmpty() {
            return fields.isEmpty();
        }

        private String function {
            get;
            set {
                if (function == null) {
                    function = value;
                } else if (function != value) {
                    throw new QueryException(
                        'Grouping function redefinition is prohibited: the GROUP BY clause has already been initialized.'
                    );
                }
            }
        }

        public void ordinary(final String field) {
            add(field, '');
        }

        public void ordinary(final Iterable<Object> fields) {
            addAll(fields, '');
        }

        public void rollup(final String field) {
            add(field, 'ROLLUP');
        }

        public void rollup(final Iterable<Object> fields) {
            addAll(fields, 'ROLLUP');
        }

        public void cube(final String field) {
            add(field, 'CUBE');
        }

        public void cube(final Iterable<Object> fields) {
            addAll(fields, 'CUBE');
        }

        private void add(String field, String function) {
            validateField(field);
            fields.add(field);
            this.function = function;
        }

        private void addAll(Iterable<Object> fields, String function) {
            validateFields(fields);
            for (Object field : fields) {
                validateField(field);
                add(field instanceof String ? (String) field : field.toString(), function);
            }
        }

        public override String toString() {
            Boolean isParenthesized = function == 'ROLLUP' || function == 'CUBE';
            return String.format(
                'GROUP BY {0}{1}',
                new List<String>{
                    function,
                    String.format(isParenthesized ? ' ({0})' : '{0}', new List<String>{ String.join(fields, ', ') })
                }
            );
        }
    }

    private class HavingClause extends Junction implements Query.Part {
        public override String toString() {
            String result = super.toString();
            return String.isBlank(result) ? '' : 'HAVING ' + result;
        }
    }

    private class OrderByClause implements Query.Part {
        private final List<SortField> ordersBy = new List<SortField>();

        public Boolean isEmpty() {
            return ordersBy.isEmpty();
        }

        public void add(final SortField orderBy) {
            ordersBy.add(orderBy);
        }

        public override String toString() {
            List<String> orders = new List<String>();
            for (SortField o : ordersBy) {
                orders.add(o.toString());
            }
            return 'ORDER BY ' + String.join(orders, ', ');
        }
    }

    private class LimitClause implements Query.Part {
        private Integer lim;

        public Boolean isEmpty() {
            return lim == null;
        }

        private void set(final Integer count) {
            validateIsTrue(count >= 0, 'LIMIT must be >= 0. LIMIT = ' + count);
            lim = count;
        }

        public override String toString() {
            return 'LIMIT ' + lim;
        }
    }

    private class OffsetClause implements Query.Part {
        private Integer offset;

        public Boolean isEmpty() {
            return offset == null;
        }

        private void set(final Integer count) {
            validateIsTrue(count >= 0, 'OFFSET must be >= 0. OFFSET = ' + count);
            offset = count;
        }

        public override String toString() {
            return 'OFFSET ' + offset;
        }
    }

    // prettier-ignore
    private class ForViewRefClause implements Query.Part {
        private String forViewRef;
        public Boolean isEmpty() { return forViewRef == null; }
        private void forView() { forViewRef = 'FOR VIEW'; }
        private void forReference() { forViewRef = 'FOR REFERENCE'; }
        public override String toString() { return forViewRef.trim(); }
    }
    // prettier-ignore
    private class UpdateClause implements Query.Part {
        private String updateStatement;
        public Boolean isEmpty() { return updateStatement == null; }
        private void updateTracking() { updateStatement = 'UPDATE TRACKING'; }
        private void updateViewstat() { updateStatement = 'UPDATE VIEWSTAT'; }
        public override String toString() { return updateStatement.trim(); }
    }
    // prettier-ignore
    private class ForUpdateClause implements Query.Part {
        private String forUpdate;
        public Boolean isEmpty() { return forUpdate == null; }
        private void set() { forUpdate = 'FOR UPDATE'; }
        public override String toString() { return forUpdate.trim(); }
    }
    // prettier-ignore
    private class AllRowsClause implements Query.Part {
        private String allRows;
        public Boolean isEmpty() { return allRows == null; }
        private void set() { allRows = 'ALL ROWS'; }
        public override String toString() { return allRows.trim(); }
    }
    // </editor-fold>

    // <editor-fold desc="Helpers">
    @TestVisible
    private interface CachePartition {
        Object get(String key);
        void put(String key, Object value);
        void put(String key, Object value, Integer ttlInSecs);
    }

    @TestVisible
    private class PlatformCachePartition implements CachePartition {
        private final Cache.Partition partition;

        @TestVisible
        private PlatformCachePartition(Cache.Partition partition) {
            this.partition = partition;
        }

        public Object get(final String key) {
            return partition?.get(key);
        }

        public void put(final String key, final Object value) {
            partition?.put(key, value);
        }

        public void put(final String key, final Object value, final Integer ttlInSecs) {
            partition?.put(key, value, ttlInSecs);
        }
    }

    private class MemoPartition implements CachePartition {
        private final Map<String, Object> storage = new Map<String, Object>();

        public Object get(final String key) {
            return storage.get(key);
        }

        public void put(final String key, final Object value) {
            storage.put(key, value);
        }

        public void put(final String key, final Object value, final Integer ttlInSecs) {
            storage.put(key, value);
        }
    }

    @TestVisible
    private interface CacheFactory {
        CachePartition getSessionPartition(String partitionName);
        CachePartition getOrgPartition(String partitionName);
        CachePartition getMemoPartition();
    }

    private class DefaultCacheFactory implements CacheFactory {
        private final MemoPartition memoPartition = new MemoPartition();

        public CachePartition getSessionPartition(final String partitionName) {
            return new PlatformCachePartition(Cache.Session.getPartition(partitionName));
        }

        public CachePartition getOrgPartition(final String partitionName) {
            return new PlatformCachePartition(Cache.Org.getPartition(partitionName));
        }

        public CachePartition getMemoPartition() {
            return memoPartition;
        }
    }

    private class CacheConfig {
        private final Map<String, CacheOption> targets = new Map<String, CacheOption>();

        private void add(CachingStrategy strategy) {
            add(strategy, null, null);
        }

        private void add(CachingStrategy strategy, String partition) {
            add(strategy, partition, null);
        }

        private void add(CachingStrategy strategy, String partition, Integer ttlInSecs) {
            if (strategy != CachingStrategy.MEMO) {
                validateNotBlank(partition, 'partition');
            }
            String key = strategy.name() + (partition != null ? ':' + partition : '');
            targets.put(key, new CacheOption(strategy, partition, ttlInSecs));
        }

        private List<CacheOption> getOptions(CachingStrategy strategy) {
            List<CacheOption> options = new List<CacheOption>();
            for (CacheOption opt : targets.values()) {
                if (opt.strategy == strategy) {
                    options.add(opt);
                }
            }
            return options;
        }
    }

    private class CacheOption {
        private final CachingStrategy strategy;
        private final String partition;
        private final Integer ttlInSecs;
        private CacheOption(CachingStrategy strategy, String partition, Integer ttlInSecs) {
            this.strategy = strategy;
            this.partition = partition;
            this.ttlInSecs = ttlInSecs;
        }
    }

    private enum CachingStrategy {
        MEMO,
        SESSION,
        ORG
    }

    private class DatePart {
        private final String function;
        private final String field;

        private DatePart(String function, SObjectField field) {
            this(function, field.toString());
        }

        private DatePart(String function, String field) {
            this.function = function;
            this.field = field;
        }

        public override String toString() {
            return String.format('{0}({1})', new List<String>{ function, field });
        }
    }

    // prettier-ignore
    private class SortField {
        private final String field;
        private final String order;
        private final String nullsOrder;

        private SortField(String field, Query.SortOrder sortOrder, Query.NullsOrder nullsOrder) {
            validateField(field);
            this.field = field;
            order = getOrder(sortOrder);
            this.nullsOrder = getNullsOrder(nullsOrder);
        }

        private String getOrder(Query.SortOrder sortOrder) {
            switch on sortOrder {
                when ASCX { return ' ASC'; }
                when DESCX { return ' DESC'; }
                when else { return ''; }
            }
        }

        private String getNullsOrder(Query.NullsOrder nullsOrder) {
            switch on nullsOrder {
                when NULLS_FIRST { return ' NULLS FIRST'; }
                when NULLS_LAST { return ' NULLS LAST'; }
                when else { return ''; }
            }
        }

        public override String toString() {
            return field + order + nullsOrder;
        }
    }
    private class ComparisonOperator {
        public final String EQ = '=';
        public final String NE = '!=';
        public final String LT = '<';
        public final String LE = '<=';
        public final String GT = '>';
        public final String GE = '>=';
        public final String LIKEX = 'LIKE';
        public final String INX = 'IN';
        public final String NOT_IN = 'NOT IN';
        public final String INCLUDES = 'INCLUDES';
        public final String EXCLUDES = 'EXCLUDES';
    }

    private inherited sharing class Context {
        private final SoqlQuery query;
        private AccessLevel accessMode = AccessLevel.USER_MODE;
        private Driver driver = new InheritedSharingDriver();
        private AccessType accessType;

        private Context(SoqlQuery query) {
            this.query = query;
        }

        private Compiled compile(Boolean isCount) {
            BindContext ctx = new BindContext();
            String q = isCount ? query.toCountString(ctx) : query.buildQueryString(ctx);
            String iq = isCount ? query.toInlineCountString() : query.toInlineString();
            Map<String, Object> binds = ctx.getMap().clone();
            binds.putAll(query.getUserBindings());
            return new Compiled(q, iq, binds);
        }

        private void setMode(AccessLevel accessLevel) {
            validateNotNull(accessLevel, 'accessLevel');
            accessMode = accessLevel;
        }

        private void addPermissionSetIds(Iterable<Id> permissionSetIds) {
            validateNotNull(permissionSetIds, 'permissionSetIds');
            for (Id permissionSetId : permissionSetIds) {
                validateNotNull(permissionSetId, 'permissionSetId');
                accessMode = accessMode.withPermissionSetId(permissionSetId);
            }
        }

        private void setAccessType(AccessType type) {
            validateNotNull(type, 'type');
            accessType = type;
        }

        private void setDriver(Driver driver) {
            this.driver = driver;
        }

        private DescribeProvider getDescribeProvider() {
            return driver.getDescribeProvider();
        }

        private List<Object> run(Type listType) {
            QueryArgs args = getArgs(false, listType);
            if (driver instanceof RestDriver) {
                args.subQueryHierarchy = query.getSubQueryHierarchy();
            }
            final String key = getCacheKey('run', args);
            List<Object> result = (List<Object>) getFromCache(key);
            if (result == null) {
                result = driver.run(args);
                putInCache(key, result);
            }
            return (accessType == null || driver instanceof RestDriver)
                ? result
                : Security.stripInaccessible(accessType, (List<SObject>) result).getRecords();
        }

        private Iterable<Object> runMore(Type listType) {
            QueryArgs args = getArgs(false, listType);
            if (driver instanceof RestDriver) {
                args.subQueryHierarchy = query.getSubQueryHierarchy();
            }
            return driver.runMore(args);
        }

        private Integer count() {
            QueryArgs args = getArgs(true, List<SObject>.class);
            final String key = getCacheKey('count', args);
            Integer result = (Integer) getFromCache(key);
            if (result == null) {
                result = driver.count(args);
                putInCache(key, result);
            }
            return result;
        }

        private Database.QueryLocator locator() {
            return driver.locator(getArgs(false, List<SObject>.class));
        }

        private Database.Cursor cursor() {
            return driver.cursor(getArgs(false, List<SObject>.class));
        }

        private Database.PaginationCursor paginationCursor() {
            return driver.paginationCursor(getArgs(false, List<SObject>.class));
        }

        private Object explain() {
            return driver.explain(getArgs(false, List<SObject>.class));
        }

        private QueryArgs getArgs(Boolean isCount, Type listType) {
            final Compiled compiled = compile(isCount);
            QueryArgs args = new QueryArgs(compiled.query, compiled.inlineQuery, compiled.binds, accessMode);
            validateNotNull(listType, 'elementType');
            args.listType = listType;
            args.isDebugEnabled = query.isDebugEnabled();
            args.isTimerEnabled = query.isTimerEnabled();
            args.timerMode = query.getTimer();
            elementType(listType);
            return args;
        }

        private String getCacheKey(String suffix, QueryArgs args) {
            final String sharingMode = driver instanceof InheritedSharingDriver
                ? 'inherited'
                : (driver instanceof WithSharingDriver || driver instanceof RestDriver) ? 'with' : 'without';
            final String accType = accessType?.name() ?? 'none';
            final String userScope = isSharingSensitiveCacheContext(sharingMode) ? UserInfo.getUserId() : 'global';
            final String context = '' + accessMode + ':' + accType + ':' + sharingMode + ':' + userScope;
            final String base = args.query + ':' + args.binds + ':' + context + ':' + suffix;
            return EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(base)));
        }

        private Boolean isSharingSensitiveCacheContext(String sharingMode) {
            return sharingMode == 'with' || sharingMode == 'inherited' || accessMode == AccessLevel.USER_MODE;
        }

        private Object getFromCache(String key) {
            for (CacheOption opt : getCacheOptions()) {
                final Object value = getPartition(opt)?.get(key);
                if (value != null) {
                    return value;
                }
            }
            return null;
        }

        private void putInCache(String key, Object value) {
            for (CacheOption opt : getCacheOptions()) {
                final CachePartition partition = getPartition(opt);
                if (partition != null) {
                    if (opt.ttlInSecs != null) {
                        partition.put(key, value, opt.ttlInSecs);
                    } else {
                        partition.put(key, value);
                    }
                }
            }
        }

        private List<CacheOption> getCacheOptions() {
            List<CacheOption> options = new List<CacheOption>();
            options.addAll(query.caching.getOptions(CachingStrategy.MEMO));
            options.addAll(query.caching.getOptions(CachingStrategy.SESSION));
            if (accessMode != AccessLevel.USER_MODE) {
                options.addAll(query.caching.getOptions(CachingStrategy.ORG));
            }
            return options;
        }

        // prettier-ignore
        private CachePartition getPartition(CacheOption opt) {
            switch on opt.strategy {
                when MEMO { return cacheFactory.getMemoPartition(); }
                when SESSION { return cacheFactory.getSessionPartition(opt.partition); }
                when ORG { return cacheFactory.getOrgPartition(opt.partition); } when else { return null; }
            }
        }
    }

    private class Compiled {
        final String query;
        final String inlineQuery;
        final Map<String, Object> binds;
        private Compiled(String query, String inlineQuery, Map<String, Object> binds) {
            this.query = query;
            this.inlineQuery = inlineQuery;
            this.binds = binds;
        }
    }

    public interface DescribeProvider {
        Object describeSObject(String sObjectType);
    }

    private inherited sharing class SchemaDescribeProvider implements DescribeProvider {
        private final Map<String, DescribeSObjectResult> cache = new Map<String, DescribeSObjectResult>();

        public DescribeSObjectResult describeSObject(final String sObjectType) {
            if (!cache.containsKey(sObjectType)) {
                cache.put(
                    sObjectType,
                    Schema.describeSObjects(new List<String>{ sObjectType }, SObjectDescribeOptions.DEFERRED)[0]
                );
            }
            return cache.get(sObjectType);
        }
    }

    public class QueryArgs {
        public final String query;
        public final String inlineQuery;
        public final Map<String, Object> binds;
        public final AccessLevel accessMode;
        public Type listType;
        public Map<String, Set<String>> subQueryHierarchy;
        public Boolean isDebugEnabled;
        public Boolean isTimerEnabled;
        public Query.Timer timerMode;

        public QueryArgs(String query, String inlineQuery, Map<String, Object> binds, AccessLevel accessMode) {
            validateNotBlank(query, 'query');
            validateNotBlank(inlineQuery, 'inlineQuery');
            this.query = query;
            this.inlineQuery = inlineQuery;
            this.binds = binds;
            this.accessMode = accessMode;
        }
    }

    public interface Driver {
        DescribeProvider getDescribeProvider();
        List<Object> run(QueryArgs args);
        Iterable<Object> runMore(QueryArgs args);
        Integer count(QueryArgs args);
        Database.QueryLocator locator(QueryArgs args);
        Database.Cursor cursor(QueryArgs args);
        Database.PaginationCursor paginationCursor(QueryArgs args);
        Object explain(QueryArgs args);
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public abstract inherited sharing class DatabaseDriver implements Driver {
        private final DescribeProvider describeProvider = new SchemaDescribeProvider();
        protected Boolean timersEnabled = false;
        protected Query.Timer timerMode = Query.Timer.SYS;

        public DescribeProvider getDescribeProvider() {
            return describeProvider;
        }

        public virtual List<Object> run(final QueryArgs args) {
            applyExecutionArgs(args);
            log(args.isDebugEnabled ?? false, args, 'db.run');
            Long start = timerStart(timerMode);
            List<Object> result = Database.queryWithBinds(args.query, args.binds, args.accessMode);
            logTimer(timersEnabled, timerMode, 'db.run', start);
            return result;
        }

        public virtual Iterable<Object> runMore(final QueryArgs args) {
            return new CursorIterable(new DatabaseCursor(cursor(args)));
        }

        public virtual Integer count(final QueryArgs args) {
            applyExecutionArgs(args);
            log(args.isDebugEnabled ?? false, args, 'db.count');
            Long start = timerStart(timerMode);
            Integer result = Database.countQueryWithBinds(args.query, args.binds, args.accessMode);
            logTimer(timersEnabled, timerMode, 'db.count', start);
            return result;
        }

        public virtual Database.QueryLocator locator(final QueryArgs args) {
            applyExecutionArgs(args);
            log(args.isDebugEnabled ?? false, args, 'db.locator');
            Long start = timerStart(timerMode);
            Database.QueryLocator result = Database.getQueryLocatorWithBinds(args.query, args.binds, args.accessMode);
            logTimer(timersEnabled, timerMode, 'db.locator', start);
            return result;
        }

        public virtual Database.Cursor cursor(final QueryArgs args) {
            applyExecutionArgs(args);
            log(args.isDebugEnabled ?? false, args, 'db.cursor');
            Long start = timerStart(timerMode);
            Database.Cursor result = Database.getCursorWithBinds(args.query, args.binds, args.accessMode);
            logTimer(timersEnabled, timerMode, 'db.cursor', start);
            return result;
        }

        public virtual Database.PaginationCursor paginationCursor(final QueryArgs args) {
            applyExecutionArgs(args);
            log(args.isDebugEnabled ?? false, args, 'db.paginationCursor');
            Long start = timerStart(timerMode);
            Database.PaginationCursor result = Database.getPaginationCursorWithBinds(
                args.query,
                args.binds,
                args.accessMode
            );
            logTimer(timersEnabled, timerMode, 'db.paginationCursor', start);
            return result;
        }

        public virtual Object explain(final QueryArgs args) {
            throw new QueryException('Database SOQL does not support query explain at runtime.');
        }

        private void applyExecutionArgs(QueryArgs args) {
            timersEnabled = args.isTimerEnabled ?? false;
            timerMode = args.timerMode ?? Query.Timer.SYS;
        }

        @SuppressWarnings('PMD.AvoidDebugStatements')
        private void log(Boolean enabled, QueryArgs args, String label) {
            if (enabled) {
                System.debug(LoggingLevel.ERROR, label + ': ' + args.query + '\n' + JSON.serializePretty(args.binds));
            }
        }
    }

    public virtual inherited sharing class InheritedSharingDriver extends DatabaseDriver {
    }
    public virtual with sharing class WithSharingDriver extends DatabaseDriver {
    }
    public virtual without sharing class WithoutSharingDriver extends DatabaseDriver {
    }

    private inherited sharing class RestDescribeProvider implements DescribeProvider {
        private final RestDriver driver;
        private final Map<String, DescribeSObjectResponse> cache = new Map<String, DescribeSObjectResponse>();

        public RestDescribeProvider(final RestDriver driver) {
            this.driver = driver;
        }

        public DescribeSObjectResponse describeSObject(final String sObjectType) {
            if (!cache.containsKey(sObjectType)) {
                HttpRequest req = new HttpRequest();
                req.setMethod('GET');
                req.setEndpoint(
                    driver.namedCredential + driver.getBaseEndpoint() + 'sobjects/' + sObjectType + '/describe'
                );
                HttpResponse res = driver.send(req, 'describeRequest');
                if (res.getStatusCode() != 200) {
                    throw new QueryException('REST Describe Failed: ' + res.getStatusCode() + ' ' + res.getBody());
                }
                DescribeSObjectResponse describe = (DescribeSObjectResponse) JSON.deserialize(
                    res.getBody(),
                    DescribeSObjectResponse.class
                );
                cache.put(sObjectType, describe);
            }
            return cache.get(sObjectType);
        }
    }

    private class DescribeSObjectResponse {
        private final List<FieldDto> fields;
    }

    @TestVisible
    private class FieldDto {
        private final String name;
        private final Boolean aggregatable;
        private final Boolean calculated;
        private final Boolean createable;
        private final Boolean custom;
        private final Boolean encrypted;
        private final Boolean externalId;
        private final Boolean filterable;
        private final Boolean groupable;
        private final Boolean idLookup;
        private final Boolean nillable;
        private final Boolean sortable;
        private final Boolean unique;
        private final Boolean updateable;
        public override String toString() {
            return name;
        }
    }

    /**
     * REST API driver for executing SOQL queries against remote Salesforce orgs.
     * Note: Requires a Named Credential for authentication.
     * Warning: This driver enforces USER_MODE and will throw an exception if SYSTEM_MODE is requested,
     * as REST API queries always run in user context.
     * @example
     * SoqlQuery.of('Account')
     *     .useDriver(new SoqlQuery.RestDriver('MyNamedCredential'))
     *     .fetch();
     */
    public enum QueryMoreEngine {
        COMPOSITE,
        COMPOSITE_BATCH,
        QUERY
    }

    public interface RestEngine {
        Iterable<Object> runMore(RestDriver driver, QueryArgs args);
        Integer count(RestDriver driver, QueryArgs args);
        Object explain(RestDriver driver, QueryArgs args);
        String resolveQueryResource(Boolean allRows);
    }

    /**
     * REST Query engine backed by `/query` and `/queryAll` resources.
     *
     * Responsibilities:
     * - Executes root SOQL REST requests.
     * - Resolves standard vs tooling query resources.
     * - Orchestrates queryMore hydration using selected queryMore transport strategy.
     *
     * Configuration:
     * - `setBatchSize(Integer)`: sets `Sforce-Query-Options` for root query pages.
     * - `setQueryMore(Boolean)`: enables/disables continuation hydration (disabled by default).
     * - `setChunkSize(Integer)`: continuation chunk size for composite-based queryMore engines.
     * - `useQueryMoreEngine(QueryMoreEngine)`: continuation transport (`COMPOSITE`, `COMPOSITE_BATCH`, `QUERY`).
     * - `useTooling(Boolean)`: switches between standard query resources and tooling query resources.
     *
     * Notes:
     * - `QueryMoreEngine.QUERY` processes continuation URLs sequentially (one URL per request),
     *   so chunking does not increase parallelism.
     * - `count()` and `explain()` are executed through REST query endpoints.
     */
    public virtual class QueryEngine implements RestEngine {
        /**
         * Requested page size for root REST query calls (`Sforce-Query-Options: batchSize=<size>`).
         * If null, Salesforce API defaults are used.
         */
        protected Integer batchSize;
        protected Boolean queryMore = false;
        protected Integer chunkSize = 25;
        protected QueryMoreEngine queryMoreEngineType = QueryMoreEngine.COMPOSITE_BATCH;
        protected Boolean useTooling = false;

        /**
         * Sets the requested page size for the root REST query call.
         *
         * The engine sends this as `Sforce-Query-Options: batchSize=<size>` on the
         * initial GET query request (`/query`, `/queryAll`, or tooling variants).
         *
         * Notes:
         * - Salesforce may still return fewer rows than requested.
         * - This setting does not tune Composite or Composite Batch transport payloads.
         *
         * @param size requested row count per page (typically 1-2000, must be > 0)
         * @return this engine
         */
        public virtual QueryEngine setBatchSize(final Integer size) {
            validateIsTrue(size > 0, 'Batch size must be greater than 0. Value: ' + size);
            this.batchSize = size;
            return this;
        }

        /**
         * Enables or disables (default) automatic fetching of subsequent pages.
         * Warning: Enabling queryMore can significantly impact performance as it will eagerly
         * fetch all pages using the Unified Wave hydration strategy, which may result in
         * multiple composite API calls, increased heap usage for large result sets, or hitting
         * governor limits.
         * @param enabled true to enable queryMore, false to disable
         * @return this driver
         */
        public virtual QueryEngine setQueryMore(final Boolean enabled) {
            validateNotNull(enabled, 'enabled');
            this.queryMore = enabled;
            return this;
        }

        /**
         * Sets the queryMore wave chunk size.
         *
         * When queryMore is enabled, this controls how many continuation URLs are packed
         * into one transport call by the queryMore engine.
         *
         * Practical limits depend on selected queryMore engine:
         * - `QueryMoreEngine.COMPOSITE`: typically 1-5 per call.
         * - `QueryMoreEngine.COMPOSITE_BATCH`: typically 1-25 per call.
         * - `QueryMoreEngine.QUERY`: ignored (URLs are fetched sequentially, one by one).
         *
         * Values above engine limits can fail at runtime.
         *
         * @param size Subrequest chunk size (must be > 0)
         * @return this engine
         */
        public virtual QueryEngine setChunkSize(final Integer size) {
            validateIsTrue(size > 0, 'Chunk size must be greater than 0. Value: ' + size);
            this.chunkSize = size;
            return this;
        }

        /**
         * Switches the queryMore transport engine.
         *
         * `COMPOSITE_BATCH` (default) supports up to 25 query sub-requests per call.
         * `COMPOSITE` is limited to 5 query sub-requests per call.
         * `QUERY` fetches each continuation URL sequentially via direct GET /query requests.
         *
         * @param engine transport engine for queryMore calls
         * @return this engine
         */
        public virtual QueryEngine useQueryMoreEngine(final QueryMoreEngine engine) {
            validateNotNull(engine, 'engine');
            this.queryMoreEngineType = engine;
            return this;
        }

        public virtual QueryEngine useTooling(final Boolean enabled) {
            validateNotNull(enabled, 'enabled');
            this.useTooling = enabled;
            return this;
        }

        public virtual Iterable<Object> runMore(final RestDriver driver, final QueryArgs args) {
            return new QueryMoreIterable(driver, args, this);
        }

        protected virtual QueryMoreRequestEngine createQueryMoreEngine(final RestDriver driver, final QueryArgs args) {
            if (queryMoreEngineType == SoqlQuery.QueryMoreEngine.COMPOSITE_BATCH) {
                return new CompositeBatchEngine(driver, args.subQueryHierarchy);
            }
            if (queryMoreEngineType == SoqlQuery.QueryMoreEngine.QUERY) {
                return new DirectQueryMoreEngine(driver, args.subQueryHierarchy, this);
            }
            return new CompositeEngine(driver, args.subQueryHierarchy);
        }

        public virtual Integer count(final RestDriver driver, final QueryArgs args) {
            String resource = resolveQueryResource(args.inlineQuery.containsIgnoreCase(' ALL ROWS'));
            String finalQuery = args.inlineQuery.replaceAll('(?i) ALL ROWS', '');
            HttpResponse res = send(
                driver,
                driver.getBaseEndpoint() + resource + '/?q=' + EncodingUtil.urlEncode(finalQuery, 'UTF-8')
            );
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (Integer) body.get('totalSize');
        }

        public virtual Object explain(final RestDriver driver, final QueryArgs args) {
            HttpResponse res = send(
                driver,
                driver.getBaseEndpoint() +
                    resolveQueryResource(false) +
                    '/?explain=' +
                    EncodingUtil.urlEncode(args.inlineQuery, 'UTF-8')
            );
            return JSON.deserializeUntyped(res.getBody());
        }

        protected virtual HttpResponse send(final RestDriver driver, final String path) {
            HttpRequest req = new HttpRequest();
            String separator = path.startsWith('/') ? '' : '/';
            if (batchSize != null) {
                req.setHeader('Sforce-Query-Options', 'batchSize=' + batchSize);
            }
            req.setEndpoint('callout:' + driver.namedCredential + separator + path);
            req.setMethod('GET');
            HttpResponse res = driver.send(req, 'queryRequest');
            if (res.getStatusCode() != 200) {
                throw new QueryException('REST Query Failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
            return res;
        }

        public virtual String resolveQueryResource(final Boolean allRows) {
            if (useTooling) {
                return allRows ? 'tooling/queryAll' : 'tooling/query';
            }
            return allRows ? 'queryAll' : 'query';
        }
    }

    /**
     * REST sObject Collections query engine backed by `/composite/sobjects/{sObject}`.
     *
     * Supported SOQL shape (strict):
     * - `SELECT <fields> FROM <SObject> WHERE Id = <value|:bind>`
     * - `SELECT <fields> FROM <SObject> WHERE Id IN (<values>|:bind)`
     *
     * Notes:
     * - IDs are fetched in chunks using POST request body (`ids`) to avoid URI length limits.
     *
     * Limitations:
     * - Subqueries are rejected by Salesforce for this resource.
     * - At least one field must be selected in the root `SELECT` list.
     *
     * Additional engine limitations:
     * - `explain()` is not supported by this engine and throws `QueryException`.
     */
    public virtual class SObjectCollectionsEngine implements RestEngine {
        protected Integer chunkSize = 2000;
        protected final Pattern selectFromWherePattern = Pattern.compile(
            '(?is)^\\s*SELECT\\s+(.+?)\\s+FROM\\s+([A-Za-z0-9_]+)\\s+WHERE\\s+(.+?)\\s*$'
        );
        protected final Pattern idEqPattern = Pattern.compile('(?is)^Id\\s*=\\s*(.+)$');
        protected final Pattern idInPattern = Pattern.compile('(?is)^Id\\s+IN\\s*(.+)$');

        /**
         * Sets chunk size for request-body `ids` batches.
         * @param size IDs per request chunk (must be > 0)
         * @return this engine
         */
        public virtual SObjectCollectionsEngine setChunkSize(final Integer size) {
            validateIsTrue(size > 0, 'Chunk size must be greater than 0. Value: ' + size);
            this.chunkSize = size;
            return this;
        }

        public virtual Iterable<Object> runMore(final RestDriver driver, final QueryArgs args) {
            validateNotNull(args, 'args');
            validateNotNull(args.listType, 'args.listType');
            return new SObjectCollectionsIterable(driver, args, this);
        }

        public virtual Integer count(final RestDriver driver, final QueryArgs args) {
            QueryArgs runArgs = new QueryArgs(
                args.query,
                rewriteCountQueryToId(args.inlineQuery),
                args.binds,
                args.accessMode
            );
            runArgs.listType = List<Map<String, Object>>.class;
            Integer result = 0;
            for (Object row : runMore(driver, runArgs)) {
                if (row != null) {
                    result++;
                }
            }
            return result;
        }

        public virtual Object explain(final RestDriver driver, final QueryArgs args) {
            throw new QueryException('SObjectCollectionsEngine does not support explain()');
        }

        public virtual String resolveQueryResource(final Boolean allRows) {
            return 'composite/sobjects';
        }

        protected virtual List<Object> fetchChunk(
            final RestDriver driver,
            final String sObjectType,
            final List<String> fields,
            final List<String> idsChunk
        ) {
            String path = driver.getBaseEndpoint() + 'composite/sobjects/' + sObjectType;
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint('callout:' + driver.namedCredential + path);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(JSON.serialize(new Map<String, Object>{ 'ids' => idsChunk, 'fields' => fields }));
            logRequest(driver.isDebugEnabled, req, 'sobjectCollectionsRequest');
            HttpResponse res = driver.send(req, 'sobjectCollectionsRequest');
            if (res.getStatusCode() != 200) {
                throw new QueryException(
                    'REST sObject Collections Failed: ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }

            return (List<Object>) JSON.deserializeUntyped(res.getBody());
        }

        protected virtual List<Object> projectRecords(final List<Object> records, final Type listType) {
            Type elementType = elementType(listType);
            Boolean isUntyped = isUntyped(elementType);
            Boolean isSObject = isSObjectLikeType(elementType);
            Boolean requiresNormalization = !isUntyped && !isSObject;
            return projectRowsByElementType(records, listType, isUntyped, requiresNormalization);
        }

        protected virtual Map<String, Object> parseQuery(final QueryArgs args) {
            validateNotBlank(args.inlineQuery, 'inlineQuery');
            Matcher m = selectFromWherePattern.matcher(args.inlineQuery);
            validateIsTrue(
                m.matches(),
                'SObjectCollectionsEngine supports only: SELECT <fields> FROM <SObject> WHERE Id = ... or Id IN ...'
            );

            String selectPart = m.group(1).trim();
            String sObjectType = m.group(2).trim();
            String wherePart = m.group(3).trim();
            validateIsTrue(
                !(wherePart.startsWith('(') && wherePart.endsWith(')')),
                'SObjectCollectionsEngine WHERE clause must not be wrapped in parentheses'
            );

            List<String> fields = parseFields(selectPart);
            List<String> ids = parseIds(wherePart);
            validateIsTrue(!ids.isEmpty(), 'SObjectCollectionsEngine requires at least one Id');
            return new Map<String, Object>{ 'sObjectType' => sObjectType, 'fields' => fields, 'ids' => ids };
        }

        private List<String> parseFields(String selectPart) {
            validateNotBlank(selectPart, 'SELECT fields');
            List<String> fields = new List<String>();
            for (String raw : selectPart.split(',')) {
                String field = raw.trim();
                validateNotBlank(field, 'field');
                fields.add(field);
            }
            return fields;
        }

        private List<String> parseIds(String wherePart) {
            Matcher inMatcher = idInPattern.matcher(wherePart);
            if (inMatcher.matches()) {
                return parseIdsFromRhs(inMatcher.group(1).trim());
            }

            Matcher eqMatcher = idEqPattern.matcher(wherePart);
            validateIsTrue(eqMatcher.matches(), 'SObjectCollectionsEngine supports only WHERE Id = ... or Id IN ...');
            String rhs = eqMatcher.group(1).trim();
            List<String> ids = parseIdsFromRhs(rhs);
            validateIsTrue(ids.size() == 1, 'WHERE Id = ... must resolve to exactly one Id');
            return ids;
        }

        private List<String> parseIdsFromRhs(String rhs) {
            if (rhs.startsWith('(') && rhs.endsWith(')')) {
                return parseLiteralIds(rhs.substring(1, rhs.length() - 1));
            }
            return new List<String>{ parseLiteralId(rhs) };
        }

        private List<String> parseLiteralIds(String csv) {
            List<String> ids = new List<String>();
            for (String token : csv.split(',')) {
                ids.add(parseLiteralId(token));
            }
            return ids;
        }

        private String parseLiteralId(String token) {
            String value = token?.trim();
            if (value != null && value.startsWith('\'') && value.endsWith('\'') && value.length() >= 2) {
                value = value.substring(1, value.length() - 1);
            }
            validateNotBlank(value, 'Id literal');
            return value;
        }
    }

    /**
     * REST Bulk API v2 Query engine backed by `/jobs/query` resources.
     *
     * Flow:
     * - Creates a Bulk v2 query job (`query` or `queryAll` depending on `ALL ROWS`).
     * - Polls job status until completion.
     * - Fetches CSV result pages and projects them into requested `List<T>.class`.
     * - Optionally follows result locators when `setQueryMore(true)` is enabled.
     *
     * Configuration:
     * - `setPollInterval(Integer)`: polling interval between status checks.
     * - `setCpuTimeout(Integer)`: CPU guard for polling wait loop.
     * - `setMaxRecords(Integer)`: `maxRecords` request parameter for results pages.
     * - `setQueryMore(Boolean)`: follow Bulk locator pages or stop at first page.
     *
     * Limitations (Bulk API 2.0 query):
     * - Does not support SOQL with `GROUP BY`, `OFFSET`, or `TYPEOF`.
     * - Does not support aggregate functions such as `COUNT()`.
     * - Does not support date functions in `GROUP BY` clauses (date functions in `WHERE` are supported).
     * - Does not support compound address/geolocation fields; query individual component fields instead.
     * - Does not support parent-to-child relationship queries.
     * - Supports child-to-parent relationship queries.
     *
     * Additional engine limitations:
     * - `explain()` is not supported by this engine and throws `QueryException`.
     */
    public virtual class BulkV2QueryEngine implements RestEngine {
        protected Integer pollIntervalMs = 1000;
        protected Integer pollCpuTimeoutMs;
        protected Integer maxRecords;
        protected Boolean queryMore = false;

        /**
         * Sets poll interval (milliseconds) for Bulk API v2 job status checks.
         * @param ms interval in milliseconds, must be > 0
         * @return this engine
         */
        public virtual BulkV2QueryEngine setPollInterval(final Integer ms) {
            validateIsTrue(ms > 0, 'pollInterval must be greater than 0. Value: ' + ms);
            this.pollIntervalMs = ms;
            return this;
        }

        /**
         * Enables or disables (default) fetching additional result pages via Bulk V2 locator.
         * When disabled, only the first `/results` page is returned.
         * @param enabled true to follow locator pages, false to return first page only
         * @return this engine
         */
        public virtual BulkV2QueryEngine setQueryMore(final Boolean enabled) {
            validateNotNull(enabled, 'enabled');
            this.queryMore = enabled;
            return this;
        }

        /**
         * Sets CPU guard used while busy-waiting between polls.
         * @param ms CPU threshold in milliseconds, must be > 0
         * @return this engine
         */
        public virtual BulkV2QueryEngine setCpuTimeout(final Integer ms) {
            validateIsTrue(ms > 0, 'cpuTimeout must be greater than 0. Value: ' + ms);
            this.pollCpuTimeoutMs = ms;
            return this;
        }

        /**
         * Sets the Bulk V2 `maxRecords` request parameter for `/results`.
         * @param records maximum records per results page, must be > 0
         * @return this engine
         */
        public virtual BulkV2QueryEngine setMaxRecords(final Integer records) {
            validateIsTrue(records > 0, 'maxRecords must be greater than 0. Value: ' + records);
            this.maxRecords = records;
            return this;
        }

        public virtual Iterable<Object> runMore(final RestDriver driver, final QueryArgs args) {
            validateNotNull(args.listType, 'args.listType');
            return new BulkV2Iterable(driver, args, this);
        }

        public virtual Integer count(final RestDriver driver, final QueryArgs args) {
            String jobId = createJob(driver, SoqlQuery.rewriteCountQueryToId(args.inlineQuery));
            Map<String, Object> completedJob = waitUntilCompleted(driver, jobId);
            return (Integer) completedJob.get('numberRecordsProcessed');
        }

        public virtual Object explain(final RestDriver driver, final QueryArgs args) {
            throw new QueryException('BulkV2QueryEngine does not support explain()');
        }

        public virtual String resolveQueryResource(final Boolean allRows) {
            return 'jobs/query';
        }

        protected virtual String createJob(final RestDriver driver, final String query) {
            Boolean allRows = query.containsIgnoreCase(' ALL ROWS');
            String finalQuery = query.replaceAll('(?i) ALL ROWS', '');
            String basePath = driver.getBaseEndpoint() + 'jobs/query';
            HttpRequest req = new HttpRequest();
            req.setMethod('POST');
            req.setEndpoint('callout:' + driver.namedCredential + basePath);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            req.setBody(
                JSON.serialize(
                    new Map<String, Object>{ 'operation' => allRows ? 'queryAll' : 'query', 'query' => finalQuery }
                )
            );

            HttpResponse res = sendRequest(driver, req, 'create');
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            String jobId = (String) body.get('id');
            if (String.isBlank(jobId)) {
                throw new QueryException('REST Bulk V2 Query create failed: missing job id');
            }
            return jobId;
        }

        protected virtual Map<String, Object> waitUntilCompleted(final RestDriver driver, final String jobId) {
            String statusPath = driver.getBaseEndpoint() + 'jobs/query/' + jobId;
            Map<String, Object> completedBody;
            while (completedBody == null) {
                HttpRequest req = new HttpRequest();
                req.setMethod('GET');
                req.setEndpoint('callout:' + driver.namedCredential + statusPath);
                req.setHeader('Accept', 'application/json');

                HttpResponse res = sendRequest(driver, req, 'status');
                Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                String state = (String) body.get('state');
                if (state == 'JobComplete') {
                    completedBody = body;
                    continue;
                }
                if (state == 'Failed' || state == 'Aborted') {
                    throw new QueryException(
                        'REST Bulk V2 Query failed: state=' + state + ', error=' + (String) body.get('errorMessage')
                    );
                }
                waitForNextPoll();
            }
            return completedBody;
        }

        protected virtual Map<String, Object> fetchResultsCsv(RestDriver driver, String jobId, String locator) {
            String resultsPath = driver.getBaseEndpoint() + 'jobs/query/' + jobId + '/results';
            String separator = '?';
            if (maxRecords != null) {
                resultsPath += separator + 'maxRecords=' + maxRecords;
                separator = '&';
            }
            if (String.isNotBlank(locator)) {
                resultsPath += separator + 'locator=' + EncodingUtil.urlEncode(locator, 'UTF-8');
            }
            HttpRequest req = new HttpRequest();
            req.setMethod('GET');
            req.setEndpoint('callout:' + driver.namedCredential + resultsPath);
            req.setHeader('Accept', 'text/csv');
            HttpResponse res = sendRequest(driver, req, 'results');
            String nextLocator = res.getHeader('Sforce-Locator');
            if (String.isNotBlank(nextLocator) && nextLocator.toLowerCase() == 'null') {
                nextLocator = null;
            }
            return new Map<String, Object>{ 'csv' => res.getBody(), 'locator' => nextLocator };
        }

        @SuppressWarnings('PMD.AvoidDebugStatements')
        private HttpResponse sendRequest(RestDriver driver, HttpRequest req, String phase) {
            HttpResponse res = driver.send(req, 'bulkRequest[' + phase + ']');
            if (res.getStatusCode() >= 400) {
                throw new QueryException(
                    'REST Bulk V2 Query ' + phase + ' failed: ' + res.getStatusCode() + ' ' + res.getBody()
                );
            }
            return res;
        }

        private void waitForNextPoll() {
            Long targetMs = Datetime.now().getTime() + pollIntervalMs;
            while (Datetime.now().getTime() < targetMs) {
                if (Limits.getCpuTime() >= pollCpuTimeoutMs) {
                    throw new QueryException('REST Bulk V2 Query wait exceeded CPU guard ' + pollCpuTimeoutMs + 'ms');
                }
            }
        }

        protected virtual List<Object> projectParsedRows(List<List<String>> parsed, Type listType, String rootType) {
            if (parsed?.isEmpty() ?? true) {
                return new List<Object>();
            }
            Type elementType = elementType(listType);
            Boolean isUntyped = isUntyped(elementType);
            Boolean isSObject = isSObjectLikeType(elementType);
            if (isUntyped) {
                return buildRows(parsed, true, false, true, false, rootType);
            }
            List<Map<String, Object>> rows = buildRows(parsed, true, !isSObject, true, !isSObject, rootType);
            String jsonRows = JSON.serialize(rows);
            return (List<Object>) JSON.deserialize(jsonRows, listType);
        }

        private List<Map<String, Object>> buildRows(
            List<List<String>> parsed,
            Boolean useNestedPaths,
            Boolean normalizeDtoKeys,
            Boolean emptyToNull,
            Boolean coercePrimitives,
            String rootType
        ) {
            List<String> headers = parsed[0];
            List<String> planKeys = new List<String>();
            List<Boolean> planNested = new List<Boolean>();
            List<List<String>> planTokens = new List<List<String>>();
            buildColumnPlans(headers, useNestedPaths, normalizeDtoKeys, planKeys, planNested, planTokens);
            List<Map<String, Object>> rows = new List<Map<String, Object>>();

            for (Integer r = 1; r < parsed.size(); r++) {
                List<String> values = parsed[r];
                Map<String, Object> row = new Map<String, Object>();
                row.put('attributes', buildAttributes(rootType));
                for (Integer c = 0; c < planKeys.size(); c++) {
                    String raw = c < values.size() ? values[c] : '';
                    Object value = toTypedValue(raw, emptyToNull, coercePrimitives);
                    if (planNested[c]) {
                        putNestedValue(row, planTokens[c], value);
                    } else {
                        row.put(planKeys[c], value);
                    }
                }
                rows.add(row);
            }
            return rows;
        }

        private void buildColumnPlans(
            List<String> headers,
            Boolean useNestedPaths,
            Boolean normalizeDtoKeys,
            List<String> planKeys,
            List<Boolean> planNested,
            List<List<String>> planTokens
        ) {
            for (Integer i = 0; i < headers.size(); i++) {
                String key = headers[i];
                if (normalizeDtoKeys && key.contains('__')) {
                    key = key.replace('__', '_');
                }
                Boolean nested = useNestedPaths && key.contains('.');
                planKeys.add(key);
                planNested.add(nested);
                planTokens.add(nested ? key.split('\\.') : null);
            }
        }

        private void putNestedValue(Map<String, Object> row, List<String> parts, Object value) {
            Map<String, Object> current = row;
            for (Integer i = 0; i < parts.size(); i++) {
                String part = parts[i];
                if (i == parts.size() - 1) {
                    current.put(part, value);
                    return;
                }
                Object next = current.get(part);
                if (!(next instanceof Map<String, Object>)) {
                    Map<String, Object> child = new Map<String, Object>();
                    child.put('attributes', buildAttributes(null));
                    current.put(part, child);
                    current = child;
                    continue;
                }
                current = (Map<String, Object>) next;
            }
        }

        private Object toTypedValue(String raw, Boolean emptyToNull, Boolean coercePrimitives) {
            if (raw == '') {
                return emptyToNull ? null : raw;
            }
            if (!coercePrimitives) {
                return raw;
            }
            String lower = raw.toLowerCase();
            if (lower == 'true') {
                return true;
            }
            if (lower == 'false') {
                return false;
            }
            return raw;
        }

        private Map<String, Object> buildAttributes(String objectType) {
            Map<String, Object> attrs = new Map<String, Object>();
            if (String.isNotBlank(objectType)) {
                attrs.put('type', objectType);
            }
            return attrs;
        }

        protected virtual List<List<String>> parseCsvByCharIndexes(String csv) {
            List<List<String>> rows = new List<List<String>>();
            List<String> row = new List<String>();
            Boolean inQuotes = false;
            Integer n = csv.length();
            Integer i = 0;
            if (n > 0 && csv.charAt(0) == 65279) {
                i = 1;
            }
            Integer fieldStart = i;

            while (i < n) {
                Integer code = csv.charAt(i);
                if (code == 34) {
                    if (inQuotes && i + 1 < n && csv.charAt(i + 1) == 34) {
                        i += 2;
                        continue;
                    }
                    inQuotes = !inQuotes;
                    i++;
                    continue;
                }

                if (!inQuotes && (code == 44 || code == 10 || code == 13)) {
                    row.add(decodeCsvField(csv, fieldStart, i));
                    if (code == 44) {
                        i++;
                        fieldStart = i;
                        continue;
                    }
                    if (code == 13 && i + 1 < n && csv.charAt(i + 1) == 10) {
                        i++;
                    }
                    i++;
                    rows.add(row);
                    row = new List<String>();
                    fieldStart = i;
                    continue;
                }
                i++;
            }

            String tail = decodeCsvField(csv, fieldStart, n);
            if (tail != '' || !row.isEmpty()) {
                row.add(tail);
                rows.add(row);
            }
            return rows;
        }

        private String decodeCsvField(String csv, Integer fromIdx, Integer toIdxExclusive) {
            if (toIdxExclusive <= fromIdx) {
                return '';
            }
            String raw = csv.substring(fromIdx, toIdxExclusive);
            Integer len = raw.length();
            if (len >= 2 && raw.charAt(0) == 34 && raw.charAt(len - 1) == 34) {
                String unwrapped = raw.substring(1, len - 1);
                return unwrapped.contains('""') ? unwrapped.replace('""', '"') : unwrapped;
            }
            return raw;
        }
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public virtual class RestDriver implements Driver {
        protected final Pattern apiVersionPattern = Pattern.compile('(?i)^v\\d{2}\\.\\d$');
        protected String apiVersion = 'v66.0';
        protected final String namedCredential;
        protected final DescribeProvider describeProvider = new RestDescribeProvider(this);
        protected RestEngine engine = new QueryEngine();
        protected Boolean isDebugEnabled = false;
        protected Boolean isTimerEnabled = false;
        protected Query.Timer timerMode = Query.Timer.SYS;

        public RestDriver(final String namedCredential) {
            this.namedCredential = namedCredential;
        }

        public DescribeProvider getDescribeProvider() {
            return describeProvider;
        }

        /**
         * Overrides the REST execution engine used by this driver.
         *
         * @param engine Engine implementation used for subsequent REST calls
         * @return Current driver instance for fluent chaining
         *
         * @example
         * SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyNamedCreds')
         *     .useEngine(new SoqlQuery.SObjectCollectionsEngine());
         * // result: query execution uses SObjectCollectionsEngine instead of the default QueryEngine
         */
        public virtual RestDriver useEngine(final RestEngine engine) {
            validateNotNull(engine, 'engine');
            this.engine = engine;
            return this;
        }

        public virtual RestDriver setApiVersion(final String apiVersion) {
            validateNotBlank(apiVersion, 'apiVersion');
            String requested = apiVersion.trim().toLowerCase();
            validateIsTrue(
                apiVersionPattern.matcher(requested).matches(),
                'apiVersion must match vXX.X (example: v66.0). Value: ' + apiVersion
            );
            this.apiVersion = requested;
            return this;
        }

        protected String getBaseEndpoint() {
            return '/services/data/' + apiVersion + '/';
        }

        public virtual List<Object> run(final QueryArgs args) {
            requireUserMode(args.accessMode);
            applyExecutionArgs(args);
            validateNotNull(args.listType, 'args.listType');
            Long start = timerStart(timerMode);
            Type resultListType = args.listType;
            List<Object> results = (List<Object>) resultListType.newInstance();
            for (Object record : runMore(args)) {
                results.add(record);
            }
            logTimer(isTimerEnabled, timerMode, 'rest.run', start);
            return results;
        }

        public virtual Iterable<Object> runMore(final QueryArgs args) {
            requireUserMode(args.accessMode);
            applyExecutionArgs(args);
            return engine.runMore(this, args);
        }

        public virtual Integer count(final QueryArgs args) {
            requireUserMode(args.accessMode);
            applyExecutionArgs(args);
            Long start = timerStart(timerMode);
            Integer result = engine.count(this, args);
            logTimer(isTimerEnabled, timerMode, 'rest.count', start);
            return result;
        }

        public virtual Database.QueryLocator locator(final QueryArgs args) {
            throw new QueryException('REST API does not support QueryLocator');
        }

        public virtual Database.Cursor cursor(final QueryArgs args) {
            throw new QueryException('REST API does not support Cursor');
        }

        public virtual Database.PaginationCursor paginationCursor(final QueryArgs args) {
            throw new QueryException('REST API does not support PaginationCursor');
        }

        public virtual Object explain(final QueryArgs args) {
            requireUserMode(args.accessMode);
            applyExecutionArgs(args);
            final Long start = timerStart(timerMode);
            Object result = engine.explain(this, args);
            logTimer(isTimerEnabled, timerMode, 'rest.explain', start);
            return result;
        }

        protected virtual HttpResponse send(final HttpRequest req, final String requestLabel) {
            logRequest(isDebugEnabled, req, requestLabel);
            final Long start = timerStart(timerMode);
            HttpResponse res = new Http().send(req);
            if (isTimerEnabled) {
                System.debug(LoggingLevel.ERROR, requestLabel + ' duration: ' + timerElapsed(timerMode, start) + 'ms');
            }
            return res;
        }

        private void requireUserMode(AccessLevel accessMode) {
            if (accessMode == AccessLevel.SYSTEM_MODE) {
                throw new QueryException(
                    'RestDriver requires AccessLevel.USER_MODE because REST resources always run in user mode.'
                );
            }
        }

        private void applyExecutionArgs(QueryArgs args) {
            isDebugEnabled = args?.isDebugEnabled ?? false;
            isTimerEnabled = args?.isTimerEnabled ?? false;
            timerMode = args?.timerMode ?? Query.Timer.SYS;
        }
    }

    @TestVisible
    interface Cursor {
        Integer getNumRecords();
        List<SObject> fetch(Integer offset, Integer count);
    }

    private class DatabaseCursor implements Cursor {
        private final Database.Cursor cursor;

        private DatabaseCursor(Database.Cursor cursor) {
            this.cursor = cursor;
        }

        public Integer getNumRecords() {
            return cursor.getNumRecords();
        }

        public List<SObject> fetch(final Integer offset, final Integer count) {
            return cursor.fetch(offset, count);
        }
    }

    private class CursorIterable implements Iterable<SObject> {
        private final Cursor cursor;

        private CursorIterable(Cursor cursor) {
            this.cursor = cursor;
        }

        public Iterator<SObject> iterator() {
            return new CursorIterator(cursor);
        }
    }

    @TestVisible
    private class CursorIterator implements Iterator<SObject> {
        private final Cursor cursor;
        @TestVisible
        private Integer batchSize = 2000;
        private List<SObject> currentBatch;
        private Integer index = 0;
        private Integer offset = 0;

        private CursorIterator(Cursor cursor) {
            this.cursor = cursor;
        }

        public Boolean hasNext() {
            return index < (currentBatch?.size() ?? 0) || offset < cursor.getNumRecords();
        }

        public SObject next() {
            if (index >= (currentBatch?.size() ?? 0)) {
                fetch();
            }
            return currentBatch[index++];
        }

        private void fetch() {
            final Integer count = Math.min(batchSize, cursor.getNumRecords() - offset);
            if (count > 0) {
                currentBatch = cursor.fetch(offset, count);
                offset += count;
                index = 0;
            } else {
                currentBatch = new List<SObject>();
            }
        }
    }

    private class QueryMoreIterable implements Iterable<Object> {
        private final RestDriver driver;
        private final QueryArgs args;
        private final QueryEngine engine;

        private QueryMoreIterable(RestDriver driver, QueryArgs args, QueryEngine engine) {
            this.driver = driver;
            this.args = args;
            this.engine = engine;
        }

        public Iterator<Object> iterator() {
            return new QueryMoreIterator(driver, args, engine);
        }
    }

    public interface QueryMoreRequestEngine {
        HttpResponse send(List<String> urls);
        void process(
            HttpResponse res,
            List<WorkTask> batchTasks,
            List<WorkTask> continuationTasks,
            List<WorkTask> foundChildren
        );
        List<WorkTask> getChildren(WorkTask parent, List<Object> records);
    }

    private abstract class BaseQueryMoreEngine {
        protected final RestDriver driver;
        protected final Map<String, Set<String>> subQueryHierarchy;

        protected BaseQueryMoreEngine(final RestDriver driver, final Map<String, Set<String>> subQueryHierarchy) {
            this.driver = driver;
            this.subQueryHierarchy = subQueryHierarchy;
        }

        protected List<Object> processResponseEntry(
            final WorkTask t,
            final Map<String, Object> body,
            final List<WorkTask> newlyReceived
        ) {
            List<Object> newRecords = (List<Object>) body.get('records');
            if (!(newRecords?.isEmpty() ?? true)) {
                List<Object> records = (List<Object>) t.target.get('records');
                records.addAll(newRecords);
            }
            if (body.get('nextRecordsUrl') != null) {
                newlyReceived.add(new WorkTask(t.target, t.path));
            }
            t.target.put('nextRecordsUrl', body.get('nextRecordsUrl'));
            t.target.put('done', body.get('done') == true || body.get('nextRecordsUrl') == null);
            return newRecords;
        }

        public List<WorkTask> getChildren(final WorkTask parent, final List<Object> records) {
            return collectChildren(parent.path, records);
        }

        private List<WorkTask> collectChildren(String parentPath, List<Object> records) {
            List<WorkTask> children = new List<WorkTask>();
            Set<String> childRels = subQueryHierarchy.get(parentPath);
            if ((childRels?.isEmpty() ?? true) || (records?.isEmpty() ?? true)) {
                return children;
            }
            String prefix = (parentPath == '') ? '' : parentPath + '.';
            for (Object obj : records) {
                Map<String, Object> record = (Map<String, Object>) obj;
                for (String rel : childRels) {
                    Object val = record.get(rel);
                    if (val instanceof Map<String, Object>) {
                        Map<String, Object> child = (Map<String, Object>) val;
                        String childPath = prefix + rel;
                        if (String.isNotBlank((String) child.get('nextRecordsUrl'))) {
                            children.add(new WorkTask(child, childPath));
                        }
                        children.addAll(collectChildren(childPath, (List<Object>) child.get('records')));
                    }
                }
            }
            return children;
        }
    }

    private abstract class EnvelopeQueryMoreEngine extends BaseQueryMoreEngine implements QueryMoreRequestEngine {
        protected EnvelopeQueryMoreEngine(final RestDriver driver, final Map<String, Set<String>> subQueryHierarchy) {
            super(driver, subQueryHierarchy);
        }

        protected abstract String getEntriesKey();
        protected abstract String getStatusKey();
        protected abstract String getBodyKey();
        protected virtual Boolean hasErrors(Map<String, Object> parsed) {
            return false;
        }

        public void process(
            final HttpResponse res,
            final List<WorkTask> batchTasks,
            final List<WorkTask> continuationTasks,
            final List<WorkTask> foundChildren
        ) {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            Boolean envelopeHasErrors = hasErrors(parsed);
            List<Object> entries = (List<Object>) parsed.get(getEntriesKey());
            Set<String> errors = new Set<String>();

            for (Integer i = 0; i < entries.size(); i++) {
                Map<String, Object> entry = (Map<String, Object>) entries[i];
                Integer status = (Integer) entry.get(getStatusKey());
                Object body = entry.get(getBodyKey());
                if (status != 200) {
                    List<Object> errorItems = (List<Object>) body;
                    for (Object item : errorItems) {
                        Map<String, Object> errorItem = (Map<String, Object>) item;
                        String message = (String) errorItem.get('message');
                        if (String.isNotBlank(message)) {
                            errors.add(message);
                        }
                    }
                    continue;
                }
                Map<String, Object> successBody = (Map<String, Object>) body;

                WorkTask t = batchTasks[i];
                List<Object> delta = processResponseEntry(t, successBody, continuationTasks);
                if (!(delta?.isEmpty() ?? true)) {
                    foundChildren.addAll(getChildren(t, delta));
                }
            }
            if (!errors.isEmpty()) {
                throw new QueryException('REST API Error: ' + String.join(new List<String>(errors), '; '));
            }
            if (envelopeHasErrors) {
                throw new QueryException('REST API Error: Composite Batch response hasErrors=true');
            }
        }
    }

    private class CompositeEngine extends EnvelopeQueryMoreEngine {
        private CompositeEngine(RestDriver driver, Map<String, Set<String>> hierarchy) {
            super(driver, hierarchy);
        }

        protected override String getEntriesKey() {
            return 'compositeResponse';
        }

        protected override String getStatusKey() {
            return 'httpStatusCode';
        }

        protected override String getBodyKey() {
            return 'body';
        }

        public HttpResponse send(final List<String> urls) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + driver.namedCredential + driver.getBaseEndpoint() + 'composite');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            List<Map<String, Object>> compositeRequests = new List<Map<String, Object>>();
            for (Integer i = 0; i < urls.size(); i++) {
                compositeRequests.add(
                    new Map<String, Object>{ 'method' => 'GET', 'url' => urls[i], 'referenceId' => 'ref' + i }
                );
            }
            Map<String, Object> compositeRequest = new Map<String, Object>{
                'allOrNone' => true,
                'compositeRequest' => compositeRequests
            };
            req.setBody(JSON.serialize(compositeRequest));
            logRequest(driver.isDebugEnabled, req, 'compositeRequest');
            HttpResponse res = driver.send(req, 'compositeRequest');
            if (res.getStatusCode() != 200) {
                throw new QueryException('REST Composite Failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
            return res;
        }
    }

    private class CompositeBatchEngine extends EnvelopeQueryMoreEngine {
        private CompositeBatchEngine(RestDriver driver, Map<String, Set<String>> hierarchy) {
            super(driver, hierarchy);
        }

        protected override String getEntriesKey() {
            return 'results';
        }

        protected override String getStatusKey() {
            return 'statusCode';
        }

        protected override String getBodyKey() {
            return 'result';
        }

        protected override Boolean hasErrors(Map<String, Object> parsed) {
            return parsed.get('hasErrors') == true;
        }

        public HttpResponse send(final List<String> urls) {
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:' + driver.namedCredential + driver.getBaseEndpoint() + 'composite/batch');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            List<Map<String, Object>> batchRequests = new List<Map<String, Object>>();
            for (String url : urls) {
                batchRequests.add(new Map<String, Object>{ 'method' => 'GET', 'url' => url });
            }
            Map<String, Object> compositeRequest = new Map<String, Object>{ 'batchRequests' => batchRequests };
            req.setBody(JSON.serialize(compositeRequest));
            logRequest(driver.isDebugEnabled, req, 'batchRequest');
            HttpResponse res = driver.send(req, 'batchRequest');
            if (res.getStatusCode() != 200) {
                throw new QueryException('REST Composite Batch Failed: ' + res.getStatusCode() + ' ' + res.getBody());
            }
            return res;
        }
    }

    private class DirectQueryMoreEngine extends BaseQueryMoreEngine implements QueryMoreRequestEngine {
        private final QueryEngine queryEngine;

        private DirectQueryMoreEngine(RestDriver driver, Map<String, Set<String>> hierarchy, QueryEngine queryEngine) {
            super(driver, hierarchy);
            this.queryEngine = queryEngine;
        }

        public HttpResponse send(final List<String> urls) {
            return queryEngine.send(driver, urls[0]);
        }

        public void process(
            final HttpResponse res,
            final List<WorkTask> batchTasks,
            final List<WorkTask> continuationTasks,
            final List<WorkTask> foundChildren
        ) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            WorkTask t = batchTasks[0];
            List<Object> delta = processResponseEntry(t, body, continuationTasks);
            if (!(delta?.isEmpty() ?? true)) {
                foundChildren.addAll(getChildren(t, delta));
            }
        }
    }

    private class QueryMoreIterator implements Iterator<Object> {
        private final RestDriver driver;
        private final QueryEngine engine;
        private final QueryMoreRequestEngine queryMoreEngine;
        private final Map<String, Set<String>> subQueryHierarchy;
        private final Type elementType;
        private final Type typedListType;
        private final Boolean isUntyped;
        private final Boolean isSObject;
        private final Boolean requiresNormalization;
        private final Boolean isSequentialQueryMoreEngine;
        private final List<Object> buffer = new List<Object>();
        private Integer index = 0;
        private String nextUrl;
        private Boolean done = false;

        private QueryMoreIterator(RestDriver driver, QueryArgs args, QueryEngine engine) {
            this.driver = driver;
            this.engine = engine;
            subQueryHierarchy = args.subQueryHierarchy;
            validateNotNull(args.listType, 'args.listType');
            elementType = elementType(args.listType);
            isUntyped = isUntyped(elementType);
            isSObject = isSObjectLikeType(elementType);
            requiresNormalization = !isUntyped && !isSObject;
            typedListType = isUntyped ? null : args.listType;
            isSequentialQueryMoreEngine = engine.queryMoreEngineType == SoqlQuery.QueryMoreEngine.QUERY;
            queryMoreEngine = engine.createQueryMoreEngine(driver, args);

            String resource = engine.resolveQueryResource(args.inlineQuery.containsIgnoreCase(' ALL ROWS'));
            String finalQuery = args.inlineQuery.replaceAll('(?i) ALL ROWS', '');
            nextUrl = driver.getBaseEndpoint() + resource + '/?q=' + EncodingUtil.urlEncode(finalQuery, 'UTF-8');
        }

        public Boolean hasNext() {
            if (index < buffer.size()) {
                return true;
            }
            while (!done && index >= buffer.size()) {
                fetchNextChunk();
            }
            return index < buffer.size();
        }

        public Object next() {
            if (!hasNext()) {
                throw new QueryException('Iterator has no more elements');
            }
            return buffer[index++];
        }

        private void fetchNextChunk() {
            if (String.isBlank(nextUrl)) {
                done = true;
                return;
            }
            HttpResponse res = engine.send(driver, nextUrl);
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>) body.get('records');

            nextUrl = engine.queryMore ? null : (String) body.get('nextRecordsUrl');
            hydrateWaveUnified(new WorkTask(body, ''));
            fillBuffer(records);
            if (!engine.queryMore) {
                done = true;
            }
        }

        private void fillBuffer(List<Object> records) {
            buffer.clear();
            index = 0;
            if (records?.isEmpty() ?? true) {
                return;
            }
            if (isSObject) {
                finalizeSObjectMetadata(records);
            }
            buffer.addAll(projectRowsByElementType(records, typedListType, isUntyped, requiresNormalization));
        }

        private void hydrateWaveUnified(WorkTask root) {
            if (!engine.queryMore) {
                return;
            }

            List<WorkTask> tasks = new List<WorkTask>();
            if (String.isNotBlank((String) root.target.get('nextRecordsUrl'))) {
                tasks.add(root);
            }
            tasks.addAll(queryMoreEngine.getChildren(root, (List<Object>) root.target.get('records')));

            Integer taskIndex = 0;
            while (taskIndex < tasks.size()) {
                List<WorkTask> continuationTasks = new List<WorkTask>();
                List<WorkTask> nextDepthTasks = new List<WorkTask>();
                List<WorkTask> currentBatch = new List<WorkTask>();
                List<String> urls = new List<String>();
                Integer maxBatchSize = isSequentialQueryMoreEngine ? 1 : engine.chunkSize;

                while (taskIndex < tasks.size() && currentBatch.size() < maxBatchSize) {
                    WorkTask t = tasks[taskIndex++];
                    String url = (String) t.target.get('nextRecordsUrl');
                    if (String.isNotBlank(url)) {
                        currentBatch.add(t);
                        urls.add(url);
                    }
                }

                HttpResponse res = queryMoreEngine.send(urls);
                queryMoreEngine.process(res, currentBatch, continuationTasks, nextDepthTasks);
                tasks.addAll(continuationTasks);
                tasks.addAll(nextDepthTasks);
            }
        }

        private void finalizeSObjectMetadata(List<Object> records) {
            finalizeSObjectMetadataByPath(records, '');
        }

        private void finalizeSObjectMetadataByPath(List<Object> records, String parentPath) {
            if (records?.isEmpty() ?? true) {
                return;
            }
            Set<String> childRels = subQueryHierarchy?.get(parentPath);
            if (childRels?.isEmpty() ?? true) {
                return;
            }
            String prefix = (parentPath == '') ? '' : parentPath + '.';
            for (Object row : records) {
                Map<String, Object> record = (Map<String, Object>) row;
                for (String rel : childRels) {
                    Map<String, Object> childQueryResult = (Map<String, Object>) record.get(rel);
                    if (childQueryResult == null) {
                        continue;
                    }
                    childQueryResult.put('done', true);
                    childQueryResult.remove('nextRecordsUrl');
                    finalizeSObjectMetadataByPath((List<Object>) childQueryResult.get('records'), prefix + rel);
                }
            }
        }
    }

    private class SObjectCollectionsIterable implements Iterable<Object> {
        private final RestDriver driver;
        private final QueryArgs args;
        private final SObjectCollectionsEngine engine;

        private SObjectCollectionsIterable(RestDriver driver, QueryArgs args, SObjectCollectionsEngine engine) {
            this.driver = driver;
            this.args = args;
            this.engine = engine;
        }

        public Iterator<Object> iterator() {
            return new SObjectCollectionsIterator(driver, args, engine);
        }
    }

    private class SObjectCollectionsIterator implements Iterator<Object> {
        private final RestDriver driver;
        private final SObjectCollectionsEngine engine;
        private final String sObjectType;
        private final List<String> fields;
        private final List<String> ids;
        private final Type listType;
        private final List<Object> buffer = new List<Object>();
        private Integer index = 0;
        private Integer offset = 0;

        private SObjectCollectionsIterator(RestDriver driver, QueryArgs args, SObjectCollectionsEngine engine) {
            this.driver = driver;
            this.engine = engine;
            listType = args.listType;
            Map<String, Object> parsed = engine.parseQuery(args);
            sObjectType = (String) parsed.get('sObjectType');
            fields = (List<String>) parsed.get('fields');
            ids = (List<String>) parsed.get('ids');
        }

        public Boolean hasNext() {
            if (index < buffer.size()) {
                return true;
            }
            while (offset < ids.size() && index >= buffer.size()) {
                fetchNextChunk();
            }
            return index < buffer.size();
        }

        public Object next() {
            if (!hasNext()) {
                throw new QueryException('Iterator has no more elements');
            }
            return buffer[index++];
        }

        private void fetchNextChunk() {
            List<String> idsChunk = new List<String>();
            Integer chunkEnd = Math.min(offset + engine.chunkSize, ids.size());
            for (Integer i = offset; i < chunkEnd; i++) {
                idsChunk.add(ids[i]);
            }
            offset = chunkEnd;
            buffer.clear();
            index = 0;
            List<Object> rows = engine.fetchChunk(driver, sObjectType, fields, idsChunk);
            buffer.addAll(engine.projectRecords(rows, listType));
        }
    }

    private class BulkV2Iterable implements Iterable<Object> {
        private final RestDriver driver;
        private final QueryArgs args;
        private final BulkV2QueryEngine engine;

        private BulkV2Iterable(RestDriver driver, QueryArgs args, BulkV2QueryEngine engine) {
            this.driver = driver;
            this.args = args;
            this.engine = engine;
        }

        public Iterator<Object> iterator() {
            return new BulkV2Iterator(driver, args, engine);
        }
    }

    private class BulkV2Iterator implements Iterator<Object> {
        private final RestDriver driver;
        private final BulkV2QueryEngine engine;
        private final String query;
        private final Type listType;
        private final List<Object> buffer = new List<Object>();
        private Integer index = 0;
        private String jobId;
        private String locator;
        private String rootType;
        private Boolean initialized = false;
        private Boolean done = false;
        private List<String> headers;

        private BulkV2Iterator(RestDriver driver, QueryArgs args, BulkV2QueryEngine engine) {
            this.driver = driver;
            this.engine = engine;
            query = args.inlineQuery;
            listType = args.listType;
        }

        public Boolean hasNext() {
            if (index < buffer.size()) {
                return true;
            }
            while (!done && index >= buffer.size()) {
                fetchNextChunk();
            }
            return index < buffer.size();
        }

        public Object next() {
            if (!hasNext()) {
                throw new QueryException('Iterator has no more elements');
            }
            return buffer[index++];
        }

        private void fetchNextChunk() {
            if (!initialized) {
                jobId = engine.createJob(driver, query);
                Map<String, Object> completedJob = engine.waitUntilCompleted(driver, jobId);
                rootType = (String) completedJob?.get('object');
                initialized = true;
            }

            Map<String, Object> chunk = engine.fetchResultsCsv(driver, jobId, locator);
            List<List<String>> chunkRows = engine.parseCsvByCharIndexes((String) chunk.get('csv'));
            List<List<String>> projectedRows = projectRowsWithHeader(chunkRows);

            buffer.clear();
            index = 0;
            buffer.addAll(engine.projectParsedRows(projectedRows, listType, rootType));

            String nextLocator = (String) chunk.get('locator');
            if (!engine.queryMore || String.isBlank(nextLocator)) {
                done = true;
                return;
            }
            locator = nextLocator;
        }

        private List<List<String>> projectRowsWithHeader(List<List<String>> chunkRows) {
            List<List<String>> projectedRows = new List<List<String>>();
            if (headers == null && (chunkRows?.isEmpty() ?? true)) {
                return projectedRows;
            }
            if (headers == null) {
                headers = chunkRows[0];
                projectedRows.addAll(chunkRows);
                return projectedRows;
            }
            projectedRows.add(headers);
            for (Integer i = 1; i < chunkRows.size(); i++) {
                projectedRows.add(chunkRows[i]);
            }
            return projectedRows;
        }
    }

    public class WorkTask {
        private final Map<String, Object> target;
        private final String path;
        private WorkTask(Map<String, Object> target, String path) {
            this.target = target;
            this.path = path;
        }
    }
    // </editor-fold>
}
