---
name: apex-testing
description: Apex test conventions for the apex-query repository. Use when adding, changing, reviewing, deploying, or diagnosing unit, integration, regression, Stub API, REST, cache, access-mode, or sharing tests in this project.
---

# Testing Standards for apex-query

This document defines the requirements for writing high-quality Apex tests in this project. All agents and developers must adhere to these standards to ensure consistency and reliability.

> [!IMPORTANT]
> **Philosophy: Quality Over Coverage**
> Tests must be designed to **discover bugs and handle edge cases**, not just to increase code coverage metrics.
>
> - **Negative Scenarios**: Every core feature must be tested for failure modes (invalid inputs, nulls, unauthorized access).
> - **Complex Variations**: Test combinations of features (e.g., Sub-queries + Set Operators + Cursors) to ensure integration stability.
> - **Edge Cases**: Push boundary conditions (empty results, maximum limits, specialized data types).
>   Senseless coverage inflation without robust assertions and negative test cases is prohibited.

## 1. Naming Conventions

Test methods must use **snake_case** for readability and follow the behavior-driven naming pattern:

- Pattern: `should_[expected_behavior]_when_[scenario]`
- Example: `should_throw_exception_when_query_is_malformed`
- Example: `should_return_cached_result_when_memoization_is_enabled`

## 2. Test Structure (AAA Pattern)

Every test method must be organized into three distinct, commented blocks:

- `// Arrange`: Setup data, mocks, and initial state.
- `// Act`: Execute the method under test.
- `// Assert`: Verify the results and side effects.

## 3. Mocking Protocols

### Apex Stub API

- Keep direct `Test.createStub` coverage for every concrete query class intended
  to be mocked.
- After changing a public virtual collection signature, create the complete stub
  and invoke both its `List<T>` and `Set<T>` overloads. Stub creation validates
  the entire virtual surface; invocation validates dispatch and arguments.
- For parameterized interface returns, invoke the concrete covariant wrapper and
  verify that iteration remains lazy.

### REST API Callouts

Use the internal `MockRest` class (found in `RestDriverTest.cls`) to simulate Salesforce REST API responses. Always test both success and failure (4xx/5xx) paths.

### Platform Cache

Never hit real Platform Cache partitions in unit tests. Use the `MockCacheFactory` and `MockCachePartition` to simulate cache behavior without external dependencies.

## 4. Security & Context

- **Access Modes**: Verify behavior in both `AccessLevel.USER_MODE` and `AccessLevel.SYSTEM_MODE` where appropriate.
- **Sharing**: Verify that `WithSharingDriver` and `WithoutSharingDriver` respect the execution context.

## 5. Critical Rules

- **No Empty Catch Blocks**: Never use an empty `catch` block to suppress exceptions in tests. If an exception is expected, use a `try-catch` with `Assert.fail()` at the end of the `try` block and assertions inside the `catch`.
- **Modern Assertions**: Use the `Assert` class (`Assert.areEqual`, `Assert.isTrue`, etc.) instead of the legacy `System.assert` methods.
- **Independence**: Each test must be isolated and not depend on state created by other tests.
- **Unit vs. Integration Tests**: Keep focused unit tests DML-free where
  practical. Use real DML only when persistence, access mode, or record sharing
  is the behavior under test.
- **Parallel Isolation**: Keep tests that create users or perform real sharing
  DML in a dedicated `@IsTest(IsParallel=false)` class. Do not place them in the
  parallel unit-test class.
- **Organization & Folds**:
    - Each test must be grouped into a relevant `// <editor-fold desc="...">` block.
    - Groups should be sorted in a logical order (e.g., Basic Syntax -> Complex Logic -> Exceptions).
- **Code Ordering**:
    - All `@IsTest` methods must come first.
    - Static helper methods and internal helper classes (like `MockRest`) must be placed at the very bottom of the file.
