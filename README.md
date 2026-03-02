# Apex Query

![](https://img.shields.io/github/v/release/berehovskyi/apex-query?include_prereleases)
![](https://img.shields.io/badge/build-passing-brightgreen.svg)
![](https://img.shields.io/badge/coverage-100%25-brightgreen.svg)

`apex-query` is a premium, high-performance query engine for Salesforce Apex. It provides a unified, chainable DSL for **SOQL**, while maintaining architectural support for **ANSI SQL** and **Data Cloud (CDP)**. Designed for technical superiority, type safety, and maximum developer productivity.

## Table of Contents

- [Installation](#installation)
- [Features](#features)
- [SOQL Usage](#soql-usage)
    - [Initialization](#initialization)
    - [Usage Styles (Composition and Inheritance)](#usage-styles-composition-and-inheritance)
    - [Select](#select)
    - [Aggregates](#aggregates)
    - [Select Functions](#select-functions)
    - [Polymorphic Queries (TYPEOF)](#polymorphic-queries-typeof)
    - [Relationship Queries (Sub-queries)](#relationship-queries-sub-queries)
    - [Specialized Providers](#specialized-providers)
    - [Filtering](#filtering)
    - [Logical Junctions](#logical-junctions)
    - [Grouping](#grouping)
    - [Having](#having)
    - [Ordering](#ordering)
    - [Paging](#paging)
    - [Other](#other)
    - [Security & Privacy](#security--privacy)
    - [Caching](#caching)
    - [Execution Drivers](#execution-drivers)
    - [Terminal Execution API](#terminal-execution-api)
    - [Introspection & Debugging](#introspection--debugging)
- [SQL Usage](#sql-usage)
    - [Initialization](#initialization-1)
    - [Select](#select-1)
    - [Aggregates](#aggregates-1)
    - [Joins](#joins)
    - [Filtering](#filtering-1)
    - [Grouping](#grouping-1)
    - [Having](#having-1)
    - [Set Operators](#set-operators)
    - [CTEs](#ctes)
    - [VALUES](#values)
    - [CASE](#case)
    - [Window Functions](#window-functions)
    - [Ordering](#ordering-1)
    - [Row Limiting](#row-limiting)
    - [Dialect Extensions](#dialect-extensions)
    - [Execution and Terminal Operations](#execution-and-terminal-operations)
    - [Introspection and Debugging](#introspection-and-debugging)
- [CDP Query Usage](#cdp-query-usage)
    - [Driver Overview](#driver-overview)
    - [ConnectApi Driver (Default)](#connectapi-driver-default)
    - [REST Driver (Named Credential)](#rest-driver-named-credential)
    - [Projection Strategy](#projection-strategy)
- [Architecture](#architecture)

---

## Installation

### Option 1: Source Deploy (all layers)

```sh
# Core (SOQL)
sf project deploy start -d sfdx-source/apex-query -o <org-alias>

# (Optional) SQL layer (ANSI SQL + PostgreSQL + MySQL helpers)
sf project deploy start -d sfdx-source/apex-sql-query -o <org-alias>

# (Optional) Data 360 layer (CDP/Data 360)
sf project deploy start -d sfdx-source/apex-cdp-query -o <org-alias>
```

### Option 2: Unlocked Packages

Only these two packages are currently distributed as unlocked packages.
Install in dependency order:

### Core (SOQL)

```sh pkg::apex-query
sf package install -p 04tJ5000000D9ZrIAK -o <org-alias> -r -w 10
```

### (Optional) SQL layer (SQL + PostgreSQL + MySQL)

```sh pkg::apex-sql-query
sf package install -p 04tJ5000000D9ZwIAK -o <org-alias> -r -w 10
```

### (Optional) Data 360 layer (CDP/Data Cloud Query)

> Data 360 layer (`apex-cdp-query`) is source-deploy only at this time.
> Use Option 1 for CDP/Data 360 support.

> _Data 360 source metadata package requires an org with Data 360/Data Cloud enabled._

---

## Features

- **Unified Query DSL:** Build SOQL, ANSI SQL, and Data 360 SQL (CDP) with one fluent API.
- **Dialect Coverage:** Includes major SQL dialect helpers (PostgresSqlQuery, MySqlQuery) for real-world query syntax.
- **Pluggable Execution Drivers:** Execute via local database, Salesforce REST, ConnectApi, or custom drivers without changing query intent.
- **Typed and Untyped Projection:** Fetch into maps, DTOs, or supported SObject models with consistent terminal APIs.
- **Advanced Query Capabilities:** Supports joins, subqueries, CTEs, window functions, aggregates, grouping sets, and set operators.
- **Security and Runtime Controls:** Built-in sharing/access mode controls, strip-inaccessible options, caching, and debug/timing introspection.
- **Cross-Org and External Querying:** Use Named Credentials and REST engines to query local orgs, remote orgs, and external backends.
- **Scalable Data Retrieval:** Supports lazy iteration, query continuation, and bulk-oriented execution paths for large datasets.
- **Deterministic Query Introspection:** Inspect bound SQL/SOQL, inline-rendered queries, count variants, and bindings at runtime.
- **Composable Architecture:** Reuse query fragments through composition, subclass constrained query types, and standardize patterns across teams.

---

## SOQL Usage

### Initialization

Initialize queries using SObject types, tokens, or API name strings.
This can be achieved using either the static `of()` method or by calling the `SoqlQuery` constructor directly.

```apex
// Static Factory
SoqlQuery q1 = SoqlQuery.of(Account.SObjectType);
SoqlQuery q2 = SoqlQuery.of('Account');
// SELECT Id FROM Account

// Direct Constructor
SoqlQuery q3 = new SoqlQuery(Account.SObjectType);
SoqlQuery q4 = new SoqlQuery('Account');
// SELECT Id FROM Account
```

### Usage Styles (Composition and Inheritance)

Use `SoqlQuery` in different ways depending on reuse and ownership boundaries.

```apex
// 1) Inline/Direct usage (ad hoc)
List<Account> rows = SoqlQuery.of(Account.SObjectType)
    .field(Account.Id)
    .field(Account.Name)
    .addConditionEq(Account.Type, 'Customer')
    .lim(50)
    .fetch();

// 2) Composition: reusable query fragment
public class AccountQueryFragments {
    public static SoqlQuery activeCustomerOnly(SoqlQuery q) {
        return q
            .addConditionEq(Account.IsDeleted, false)
            .addConditionEq(Account.Type, 'Customer');
    }
}

SoqlQuery composed = AccountQueryFragments
    .activeCustomerOnly(SoqlQuery.of(Account.SObjectType))
    .field(Account.Id)
    .field(Account.Name)
    .orderBy(Account.CreatedDate, Query.SortOrder.DESCX);

// 3) Inheritance: constrained query type
public virtual class AccountQuery extends SoqlQuery {
    public AccountQuery() {
        super(Account.SObjectType);
        field(Account.Id).field(Account.Name);
    }

    public AccountQuery activeOnly() {
        addConditionEq(Account.IsDeleted, false);
        return this;
    }
}

List<Account> accounts = (List<Account>) new AccountQuery()
    .activeOnly()
    .fetch();
```

| Style       | Best For                                             | Tradeoff                                |
| :---------- | :--------------------------------------------------- | :-------------------------------------- |
| Inline      | One-off queries in service/controller code           | Reuse is low                            |
| Composition | Reusable filters/fragments shared across modules     | Requires discipline around fragment API |
| Inheritance | Opinionated query types with fixed defaults/policies | Tighter coupling to class hierarchy     |

> [!NOTE]
> Prefer composition first. Use inheritance when you need a strongly constrained query type with enforced defaults.

### Select

Select fields individually, via FieldSets, or using native `FIELDS()` shortcuts.

```apex
q.field(Account.Name)
 .field('Owner.Alias')
 .fields('ExternalId__c, CustomField__c')
 .fieldSet('Custom_FieldSet__c')
 .customFields();
// SELECT Name, Owner.Alias, ExternalId__c, CustomField__c, [FieldSet Fields], FIELDS(CUSTOM) FROM Account
```

**Available Selection Methods:**

| Method                 | Description                                                         |
| :--------------------- | :------------------------------------------------------------------ |
| `field(field)`         | Selects a single field by token or string name.                     |
| `fields(fields)`       | Selects multiple fields from a list or comma-separated string.      |
| `fieldSet(name)`       | Selects all fields from a specific FieldSet (uses schema describe). |
| `standardFields()`     | Native `FIELDS(STANDARD)`.                                          |
| `customFields()`\*     | Native `FIELDS(CUSTOM)`. Sets LIMIT 200.                            |
| `allFields()`\*        | Native `FIELDS(ALL)`. Sets LIMIT 200.                               |
| `allDescribeFields()`  | Selects all fields using schema describe.                           |
| `allReadableFields()`  | Selects all fields accessible to the current user.                  |
| `allEditableFields()`  | Selects all fields updateable by the current user.                  |
| `allCreatableFields()` | Selects all fields creatable by the current user.                   |

\* _Unbounded queries are supported when using the [RestDriver](#execution-drivers)._

### Aggregates

Perform standard SOQL aggregations with optional aliasing.

```apex
q.count('Id', 'total')
 .sum(Opportunity.Amount, 'revenue');
// SELECT COUNT(Id) total, SUM(Amount) revenue FROM Opportunity
```

**Available Aggregates:**

> [!NOTE]
> Aggregates and Functions support optional `alias`.

| Method                          | Description                    |
| :------------------------------ | :----------------------------- |
| `count(field, [alias])`         | `COUNT(field) alias`.          |
| `countDistinct(field, [alias])` | `COUNT_DISTINCT(field) alias`. |
| `sum(field, [alias])`           | `SUM(field) alias`.            |
| `avg(field, [alias])`           | `AVG(field) alias`.            |
| `min(field, [alias])`           | `MIN(field) alias`.            |
| `max(field, [alias])`           | `MAX(field) alias`.            |

### Select Functions

Apply SOQL-specific transformations directly to selected fields.

```apex
q.toLabel(Account.Type)
 .format(Opportunity.Amount);
// SELECT toLabel(Type), format(Amount) FROM Opportunity
```

**Available Functions:**

| Method                            | Description                                             |
| :-------------------------------- | :------------------------------------------------------ |
| `toLabel(field, [alias])`         | Translates picklist values into the user's language.    |
| `format(field, [alias])`          | Formats numbers, dates, and times based on user locale. |
| `convertCurrency(field, [alias])` | Converts currency amounts to the user's currency.       |
| `convertTimezone(field)`          | Converts datetime fields to the user's timezone.        |
| `grouping(field, [alias])`        | Used with ROLLUP/CUBE to identify subtotal rows.        |

### Polymorphic Queries (TYPEOF)

Handle polymorphic relationship fields with a clean, builder-based `TYPEOF` syntax.

```apex
SoqlQuery.TypeOf ownerType = new SoqlQuery.TypeOf('Owner')
        .when('User').then('Alias, Email')
        .when('Group').then('Name')
        .elsex('Name')
    .end();

q.typeOf(ownerType);
// SELECT TYPEOF Owner WHEN User THEN Alias, Email WHEN Group THEN Name ELSE Name END FROM Account
```

### Relationship Queries (Sub-queries)

Construct nested child relationship queries.

```apex
q.subQuery('Contacts', SoqlQuery.of('Contact').field('LastName'));
// SELECT (SELECT LastName FROM Contact) FROM Account
```

**Available Sub-query Methods:**

| Method                            | Description                                                            |
| :-------------------------------- | :--------------------------------------------------------------------- |
| `subQuery(relName, builder)`      | Adds a relationship sub-query using a `SoqlQuery` instance.            |
| `subQuery(relName, type, fields)` | Shortcut to add a sub-query for a specific SObjectType and field list. |

### Specialized Providers

Static providers help you author complex SOQL elements with type safety.

#### Date Functions (`SoqlQuery.DT`)

Methods for extracting date parts from fields. Supports both `SObjectField` and `String` inputs.

| Method                   | Description               |
| :----------------------- | :------------------------ |
| `calendarMonth(field)`   | `CALENDAR_MONTH(field)`   |
| `calendarQuarter(field)` | `CALENDAR_QUARTER(field)` |
| `calendarYear(field)`    | `CALENDAR_YEAR(field)`    |
| `dayInMonth(field)`      | `DAY_IN_MONTH(field)`     |
| `dayInWeek(field)`       | `DAY_IN_WEEK(field)`      |
| `dayInYear(field)`       | `DAY_IN_YEAR(field)`      |
| `dayOnly(field)`         | `DAY_ONLY(field)`         |
| `fiscalMonth(field)`     | `FISCAL_MONTH(field)`     |
| `fiscalQuarter(field)`   | `FISCAL_QUARTER(field)`   |
| `fiscalYear(field)`      | `FISCAL_YEAR(field)`      |
| `hourInDay(field)`       | `HOUR_IN_DAY(field)`      |
| `weekInMonth(field)`     | `WEEK_IN_MONTH(field)`    |
| `weekInYear(field)`      | `WEEK_IN_YEAR(field)`     |

#### Date Literals (`SoqlQuery.LIT`)

Static constants and parameterized methods for SOQL date literals.

**Constants:**
`yesterday`, `today`, `tomorrow`, `lastWeek`, `thisWeek`, `nextWeek`, `lastMonth`, `thisMonth`, `nextMonth`, `last90Days`, `next90Days`, `thisQuarter`, `lastQuarter`, `nextQuarter`, `thisYear`, `lastYear`, `nextYear`, `thisFiscalQuarter`, `lastFiscalQuarter`, `nextFiscalQuarter`, `thisFiscalYear`, `lastFiscalYear`, `nextFiscalYear`.

**Parameterized Methods (`Integer n`):**
`lastNDays(n)`, `nextNDays(n)`, `nDaysAgo(n)`, `nextNWeeks(n)`, `lastNWeeks(n)`, `nWeeksAgo(n)`, `nextNMonths(n)`, `lastNMonths(n)`, `nMonthsAgo(n)`, `nextNQuarters(n)`, `lastNQuarters(n)`, `nQuartersAgo(n)`, `nextNYears(n)`, `lastNYears(n)`, `nYearsAgo(n)`, `nextNFiscalQuarters(n)`, `lastNFiscalQuarters(n)`, `nFiscalQuartersAgo(n)`, `nextNFiscalYears(n)`, `lastNFiscalYears(n)`, `nFiscalYearsAgo(n)`

#### Geolocation & Currency

Specialized types for spatial and monetary literals.

**Geolocation (`SoqlQuery.GEO`):**

```apex
Location hq = Location.newInstance(37.7749, -122.4194);
q.addCondition(SoqlQuery.COND.field(SoqlQuery.GEO.of('BillingAddress', hq, SoqlQuery.DistanceUnit.MI)).lt(50));
// WHERE DISTANCE(BillingAddress, GEOLOCATION(37.7749, -122.4194), 'mi') < 50
```

- `of(field, Location, DistanceUnit)`: Calculates `DISTANCE` between a field and a static point.

**Currency (`SoqlQuery.CUR`):**

```apex
q.addCondition(SoqlQuery.COND.field('AnnualRevenue').gt(SoqlQuery.CUR.of('USD', 500000)));
// WHERE AnnualRevenue > USD500000
```

- `of(String code, Decimal value)`: Generates currency literals like `USD100.50`.

#### Data Categories (`SoqlQuery.CAT`)

Fluent builder for `WITH DATA CATEGORY` selections.

```apex
q.withDataCategory(SoqlQuery.CAT.of('Geography').at('Europe'));
// WITH DATA CATEGORY Geography AT Europe
```

| Method                   | Description                           |
| :----------------------- | :------------------------------------ |
| `of(name)`               | Sets the group name.                  |
| `at(category)`           | Selects a specific category.          |
| `above(category)`        | Selects category and all ancestors.   |
| `below(category)`        | Selects category and all descendants. |
| `aboveOrBelow(category)` | Selects ancestors and descendants.    |

### Filtering

Author conditions using builder shortcuts or the dedicated `COND` factory.

```apex
// Shortcut approach (additive)
q.addConditionEq(Account.Industry, 'Technology')
 .addConditionIn('Id', SoqlQuery.of('Contact').field('AccountId'));
// WHERE Industry = 'Technology' AND Id IN (SELECT AccountId FROM Contact)

// Explicit approach (replaces existing filters)
q.wherex(SoqlQuery.COND.field(Account.Industry).eq('Technology'));
// WHERE Industry = 'Technology'
```

**Selection vs. Chaining:**

| Method                | Behavior                                   | Use Case                                          |
| :-------------------- | :----------------------------------------- | :------------------------------------------------ |
| `wherex(...)`         | **Replaces** entire WHERE clause.          | When you want to reset or set the primary filter. |
| `addCondition*(...)`  | **Appends** to existing filters via `AND`. | When adding multiple filters incrementally.       |
| `addConditionOr(...)` | **Appends** to existing filters via `OR`.  | For simple logical branching.                     |

**Available Filtering Methods:**

| Category       | Method                                          | Description                                               |
| :------------- | :---------------------------------------------- | :-------------------------------------------------------- |
| **Criterion**  | `addCondition(Criterion)` / `wherex(Criterion)` | Accepts a pre-built `SoqlQuery.COND` or `ands()`/`ors()`. |
| **Raw String** | `addCondition(String)` / `wherex(String)`       | Direct injection of raw SOQL snippets.                    |
| **Shortcut**   | `addConditionEq(field, value)`                  | `field = value`                                           |
| **Shortcut**   | `addConditionNe(field, value)`                  | `field != value`                                          |
| **Shortcut**   | `addConditionIn(field, value)`                  | `field IN :iterable` or `field IN (subquery)`             |
| **Shortcut**   | `addConditionNotIn(field, value)`               | `field NOT IN :iterable` or `field NOT IN (subquery)`     |
| **Identity**   | `byId(Id)` / `byIds(Iterable<Id>)`              | `Id = :id` or `Id IN :ids`                                |

**Available Operators (via `SoqlQuery.COND`):**

| Operator    | Method                     | Description                                |
| :---------- | :------------------------- | :----------------------------------------- |
| `=`         | `eq(val)`                  | Equals.                                    |
| `!=`        | `ne(val)`                  | Not Equals.                                |
| `>` / `<`   | `gt(val)` / `lt(val)`      | Greater / Less than.                       |
| `>=` / `<=` | `ge(val)` / `le(val)`      | Greater or Equal / Less or Equal.          |
| `LIKE`      | `likex(val)`               | Partial match (supports `%`).              |
| `IN`        | `inx(iterable/subquery)`   | Value in a list or semi-join subquery.     |
| `NOT IN`    | `notIn(iterable/subquery)` | Value not in a list or anti-join subquery. |
| `INCLUDES`  | `includes(iterable)`       | Multiselect picklist contains any.         |
| `EXCLUDES`  | `excludes(iterable)`       | Multiselect picklist contains none.        |

#### Condition Builder (`SoqlQuery.COND`)

Factory for advanced `WHERE` logic. Returns a fluent `Condition` object.

**Selection:** `id()`, `field(field)`.

**Operators:** `eq(value)`, `ne(value)`, `gt(value)`, `ge(value)`, `lt(value)`, `le(value)`, `likex(value)`.

**Collections:** `inx(iterable/subquery)`, `notIn(iterable/subquery)`, `includes(iterable)`, `excludes(iterable)`.

**Logical:** `isNull()`, `isNotNull()`, `isTrue()`, `isFalse()`.

**Chaining:** `add(cond)`, `addAnd(cond)`, `addOr(cond)`, `notx()`.

### Logical Junctions

Group conditions with `SoqlQuery.ands()`, `ors()`, and `notx()` for precedence.

```apex
q.addCondition(
    SoqlQuery.ors(
        SoqlQuery.COND.field('Rating').eq('Hot'),
        SoqlQuery.ands(
            SoqlQuery.COND.field('Type').eq('VIP'),
            SoqlQuery.COND.field('IsActive').isTrue()
        )
    )
);
// WHERE (Rating = 'Hot' OR (Type = 'VIP' AND IsActive = TRUE))

q.addCondition(SoqlQuery.notx(SoqlQuery.COND.field('Name').likex('Test%')));
// WHERE (NOT Name LIKE 'Test%')
```

### Grouping

Group rows using standard or advanced rollup/cube syntax.

```apex
// Standard Grouping
q.groupBy(Account.Industry);
// GROUP BY Industry

// Advanced Grouping (Rollup/Cube)
q.groupByRollup(new List<SObjectField>{ Opportunity.StageName, Opportunity.Type });
// GROUP BY ROLLUP(StageName, Type)
```

**Available Grouping Methods:**

| Method                   | Description                                                            |
| :----------------------- | :--------------------------------------------------------------------- |
| `groupBy(field/s)`       | Standard `GROUP BY`. Supports `SObjectField`, `String`, or `Iterable`. |
| `groupByRollup(field/s)` | Aggregates with `ROLLUP` for subtotals and grand totals.               |
| `groupByCube(field/s)`   | Aggregates with `CUBE` for cross-tabulation of all combinations.       |

### Having

Apply logical filters to aggregated results.

```apex
q.groupBy(Account.Industry)
 .havingx(SoqlQuery.HAV.count('Id').gt(10));
// GROUP BY Industry HAVING COUNT(Id) > 10
```

**Selection vs. Chaining:**

| Method             | Behavior                                   | Use Case                                                    |
| :----------------- | :----------------------------------------- | :---------------------------------------------------------- |
| `havingx(...)`     | **Replaces** entire HAVING clause.         | When you want to reset or set the primary aggregate filter. |
| `addHaving*(...)`  | **Appends** to existing filters via `AND`. | When adding multiple aggregate filters incrementally.       |
| `addHavingOr(...)` | **Appends** to existing filters via `OR`.  | For simple logical branching in aggregates.                 |

**Available Having Methods:**

| Category       | Method                                        | Description                                              |
| :------------- | :-------------------------------------------- | :------------------------------------------------------- |
| **Criterion**  | `addHaving(Criterion)` / `havingx(Criterion)` | Accepts a pre-built `SoqlQuery.HAV` or `ands()`/`ors()`. |
| **Raw String** | `addHaving(String)` / `havingx(String)`       | Direct injection of raw HAVING snippets.                 |
| **Shortcut**   | `addHavingEq(field, value)`                   | `field = value` (typically used with aggregates).        |
| **Shortcut**   | `addHavingNe(field, value)`                   | `field != value`                                         |
| **Shortcut**   | `addHavingIn(field, iterable)`                | `field IN :iterable`                                     |
| **Shortcut**   | `addHavingNotIn(field, iterable)`             | `field NOT IN :iterable`                                 |

#### Having Builder (`SoqlQuery.HAV`)

Factory for `HAVING` clause aggregate filters. Returns a fluent `HavingCondition` object.

| Method                 | Description                                         |
| :--------------------- | :-------------------------------------------------- |
| `avg(field)`           | Applies `AVG()` to the aggregate filter.            |
| `count(field)`         | Applies `COUNT()` to the aggregate filter.          |
| `countDistinct(field)` | Applies `COUNT_DISTINCT()` to the aggregate filter. |
| `min(field)`           | Applies `MIN()` to the aggregate filter.            |
| `max(field)`           | Applies `MAX()` to the aggregate filter.            |
| `sum(field)`           | Applies `SUM()` to the aggregate filter.            |

### Ordering

Sort query results with specific null placement control.

```apex
// Sorting with Null Control
q.orderBy(Account.Name, Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST);
// ORDER BY Name DESC NULLS LAST

// Simple Sorting
q.orderBy(Account.CreatedDate);
// ORDER BY CreatedDate
```

**Available Ordering Methods:**

| Method                                      | Description                                                                                                                   |
| :------------------------------------------ | :---------------------------------------------------------------------------------------------------------------------------- |
| `orderBy(field)`                            | Standard `ORDER BY`. Default is `ASC`.                                                                                        |
| `orderBy(field, [sortOrder, [nullsOrder]])` | Sort using `Query.SortOrder` (`ASCX` or `DESCX`) and precise control with `Query.NullsOrder` (`NULLS_FIRST` or `NULLS_LAST`). |

### Paging

Control query volume and result offsets.

```apex
q.lim(50)
 .offset(100);
// LIMIT 50 OFFSET 100
```

**Available Paging Methods:**

| Method          | Description              |
| :-------------- | :----------------------- |
| `lim(count)`    | Sets the query `LIMIT`.  |
| `offset(count)` | Sets the query `OFFSET`. |

### Other

Support for specialized SOQL clauses and tracking options.

```apex
q.forView()
 .updateTracking();
// FOR VIEW UPDATE TRACKING

q.allRows();
// ALL ROWS
```

**Available Options:**

| Method             | Description                 |
| :----------------- | :-------------------------- |
| `forView()`        | Standard `FOR VIEW`.        |
| `forReference()`   | Standard `FOR REFERENCE`.   |
| `forUpdate()`      | Standard `FOR UPDATE`.      |
| `updateTracking()` | Standard `UPDATE TRACKING`. |
| `updateViewstat()` | Standard `UPDATE VIEWSTAT`. |
| `allRows()`        | Standard `ALL ROWS`.        |

### Security & Privacy

Control the execution mode and sharing policies. By default, queries run in **User Mode** and use **Inherited Sharing**.

```apex
// Enforcing User Mode and sharing (Default)
q.withUserMode()
 .withSharing();

// Elevated Privileges (System Mode)
q.withSystemMode()
 .withoutSharing();

// Field-level stripping
q.withStrip(AccessType.READABLE);
```

**Available Security Methods:**

| Method                      | Description                                                                                             |
| :-------------------------- | :------------------------------------------------------------------------------------------------------ |
| `withUserMode()`            | Executes in User Mode (CRUD/FLS) (**Default**). Implies `with sharing`.                                 |
| `withSystemMode()`          | Executes in System Mode (CRUD/FLS).                                                                     |
| `withSharing()`             | Forces the class to respect sharing model.                                                              |
| `withoutSharing()`          | Forces the class to ignore sharing model.                                                               |
| `inheritedSharing()`        | Inherits sharing from the caller (**Default**).                                                         |
| `withPermissionSetId(id)`   | Restricts query permissions to a specific Permission Set in addition to the running user's permissions. |
| `withPermissionSetIds(ids)` | Restricts query permissions to multiple Permission Sets in addition to the running user's permissions.  |
| `withStrip(accessLevel)`    | Applies `Security.stripInaccessible` (CRUD/FLS) to the results.                                         |

### Caching

Utilize multi-tier caching to optimize performance.

**Available Caching Methods:**

| Method                           | Description                                           |
| :------------------------------- | :---------------------------------------------------- |
| `memoize()`                      | Static transaction-scoped cache.                      |
| `cacheSession(partition, [ttl])` | Platform Cache (Session) with optional TTL (seconds). |
| `cacheOrg(partition, [ttl])`     | Platform Cache (Org) with optional TTL (seconds).     |

```apex
// Cache results across the current session
q.cacheSession('local.myPartition').fetch();

// Share results across all users (Requires System Mode)
q.withSystemMode()
 .cacheOrg('local.myPartition')
 .fetch();
```

> [!IMPORTANT]
> **Security Limitation**: `cacheOrg` is only active when running in `withSystemMode()`. In `withUserMode()` (default), Org Cache is bypassed to prevent cross-user data leakage.

### Execution Drivers

The `SoqlQuery` builder decouples the logical query structure from the physical execution mechanism using a **Driver-Pattern**. This allows the same DSL to execute against the local database, remote orgs via REST, or specialized big-data engines.

#### 1. Database Driver (Default)

Executes queries within the current Salesforce org using native `Database` methods. It is optimized for performance and respects the transaction's security context.

- **Mechanics**: Utilizes `Database.queryWithBinds` to support secure, dynamic binding.
- **Sharing Models**:
    - `withSharing()`: Enforces the sharing model.
    - `withoutSharing()`: Bypasses the sharing model.
    - `inheritedSharing()`: Inherits sharing from the caller (**Default**).

#### 2. REST Driver

Executes queries against a remote Salesforce org via the REST API. This is ideal for cross-org integrations or secondary data sources.

> [!TIP]
> **Self-Querying**: You can use the REST Driver to query the **local org** (the "self" org) by using a Named Credential that points back to the same instance. This is highly useful for:
>
> - **Tooling API Queries**: Fetching metadata or running queries not available in standard SOQL (e.g., `ValidationRule`, `ApexClass`).
> - **Bypassing SOQL Limits**: Leveraging REST endpoints (like `/composite/sobjects`) to handle large ID lists or specific query shapes that might hit local character limits or governor constraints.
> - **Asynchronous Scale**: Using the Bulk V2 engine for large data exports without consuming standard transaction heap.
> - **Query Plans (Explain)**: Obtaining a query plan for performance analysis via the `/query/?explain` resource.

- **Setup**: Requires a **Named Credential** to handle authentication and endpoint resolution.
- **Security Constraint**: Always executes in `USER_MODE`. Attempting to use `withSystemMode()` will throw an exception.

```apex
// Explicitly using a REST Driver
SoqlQuery.of('Account')
    .useRestDriver('RemoteOrgNC') // Named Credential
    .field('Name')
    .fetch();
```

#### 3. Rest Engines

The `RestDriver` uses pluggable **Engines** to handle different query scales and requirements.

| Engine                    | Resource               | Best For         | Key Specifics                                                                              |
| :------------------------ | :--------------------- | :--------------- | :----------------------------------------------------------------------------------------- |
| **QueryEngine** (Default) | `/query` / `/queryAll` | Standard SOQL    | Supports `Tooling API`, parent-child subqueries, and `batchSize` tuning.                   |
| **SObject Collections**   | `/composite/sobjects`  | ID Lookups       | Optimized for fetching multiple records by ID (up to 2000). No subquery support.           |
| **Bulk V2 Query**         | `/jobs/query`          | Massive Datasets | Asynchronous execution via Bulk API 2.0. Handles polling and CSV projection automatically. |

```apex
// Optimizing REST for ID lookups (avoids SOQL string length limits)
SoqlQuery q = SoqlQuery.of('Account')
    .useRestDriver('MyNC')
    .useEngine(new SoqlQuery.SObjectCollectionsEngine())
    .field('Name')
    .addConditionIn('Id', accountIds);
```

#### 4. Engine Tuning & Orchestration

Each execution engine provides granular control over the REST transport layer to optimize for throughput, heap usage, or governor limit consumption.

##### QueryEngine (Standard REST)

Optimized for standard SOQL and Tooling API requests.

- `setBatchSize(Integer)`: Requested row count per page (sets `Sforce-Query-Options: batchSize`).
- `setQueryMore(Boolean)`: Enables/disables automatic continuation fetching (default: `false`).
- `setChunkSize(Integer)`: Number of continuation URLs packed into one transport wave (default: `25`).
- `useQueryMoreEngine(QueryMoreEngine)`: Sets hydration transport (`COMPOSITE_BATCH`, `COMPOSITE`, or `QUERY`).
- `useTooling(Boolean)`: Switches between `/query` and `/tooling/query` resources.

##### SObjectCollectionsEngine (ID Bundling)

Optimized for fetching thousands of records by ID without hitting SOQL character limits.

- `setChunkSize(Integer)`: Number of IDs processed per `POST` request (default: `2000`).

##### BulkV2QueryEngine (Asynchronous Scale)

Handles massive data exports via Bulk API 2.0 with automated polling and projection.

- `setPollInterval(Integer)`: Milliseconds to wait between job status checks (default: `1000`).
- `setCpuTimeout(Integer)`: CPU guard threshold for the polling loop.
- `setMaxRecords(Integer)`: Result record count per CSV page.
- `setQueryMore(Boolean)`: Follows record locators to fetch all result pages (default: `false`).

---

#### 5. QueryMore & Hydration

When handling large result sets or complex subquery trees via REST, the driver employs a **Unified Wave Hydration** strategy to ensure all related data is fetched using one of the following transport protocols:

- `COMPOSITE_BATCH` (Default): Efficiently packs up to 25 continuation URLs into one batch call.
- `COMPOSITE`: Standard composite bundling (up to 5 requests).
- `QUERY`: Sequential fetching of continuation URLs (guarantees order but slower).

```apex
// Deeply tuned REST execution for high-volume hydration
SoqlQuery.RestDriver driver = new SoqlQuery.RestDriver('MyNC');
driver.useEngine(
    new SoqlQuery.QueryEngine()
        .setQueryMore(true)
        .setChunkSize(25)
        .useQueryMoreEngine(SoqlQuery.QueryMoreEngine.COMPOSITE_BATCH)
);

q.useDriver(driver).fetchLazy();
```

---

### Terminal Execution API

Common execution methods available across all query types.

```apex
// 1. Standard list fetch
List<Account> accounts = SoqlQuery.of('Account').field('Name').fetch();

// 2. Fetch first record with null safety
Account first = (Account) SoqlQuery.of('Account').field('Name').fetchFirst();

// 3. Project results into a custom DTO list
List<AccountDto> dtos = (List<AccountDto>) SoqlQuery.of('Account')
    .field('Name')
    .fetchInto(List<AccountDto>.class);
```

**DTO Field Normalization (`__` -> `_`)**

When projecting into a typed DTO (`fetchInto(...)`, `fetchFirstAs(...)`), column/alias keys are normalized:

- `Custom__c` -> `Custom_c`
- `ns__CreatedDate__c` -> `ns_CreatedDate_c`

This helps map names to valid Apex DTO field names.

```apex
public class AccountDto {
    public String Custom_c;
}
```

If you need to preserve original field/alias names exactly (including `__`), use an untyped projection:

```apex
List<Map<String, Object>> rows = (List<Map<String, Object>>) SoqlQuery.of('Account')
    .field('Custom__c')
    .fetchInto(List<Map<String, Object>>.class); // no key normalization
```

| Method                     | Returns                     | Description                                                      |
| :------------------------- | :-------------------------- | :--------------------------------------------------------------- |
| `fetch()`                  | `List<SObject>`             | Executes the query and returns all rows.                         |
| `fetchFirst()`             | `SObject`                   | Returns the first record or null.                                |
| `fetchCount()`             | `Integer`                   | Executes a `COUNT()` variant of the query.                       |
| `fetchInto(Type listType)` | `List<T>`                   | Projects into typed DTO/SObject; DTO keys normalize `__` to `_`. |
| `fetchLazy()`              | `Iterable<SObject>`         | Returns an iterator for chunked/lazy processing.                 |
| `locator()`                | `Database.QueryLocator`     | Returns a locator for Batch Apex.                                |
| `cursor()`                 | `Database.Cursor`           | Returns an Apex Cursor for high-volume processing.               |
| `paginationCursor()`       | `Database.PaginationCursor` | Returns a Pagination Cursor for stateful UI paging.              |
| `explain()`                | `Object`                    | Returns Query Plans (REST Driver only).                          |

### Introspection & Debugging

Inspect the built query state, bindings, and execution performance.

```apex
SoqlQuery q = SoqlQuery.of('Account')
    .field('Name')
    .addConditionEq('Type', 'Customer')
    .useTimer()
    .debug();

System.debug(q.toString()); // SELECT Name FROM Account WHERE Type = :var$0
System.debug(q.getBindings()); // { var$0=Customer }
System.debug(q.toInlineString()); // SELECT Name FROM Account WHERE Type = 'Customer'

q.fetch();
// db.run: SELECT Name FROM Account WHERE Type = :var$0
// {
//   "var$0" : "Customer"
// }
// db.run duration: 8ms
```

| Method                  | Description                                                                |
| :---------------------- | :------------------------------------------------------------------------- |
| `debug()`               | Enables logging of generated SOQL and execution stats to the debug log.    |
| `useTimer([mode])`      | Enables execution timing (`Query.Timer.CPU` (**Default**) or `SYS`).       |
| `toString()`            | Returns the compiled SOQL string with bind variables (e.g., `:var1`).      |
| `toInlineString()`      | Returns the compiled SOQL string with all binds formatted as literals.     |
| `toCountString()`       | Returns the `SELECT COUNT()` variant of the current query string.          |
| `toInlineCountString()` | Returns the `SELECT COUNT()` variant with all binds formatted as literals. |
| `getBindings()`         | Returns the current map of bind variables and their values.                |

---

## SQL Usage

### Initialization

Initialize ANSI SQL builders using `SqlQuery`, or use dialect-specialized builders for PostgreSQL/MySQL behavior.

```apex
SqlQuery q1 = SqlQuery.of('orders');
// SELECT * FROM orders

SqlQuery q2 = SqlQuery.of('orders', 'o');
// SELECT * FROM orders o

PostgresSqlQuery pg = PostgresSqlQuery.of('orders', 'o');
// SELECT * FROM orders o

MySqlQuery my = MySqlQuery.of('orders', 'o');
// SELECT * FROM orders o
```

**Available Initialization Methods:**

| Method                      | Description                                                    |
| :-------------------------- | :------------------------------------------------------------- |
| `SqlQuery.of(table)`        | Creates a SQL builder for a table.                             |
| `SqlQuery.of(table, alias)` | Creates a SQL builder with table alias.                        |
| `new SqlQuery(...)`         | Constructor alternative for `SqlQuery`.                        |
| `PostgresSqlQuery.of(...)`  | PostgreSQL builder (default indexed bindings like `$1`, `$2`). |
| `MySqlQuery.of(...)`        | MySQL builder (default anonymous bindings like `?`).           |
| `useBindingStrategy(...)`   | Overrides placeholder style (`NAMED`, `INDEXED`, `ANONYMOUS`). |

> [!NOTE]
> Binding defaults are dialect-specific:
>
> - `SqlQuery`: `NAMED` (`:var$0`)
> - `PostgresSqlQuery`: `INDEXED` (`$1`)
> - `MySqlQuery`: `ANONYMOUS` (`?`)

### Select

Build projections with fields, aliases, and `DISTINCT`.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .distinct().field('o.id')
    .field('o.customer_id', 'customer_id')
    .fields('o.created_at, o.status');
// SELECT DISTINCT o.id, o.customer_id customer_id, o.created_at, o.status FROM orders o
```

**Available Selection Methods:**

| Method                  | Description                                |
| :---------------------- | :----------------------------------------- |
| `distinct()`            | Adds `DISTINCT` to the select list         |
| `field(field, [alias])` | Adds one selected expression/column        |
| `fields(iterable/csv)`  | Adds multiple selected expressions/columns |
| `allFields()`           | Shortcut for `*`                           |

### Aggregates

Build aggregate projections with aliases and grouping helpers.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.customer_id')
    .countAll('row_count')
    .sum('o.total_amount', 'revenue')
    .avg('o.total_amount', 'avg_revenue')
    .grouping('o.customer_id', 'is_grouped');
```

**Available Aggregate Methods:**

| Method                          | Description                           |
| :------------------------------ | :------------------------------------ |
| `countAll([alias])`             | Adds `COUNT(*)`                       |
| `count(field, [alias])`         | Adds `COUNT(field)`                   |
| `countDistinct(field, [alias])` | Adds `COUNT(DISTINCT field)`          |
| `sum(field, [alias])`           | Adds `SUM(field)`                     |
| `avg(field, [alias])`           | Adds `AVG(field)`                     |
| `min(field, [alias])`           | Adds `MIN(field)`                     |
| `max(field, [alias])`           | Adds `MAX(field)`                     |
| `grouping(field, [alias])`      | Adds SQL `GROUPING(field)` expression |

> [!NOTE]
> Aggregate methods support optional aliases

### Joins

Join tables using ANSI join types with `ON`, `USING`, or `NATURAL` modifiers.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .field('c.name', 'customer_name')
    .innerJoin('customers', 'c').onEq('o.customer_id', 'c.id')
    .leftJoin('regions', 'r').usingx('region_id');
// SELECT o.id, c.name customer_name FROM orders o INNER JOIN customers c ON o.customer_id = c.id LEFT JOIN regions r USING (region_id)
```

**Available Join Methods:**

| Method                         | Description                               |
| :----------------------------- | :---------------------------------------- |
| `join(...)` / `innerJoin(...)` | Adds `INNER JOIN`.                        |
| `leftJoin(...)`                | Adds `LEFT JOIN`.                         |
| `rightJoin(...)`               | Adds `RIGHT JOIN`.                        |
| `fullJoin(...)`                | Adds `FULL JOIN`.                         |
| `crossJoin(...)`               | Adds `CROSS JOIN`.                        |
| `onx(condition)`               | Sets `ON` condition for the latest join.  |
| `onEq(leftField, rightField)`  | Shortcut for `ON leftField = rightField`. |
| `usingx(column/list)`          | Sets `USING (...)` for the latest join.   |
| `natural()`                    | Marks the latest join as `NATURAL`.       |

> [!NOTE]
> Support for `RIGHT`, `FULL`, or `CROSS` joins depends on the backend SQL engine.

### Filtering

Compose `WHERE` predicates using either raw SQL strings or type-safe condition objects.

```apex
SqlQuery activeCustomers = SqlQuery.of('customers', 'c')
    .field('c.id')
    .wherex(new SqlQuery.Condition().field('c.status').eq('active'));
// SELECT c.id FROM customers c WHERE c.status = 'active'

SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .addConditionEq('o.channel', 'web')
    .addConditionIn('o.customer_id', activeCustomers)
    .addCondition(SqlQuery.notx(new SqlQuery.Condition().field('o.is_deleted').isTrue()));
// SELECT o.id FROM orders o WHERE o.channel = 'web' AND o.customer_id IN (SELECT c.id FROM customers c WHERE c.status = 'active') AND (NOT o.is_deleted = TRUE)
```

**Available Filtering Methods:**

| Method                            | Description                                           |
| :-------------------------------- | :---------------------------------------------------- |
| `wherex(Criterion/String)`        | Replaces the whole `WHERE` clause.                    |
| `addCondition*(...)`              | Appends conditions (`AND`/`OR`, eq/ne/in/notIn, etc). |
| `byId(id)` / `byIds(ids)`         | Identity shortcuts (`id = ...`, `id IN (...)`).       |
| `SqlQuery.ands/ors/notx(...)`     | Explicit Boolean grouping and precedence control.     |
| `SqlQuery.exists(subquery)`       | `EXISTS (subquery)` predicate.                        |
| `SqlQuery.any/some/all(subquery)` | Subquery comparison wrappers (`ANY`, `SOME`, `ALL`).  |

> [!NOTE]
> Use `SqlQuery.literal(...)` when you need raw SQL expressions instead of quoted values.
>
> ```apex
> SqlQuery q = SqlQuery.of('orders', 'o')
>     .field('o.id')
>     .addConditionEq('o.created_by', SqlQuery.literal('o.updated_by'));
> // SELECT o.id FROM orders o WHERE o.created_by = o.updated_by
> ```

### Grouping

Aggregate grouped data with standard and advanced grouping elements (`ROLLUP`, `CUBE`, `GROUPING SETS`).

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.region')
    .sum('o.total_amount', 'revenue')
    .groupBy('o.region')
    .groupByRollup(new List<Object>{ 'o.sales_rep_id', 'o.channel' });
// SELECT o.region, SUM(o.total_amount) revenue FROM orders o GROUP BY o.region, ROLLUP (o.sales_rep_id, o.channel)

SqlQuery q2 = SqlQuery.of('orders', 'o')
    .field('o.region')
    .field('o.channel')
    .sum('o.total_amount', 'revenue')
    .groupByGroupingSets(new List<Object>{
        new List<Object>{ 'o.region' },
        new List<Object>{ 'o.channel' },
        '()'
    });
// SELECT o.region, o.channel, SUM(o.total_amount) revenue FROM orders o GROUP BY GROUPING SETS ((o.region), (o.channel), ())
```

**Available Grouping Methods:**

| Method                          | Description                   |
| :------------------------------ | :---------------------------- |
| `groupBy(element/list)`         | Standard `GROUP BY`           |
| `groupByRollup(element/list)`   | `GROUP BY ROLLUP(...)`        |
| `groupByCube(element/list)`     | `GROUP BY CUBE(...)`          |
| `groupByGroupingSets(elements)` | `GROUP BY GROUPING SETS(...)` |

### Having

Filter grouped results with `HAVING` conditions and fluent condition builders.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.region')
    .sum('o.total_amount', 'revenue')
    .groupBy('o.region')
    .havingx(new SqlQuery.HavingCondition().sum('o.total_amount').gt(100000));
// SELECT o.region, SUM(o.total_amount) revenue FROM orders o GROUP BY o.region HAVING SUM(o.total_amount) > 100000
```

**Available Having Methods:**

| Method                        | Description                             |
| :---------------------------- | :-------------------------------------- |
| `havingx(Criterion/String)`   | Replaces the whole `HAVING` clause      |
| `addHaving*(...)`             | Appends additional `HAVING` predicates  |
| `addHavingEq` / `addHavingIn` | Shortcut predicates for grouped results |

### Set Operators

Combine multiple query builders using ANSI set operators.

```apex
SqlQuery us = SqlQuery.of('us_orders').field('customer_id');
SqlQuery eu = SqlQuery.of('eu_orders').field('customer_id');

SqlQuery combined = us.unionAll(eu);
// SELECT customer_id FROM us_orders UNION ALL SELECT customer_id FROM eu_orders
```

**Available Set Operators:**

| Method                | Description     |
| :-------------------- | :-------------- |
| `union(other)`        | `UNION`         |
| `unionAll(other)`     | `UNION ALL`     |
| `intersect(other)`    | `INTERSECT`     |
| `intersectAll(other)` | `INTERSECT ALL` |
| `except(other)`       | `EXCEPT`        |
| `exceptAll(other)`    | `EXCEPT ALL`    |

### CTEs

Use Common Table Expressions (CTEs) with `WITH` to modularize large statements and reuse intermediate query results.

```apex
SqlQuery topCustomers = SqlQuery.of('orders')
    .field('customer_id')
    .sum('total_amount', 'revenue')
    .groupBy('customer_id');

SqlQuery q = SqlQuery.of('customers', 'c')
    .with('top_customers', topCustomers)
    .field('c.id')
    .field('tc.revenue')
    .innerJoin('top_customers', 'tc')
    .onx('c.id = tc.customer_id');
// WITH top_customers AS (SELECT customer_id, SUM(total_amount) revenue FROM orders GROUP BY customer_id)
// SELECT c.id, tc.revenue FROM customers c INNER JOIN top_customers tc ON c.id = tc.customer_id
```

**Available CTE Methods:**

| Method                 | Description      |
| :--------------------- | :--------------- |
| `with(name, subquery)` | Adds a named CTE |

### VALUES

Use `VALUES` to embed virtual rows inline and treat them as a queryable table source.

```apex
SqlQuery seed = SqlQuery.of('stub')
    .values(
        new List<List<Object>>{
            new List<Object>{ 'A', 1 },
            new List<Object>{ 'B', 2 }
        },
        'v',
        new List<String>{ 'code', 'score' }
    );
// SELECT * FROM (VALUES ('A', 1), ('B', 2)) AS v(code, score)
```

**Available VALUES Methods:**

| Method                         | Description                                       |
| :----------------------------- | :------------------------------------------------ |
| `values(rows, alias, columns)` | Adds `VALUES (...) AS alias(col1, ...)` as source |

### CASE

Build conditional expressions with simple and searched `CASE` syntax.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .field(
        SqlQuery.CASEX.match('o.status')
            .when('paid').then('closed')
            .when('pending').then('open')
            .elsex('other')
            .end(),
        'status_group'
    );
// SELECT o.id, CASE o.status WHEN 'paid' THEN 'closed' WHEN 'pending' THEN 'open' ELSE 'other' END status_group FROM orders o
```

**Available CASE Methods:**

| Method                                                | Description                                  |
| :---------------------------------------------------- | :------------------------------------------- |
| `SqlQuery.CASEX.match(field)`                         | Starts simple `CASE field WHEN ... THEN ...` |
| `SqlQuery.CASEX.when(condition)`                      | Starts searched `CASE WHEN ... THEN ...`     |
| `SqlQuery.CASEX.when(...).then(...).elsex(...).end()` | Completes the `CASE` expression              |

### Window Functions

Build analytical SQL with partitioned/windowed calculations.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .field(
        SqlQuery.WIN.rowNumber()
            .partitionBy('o.customer_id')
            .orderBy('o.created_at', Query.SortOrder.DESCX),
        'row_num'
    )
    .field(
        SqlQuery.WIN.sum('o.total_amount')
            .partitionBy('o.customer_id')
            .orderBy('o.created_at')
            .rowsBetween('UNBOUNDED PRECEDING', 'CURRENT ROW'),
        'running_total'
    );
// SELECT
//   o.id,
//   ROW_NUMBER() OVER (PARTITION BY o.customer_id ORDER BY o.created_at DESC) row_num,
//   SUM(o.total_amount) OVER (
//     PARTITION BY o.customer_id ORDER BY o.created_at ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
//   ) running_total
//   FROM orders o
```

**Available Window Methods:**

| Method                                            | Description                              |
| :------------------------------------------------ | :--------------------------------------- |
| `SqlQuery.WIN.rowNumber/rank/denseRank()`         | Ranking window functions                 |
| `SqlQuery.WIN.lead/lag/firstValue/lastValue(...)` | Value-access window functions            |
| `SqlQuery.WIN.ntile(n)` / `nthValue(expr, n)`     | Bucketing and nth-value window functions |
| `partitionBy(...)`, `orderBy(...)`                | Window partitioning and ordering         |
| `rowsBetween(...)`, `rangeBetween(...)`           | Window frame definitions                 |

### Ordering

Control result sort order with direction and null placement.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .orderBy('o.created_at', Query.SortOrder.DESCX, Query.NullsOrder.NULLS_LAST);
// SELECT o.id FROM orders o ORDER BY o.created_at DESC NULLS LAST
```

**Available Ordering Methods:**

| Method                                    | Description                                    |
| :---------------------------------------- | :--------------------------------------------- |
| `orderBy(field)`                          | Adds `ORDER BY field ASC`                      |
| `orderBy(field, sortOrder, [nullsOrder])` | Adds ordered sort with explicit null placement |

### Row Limiting

Control page size/offset and SQL:2008 row limiting clauses.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .lim(50)
    .offset(100);
// SELECT o.id FROM orders o LIMIT 50 OFFSET 100

SqlQuery q2 = SqlQuery.of('orders')
    .fetchFirstWithTies(10);
// SELECT * FROM orders FETCH FIRST 10 ROWS WITH TIES
```

**Available Row Limiting Methods:**

| Method                      | Description                         |
| :-------------------------- | :---------------------------------- |
| `lim(count)`                | Adds `LIMIT`                        |
| `offset(count)`             | Adds `OFFSET`                       |
| `fetchFirst(count)`         | Adds `FETCH FIRST n ROWS ONLY`      |
| `fetchFirstWithTies(count)` | Adds `FETCH FIRST n ROWS WITH TIES` |
| `fetchNext(count)`          | Adds `FETCH NEXT n ROWS ONLY`       |
| `fetchNextWithTies(count)`  | Adds `FETCH NEXT n ROWS WITH TIES`  |

> [!NOTE]
> `FETCH FIRST/NEXT` support is backend-dependent and some engines accept only `LIMIT/OFFSET`

### Dialect Extensions

Use PostgreSQL and MySQL subclasses for engine-specific SQL features while keeping the same fluent model.

```apex
PostgresSqlQuery pg = (PostgresSqlQuery) PostgresSqlQuery.of('weather_reports')
    .distinctOn('location').field('location')
    .field('time')
    .orderBy('location')
    .orderBy('time', Query.SortOrder.DESCX);
// SELECT DISTINCT ON (location) location, time FROM weather_reports ORDER BY location, time DESC

PostgresSqlQuery lateralSub = (PostgresSqlQuery) PostgresSqlQuery.of('line_items', 'li')
    .field('li.amount')
    .wherex(new SqlQuery.Condition().field('li.order_id').eq(SqlQuery.literal('o.id')))
    .orderBy('li.amount', Query.SortOrder.DESCX)
    .lim(1);

PostgresSqlQuery pgLateral = (PostgresSqlQuery) PostgresSqlQuery.of('orders', 'o')
    .leftJoinLateral(lateralSub, 'li_last').onx('TRUE')
    .field('o.id')
    .field('li_last.amount', 'last_amount');

// SELECT o.id, li_last.amount last_amount
// FROM orders o LEFT JOIN LATERAL (
//     SELECT li.amount FROM line_items li WHERE li.order_id = o.id ORDER BY li.amount DESC LIMIT 1
// ) li_last ON TRUE

MySqlQuery my = (MySqlQuery) MySqlQuery.of('users')
    .field(MySqlQuery.groupConcat(SqlQuery.literal('role')), 'roles')
    .wherex(new MySqlQuery.Condition().mySqlField('email').regexp('.*@gmail.com'));
// SELECT GROUP_CONCAT(role) roles FROM users WHERE email REGEXP '.*@gmail.com'
```

**Dialect-Specific APIs:**

| Dialect    | Method / Feature                                                | Description                       |
| :--------- | :-------------------------------------------------------------- | :-------------------------------- |
| PostgreSQL | `distinctOn(expr/list)`                                         | Adds `DISTINCT ON (...)`.         |
| PostgreSQL | `joinLateral/innerJoinLateral/leftJoinLateral/crossJoinLateral` | Adds `LATERAL` joins.             |
| PostgreSQL | `PostgresSqlQuery.castColon(value, type)`                       | Produces `value::type`.           |
| PostgreSQL | `Condition.iLike/regex/...`                                     | PostgreSQL comparison operators.  |
| MySQL      | `MySqlQuery.groupConcat(...)`                                   | `GROUP_CONCAT` expression helper. |
| MySQL      | `MySqlQuery.dateFormat(...)`                                    | `DATE_FORMAT` expression helper.  |
| MySQL      | `MySqlQuery.jsonExtract(...)`                                   | `JSON_EXTRACT` expression helper. |
| MySQL      | `Condition.regexp/notRegexp/nullSafeEq(...)`                    | MySQL comparison operators.       |

### Execution and Terminal Operations

`SqlQuery` is execution-agnostic. Attach a `SqlQuery.Driver` implementation to execute queries.

```apex
public class DemoSqlDriver implements SqlQuery.Driver {
    public List<Object> run(SqlQuery.QueryArgs args) { return new List<Object>(); }
    public Integer count(SqlQuery.QueryArgs args) { return 0; }
    public Object explain(SqlQuery.QueryArgs args) { return null; }
}

SqlQuery q = SqlQuery.of('orders').field('id').useDriver(new DemoSqlDriver());
List<Object> rows = q.fetch();
Integer total = q.fetchCount();
```

**Available Execution Methods:**

| Method                           | Returns        | Description                                               |
| :------------------------------- | :------------- | :-------------------------------------------------------- |
| `useDriver(driver)`              | `SqlQuery`     | Assigns execution driver (`run`, `count`, `explain`)      |
| `fetch()`                        | `List<Object>` | Executes and returns rows as untyped records.             |
| `fetchInto(Type listType)`       | `List<T>`      | Projects rows into DTO or untyped map/object targets.     |
| `fetchFirst()`                   | `Object`       | Returns first row or `null`.                              |
| `fetchFirstAs(Type elementType)` | `T`            | Returns first row projected to a target type or `null`.   |
| `fetchCount()`                   | `Integer`      | Executes count path via driver.                           |
| `explain()`                      | `Object`       | Executes explain path if supported by the driver/backend. |

> [!NOTE]
> Typed DTO projection normalizes keys by replacing `__` with `_`.
> Use untyped map/object targets to preserve original field/alias names exactly.

> [!IMPORTANT]
> Calling terminal methods without `useDriver(...)` throws `QueryException`.

### Introspection and Debugging

Inspect generated SQL and runtime bindings exactly as sent to the driver.

```apex
SqlQuery q = SqlQuery.of('orders', 'o')
    .field('o.id')
    .addConditionEq('o.channel', 'web')
    .useTimer()
    .debug();

System.debug(q.toString());        // SELECT o.id FROM orders o WHERE o.channel = :var$0
System.debug(q.toInlineString());  // SELECT o.id FROM orders o WHERE o.channel = 'web'
System.debug(q.toCountString());   // SELECT COUNT(*) FROM orders o WHERE o.channel = :var$0
System.debug(q.toInlineCountString()); // SELECT COUNT(*) FROM orders o WHERE o.channel = 'web'
System.debug(q.getBindings());         // { "var$0" : "web" }
```

**Available Introspection Methods:**

| Method                  | Description                                             |
| :---------------------- | :------------------------------------------------------ |
| `debug()`               | Enables query/request debug logging.                    |
| `useTimer([mode])`      | Enables timing metrics (`CPU` or `SYS`).                |
| `toString()`            | Returns SQL with bind placeholders.                     |
| `toInlineString()`      | Returns SQL with inline formatted literal values.       |
| `toCountString()`       | Returns generated `COUNT(*)` SQL.                       |
| `toInlineCountString()` | Returns generated inline `COUNT(*)` SQL.                |
| `getBindings()`         | Returns current binding map used by the query/compiler. |

---

## CDP Query Usage

`CdpSqlQuery` is the Data 360 (formerly Data Cloud) provider. It extends `PostgresSqlQuery`, so SQL builder capabilities are inherited from the PostgreSQL layer.
In day-to-day CDP work, the key decision is execution driver selection.

### Driver Overview

Use one query shape and switch the execution driver based on runtime requirements.

```apex
CdpSqlQuery q = CdpSqlQuery.of('default', 'ssot__Account__dlm', 'a')
    .field('a.ssot__Id__c')
    .field('a.ssot__Name__c')
    .lim(5);

// Default: ConnectApi driver
List<Object> viaConnectApi = q.fetch();

// Opt-in: REST driver via Named Credential
List<Object> viaRest = q.useRestDriver('DataCloud').fetch();
```

| Driver             | Selection API                    | Transport                                  | Typical Use Case                                      |
| :----------------- | :------------------------------- | :----------------------------------------- | :---------------------------------------------------- |
| `ConnectApiDriver` | Default on `CdpSqlQuery.of(...)` | `ConnectApi.CdpQuery.queryAnsiSqlV2`       | Fast in-org execution with minimal setup              |
| `RestDriver`       | `useRestDriver(namedCredential)` | `POST /services/data/vXX.X/ssot/query-sql` | Named Credential control, callout-level observability |

> [!NOTE]
> Dataspace defaults to `default`. Use `CdpSqlQuery.of(dataspace, table, alias)` to target a non-default dataspace.

### ConnectApi Driver (Default)

ConnectApi is used automatically unless you switch to REST.

```apex
CdpSqlQuery q = CdpSqlQuery.of('ssot__Account__dlm')
    .field('ssot__Id__c')
    .field('ssot__Name__c')
    .lim(10);

List<Object> rows = q.fetch();
Integer total = q.fetchCount();
```

| Capability     | Behavior                                               |
| :------------- | :----------------------------------------------------- |
| `fetch()`      | Returns untyped rows projected from `CdpQueryOutputV2` |
| `fetchCount()` | Executes count path and reads first scalar value       |

> [!WARNING]
> For typed SObject projection, ConnectApi payload value formatting (especially datetime) can fail JSON-based SObject deserialization.

### REST Driver (Named Credential)

REST driver executes Data Cloud SQL over callouts and requires a configured Named Credential.

```apex
CdpSqlQuery q = CdpSqlQuery.of('default', 'ssot__Account__dlm', 'a')
    .useRestDriver('DataCloud')
    .field('a.ssot__Id__c', 'account_id')
    .field('a.ssot__Name__c', 'account_name')
    .field('a.ssot__CreatedDate__c', 'created_at')
    .lim(5);

List<Map<String, Object>> rows = (List<Map<String, Object>>) q.fetchInto(List<Map<String, Object>>.class);
Integer total = q.fetchCount();
```

| Capability     | Behavior                                                             |
| :------------- | :------------------------------------------------------------------- |
| `fetch()`      | Reads REST `data` payload and maps matrix rows using `metadata.name` |
| `fetchCount()` | Reads `data[0][0]`                                                   |

### Projection Strategy

Projection works through the shared SQL terminal API, but driver payload format matters.

```apex
public class AccountDto {
    public String ssot_Id_c;
    public String ssot_Name_c;
}

List<AccountDto> dtoRows = (List<AccountDto>) CdpSqlQuery.of('ssot__Account__dlm')
    .useRestDriver('DataCloud')
    .field('ssot__Id__c')
    .field('ssot__Name__c')
    .lim(5)
    .fetchInto(List<AccountDto>.class);
```

```apex
Object firstUntyped = CdpSqlQuery.of('ssot__Account__dlm')
    .field('ssot__Id__c')
    .lim(1)
    .fetchFirstAs(Object.class);

AccountDto firstDto = (AccountDto) CdpSqlQuery.of('ssot__Account__dlm')
    .useRestDriver('DataCloud')
    .field('ssot__Id__c')
    .field('ssot__Name__c')
    .lim(1)
    .fetchFirstAs(AccountDto.class);
```

| Target Type                     | Key Behavior                              | Recommendation                                           |
| :------------------------------ | :---------------------------------------- | :------------------------------------------------------- |
| `List<Object>`                  | Untyped rows, original keys preserved     | Default for ad-hoc exploration                           |
| `List<Map<String, Object>>`     | Untyped map rows, original keys preserved | Best when exact column names matter                      |
| `List<MyDto>.class`             | DTO field normalization: `__` becomes `_` | Good for strongly typed app DTOs                         |
| `List<? extends SObject>.class` | JSON-based SObject materialization        | Only for Data Cloud DMO/DLO SObjects; prefer REST driver |

> [!NOTE]
> Use untyped map targets when you need exact Data Cloud field names without normalization.
> Typed SObject projection in CDP is intended for Data Cloud schema SObjects only (DMOs and DLOs).

**Terminal projection methods and supported parameters:**

| Method                      | Parameter Type                  | Supported Values                                                                                                             | Returns                       |
| :-------------------------- | :------------------------------ | :--------------------------------------------------------------------------------------------------------------------------- | :---------------------------- |
| `fetchInto(listType)`       | `Type` (required, non-null)     | `List<Object>.class`, `List<Map<String, Object>>.class`, `List<MyDto>.class`, `List<? extends SObject>.class` (DMO/DLO only) | `List<Object>` cast to target |
| `fetchFirstAs(elementType)` | `Type` (required, element type) | `Object.class`, `MyDto.class`, `MySObject.class` (DMO/DLO only)                                                              | First projected row or `null` |

> [!IMPORTANT]
> `fetchInto(...)` expects a **list type** (`List<T>.class`). Passing `null` or a non-list type causes `QueryException`.

---

## Architecture

The project uses a layered query architecture that separates **query construction**, **execution**, and **projection**.

- **Core Layer (`apex-query`)**:
    - `Query`: shared primitives (conditions, junctions, bindings, literals, timers, caching)
    - `SoqlQuery`: SOQL DSL + SOQL-specific drivers (`DatabaseDriver`, `RestDriver`) and REST engines (`QueryEngine`, `BulkV2QueryEngine`)
- **SQL Layer (`apex-sql-query`)**:
    - `SqlQuery`: ANSI SQL DSL built on top of `Query`
    - `PostgresSqlQuery` / `MySqlQuery`: dialect extensions on top of `SqlQuery`
- **CDP Layer (`apex-cdp-query`)**:
    - `CdpSqlQuery`: Data Cloud query provider built on `PostgresSqlQuery`
    - Execution drivers: `ConnectApiDriver` and Data Cloud `RestDriver`

Execution pipeline:

1. **Builder DSL** collects clauses and bindings
2. **Compiler** produces bound (`query`) and inline (`inlineQuery`) representations
3. **Context** creates `QueryArgs` and applies execution/security settings
4. **Driver/Engine** executes against local DB, Salesforce REST, or Data Cloud APIs
5. **Projection** materializes results as untyped rows, DTOs, or SObjects
