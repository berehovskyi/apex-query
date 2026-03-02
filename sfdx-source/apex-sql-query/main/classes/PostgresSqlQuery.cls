/**
 * PostgreSQL-specialized SQL query builder.
 *
 * Extends `SqlQuery` with PostgreSQL-specific helpers while keeping the same fluent API.
 * Key additions:
 * - `DISTINCT ON (...)` via `distinctOn(...)`
 * - `LATERAL` join helpers via `innerJoinLateral(...)`, `leftJoinLateral(...)`, `crossJoinLateral(...)`
 * - PostgreSQL cast shortcut `value::type` via `castColon(...)`
 * - PostgreSQL condition operators in `Condition`: `ILIKE`, `NOT ILIKE`, regex operators
 *
 * By default this class uses `Query.BindingStrategy.INDEXED`, producing placeholders like `$1`, `$2`, etc.
 *
 * @example
 * String sql = PostgresSqlQuery.of('weather_reports')
 *     .distinctOn('location')
 *     .field('location')
 *     .field('time')
 *     .orderBy('location')
 *     .orderBy('time', Query.SortOrder.DESCX)
 *     .toString();
 */
@SuppressWarnings('PMD.ApexDoc')
public virtual inherited sharing class PostgresSqlQuery extends SqlQuery {
    private final List<Object> distinctOnExpressions = new List<Object>();

    /**
     * Creates a PostgreSQL query for a table and enables indexed bindings (`$1`, `$2`, ...).
     * @param table source table name
     */
    public PostgresSqlQuery(String table) {
        super(table);
        useBindingStrategy(Query.BindingStrategy.INDEXED);
    }

    /**
     * Creates a PostgreSQL query for a table alias pair and enables indexed bindings (`$1`, `$2`, ...).
     * @param table source table name
     * @param alias table alias
     */
    public PostgresSqlQuery(String table, String alias) {
        super(table, alias);
        useBindingStrategy(Query.BindingStrategy.INDEXED);
    }

    /**
     * Static factory for `PostgresSqlQuery(String)`.
     * @param table source table name
     * @return a new PostgreSQL query instance
     */
    public static PostgresSqlQuery of(String table) {
        return new PostgresSqlQuery(table);
    }

    /**
     * Static factory for `PostgresSqlQuery(String, String)`.
     * @param table source table name
     * @param alias table alias
     * @return a new PostgreSQL query instance
     */
    public static PostgresSqlQuery of(String table, String alias) {
        return new PostgresSqlQuery(table, alias);
    }

    /**
     * Alias for `innerJoinLateral(...)`.
     * @param subquery lateral subquery builder
     * @param alias alias for the lateral subquery result
     * @return this query
     */
    public PostgresSqlQuery joinLateral(Query.Builder subquery, String alias) {
        return innerJoinLateral(subquery, alias);
    }

    /**
     * Adds `INNER JOIN LATERAL (<subquery>) alias`.
     * @param subquery lateral subquery builder
     * @param alias alias for the lateral subquery result
     * @return this query
     */
    public PostgresSqlQuery innerJoinLateral(Query.Builder subquery, String alias) {
        return (PostgresSqlQuery) addLateralJoin('INNER JOIN', subquery, alias);
    }

    /**
     * Adds `LEFT JOIN LATERAL (<subquery>) alias`.
     * @param subquery lateral subquery builder
     * @param alias alias for the lateral subquery result
     * @return this query
     */
    public PostgresSqlQuery leftJoinLateral(Query.Builder subquery, String alias) {
        return (PostgresSqlQuery) addLateralJoin('LEFT JOIN', subquery, alias);
    }

    /**
     * Adds `CROSS JOIN LATERAL (<subquery>) alias`.
     * @param subquery lateral subquery builder
     * @param alias alias for the lateral subquery result
     * @return this query
     */
    public PostgresSqlQuery crossJoinLateral(Query.Builder subquery, String alias) {
        return (PostgresSqlQuery) addLateralJoin('CROSS JOIN', subquery, alias);
    }

    /**
     * Produces a raw literal using PostgreSQL cast syntax: `value::type`.
     * The value is first formatted using the framework formatter, then wrapped as a SQL literal fragment.
     * @param value value or expression to cast
     * @param type PostgreSQL target type (for example `int`, `timestamp`, `jsonb`)
     * @return a literal expression suitable for `SELECT`, predicates, etc
     *
     * @example
     * PostgresSqlQuery.of('events')
     *     .field(PostgresSqlQuery.castColon('42', 'int'), 'answer_int')
     *     .field(PostgresSqlQuery.castColon(SqlQuery.literal('created_at'), 'timestamp'), 'created_ts');
     */
    public static Object castColon(Object value, String type) {
        validateNotNull(value, 'value');
        validateNotBlank(type, 'type');
        return SqlQuery.literal(Query.formatValue(value) + '::' + type);
    }

    /**
     * Adds one expression to `DISTINCT ON (...)`.
     * @param expression column or expression used by `DISTINCT ON`
     * @return this query
     */
    public PostgresSqlQuery distinctOn(Object expression) {
        validateDistinctOnExpression(expression);
        distinctOnExpressions.add(expression);
        return this;
    }

    /**
     * Adds multiple expressions to `DISTINCT ON (...)`.
     * @param expressions columns/expressions used by `DISTINCT ON`; cannot be null or empty
     * @return this query
     */
    public PostgresSqlQuery distinctOn(Iterable<Object> expressions) {
        validateNotNull(expressions, 'expressions');
        validateIsTrue(expressions.iterator().hasNext(), 'expressions cannot be empty');
        for (Object expression : expressions) {
            distinctOn(expression);
        }
        return this;
    }

    /**
     * Builds count SQL.
     * When `DISTINCT ON` is present, count is performed on a wrapped subquery to keep PostgreSQL semantics
     * correct for distinct-row counting.
     * @param targetContext bind context or null for inline SQL
     * @return count query string
     */
    public override String toCountString(BindContext targetContext) {
        if (!hasDistinctOn()) {
            return super.toCountString(targetContext);
        }
        return 'SELECT COUNT(*) FROM (' + buildQueryString(targetContext) + ') AS count_wrapper';
    }

    protected Boolean hasDistinctOn() {
        return !distinctOnExpressions.isEmpty();
    }

    protected List<Object> getDistinctOnExpressions() {
        return distinctOnExpressions.clone();
    }

    protected override List<Query.Part> build(BindContext targetContext) {
        List<Query.Part> parts = super.build(targetContext);
        if (!hasDistinctOn() || parts.size() < 2) {
            return parts;
        }
        parts[1] = new DistinctOnSelectPart(parts[1], getDistinctOnExpressions());
        return parts;
    }

    private static void validateDistinctOnExpression(Object expression) {
        validateNotNull(expression, 'expression');
        if (expression instanceof String) {
            validateNotBlank((String) expression, 'expression');
        }
    }

    private static String joinExpressions(Iterable<Object> expressions) {
        List<String> result = new List<String>();
        for (Object expression : expressions) {
            result.add(String.valueOf(expression));
        }
        return String.join(result, ', ');
    }

    /**
     * PostgreSQL-aware condition builder.
     * Extends `SqlQuery.Condition` with PostgreSQL operators while preserving fluent chaining.
     * Use `pgField(String)` as the fluent entry point before operator methods.
     *
     * @example
     * SqlQuery.Condition c = new PostgresSqlQuery.Condition()
     *     .pgField('name')
     *     .iLike('%john%');
     */
    public class Condition extends SqlQuery.Condition {
        /**
         * Creates an empty condition.
         */
        public Condition() {
            super();
        }

        /**
         * Creates a raw condition fragment.
         * @param raw verbatim condition SQL
         */
        public Condition(String raw) {
            super(raw);
        }

        /**
         * PostgreSQL id shortcut using lowercase `id`.
         * @return base condition reference
         */
        public override SqlQuery.Condition id() {
            return pgField('id');
        }

        /**
         * Sets the condition field and returns PostgreSQL condition type for fluent chaining.
         * @param field column/expression
         * @return current condition
         */
        public Condition pgField(String field) {
            return (Condition) super.field(field);
        }

        /**
         * Adds `ILIKE` comparison.
         * @param pattern right-hand pattern
         * @return current condition
         */
        public Condition iLike(Object pattern) {
            return (Condition) super.comparand('ILIKE', pattern);
        }

        /**
         * Adds `NOT ILIKE` comparison.
         * @param pattern right-hand pattern
         * @return current condition
         */
        public Condition notILike(Object pattern) {
            return (Condition) super.comparand('NOT ILIKE', pattern);
        }

        /**
         * Adds case-sensitive regex operator `~`.
         * @param pattern regex pattern
         * @return current condition
         */
        public Condition regex(Object pattern) {
            return (Condition) super.comparand('~', pattern);
        }

        /**
         * Adds case-insensitive regex operator `~*`.
         * @param pattern regex pattern
         * @return current condition
         */
        public Condition iRegex(Object pattern) {
            return (Condition) super.comparand('~*', pattern);
        }

        /**
         * Adds negated case-sensitive regex operator `!~`.
         * @param pattern regex pattern
         * @return current condition
         */
        public Condition notRegex(Object pattern) {
            return (Condition) super.comparand('!~', pattern);
        }

        /**
         * Adds negated case-insensitive regex operator `!~*`.
         * @param pattern regex pattern
         * @return current condition
         */
        public Condition notIRegex(Object pattern) {
            return (Condition) super.comparand('!~*', pattern);
        }
    }

    private class DistinctOnSelectPart implements Query.Part {
        private final Query.Part baseSelectPart;
        private final List<Object> expressions;

        public DistinctOnSelectPart(Query.Part baseSelectPart, List<Object> expressions) {
            this.baseSelectPart = baseSelectPart;
            this.expressions = expressions;
        }

        public Boolean isEmpty() {
            return baseSelectPart?.isEmpty() ?? true;
        }

        public override String toString() {
            String baseSql = baseSelectPart?.toString();
            String selectDistinctPrefix = 'SELECT DISTINCT ';
            String selectPrefix = 'SELECT ';
            Boolean hasDistinctPrefix = baseSql?.startsWith(selectDistinctPrefix) ?? false;
            Boolean hasSelectPrefix = baseSql?.startsWith(selectPrefix) ?? false;
            Integer prefixLength = hasDistinctPrefix
                ? selectDistinctPrefix.length()
                : (hasSelectPrefix ? selectPrefix.length() : 0);
            String payload = prefixLength > 0 ? baseSql.substring(prefixLength) : baseSql;
            return 'SELECT DISTINCT ON (' + joinExpressions(expressions) + ') ' + payload;
        }
    }
}
