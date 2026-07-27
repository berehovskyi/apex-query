---
name: apex-style
description: Apex implementation and layout conventions for the apex-query repository. Use when writing, refactoring, or reviewing Apex code in this project, especially for fluent APIs, Stub API compatibility, null handling, coercion, control flow, class organization, and sharing boundaries.
---

# Style Standards

## General Code Shape

- When two implementations are functionally equivalent and equally clear, prefer
  the one that produces less code. Do not add indirection, helpers, or ceremony
  unless it improves safety, readability, reuse, or testability.

## Apex Null Handling

- Prefer `?.` and `??` over verbose ternaries or nested null checks.

Bad:

```apex
String id = recordId == null ? null : recordId.toString();
String name = value == null ? fallback : value;
```

Good:

```apex
String id = recordId?.toString();
String name = value ?? fallback;
```

- Do not add defensive null branches for values already guaranteed non-null by
  the surrounding condition, API contract, or runtime context.

Bad:

```apex
if (date != null && now > date) {}
```

Good:

```apex
if (now > date) {}
```

## Apex Coercion

- Prefer natural string coercion in concatenation.

Bad:

```apex
'job:' + String.valueOf(System.now().getTime());
```

Good:

```apex
'job:' + System.now().getTime();
```

- For string interpolation in messages, names, or keys:
    - Use concatenation for zero or one dynamic value.
    - Use `String.format(...)` for two or more dynamic values.
    - Prefer typed format arguments, or `List<Object>` for mixed types. Do not wrap
      format arguments in `String.valueOf(...)` when they can be formatted
      directly.
    - Static SOQL fragments and field lists may use concatenation when that keeps
      the query readable.
- Exception message templates belong in `private static final` constants even
  when they have zero or one dynamic value. This keeps a class's failure surface
  visible at the top. Local non-exception strings may stay inline.

Good:

```apex
'Value "' + value + '" is invalid.';
```

Bad:

```apex
'Value "' + value + '" for field "' + fieldName + '" is invalid.';
```

Good:

```apex
String.format('Value "{0}" for field "{1}" is invalid.', new List<Object>{ value, fieldName });
```

Good:

```apex
private static final String INVALID_VALUE_MESSAGE = 'Value "{0}" is invalid.';

throw new QueueException(String.format(INVALID_VALUE_MESSAGE, new List<String>{ value }));
```

- Prefer `Map<Id, ...>` when the key is naturally a Salesforce id.

Bad:

```apex
Map<String, Job__c> jobsById;
jobsById.put(job.Id.toString(), job);
```

Good:

```apex
Map<Id, Job__c> jobsById;
jobsById.put(job.Id, job);
```

- `Id` values are string-compatible in Apex comparisons. Do not cast or
  stringify an `Id` only to compare it with a `String`.

Bad:

```apex
job.Id.toString() == jobId;
```

Good:

```apex
job.Id == jobId;
```

## Impossible Cases

- Prefer sets when comparing one value against 3+ candidates.

Bad:

```apex
val == A || val == B || val == C;
```

Good:

```apex
values.contains(val);
```

## Apex Control Flow

- Always prefer early returns.
- If an `if` guard owns more than half of a method, invert the guard and return
  early.

Bad:

```apex
if (valid) {
    run();
    return result;
}
return fallback;
```

Good:

```apex
if (!valid) {
    return fallback;
}
run();
return result;
```

- Never cover impossible cases just to appear defensive or increase coverage.

Bad:

```apex
ctx?.getTriggerId();
```

Good:

```apex
ctx.getTriggerId();
```

## Apex Class Layout

- Keep class elements in this order:

1. public static final constants
2. public static fields
3. public final fields
4. public fields
5. protected final fields
6. protected fields
7. private static final constants
8. private static fields
9. private final fields
10. private fields
11. public accessors
12. private accessors
13. public constructors
14. protected constructors
15. private constructors
16. public static methods
17. public abstract methods
18. public virtual methods
19. public non-virtual methods
20. protected abstract methods
21. private static methods
22. private virtual methods
23. private non-virtual methods
24. public enums
25. public inner interfaces
26. public abstract classes
27. public classes
28. private enums
29. private inner interfaces
30. private abstract classes
31. private classes

- If a class has both public and private methods, separate them with named
  sections. Prefer specific public section names such as `Queries`, `DMLs`,
  `Accessors`, or `Commands`. Use `API` only when no clearer name fits.
  Private methods belong in `Helpers`.

- Repository classes must use `inherited sharing`. Access levels control
  CRUD/FLS enforcement; they do not replace the repository sharing boundary.

```apex
// <editor-fold desc="Queries">
// </editor-fold>

// <editor-fold desc="Helpers">
// </editor-fold>
```

## Apex Fluent Interfaces

- When implementing an interface method, prefer a covariant return type that
  returns the concrete fluent type. Keep the interface return type at the shared
  contract level, and return `this` as the concrete type from the implementation.
  Apex supports this covariance for interface implementations; do not assume the
  same support for class-method overrides.

Interface contract:

```apex
public interface Builder {
    Builder named(String name);
}
```

Concrete implementation:

```apex
public class NamedBuilder implements Builder {
    private String name;

    public NamedBuilder named(final String name) {
        this.name = name;
        return this;
    }
}
```

This preserves the shared interface contract while allowing callers using the
concrete type to continue fluent chaining without a cast.

## Apex Stub API Compatibility

- The concrete `SoqlQuery` and `SqlQuery` classes must remain compatible with
  `Test.createStub`. Mockability is part of the public library contract.
- Do not expose parameterized interfaces such as `Iterable<T>` as parameters on
  the public virtual concrete surface when they prevent stub generation.
- Expose matching, strongly typed `List<T>` and `Set<T>` overloads on both the
  builder interface and concrete class. Do not widen concrete parameters to
  `Object` and do not use interface parameter contravariance as a compatibility
  bridge.
- Delegate both public overloads to one differently named private helper that
  accepts `Iterable<T>`. The private helper preserves reusable iterable-based
  logic without participating in Stub API generation.
- Do not give the private `Iterable<T>` helper the same name as the public
  `List<T>` and `Set<T>` overloads. Apex reports the resulting overload set as an
  ambiguous method signature.
- For methods that return parameterized interfaces, use a **Covariant Return Type
  Wrapper**: preserve the parameterized return type on the interface and return
  a concrete, non-parameterized adapter from the concrete method.
- A single unsupported method can invalidate the generated stub class even when
  a test never calls that method. When a class must support `Test.createStub`,
  probe its complete public virtual method surface after every collection API
  change.
- These failures affect Stub API-generated test classes, not normal production
  dispatch.

### Collection Parameters

Interface contract:

```apex
public interface CollectionBuilder {
    CollectionBuilder addValues(List<Object> values);
    CollectionBuilder addValues(Set<Object> values);
}
```

Concrete implementation:

```apex
public virtual class DefaultCollectionBuilder implements CollectionBuilder {
    private final List<Object> values = new List<Object>();

    public DefaultCollectionBuilder addValues(final List<Object> values) {
        return addValuesFrom(values);
    }

    public DefaultCollectionBuilder addValues(final Set<Object> values) {
        return addValuesFrom(values);
    }

    private DefaultCollectionBuilder addValuesFrom(final Iterable<Object> values) {
        for (Object value : values) {
            this.values.add(value);
        }
        return this;
    }
}
```

This keeps interface and concrete callers type-safe while reusing one private
iterable implementation. Use a semantic helper name such as `addValuesFrom` or
`addInCondition`; never add a same-named private `Iterable<T>` overload.

### Covariant Return Type Wrapper

Replacing an interface return such as `Iterable<Object>` with `Object` widens the
contract and does not implement the interface. Return a concrete adapter that
implements the parameterized interface, stores the original iterable, and
delegates `iterator()` without copying or eagerly consuming it.

Interface contract:

```apex
public interface ResultSource {
    Iterable<Object> results();
}
```

Concrete adapter and implementation:

```apex
public class ObjectIterable implements Iterable<Object> {
    private final Iterable<Object> source;

    public ObjectIterable(final Iterable<Object> source) {
        this.source = source;
    }

    public Iterator<Object> iterator() {
        return source.iterator();
    }
}

public class DefaultResultSource implements ResultSource {
    public ObjectIterable results() {
        return new ObjectIterable(loadResults());
    }
}
```

The interface remains `Iterable<Object>`, while the concrete method exposes a
non-parameterized return type that the Stub API can generate. Because Apex does
not support user-defined generic classes, create separate small adapters when
different element types require different `Iterable<T>` contracts. Keep the
adapter constructor public when Stub providers need to construct a lazy return
value around test data.

Validate both patterns explicitly:

- Create stubs for the complete concrete query classes.
- Invoke both the `List<T>` and `Set<T>` public overloads through generated stubs.
- Invoke collection methods through their builder interfaces to lock exact
  interface conformance.
- Invoke lazy return methods and verify their concrete wrappers preserve lazy
  iteration without copying the source.
- Keep public overloads and their corresponding interface declarations in the
  same logical order.
- Source compatibility does not prove managed-package upgrade or binary
  compatibility. Validate that separately before changing a released public
  method signature.
