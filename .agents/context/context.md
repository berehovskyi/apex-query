# Apex Query Framework Technical Documentation

The `apex-query` framework is a premium, high-performance query engine for Salesforce Apex. Unlike traditional SOQL builders, it provides a unified DSL for SOQL, SQL, and Data 360 (formerly Data Cloud), built for speed and technical superiority.

## 1. Architectural Foundations

The framework follows a **Unified Query Engine** approach. It isn't just a SOQL builder; it's a multi-protocol abstraction layer that allows developers to use the same fluent patterns across different data sources.

### Core Architecture: Policy-Driven Execution

- **Clause-as-a-Class**: Each query part (SELECT, WHERE, etc.) is an isolated unit, ensuring zero overhead for unused clauses.
- **Driver Strategy**: Decouples query building from execution. The engine selects the optimal `Driver` based on the protocol (SOQL, SQL, Data 360) and security context.
- **Binding Strategy**: Supports multiple binding modes to handle different protocol requirements:
    - `NAMED` (`:var$0`): Standard SOQL/Apex bindings (default).
    - `INDEXED` (`$1`): PostgreSQL/SQL style positional bindings.
    - `ANONYMOUS` (`?`): JDBC/Standard SQL anonymous bindings.
- **Bind Management**: A centralized `BindContext` ensures all variables are automatically sanitized and bound, protecting against injection across all protocols. Each terminal operation (`fetch`, `fetchCount`) generates a fresh, isolated `BindContext` with the appropriate strategy, ensuring stateless query compilation.

---

## 2. Premium DSL & "jOOQ-Style" Syntax

`apex-query` is designed to feel like a first-class language extension, borrowing the best patterns from industry standards like jOOQ.

### The "Keyword Bridge" Strategy

Apex's reserved keywords (like `where`, `having`) are elegantly handled with a consistent `x` suffix (e.g., `wherex()`, `havingx()`). This creates a predictable, professional DSL that looks closer to raw query code than generic "filter" methods.

### Terminal Execution API

Query construction is clearly separated from execution via terminal "Fetch" operations:

- `fetch()`: Returns a list of results (SObject or Object depending on engine).
- `fetchLazy()`: Returns an `Iterable` for chunked retrieval (Cursor/Locator in local DB, paging in REST).
- `fetchFirst()`: Safely returns a single result or null.
- `fetchCount()`: Specifically executes a count query.
- `locator()`: Returns `Database.QueryLocator` for batch jobs.
- `cursor()` / `paginationCursor()`: Returns a modern `Database.Cursor` / `Database.PaginationCursor`.
- `fetchInto(Type listType)`: Returns projected typed rows, where `listType` is `List<T>.class`.
- `fetchLazyInto(Type listType)`: Lazy projected typed rows, where `listType` is `List<T>.class`.
- `fetchFirstAs(Type elementType)`: First projected typed row, where `elementType` is `T.class`.

### Introspection & Debugging

The `Builder` interface provides powerful introspection methods for debugging and transparency:

- `getBindings()`: Returns all bindings for the regular query.
- `getCountBindings()`: Returns bindings specific to count queries.
- `.debug()`: Enables automatic logging of the fully inlined query to the debug console during execution.
- `.useTimer()`: Enables execution timing with default `Query.Timer.CPU` in `SoqlQuery`.
- `.useTimer(Query.Timer mode)`: Enables execution timing with selected mode (`CPU` or `SYS`).
- `toInlineString()`: Returns the query string with all bind values inlined as literals.

---

## 3. High-Performance Design

`apex-query` is architected for **Max Speed** by minimizing runtime overhead and avoiding heavy dependencies:

- **Lightweight Initialization**: Minimal object creation during builder calls.
- **Describe-Free Building**: Operates directly on field tokens and strings to avoid the performance penalty of Apex Describe calls.
- **Optimized Sub-queries**: Sub-queries are embedded as first-class objects, avoiding manual string manipulation or sub-query builder overhead.

---

## 4. Comprehensive DSL Reference

### Initialization & Basic Syntax

```apex
// Initialization
SoqlQuery.of(Account.SObjectType);
SoqlQuery.of('Account');

// Fluent Construction
SoqlQuery.of('Account')
    .field('Name')
    .addConditionEq('Type', 'Customer')
    .fetch();
```

### SELECT Functions & Aggregates

- **Transformation**: `toLabel()`, `format()`, `convertCurrency()`, `convertTimezone()`.
- **Aggregates**: `count()`, `countDistinct()`, `sum()`, `avg()`, `min()`, `max()`.
- **Grouping**: `grouping()` (for determining if a row is a subtotal).

### Condition Composition

The framework offers a flexible way to build `WHERE` clauses, starting from simple logic to complex nested structures.

#### 1. Basic Builder Methods

The simplest way to filter queries is using the builder's shortcut methods.

- `addConditionEq(field, value)`
- `addConditionIn(field, validValues)`
- `addConditionNe(field, value)`
- `addConditionNotIn(field, invalidValues)`

```apex
SoqlQuery.of('Account')
    .addConditionEq('Type', 'Customer')
    .addConditionIn('Industry', new List<String>{'Tech', 'Finance'})
    .fetch();
```

#### 2. Simple Stacking (AND / OR)

You can stack conditions using `addCondition` or `addConditionAnd`/`addConditionOr`.

```apex
q.wherex(condition1)
 .addCondition(condition2)
 .addConditionOr(condition3); // OR
```

#### 3. Constructing Conditions

For more control, create condition objects directly using `new SoqlQuery.Condition()` or the `SoqlQuery.COND` shorthand.

```apex
var c = new SoqlQuery.Condition().field('Type').eq('Customer');
// OR
var c = SoqlQuery.COND.field('Type').eq('Customer');
```

**Available Operators**:
`eq`, `ne`, `gt`, `ge`, `lt`, `le`, `likex`, `inx`, `notIn`, `includes`, `excludes`.

#### 4. Fluent Composition

Conditions themselves can be composed into chains before adding them to the query.

```apex
// Compiles to: WHERE C1 AND C2 AND C3
var chain = cond1.add(cond2).add(cond3);
```

#### 5. Complex Nested Logic (Junctions)

For complex scenarios like `C1 AND (C2 OR C3)`, use static helpers to create parenthesized **Junctions**.

- `SoqlQuery.ands(c1, c2)` -> `(c1 AND c2)`
- `SoqlQuery.ors(c1, c2)` -> `(c1 OR c2)`
- `SoqlQuery.notx(c1)` -> `(NOT c1)`

```apex
// WHERE Status = 'Active' AND (Rating = 'Hot' OR Type = 'VIP')
q.wherex(
    SoqlQuery.COND.field('Status').eq('Active')
)
.addCondition(
    SoqlQuery.ors(
        SoqlQuery.COND.field('Rating').eq('Hot'),
        SoqlQuery.COND.field('Type').eq('VIP')
    )
);
```

---

## 5. Specialized Data Providers

The framework elevates complex SOQL/SQL logic through **Rich Provider Singletons**, making advanced queries readable and type-safe.

### Date Functions (`SoqlQuery.DT`)

Exhaustive list of supported date parts:
`calendarMonth`, `calendarQuarter`, `calendarYear`, `dayInMonth`, `dayInWeek`, `dayInYear`, `dayOnly`, `fiscalMonth`, `fiscalQuarter`, `fiscalYear`, `hourInDay`, `weekInMonth`, `weekInYear`.

### Date Literals (`SoqlQuery.LIT`)

- **Constants**: `yesterday`, `today`, `tomorrow`, `lastWeek`, `thisWeek`, `nextWeek`, `lastMonth`, `thisMonth`, `nextMonth`, `last90Days`, `next90Days`, `thisQuarter`, `lastQuarter`, `nextQuarter`, `thisYear`, `lastYear`, `nextYear`, `thisFiscalQuarter`, `lastFiscalQuarter`, `nextFiscalQuarter`, `thisFiscalYear`, `lastFiscalYear`, `nextFiscalYear`.
- **Parameterized**: `lastNDays(n)`, `nextNDays(n)`, `nDaysAgo(n)`, `nextNWeeks(n)`, `lastNWeeks(n)`, `nWeeksAgo(n)`, `nextNMonths(n)`, `lastNMonths(n)`, `nMonthsAgo(n)`, `nextNQuarters(n)`, `lastNQuarters(n)`, `nQuartersAgo(n)`, `nextNYears(n)`, `lastNYears(n)`, `nYearsAgo(n)`, `nextNFiscalQuarters(n)`, `lastNFiscalQuarters(n)`, `nFiscalQuartersAgo(n)`, `nextNFiscalYears(n)`, `lastNFiscalYears(n)`, `nFiscalYearsAgo(n)`.

### Geo Location (`SoqlQuery.GEO`)

- **Functions**: `distance(field, location, unit)`
- **Units**: `DistanceUnit.KM`, `DistanceUnit.MI`

### Currency Literals (`SoqlQuery.CUR`)

- **Usage**: `CUR.of('USD', 100.50)` (generates `USD100.50`).

### Data Category (`SoqlQuery.CAT`)

Used with `WITH DATA CATEGORY` for Knowledge Article filtering:

- `CAT.of('Group').at('Category')`
- `.above()`, `.below()`, `.aboveOrBelow()` selectors.

---

## 6. Security, Caching & Engine Logic

### Unified Security Policy

The engine operates with USER_MODE by default and allows configuring the execution context, allowing for policy-driven data access.

- **Sharing**: `.withSharing()`, `.withoutSharing()`, `.inheritedSharing()`.
- **System Mode**: `.withSystemMode()`.
- **Strip Inaccessible**: `.withStrip(AccessType)` or `.withStrip()`.

### Cross-Org & Remote Drivers

The framework supports switching the underlying execution engine via `.useDriver(Driver)`:

- **DatabaseDriver (Default)**: Executes locally. `fetchLazy()` uses **Apex Cursors** for handling up to 50M records with minimal heap overhead.
- **RestDriver**: Executes queries against a remote Org (or the same Org loopback) via **Named Credentials**.
    - **User Mode Enforcement**: Inherently runs in user-mode; attempting to use `AccessLevel.SYSTEM_MODE` with this driver will throw an exception.
    - **Pagination**: Transparently handles SOQL paging during iteration through the selected REST engine.
    - **QueryAll**: Supports `allRows()` by automatically redirecting to the `/queryAll` REST resource.

### Multi-Tier Result Caching

- **Memoization**: `.memoize()` stores results in a transaction-scoped `static Map`.
- **Session Cache**: `.cacheSession('partition')` or `.cacheSession('partition', ttl)` uses Platform Cache Session.
- **Org Cache**: `.cacheOrg('partition')` or `.cacheOrg('partition', ttl)` uses Platform Cache Org (requires non-User mode).
- **TTL Support**: Platform Cache entries can have an optional `ttlInSecs` parameter for precise expiration control. TTL functionality is fully tested and validated with dedicated unit tests (`should_respect_session_cache_ttl`, `should_respect_org_cache_ttl`).
- **Deterministic Keying**: MD5-based keys ensure cache hits are precise and safe across different security modes.

---

## 7. Advanced SOQL Features

### Polymorphic Queries (`TYPEOF`)

```apex
SoqlQuery.TypeOf to = new SoqlQuery.TypeOf('Owner')
    .when('User').then('Alias')
    .when('Group').thenFields('Name, Type')
    .elsex('Name')
    .end(); // Required

SoqlQuery.of('Account').typeOf(to);
```

### Sub-Queries & Joins

Seamlessly integrates child relationship queries and sub-query junctions:

```apex
SoqlQuery.of('Account')
    .subQuery('Contacts', SoqlQuery.of('Contact').field('LastName'))
    .addConditionIn('Id', SoqlQuery.of('Contact').field('AccountId'))
    .fetch();
```

- **Semi-Joins**: `.addConditionIn(field, subQuery)`.
- **Anti-Joins**: `.addConditionNotIn(field, subQuery)`.

---

## 8. REST Engine Architecture

The REST execution layer uses a two-level strategy model:

- **RestDriver + RestEngine**:
    - `RestDriver` handles transport concerns (callout endpoint construction, USER_MODE guard, timers/debug, API version validation).
    - `RestDriver` owns the active `RestEngine` (`useEngine(RestEngine)`), and delegates `runMore`, `count`, and `explain`.
    - API version is validated with strict `vXX.X` pattern (for example `v66.0`).
    - `RestEngine` handles protocol behavior (`runMore`, `count`, `explain`, resource resolution).
- **QueryEngine (SOQL REST)**:
    - Supports `/query`, `/queryAll`, and tooling variants through `useTooling(Boolean)`.
    - Supports root page sizing with `setBatchSize(Integer)` via `Sforce-Query-Options`.
    - Supports continuation hydration with `setQueryMore(Boolean)` and `setChunkSize(Integer)`.
    - Chooses continuation transport via `useQueryMoreEngine(QueryMoreEngine)`.
- **SObjectCollectionsEngine (`/composite/sobjects/{sObject}`)**:
    - Supports strict WHERE shapes for ID retrieval: `Id = ...` or `Id IN (...)`.
    - Fetches records in request-body ID chunks (`ids`) with configurable `setChunkSize(Integer)`.
    - Requires at least one selected field.
    - `count()` rewrites to `SELECT Id ...` and counts non-null returned rows.
    - `explain()` is unsupported.
- **BulkV2QueryEngine (Bulk API v2 Query Jobs)**:
    - Creates a job, polls status, fetches CSV result pages, and projects rows into requested `List<T>.class`.
    - Supports `setPollInterval(Integer)`, `setCpuTimeout(Integer)`, and `setMaxRecords(Integer)`.
    - Supports locator continuation with `setQueryMore(Boolean)`.
    - `count()` uses `numberRecordsProcessed` from completed job status.
    - `explain()` is unsupported.

### QueryMore Transport Strategies

- `QueryMoreEngine.COMPOSITE`: Uses Composite API continuation requests.
- `QueryMoreEngine.COMPOSITE_BATCH`: Uses Composite Batch API continuation requests.
- `QueryMoreEngine.QUERY`: Uses direct sequential `/query` continuation requests (one URL per request).

The `QueryEngine` owns queryMore engine selection and provides the concrete queryMore request engine to the iterator.

---

## 9. REST Iterator Hydration Semantics

REST execution is lazy and engine-specific:

- `QueryEngine` -> `QueryMoreIterator` (root query + nested wave hydration when queryMore is enabled).
- `SObjectCollectionsEngine` -> `SObjectCollectionsIterator` (ID-chunked fetch).
- `BulkV2QueryEngine` -> `BulkV2Iterator` (job creation/polling + CSV page streaming).

For `QueryMoreIterator`, shaping is deterministic by target projection type and `queryMore` mode.

### `queryMore = false`

- Root query returns only the first page.
- **SObject projection**:
    - Nested query-result envelopes are normalized recursively to `done = true`.
    - `nextRecordsUrl` is removed from nested envelopes.
- **Untyped projection** (`Map<String, Object>` / `Object`):
    - No transformations are applied.
- **DTO projection**:
    - Key normalization converts `__` to `_`.

### `queryMore = true`

- Root and nested query continuations are hydrated in waves until no continuation URL remains.
- **SObject projection**:
    - Nested query-result envelopes are normalized recursively to `done = true`.
    - `nextRecordsUrl` is removed from nested envelopes.
- **Untyped projection** (`Map<String, Object>` / `Object`):
    - No transformations are applied.
- **DTO projection**:
    - Key normalization converts `__` to `_`.

---

## 10. Bulk API v2 CSV Projection Details

Bulk API v2 results are projected through an Apex-native CSV pipeline optimized for CPU/heap balance:

- **CSV Parser**:
    - Uses a char-index parser (`parseCsvByCharIndexes`) for row/field scanning.
- **Header Planning**:
    - Header metadata is precomputed per parsed page into a column plan (key path, nested tokens, normalization flags).
    - Per-row projection reuses the plan to avoid repeated `split()` and key normalization work.
- **Nested Relationship Materialization**:
    - Dot-path headers (for example `Owner.Name`, `Owner.Profile.Name`) are projected into nested maps.
    - Relationship nodes include `attributes` envelopes for compatibility with SObject/DTO projection shape.
- **Target Projection Modes**:
    - `List<Map<String, Object>>`: untyped nested maps.
    - `List<SObject>`: JSON projection into typed SObject list.
    - `List<DTO>`: JSON projection with `__` key normalization.

---

## 11. Typed Projection Contract

Projection is unified by list-type tokens for list-returning methods:

- `fetchInto` and `fetchLazyInto` require list type tokens (`List<T>.class`).
- `fetchFirstAs` requires an element type token (`T.class`).
- Element type is derived from the list type (`resolveElementTypeFromListType`).
- Untyped targets (`List<Map<String, Object>>.class` / `List<Object>.class`) return map payloads directly.
- Typed targets (`List<SObject>.class`, `List<DTO>.class`) use JSON projection.
- DTO projection applies recursive key normalization (`__` -> `_`).
