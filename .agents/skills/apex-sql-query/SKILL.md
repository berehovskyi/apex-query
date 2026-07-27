---
name: apex-sql-query
description: Architecture and implementation guidance for the apex-query ANSI SQL and dialect builders. Use when working on SqlQuery, PostgresSqlQuery, MySqlQuery, SQL bindings, joins, CTEs, set operations, window functions, projection, or SQL drivers in sfdx-source/apex-sql-query.
---

# Apex SQL Query Framework

## Workflow

1. Read [references/framework.md](references/framework.md) completely before
   changing or reviewing SQL framework behavior.
2. Use the `apex-query` skill for shared `Query`, binding, driver, projection,
   Stub API, and execution conventions.
3. Inspect the affected dialect implementation and its focused tests; do not
   infer PostgreSQL, MySQL, or backend support from ANSI syntax alone.
4. Apply the `apex-style` and `apex-testing` skills for code and test changes.
5. Validate the affected SQL package and any dependent Data 360 package when a
   shared SQL contract changes.

## Boundaries

- Preserve each dialect's default binding strategy.
- Treat `literal(...)` and raw fragments as explicitly trusted caller input.
- Keep query building usable without an execution driver.
- Preserve driver-neutral query arguments and typed projection behavior.
- Verify backend-specific syntax and execution behavior instead of assuming
  feature parity across SQL engines.
