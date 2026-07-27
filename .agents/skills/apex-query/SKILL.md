---
name: apex-query
description: Architecture and implementation guidance for the apex-query SOQL builder and execution framework. Use when working on Query.cls, SoqlQuery.cls, local or REST drivers, query-more engines, binding, projection, caching, security, pagination, or the sfdx-source/apex-query package.
---

# Apex Query Framework

## Workflow

1. Read [references/framework.md](references/framework.md) completely before
   changing or reviewing framework behavior.
2. Inspect the relevant production code and focused tests. Treat current source,
   deployed probes, and platform documentation as authoritative when they differ
   from the reference.
3. Preserve the builder, clause, binding, driver, engine, projection, security,
   and pagination boundaries described in the reference.
4. Apply the `apex-style` skill for implementation changes and the
   `apex-testing` skill for test changes.
5. Validate the smallest relevant package surface, then run the complete
   apex-query test set when the public builder or driver contract changes.

## Boundaries

- Keep query construction separate from terminal execution.
- Keep driver-specific transport types out of shared query contracts.
- Preserve USER_MODE defaults and explicit sharing semantics.
- Preserve direct `Test.createStub` support for public concrete query classes.
- Let Salesforce enforce version-dependent platform limits unless the framework
  must use a value to plan its own chunking.
- Recheck references and regression tests whenever a public fluent signature,
  driver contract, result projection, or API-version-dependent behavior changes.
