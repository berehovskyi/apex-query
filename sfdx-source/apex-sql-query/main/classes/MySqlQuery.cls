/**
 * MySQL-specialized SQL query builder.
 *
 * Extends `SqlQuery` with MySQL-specific behavior and helpers:
 * - Default anonymous bindings (`?`) via `Query.BindingStrategy.ANONYMOUS`
 * - MySQL condition operators: `REGEXP`, `NOT REGEXP`, `<=>`
 * - MySQL function helpers: `GROUP_CONCAT`, `DATE_FORMAT`, `JSON_EXTRACT`
 *
 * @example
 * String sql = MySqlQuery.of('users')
 *     .wherex(new MySqlQuery.Condition().mysqlField('email').regexp('.*@gmail.com'))
 *     .toString(); // SELECT * FROM users WHERE email REGEXP ?
 */
@SuppressWarnings('PMD.ApexDoc')
public virtual inherited sharing class MySqlQuery extends SqlQuery {
    /**
     * Creates a MySQL query for a table and enables anonymous bindings (`?`).
     * @param table source table name
     */
    public MySqlQuery(String table) {
        super(table);
        useBindingStrategy(Query.BindingStrategy.ANONYMOUS);
    }

    /**
     * Creates a MySQL query for a table alias pair and enables anonymous bindings (`?`).
     * @param table source table name
     * @param alias table alias
     */
    public MySqlQuery(String table, String alias) {
        super(table, alias);
        useBindingStrategy(Query.BindingStrategy.ANONYMOUS);
    }

    /**
     * Static factory for `MySqlQuery(String)`.
     * @param table source table name
     * @return new MySQL query instance
     */
    public static MySqlQuery of(String table) {
        return new MySqlQuery(table);
    }

    /**
     * Static factory for `MySqlQuery(String, String)`.
     * @param table source table name
     * @param alias table alias
     * @return new MySQL query instance
     */
    public static MySqlQuery of(String table, String alias) {
        return new MySqlQuery(table, alias);
    }

    /**
     * Builds `GROUP_CONCAT(expr)`.
     * @param value expression to aggregate
     * @return literal MySQL expression
     */
    public static Object groupConcat(Object value) {
        validateNotNull(value, 'value');
        return SqlQuery.literal('GROUP_CONCAT(' + Query.formatValue(value) + ')');
    }

    /**
     * Builds `GROUP_CONCAT(expr SEPARATOR 'x')`.
     * @param value expression to aggregate
     * @param separator output separator
     * @return literal MySQL expression
     */
    public static Object groupConcat(Object value, String separator) {
        validateNotNull(value, 'value');
        validateNotNull(separator, 'separator');
        return SqlQuery.literal(
            'GROUP_CONCAT(' + Query.formatValue(value) + ' SEPARATOR ' + Query.formatValue(separator) + ')'
        );
    }

    /**
     * Builds `DATE_FORMAT(expr, format)`.
     * @param value date/datetime expression
     * @param format MySQL format string
     * @return literal MySQL expression
     */
    public static Object dateFormat(Object value, String format) {
        validateNotNull(value, 'value');
        validateNotBlank(format, 'format');
        return SqlQuery.literal('DATE_FORMAT(' + Query.formatValue(value) + ', ' + Query.formatValue(format) + ')');
    }

    /**
     * Builds `JSON_EXTRACT(doc, path)`.
     * @param jsonDoc JSON document expression
     * @param path JSON path (for example `$.field`)
     * @return literal MySQL expression
     */
    public static Object jsonExtract(Object jsonDoc, String path) {
        validateNotNull(jsonDoc, 'jsonDoc');
        validateNotBlank(path, 'path');
        return SqlQuery.literal('JSON_EXTRACT(' + Query.formatValue(jsonDoc) + ', ' + Query.formatValue(path) + ')');
    }

    /**
     * MySQL-aware condition builder.
     * Extends `SqlQuery.Condition` with MySQL operators while preserving fluent chaining.
     */
    public class Condition extends SqlQuery.Condition {
        public Condition() {
            super();
        }

        public Condition(String raw) {
            super(raw);
        }

        /**
         * MySQL id shortcut using lowercase `id`.
         * @return base condition reference
         */
        public override SqlQuery.Condition id() {
            return mySqlField('id');
        }

        /**
         * Sets the condition field and returns MySQL condition type for fluent chaining.
         * @param field column/expression
         * @return current condition
         */
        public Condition mySqlField(String field) {
            return (Condition) super.field(field);
        }

        /**
         * Adds `REGEXP` comparison.
         * @param pattern right-hand regex pattern
         * @return current condition
         */
        public Condition regexp(Object pattern) {
            return (Condition) super.comparand('REGEXP', pattern);
        }

        /**
         * Adds `NOT REGEXP` comparison.
         * @param pattern right-hand regex pattern
         * @return current condition
         */
        public Condition notRegexp(Object pattern) {
            return (Condition) super.comparand('NOT REGEXP', pattern);
        }

        /**
         * Adds MySQL null-safe equality `<=>`.
         * @param value right-hand value
         * @return current condition
         */
        public Condition nullSafeEq(Object value) {
            return (Condition) super.comparand('<=>', value);
        }
    }
}
