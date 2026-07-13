# Apex CDP Framework Technical Documentation

The CDP module extends the SQL builder stack with Data 360 (formerly Data Cloud) specific execution in Apex.
It provides a fluent SQL authoring API (`CdpSqlQuery`) with two runtime strategies:

- ConnectApi execution (`ConnectApi.CdpQuery.queryAnsiSqlV2`)
- REST execution (`/services/data/vXX.X/ssot/query-sql`)

## 1. Fundamentals

`CdpSqlQuery` is built on top of the SQL framework hierarchy:

- `SqlQuery` -> base ANSI SQL builder
- `PostgresSqlQuery extends SqlQuery` -> PostgreSQL-oriented SQL helpers
- `CdpSqlQuery extends PostgresSqlQuery` -> Data 360 execution drivers

Main implementation files:

- `sfdx-source/apex-cdp-query/main/classes/CdpSqlQuery.cls`
- `sfdx-source/apex-cdp-query/test/classes/CdpSqlQueryTest.cls`

## 2. Initialization

### Factories

```apex
CdpSqlQuery.of('ssot__Account__dlm');
CdpSqlQuery.of('ssot__Account__dlm', 'a');
CdpSqlQuery.of('default', 'ssot__Account__dlm', 'a');
```

Default dataspace is `default` when not specified explicitly.

### Basic query

```apex
List<Object> rows = CdpSqlQuery.of('ssot__Account__dlm', 'a')
    .field('a.ssot__Id__c')
    .field('a.ssot__Name__c')
    .lim(10)
    .fetch();
```

## 3. Driver Model

`CdpSqlQuery` supports two public inner drivers.

Both drivers receive `SqlQuery.QueryArgs` (bound `query`, `inlineQuery`, and `bindings`).
Current Data 360 drivers execute `inlineQuery` payloads against the backend APIs.

### ConnectApiDriver (default)

- Backend: `ConnectApi.CdpQuery.queryAnsiSqlV2(...)`
- Good fit: default CDP query execution and untyped projections
- Result shaping: maps metadata order to row values

```apex
List<Object> rows = CdpSqlQuery.of('ssot__Account__dlm')
    .field('ssot__Id__c')
    .fetch();
```

### RestDriver (opt-in)

- Backend: `POST /services/data/vXX.X/ssot/query-sql?dataspace=<...>`
- Requires Named Credential
- Supports API version override via `.setApiVersion('v66.0')`

```apex
List<Object> rows = CdpSqlQuery.of('ssot__Account__dlm')
    .useRestDriver('DataCloud')
    .field('ssot__Id__c')
    .fetch();
```

## 4. Typed Projection Guidance

The shared SQL projection pipeline supports:

- Untyped targets: `List<Object>`, `List<Map<String,Object>>`
- DTO targets: `List<MyDto>.class`
- SObject targets: `List<? extends SObject>.class` (Data 360 schema SObjects only: DMO/DLO)

### CDP-specific note

ConnectApi can return datetime values in non-JSON/SObject-friendly string formats.
For typed SObject deserialization, REST driver is more reliable in practice.

```apex
// Prefer REST for typed SObject projection
List<Object> rows = CdpSqlQuery.of('ssot__Account__dlm')
    .useRestDriver('DataCloud')
    .field('ssot__Id__c')
    .field('ssot__CreatedDate__c')
    .fetchInto(List<ssot__Account__dlm>.class);
```

> [!WARNING]
> `ConnectApiDriver` can return datetime text that fails SObject JSON deserialization.
> If typed SObject projection fails, switch to `RestDriver` or use DTO/untyped targets.
> Typed SObject projection is intended for Data 360 DMO/DLO SObject types.

## 5. COUNT Semantics

### ConnectApiDriver

- `count()` executes through `run(args)` and reads first scalar from first row map
- Returns `0` if no rows/value

### RestDriver

- `count()` expects matrix-style row payload under `data` (for example `[[7]]`)
- If `data` block is unavailable, falls back to `status.rowCount` when present
- Returns `0` when both paths are unavailable

## 6. EXPLAIN Status

`explain()` is intentionally unsupported in both CDP drivers.

Why:

- ConnectApi path showed backend parser/cast errors for `EXPLAIN`
- REST path in tested org returned `PERMISSION_DENIED` / statement type disabled

As a result:

- `ConnectApiDriver.explain()` throws `QueryException`
- `RestDriver.explain()` throws `QueryException`

## 7. Ingestion + Data Stream Operational Notes

Common ingestion API behaviors observed:

- `404` on create-job often indicates source/object mismatch in connector config
- `409` on create-job indicates active job conflict on same source
- Missing scope causes token exchange failures (`invalid_scope`)

Data modeling flow requirements:

- Ingestion schema object names must follow connector schema constraints
- DLO must be mapped to DMO in Data Stream before DMO querying is available

## 8. Auth / Named Credential Notes

Working integration pattern:

- External Client App (OAuth/JWT flow)
- External Credential + Principal mapping
- Named Credential bound to External Credential

Frequent setup issues:

- Missing Permission Set access to External Credential principal
- Incorrect JWT `sub` value
- Wrong OAuth scopes or token endpoint

## 9. Testing Strategy

Primary test class:

- `sfdx-source/apex-cdp-query/test/classes/CdpSqlQueryTest.cls`

Coverage areas:

- ConnectApi run/count/explain behavior
- REST run/count/explain behavior
- REST payload projection from matrix rows + metadata
- API version format validation

E2E support:

- `e2e/` scripts and tests for ingestion and CDP query scenarios

## 10. Practical Recommendations

Use `ConnectApiDriver` when:

- You need straightforward CDP SQL execution
- You consume untyped rows/DTOs

Use `RestDriver` when:

- You need stable typed SObject projection behavior
- You want HTTP-level visibility and Named Credential callout control
- You need explicit API version pinning (`vXX.X`)
