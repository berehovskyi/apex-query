# Apex SQL Framework Technical Documentation

The `apex-query` framework provides a powerful, type-safe SQL builder via `SqlQuery`. Designed for external integrations (Data 360 / Data Cloud and external SQL engines), it supports ANSI SQL standards and advanced features not available in SOQL.

## 1. Fundamentals

`SqlQuery` extends the core `Query` engine, sharing the same consistent `BindContext` and Driver architecture.

Current hierarchy:

- `SqlQuery` -> base ANSI SQL builder
- `PostgresSqlQuery extends SqlQuery` -> PostgreSQL helpers (`DISTINCT ON`, `::` cast, regex + `ILIKE` conditions)
- `MySqlQuery extends SqlQuery` -> MySQL helpers (`REGEXP`, `<=>`, `GROUP_CONCAT`, `DATE_FORMAT`, `JSON_EXTRACT`)

### Initialization

```apex
SqlQuery.of('table_name');
SqlQuery.of('table_name', 'alias');

PostgresSqlQuery.of('table_name');
PostgresSqlQuery.of('table_name', 'alias');

MySqlQuery.of('table_name');
MySqlQuery.of('table_name', 'alias');
```

Alternatively, using the standard constructor:

```apex
new SqlQuery('table_name');
new SqlQuery('table_name', 'alias');

new PostgresSqlQuery('table_name');
new PostgresSqlQuery('table_name', 'alias');

new MySqlQuery('table_name');
new MySqlQuery('table_name', 'alias');
```

```apex
SqlQuery.of('users').useBindingStrategy(Query.BindingStrategy.NAMED);      // :var$0 (default for SqlQuery)
PostgresSqlQuery.of('users').toString();                                   // $1, $2... (default INDEXED)
MySqlQuery.of('users').toString();                                         // ?, ?... (default ANONYMOUS)
```

Dialect defaults:

- `SqlQuery` default binding strategy: `NAMED` (`:var$0`)
- `PostgresSqlQuery` default binding strategy: `INDEXED` (`$1`, `$2`, ...)
- `MySqlQuery` default binding strategy: `ANONYMOUS` (`?`)

### Execution & Drivers

`SqlQuery` is a builder by default. To execute queries via `.fetch()` or `.fetchCount()`, a **Driver** must be configured.

```apex
q.useDriver(new NeonDriver());
```

> [!IMPORTANT]
> Attempting to execute a query without a driver will throw a `QueryException`. This separation allows using `SqlQuery` as a pure string builder without needing a runtime connection.

## 2. Basic Query Construction

The builder supports standard SQL clauses with fluent syntax.

### Selection & Joins

```apex
SqlQuery cte = SqlQuery.of('Orders')
    .field('CustomerId')
    .field('count(id) order_count')
    .groupBy('CustomerId');

SqlQuery.of('MainTable', 'm')
    .with('CustomerStats', cte)
    .field('m.*')
    .innerJoin('CustomerStats', 'cs')
    .onx('m.CustomerId = cs.CustomerId')
    .wherex(new SqlQuery.Condition().field('cs.order_count').gt(5))
    .fetch();
```

**Supported Joins**: `join`, `innerJoin`, `leftJoin`, `rightJoin`, `fullJoin`, `crossJoin`.

`PostgresSqlQuery` additionally supports lateral joins:

- `joinLateral(...)`
- `innerJoinLateral(...)`
- `leftJoinLateral(...)`
- `crossJoinLateral(...)`

### JOIN Syntax Variants

Advanced join mechanisms using `USING`, `NATURAL`, or `CROSS` keywords.

```apex
// CROSS JOIN
new SqlQuery('TableA').crossJoin('TableB');

// USING Clause
new SqlQuery('Orders').innerJoin('Customers').usingx('CustomerId');

// NATURAL JOIN
new SqlQuery('Orders').innerJoin('Customers').natural();
```

### Filtering (WHERE / HAVING)

Standard `wherex` and `havingx` clauses support the same operator-agnostic composition as SOQL.

```apex
q.wherex(new SqlQuery.Condition().field('status').eq('shipped'))
 .groupBy('region')
 .havingx(new SqlQuery.Condition().field('count(id)').gt(10));
```

### SQL Functions

The `SqlQuery` class provides static helpers for common SQL functions.

- `SqlQuery.upper(field)` -> `UPPER(field)`
- `SqlQuery.lower(field)` -> `LOWER(field)`
- `SqlQuery.cast(field, type)` -> `CAST(field AS type)`
- `SqlQuery.coalesce(val1, val2)` -> `COALESCE(val1, val2)`
- `SqlQuery.dateTrunc(part, field)` -> `DATE_TRUNC('part', field)` (PostgreSQL-style)
- `SqlQuery.literal(value)` -> Inserts value strictly verbatim (unquoted/raw). Use for column-to-column comparisons (e.g. `status = previous_status`) or complex expressions.

### Condition Logic

Conditions are built using `SqlQuery.Condition` (same pattern as `SoqlQuery.Condition`).

- `eq('Value')` -> `... = 'Value'` (Auto-quoted literal)
- `eq(SqlQuery.literal('Column'))` -> `... = Column` (Raw column reference)
- `likex('Bank%')` -> `... LIKE 'Bank%'`
- `notLikex('%Test%')` -> `... NOT LIKE '%Test%'`

> [!NOTE]
> Dialect condition builders intentionally use `String` field entry methods (`pgField(...)`, `mysqlField(...)`) for lightweight APIs.
> For SQL expressions, pass a string like `'LOWER(name)'`.

### Arithmetic & Expressions

The builder supports raw math expressions in field selections and conditions.

```apex
q.field(SqlQuery.literal('pk + 10'), 'incremented_pk')
 .field(SqlQuery.literal('planet_int * 2'), 'doubled')
 .addCondition('pk * 2 > 20');
```

### Convenience Helpers

Shortcuts for common conditions:

```apex
q.byId('001...');                      // WHERE Id = '001...'
q.byIds(new List<String>{'a', 'b'});   // WHERE Id IN ('a', 'b')

q.addConditionEq('Type', 'Customer')
 .addConditionNe('Status', 'Inactive')
 .addConditionIn('Region', regionsList);

// Raw String Conditions (Standard SQL)
q.addCondition('created_date > NOW() - INTERVAL \'1 day\'');
```

### Aggregate Shortcuts

Directly add aggregate fields without manual field construction. All methods accept `Object` (strings as column names, or `literal()`/expressions).

```apex
q.countAll('total_records')        // SELECT COUNT(*) total_records
 .sum('Amount', 'revenue')         // SELECT SUM(Amount) revenue
 .avg(SqlQuery.literal('Score*2')); // SELECT AVG(Score*2)
```

## 3. Subquery Operators

The builder supports standard ANSI subquery operators.

### EXISTS

```apex
SqlQuery sub = SqlQuery.of('Orders').field('id').wherex('total > 100');
q.wherex(SqlQuery.exists(sub));
```

### ANY / SOME / ALL

```apex
q.wherex(new SqlQuery.Condition().field('status').eq(SqlQuery.any(sub)));
q.wherex(new SqlQuery.Condition().field('total').gt(SqlQuery.all(sub)));
```

> [!NOTE]
> Backend support for subquery operators varies. For example, some SQLite versions (like those used in latest.datasette.io) may not natively support the `ALL` operator, while `EXISTS` and `ANY` are widely supported.

## 4. Set Operations (Union / Intersect / Except)

Combine results from multiple queries using ANSI standard set operators.

- `union()`, `unionAll()`
- `intersect()`, `intersectAll()`
- `except()`, `exceptAll()`

```apex
var q1 = SqlQuery.of('us_sales').field('product_id');
var q2 = SqlQuery.of('eu_sales').field('product_id');

q1.unionAll(q2).fetch();
```

## 5. Conditional Logic (CASE Expressions)

Type-safe `CASE` expressions for complex logic.

### Simple CASE

```apex
SqlQuery.CASEX.match('status')
    .when('Active').then('Ready')
    .elsex('Unknown')
    .end();
```

### Search CASE

```apex
SqlQuery.CASEX
    .when(new SqlQuery.Condition().field('age').gt(18)).then('Adult')
    .elsex('Minor')
    .end();
```

## 6. Advanced Grouping

The `GROUP BY` clause supports advanced grouping elements like `ROLLUP`, `CUBE`, and `GROUPING SETS`.

### Mixed Elements

```apex
q.groupBy('Region')
 .groupByRollup(new List<String>{'Year', 'Month'})
 .groupByGroupingSets(new List<Object>{'Product', '()'});
```

### Helper Specifics

- `SqlQuery.rollup(field | list)`
- `SqlQuery.cube(field | list)`
- `SqlQuery.groupingSets(list)`

### Grouping Identification

Use the `GROUPING` function to distinguish between nulls and subtotals.

```apex
SqlQuery.of('Sales')
    .field('Region')
    .field(SqlQuery.grouping('Region'), 'IsSubtotal');
```

## 7. Advanced Aggregation (FILTER / HAVING)

Supports ANSI SQL `FILTER (WHERE ...)` for specific aggregates, and strictly typed `HAVING` conditions.

```apex
// Aggregate Filter
SqlQuery.AGG.sum('Amount')
    .filter(new SqlQuery.Condition().field('Year').eq(2023));

// Having Condition (supports Object fields)
q.havingx(
    new SqlQuery.HavingCondition()
        .avg('Score').gt(50)
        .addAnd(new SqlQuery.HavingCondition().countAll().gt(10))
);
```

## 8. Window Functions (Analytical Queries)

Perform calculation across a set of table rows using the `WIN` provider. Methods accept `Object` fields to support both column names and complex expressions.

**Functions**: `rowNumber`, `rank`, `denseRank`, `lead`, `lag`, `firstValue`, `lastValue`, `nthValue`, `ntile`.

```apex
// Basic Windowing
SqlQuery.WIN.rowNumber().orderBy('salary DESC').partitionBy('department');

// NTH_VALUE / NTILE (with literal expressions)
SqlQuery.WIN.nthValue('EmployeeName', 2).orderBy('Salary DESC');
SqlQuery.WIN.ntile(4).orderBy(SqlQuery.literal('Salary * 12 DESC'));

// Window Frames (ROWS / RANGE)
SqlQuery.WIN.sum('Amount')
    .orderBy('Date')
    .rowsBetween('UNBOUNDED PRECEDING', 'CURRENT ROW'); // Running Total

SqlQuery.WIN.avg('Score')
    .orderBy('Date')
    .rangeBetween(10, 'CURRENT ROW'); // Rolling average based on value range
```

### Row Limiting (LIMIT / OFFSET / FETCH)

Standard SQL row limiting using `LIMIT` or the ANSI `FETCH` clause.

```apex
// Standard LIMIT
q.lim(10).offset(20);

// ANSI FETCH (SQL:2008)
q.fetchFirst(5);                // FETCH FIRST 5 ROWS ONLY
q.fetchFirstWithTies(10);       // FETCH FIRST 10 ROWS WITH TIES
q.fetchNext(5);                 // FETCH NEXT 5 ROWS ONLY
```

## 9. Virtual Tables (VALUES)

Generate row data inline, useful for mocking or set operations.

```apex
q.values(
    new List<List<Object>>{
        new List<Object>{'A', 1},
        new List<Object>{'B', 2}
    },
    'alias',
    new List<String>{'col1', 'col2'}
);
```

### Joining Virtual Tables

The most reliable way to join a physical table with virtual data is to define the `VALUES` clause as a CTE and then join it by name.

```apex
SqlQuery planetMapping = new SqlQuery('any')
    .values(planetData, 'p', new List<String>{ 'id', 'name' });

q.with('planets_cte', planetMapping)
 .innerJoin('planets_cte', 'p2')
 .onx('f.planet_int = p2.id');
```

## 10. Modular Queries (CTEs)

Use Common Table Expressions (`WITH`) to organize complex queries.

```apex
SqlQuery regionalSales = SqlQuery.of('orders')...;

SqlQuery.of('Employees')
    .with('regional_sales', regionalSales)
    .field('*').join('regional_sales', 'rs').onx('...');
```

## 11. Standard SQL Functions

Helper static methods available directly on `SqlQuery` class.

### Type Conversion & Date

```apex
// CAST(age AS VARCHAR)
SqlQuery.cast('age', 'VARCHAR');

// DATE_TRUNC('month', created_date)
SqlQuery.dateTrunc('month', 'created_date');
```

### Conditional & Null Handling

```apex
// COALESCE(phone, 'Unknown')
// Note: Use literal() for column references to avoid auto-quoting as a string.
SqlQuery.coalesce(SqlQuery.literal('phone'), 'Unknown');

// COALESCE(val1, val2, val3) - List variant
SqlQuery.coalesce(new List<Object>{SqlQuery.literal('val1'), SqlQuery.literal('val2'), 'N/A'});
```

### String Manipulation

```apex
// UPPER(lastname)
SqlQuery.upper('lastname');

// LOWER(email)
SqlQuery.lower('email');
```

## 12. Logical Helpers & Negation

Static methods for composing complex Boolean logic.

### Condition Grouping

```apex
SqlQuery.ands(cond1, cond2); // (cond1 AND cond2)
SqlQuery.ors(cond1, cond2);  // (cond1 OR cond2)
```

### Negation

```apex
SqlQuery.notx(new SqlQuery.Condition().field('Status').eq('Closed'));
// NOT (Status = 'Closed')
```

## 13. Dialect-Specific Builders

### PostgreSQL (`PostgresSqlQuery`)

```apex
PostgresSqlQuery.of('weather_reports')
    .distinctOn('location')
    .field('location')
    .field('time')
    .orderBy('location')
    .orderBy('time', Query.SortOrder.DESCX);

new PostgresSqlQuery.Condition()
    .pgField('name')
    .iLike('%john%');

PostgresSqlQuery.castColon('42', 'int'); // '42'::int
```

Supported PostgreSQL condition operators:

- `iLike(...)` -> `ILIKE`
- `notILike(...)` -> `NOT ILIKE`
- `regex(...)` -> `~`
- `iRegex(...)` -> `~*`
- `notRegex(...)` -> `!~`
- `notIRegex(...)` -> `!~*`

### MySQL (`MySqlQuery`)

```apex
MySqlQuery.of('users')
    .wherex(new MySqlQuery.Condition().mySqlField('email').regexp('.*@gmail.com'));

MySqlQuery.groupConcat(SqlQuery.literal('customer_id'));
MySqlQuery.dateFormat(SqlQuery.literal('created_at'), '%Y-%m-%d');
MySqlQuery.jsonExtract(SqlQuery.literal('payload'), '$.amount');
```

Supported MySQL condition operators:

- `regexp(...)` -> `REGEXP`
- `notRegexp(...)` -> `NOT REGEXP`
- `nullSafeEq(...)` -> `<=>`
