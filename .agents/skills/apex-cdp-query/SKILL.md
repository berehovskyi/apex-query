---
name: apex-cdp-query
description: Architecture and implementation guidance for the apex-query Data 360 query module. Use when working on CdpSqlQuery, ConnectApi or REST execution, Data 360 typed projection, dataspace handling, ingestion diagnostics, authentication, or sfdx-source/apex-cdp-query.
---

# Apex CDP Query Framework

## Workflow

1. Read [references/framework.md](references/framework.md) completely before
   changing or reviewing Data 360 behavior.
2. Use the `apex-sql-query` skill for inherited SQL-builder behavior and the
   `apex-query` skill for shared projection and driver conventions.
3. Verify ConnectApi and REST behavior independently; do not assume identical
   payloads, datetime representations, permissions, or error shapes.
4. Apply the `apex-style` and `apex-testing` skills for code and test changes.
5. Validate the CDP package and any changed shared SQL dependency.

## Boundaries

- Keep `ConnectApiDriver` and `RestDriver` behavior explicit.
- Prefer REST when stable typed SObject projection requires JSON-compatible
  datetime values.
- Keep `EXPLAIN` unsupported until a live backend probe proves otherwise.
- Treat ingestion, DLO-to-DMO mapping, OAuth scopes, and Named Credential
  principal access as separate operational boundaries.
