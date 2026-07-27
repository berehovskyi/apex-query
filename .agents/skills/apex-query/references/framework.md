# Apex Query Framework Technical Documentation

The `apex-query` framework is a layered query builder and execution library for Salesforce Apex. It provides related fluent DSLs for SOQL, SQL, and Data 360 (formerly Data Cloud), with driver-specific execution, projection, security, and pagination behavior.

## 1. Architectural Foundations

The framework follows a **Unified Query Engine** approach. It isn't just a SOQL builder; it's a multi-protocol abstraction layer that allows developers to use the same fluent patterns across different data sources.

### Core Architecture: Policy-Driven Execution

- **Clause-as-a-Class**: Each query part (SELECT, WHERE, etc.) is an isolated renderable unit that can be composed into bound, inline, and count representations.
- **Driver Strategy**: Decouples query building from execution. SOQL uses a local database driver by default; REST, SQL, Data 360, and custom execution paths are selected explicitly by the caller.
- **Binding Strategy**: Supports multiple binding modes to handle different protocol requirements:
    - `NAMED` (`:var$0`): Standard SOQL/Apex bindings (default).
    - `INDEXED` (`$1`): PostgreSQL/SQL style positional bindings.
    - `ANONYMOUS` (`?`): JDBC/Standard SQL anonymous bindings.
- **Bind Management**: A centralized `BindContext` allocates generated bindings for each rendering operation. Typed condition methods treat ordinary inputs as values and use the selected binding or inline-literal strategy. This protection does not extend to explicitly trusted raw fragments or `literal(...)` expressions. `withBindings(...)` participates in bound Database/SQL execution; Salesforce REST query resources execute complete inline SOQL and do not accept Apex bind maps. User bindings intentionally overwrite generated bindings on a key collision, so generated names such as `var$0` must not be used as a stable override API. Each terminal operation creates a fresh context, but generated names and placeholder order remain implementation details.

### Apex Stub API Compatibility

The concrete `SoqlQuery` and `SqlQuery` classes must support
`Test.createStub`. Stub API compatibility and compile-time type safety are both
public API requirements.

- Do not expose parameterized interfaces such as `Iterable<T>` as parameters on
  the public virtual concrete surface when they prevent stub generation.
- Expose matching `List<T>` and `Set<T>` overloads on builder interfaces and
  concrete classes. Do not widen the concrete parameter to `Object` and do not
  rely on interface parameter contravariance.
- Delegate repeated `List<T>` and `Set<T>` overloads to a differently named
  private helper that accepts `Iterable<T>`. A same-named private iterable helper
  creates ambiguous overload resolution in Apex.
- Lazy return methods use covariant concrete adapters that implement
  `Iterable<T>`, wrap the original iterable, and delegate `iterator()` without
  copying or materializing results. Return types are never widened to `Object`.
- A single unsupported public method can invalidate an entire generated stub
  class. Keep regression coverage that creates each concrete query stub and
  invokes both collection overloads and parameterized-return wrappers.

---

## 2. Fluent DSL & "jOOQ-Style" Syntax

`apex-query` is designed to feel like a first-class language extension, borrowing the best patterns from industry standards like jOOQ.

### The "Keyword Bridge" Strategy

Apex's reserved keywords (like `where`, `having`) are handled with a consistent `x` suffix (e.g., `wherex()`, `havingx()`).

### Terminal Execution API

Query construction is clearly separated from execution via terminal "Fetch" operations:

- `fetch()`: Returns the rows loaded by the active driver. REST query and Bulk V2 engines return the first page unless query-more is enabled.
- `fetchLazy()`: Returns an `Iterable` contract backed by a lazy adapter over cursor or REST paging behavior.
- `fetchFirst()`: Returns the first item from the driver's normal fetch result or null; it does not add a row limit implicitly.
- `fetchCount()`: SOQL counts source records with `COUNT()` and excludes grouping; SQL counts total result rows before pagination.
- `locator()`: Returns `Database.QueryLocator` for batch jobs.
- `cursor()` / `paginationCursor()`: Returns a modern `Database.Cursor` / `Database.PaginationCursor`.
- `fetchInto(Type listType)`: Returns projected typed rows, where `listType` is `List<T>.class`.
- `fetchLazyInto(Type listType)`: Lazy projected typed rows, where `listType` is `List<T>.class`.
- `fetchFirstAs(Type elementType)`: First projected typed row, where `elementType` is `T.class`.

### Introspection & Debugging

The `Builder` interface provides powerful introspection methods for debugging and transparency:

- `getBindings()`: Returns all bindings for the regular query.
- `getCountBindings()`: Returns bindings specific to count queries.
- `.debug()`: Opts into query/request logging at error severity. Inline queries and request bodies can contain values, so enable it only where sensitive diagnostic output is acceptable.
- `.useTimer()`: Enables wall-clock millisecond timing with default `Query.Timer.SYS` in both SOQL and SQL.
- `.useTimer(Query.Timer mode)`: Enables execution timing with selected mode (`CPU` or `SYS`).
- `toInlineString()`: Returns the query string with all bind values inlined as literals.

---

## 3. Performance Characteristics

The library avoids external runtime dependencies and keeps ordinary builder operations local, while preserving the current driver contract and driver-specific resource costs:

- **Describe-Free by Default**: Field tokens and strings do not require describe calls. FieldSet and describe-based all-fields helpers do.
- **Composable Subqueries**: Subqueries are embedded as query parts instead of requiring callers to concatenate complete query strings.
- **Dual Rendering Contract**: Execution currently produces both bound and inline representations because both are part of the public driver contract, even when a selected driver consumes only one.
- **Driver-Specific Costs**: Lazy adapters do not materialize their source, but REST continuation, Bulk V2 polling, CSV download/parsing, and typed JSON projection still consume Apex callout, CPU, and heap budgets.

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
- **Driver/Sharing Ordering**: Explicit custom/REST drivers and sharing-helper drivers are mutually exclusive in either call order; the library rejects the combination instead of silently replacing either choice.

### Cross-Org & Remote Drivers

The framework supports switching the underlying execution engine via `.useDriver(Driver)`:

- **DatabaseDriver (Default)**: Executes locally. `fetchLazy()` delegates iteration to an Apex Cursor-backed iterable.
- **RestDriver**: Executes queries against a remote Org (or the same Org loopback) via **Named Credentials**.
    - **User Mode Enforcement**: Requires exactly `AccessLevel.USER_MODE`; every other access mode is rejected.
    - **Field Access**: Remote reads already enforce readable-field access. `withStrip()`/`READABLE` remain valid, while `CREATABLE`, `UPDATABLE`, and `UPSERTABLE` are rejected because local permissions cannot represent the remote user's write permissions.
    - **Pagination**: Follows SOQL continuation pages only when query-more is enabled on the selected REST engine.
    - **QueryAll**: Supports `allRows()` by automatically redirecting to the `/queryAll` REST resource.

### Multi-Tier Result Caching

- **Memoization**: `.memoize()` stores results in a transaction-scoped `static Map`. Cached list structure is shallow-copied on write/read, so callers cannot corrupt later results by adding, removing, sorting, or clearing entries; contained records remain shared objects.
- **Session Cache**: `.cacheSession('partition')` or `.cacheSession('partition', ttl)` uses Platform Cache Session.
- **Org Cache**: `.cacheOrg('partition')` or `.cacheOrg('partition', ttl)` uses Platform Cache Org only outside the default USER_MODE. Under USER_MODE the configuration is intentionally bypassed without a runtime warning.
- **TTL Support**: Platform Cache entries can have an optional `ttlInSecs` parameter for precise expiration control. TTL functionality is fully tested and validated with dedicated unit tests (`should_respect_session_cache_ttl`, `should_respect_org_cache_ttl`).
- **Cache Keys**: MD5-based keys include query/execution state, but their serialized representation is an internal implementation detail and must not be treated as a stable external identifier.

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

An unfinished `TYPEOF` builder still fails. A finalized builder with no populated `WHEN` entry is intentionally omitted from the containing SELECT list instead of rendering malformed SOQL.

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
    - API version is validated as `v<major>.<minor>` with one-or-more digits in each numeric component (for example `v66.0` or `v100.0`); version availability remains Salesforce's responsibility.
    - `RestEngine` handles protocol behavior (`runMore`, `count`, `explain`, resource resolution).
- **QueryEngine (SOQL REST)**:
    - Supports `/query`, `/queryAll`, and tooling variants through `useTooling(Boolean)`.
    - Supports root page sizing with `setBatchSize(Integer)` via `Sforce-Query-Options`.
    - Supports continuation hydration with `setQueryMore(Boolean)` and `setChunkSize(Integer)`.
    - Chooses continuation transport via `useQueryMoreEngine(QueryMoreEngine)`.
    - Explicit batch/chunk sizes are validated as positive. Salesforce API and transport limits are intentionally left to the selected API version rather than hard-coded by the library.
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
    - Polling is synchronous and can consume the transaction's Apex CPU budget. `setCpuTimeout` is an optional guard; without it, a governor-limit failure is an accepted outcome.

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

Bulk API v2 results are projected through an Apex-native CSV pipeline. Result pages are downloaded, parsed, and buffered in Apex, so this path still consumes transaction heap and CPU:

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
- DTO projection applies recursive key normalization (`__` -> `_`) and throws `QueryException` if two source keys normalize to the same target key. Untyped projection preserves original keys and is the opt-out.
