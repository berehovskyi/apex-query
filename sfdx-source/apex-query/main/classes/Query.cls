/**
 * Abstract base class for all Query implementations (SOQL, SQL).
 * Shared state and logic for query building.
 */
public abstract class Query implements Builder, Bindable {
    protected Boolean isDebugEnabled = false;
    protected Boolean isTimerEnabled = false;
    protected Timer timerMode = Timer.SYS;
    protected Boolean isSubQuery = false;
    protected BindContext bindContext = new BindContext();
    protected Map<String, Object> userBindings = new Map<String, Object>();

    public abstract String toCountString(BindContext targetContext);
    protected abstract String getCountSelectPart();
    protected abstract List<Part> buildCount(BindContext targetContext);
    protected abstract List<Part> build(BindContext targetContext);

    public Boolean isDebugEnabled() {
        return isDebugEnabled;
    }

    public Boolean isTimerEnabled() {
        return isTimerEnabled;
    }

    public Timer getTimer() {
        return timerMode ?? Timer.SYS;
    }

    public static Long timerStart(final Timer mode) {
        return mode == Timer.CPU ? Limits.getCpuTime() : System.now().getTime();
    }

    public static Long timerElapsed(final Timer mode, final Long start) {
        return timerStart(mode) - start;
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public static void logTimer(final Boolean enabled, final Timer mode, final String operation, final Long start) {
        if (enabled) {
            System.debug(LoggingLevel.ERROR, operation + ' duration: ' + timerElapsed(mode, start) + 'ms');
        }
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public static void logRequest(final Boolean enabled, final HttpRequest req, final String label) {
        if (enabled) {
            String body = req.getBody();
            body = String.isBlank(body) ? '' : ('\n' + JSON.serializePretty(JSON.deserializeUntyped(body)));
            System.debug(LoggingLevel.ERROR, label + ': ' + req.getEndpoint() + body);
        }
    }

    public virtual void withBindContext(final BindContext context) {
        this.bindContext = context;
        this.isSubQuery = true;
    }

    public Map<String, Object> getUserBindings() {
        return userBindings;
    }

    public virtual Map<String, Object> getBindings() {
        BindContext temp = new BindContext(bindContext.getStrategy());
        buildQueryString(temp);
        Map<String, Object> allBinds = temp.getMap().clone();
        allBinds.putAll(userBindings);
        return allBinds;
    }

    public virtual Map<String, Object> getCountBindings() {
        BindContext temp = new BindContext(bindContext.getStrategy());
        buildCountQueryString(temp);
        Map<String, Object> allBinds = temp.getMap().clone();
        allBinds.putAll(userBindings);
        return allBinds;
    }

    public virtual String toInlineString() {
        return buildQueryString(null);
    }

    public virtual String toInlineCountString() {
        return buildCountQueryString(null);
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public virtual String buildQueryString(final BindContext targetContext) {
        if (targetContext != null && !isSubQuery) {
            targetContext.clear();
        }

        String query = '';
        for (Part fragment : build(targetContext)) {
            if (fragment.isEmpty()) {
                continue;
            }
            String fragmentString = fragment.toString();
            if (String.isNotBlank(fragmentString)) {
                if (query != '' && !fragmentString.startsWith(' ') && !fragmentString.startsWith(',')) {
                    query += ' ';
                }
                query += fragmentString;
            }
        }
        if (targetContext != null) {
            targetContext.putAll(userBindings);
        }
        if (isDebugEnabled && !isSubQuery && targetContext == null) {
            System.debug(LoggingLevel.ERROR, '?q=' + query);
        }
        return query;
    }

    @SuppressWarnings('PMD.AvoidDebugStatements')
    public virtual String buildCountQueryString(final BindContext targetContext) {
        if (targetContext != null && !isSubQuery) {
            targetContext.clear();
        }
        String query = 'SELECT ' + getCountSelectPart();
        for (Part fragment : buildCount(targetContext)) {
            if (fragment.isEmpty()) {
                continue;
            }
            String fragmentString = fragment.toString();
            if (String.isNotBlank(fragmentString)) {
                if (!fragmentString.startsWith(' ')) {
                    query += ' ';
                }
                query += fragmentString;
            }
        }
        if (targetContext != null) {
            targetContext.putAll(userBindings);
        }
        if (isDebugEnabled && !isSubQuery && targetContext == null) {
            System.debug(LoggingLevel.ERROR, '?q=' + query);
        }
        return query;
    }

    // <editor-fold desc="Validate Methods">
    public static void validateNotNull(final Object obj, final String argName) {
        validateIsTrue(obj != null, argName + ' cannot be null');
    }

    public static void validateNotBlank(final String str, final String argName) {
        validateIsTrue(str != null, argName + ' cannot be null');
        validateIsTrue(String.isNotBlank(str), argName + ' cannot be blank');
    }

    public static void validateIsTrue(final Boolean condition, final String message) {
        if (!condition) {
            throw new QueryException(message);
        }
    }
    // </editor-fold>

    // <editor-fold desc="Projection Helpers">
    public static Type elementType(final Type listType) {
        String typeName = String.valueOf(listType);
        validateIsTrue(
            typeName.startsWith('List<') && typeName.endsWith('>'),
            'Expected list type in form List<T>.class but got: ' + typeName
        );
        String elementTypeName = typeName.substring(5, typeName.length() - 1).replace(' ', '');
        if (elementTypeName.startsWith('Map<')) {
            return Map<String, Object>.class;
        }
        return Type.forName(elementTypeName);
    }

    public static Boolean isUntyped(final Type candidateType) {
        return candidateType == null || candidateType == Map<String, Object>.class || candidateType == Object.class;
    }

    public static Object normalizeDtoKeys(final Object node) {
        if (node instanceof List<Object>) {
            List<Object> normalizedList = new List<Object>();
            for (Object item : (List<Object>) node) {
                normalizedList.add(normalizeDtoKeys(item));
            }
            return normalizedList;
        }
        if (!(node instanceof Map<String, Object>)) {
            return node;
        }
        Map<String, Object> normalizedMap = new Map<String, Object>();
        Map<String, Object> source = (Map<String, Object>) node;
        for (String key : source.keySet()) {
            String normalizedKey = key.contains('__') ? key.replace('__', '_') : key;
            normalizedMap.put(normalizedKey, normalizeDtoKeys(source.get(key)));
        }
        return normalizedMap;
    }

    public static List<Object> projectRowsByElementType(
        final List<Object> records,
        final Type listType,
        final Boolean isUntyped,
        final Boolean requiresNormalization
    ) {
        if (isUntyped) {
            return records;
        }
        Object payload = requiresNormalization ? normalizeDtoKeys(records) : records;
        return (List<Object>) JSON.deserialize(JSON.serialize(payload), listType);
    }
    // </editor-fold>

    @SuppressWarnings('PMD.ApexDoc')
    public interface Builder {
        // SELECT Fields
        Builder field(String field);
        Builder fields(Iterable<Object> fields);
        Builder fields(String fields);
        Builder allFields();
        // SELECT Functions
        Builder grouping(String field);
        Builder grouping(String field, String alias);
        // SELECT Aggregate Functions
        Builder count(String field);
        Builder count(String field, String alias);
        Builder countDistinct(String field);
        Builder countDistinct(String field, String alias);
        Builder avg(String field);
        Builder avg(String field, String alias);
        Builder min(String field);
        Builder min(String field, String alias);
        Builder max(String field);
        Builder max(String field, String alias);
        Builder sum(String field);
        Builder sum(String field, String alias);
        // WHERE
        Builder wherex(Criterion condition);
        Builder wherex(String condition);
        Builder addCondition(Criterion condition);
        Builder addCondition(String condition);
        Builder addConditionAnd(Criterion condition);
        Builder addConditionAnd(String condition);
        Builder addConditionOr(Criterion condition);
        Builder addConditionOr(String condition);
        Builder addConditionEq(String field, Object value);
        Builder addConditionNe(String field, Object value);
        Builder addConditionIn(String field, Iterable<Object> iterable);
        Builder addConditionIn(String field, Builder semiJoinSubQuery);
        Builder addConditionNotIn(String field, Iterable<Object> iterable);
        Builder addConditionNotIn(String field, Builder antiJoinSubQuery);
        // GROUP BY
        Builder groupBy(Iterable<Object> fields);
        Builder groupByRollup(Iterable<Object> fields);
        Builder groupByCube(Iterable<Object> fields);
        // HAVING
        Builder havingx(Criterion condition);
        Builder havingx(String condition);
        Builder addHaving(Criterion condition);
        Builder addHaving(String condition);
        Builder addHavingAnd(Criterion condition);
        Builder addHavingAnd(String condition);
        Builder addHavingOr(Criterion condition);
        Builder addHavingOr(String condition);
        Builder addHavingEq(String field, Object value);
        Builder addHavingIn(String field, Iterable<Object> iterable);
        // ORDER BY
        Builder orderBy(String field);
        Builder orderBy(String field, SortOrder sortOrder);
        Builder orderBy(String field, SortOrder sortOrder, NullsOrder nullsOrder);
        // LIMIT
        Builder lim(Integer count);
        // OFFSET
        Builder offset(Integer count);
        // Custom Bindings
        Map<String, Object> getBindings();
        Map<String, Object> getCountBindings();
        Builder withBindings(Map<String, Object> bindings);
        // Execution and Inspection
        Object explain();
        Builder debug();
        String toString();
        String toInlineString();
        String toCountString();
        String toInlineCountString();
    }

    public enum Timer {
        CPU,
        SYS
    }

    public enum SortOrder {
        ASCX,
        DESCX
    }

    public enum NullsOrder {
        NULLS_FIRST,
        NULLS_LAST
    }

    public enum BindingStrategy {
        NAMED, // :var$1
        INDEXED, // $1
        ANONYMOUS // ?
    }

    public interface Criterion {
    }

    public interface Bindable {
        void withBindContext(BindContext context);
    }

    public interface Part {
        Boolean isEmpty();
    }

    public virtual class BindContext {
        protected final Map<String, Object> bindings = new Map<String, Object>();
        protected Integer i = 0;
        private BindingStrategy strategy = BindingStrategy.NAMED;

        public BindContext() {
        }

        public BindContext(final BindingStrategy strategy) {
            this.strategy = strategy;
        }

        public Map<String, Object> getMap() {
            return bindings;
        }

        public virtual String add(final Object value) {
            i++;
            String key;
            if (strategy == BindingStrategy.INDEXED) {
                // Postgres style: $1, $2
                key = '$' + i;
            } else if (strategy == BindingStrategy.ANONYMOUS) {
                // MySQL style: ?
                key = '?';
            } else {
                // Named style: var0, var1 (SOQL/Oracle)
                key = 'var$' + (i - 1);
                while (bindings.containsKey(key)) {
                    i++;
                    key = 'var$' + (i - 1);
                }
            }
            if (strategy != BindingStrategy.ANONYMOUS) {
                bindings.put(key, value);
            } else {
                // Anonymous binds imply list order. Map key is irrelevant but we need to store for retrieval.
                bindings.put('?' + i, value);
            }
            return key;
        }

        public void setStrategy(final BindingStrategy strategy) {
            this.strategy = strategy;
        }

        public BindingStrategy getStrategy() {
            return strategy;
        }

        public Boolean isNamed() {
            return strategy == BindingStrategy.NAMED;
        }

        public void putAll(final Map<String, Object> binds) {
            if (binds != null) {
                bindings.putAll(binds);
            }
        }

        public void clear() {
            bindings.clear();
            i = 0;
        }

        public virtual override String toString() {
            List<String> entries = new List<String>();
            for (String key : bindings.keySet()) {
                entries.add(key + '=' + bindings.get(key));
            }
            entries.sort();
            return String.join(entries, ',');
        }
    }

    public static String formatValue(final Object value) {
        if (value == null) {
            return 'NULL';
        }
        if (value instanceof Boolean) {
            return value.toString().toUpperCase();
        }
        if (value instanceof Date) {
            return '\'' + ((Datetime) value).formatGmt('yyyy-MM-dd') + '\'';
        }
        if (value instanceof Datetime) {
            return '\'' + ((Datetime) value).formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'') + '\'';
        }
        if (value instanceof Time) {
            return '\'' + String.valueOf(value) + '\'';
        }
        if (value instanceof String) {
            return '\'' + String.escapeSingleQuotes(value.toString()) + '\'';
        }
        if (value instanceof Iterable<Object>) {
            List<String> formatted = new List<String>();
            for (Object v : (Iterable<Object>) value) {
                formatted.add(formatValue(v));
            }
            return '(' + String.join(formatted, ', ') + ')';
        }
        return value.toString();
    }

    public abstract class BindableCondition implements Criterion, Bindable {
        protected BindContext boundContext;

        public virtual void withBindContext(final BindContext context) {
            this.boundContext = context;
        }

        protected virtual String formatValue(final Object value) {
            return Query.formatValue(value);
        }
    }

    public class NegatedCondition extends BindableCondition {
        private final Criterion condition;

        public NegatedCondition(final Criterion condition) {
            this.condition = condition;
        }

        public override void withBindContext(final BindContext context) {
            if (condition instanceof Bindable) {
                ((Bindable) condition).withBindContext(context);
            }
        }

        public override String toString() {
            return '(NOT ' + condition + ')';
        }
    }

    public virtual class Junction extends BindableCondition {
        protected final List<Criterion> conditions = new List<Criterion>();
        protected Boolean wrapIfMulti = false;
        private String logicalOperator;

        public Junction add(final Criterion condition, final String logicalOperator) {
            validateNotNull(condition, 'condition');
            validateNotNull(logicalOperator, 'logicalOperator');

            if (this.logicalOperator == null) {
                this.logicalOperator = logicalOperator;
            } else if (this.logicalOperator != logicalOperator) {
                String errorMsg = String.format(
                    'Ambiguous logical criteria: The current operator \'\'{0}\'\' cannot be overridden with \'\'{1}\'\'. ' +
                    'Wrap sub-conditions in a nested Junction or Condition to clarify operator precedence.',
                    new List<String>{ this.logicalOperator, logicalOperator }
                );
                throw new QueryException(errorMsg);
            }
            conditions.add(condition);
            return this;
        }

        public Junction add(final Criterion condition) {
            validateNotNull(condition, 'condition');
            conditions.add(condition);
            return this;
        }

        public Junction addAnd(final Criterion condition) {
            return add(condition, 'AND');
        }

        public Junction addOr(final Criterion condition) {
            return add(condition, 'OR');
        }

        public Junction ands(final Criterion c1, final Criterion c2) {
            return ands(new List<Criterion>{ c1, c2 });
        }

        public Junction ands(final Iterable<Criterion> conditions) {
            addAll(conditions, 'AND');
            this.wrapIfMulti = true;
            return this;
        }

        public Junction ors(final Criterion c1, final Criterion c2) {
            return ors(new List<Criterion>{ c1, c2 });
        }

        public Junction ors(final Iterable<Criterion> conditions) {
            addAll(conditions, 'OR');
            this.wrapIfMulti = true;
            return this;
        }

        public Junction notx(final Criterion condition) {
            add(new NegatedCondition(condition));
            return this;
        }

        public void clear() {
            conditions.clear();
        }

        public Boolean isEmpty() {
            return conditions.isEmpty();
        }

        protected void addAll(final Iterable<Criterion> conditions, final String logicalOperator) {
            for (Criterion condition : conditions) {
                add(condition, logicalOperator);
            }
        }

        @SuppressWarnings('PMD.OneDeclarationPerLine')
        public virtual override String toString() {
            List<String> args = new List<String>();
            List<Object> formatArgs = new List<Object>();

            for (Integer i = 0, size = conditions.size(); i < size; i++) {
                if (conditions[i] instanceof Bindable) {
                    ((Bindable) conditions[i]).withBindContext(boundContext);
                }
                args.add('{' + i + '}');
                formatArgs.add(conditions[i]);
            }
            if (conditions.isEmpty()) {
                return '';
            }

            // Default to AND if not specified
            String op = logicalOperator ?? 'AND';
            String template = String.join(args, ' ' + op + ' ');
            String result = String.format(template, formatArgs);

            return (wrapIfMulti && conditions.size() > 1) ? '(' + result + ')' : result;
        }
    }

    public class QueryException extends Exception {
    }
}
