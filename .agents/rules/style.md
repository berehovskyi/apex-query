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

- For public Apex libraries whose classes are intended to be mocked, Stub API
  support takes priority over compile-time type safety on the concrete
  implementation surface. Preserve the strongest typed contract on interfaces,
  but accept a narrow, documented loss of parameter type safety in the concrete
  class when a live `Test.createStub` probe proves that Apex cannot generate the
  typed signature.
- Treat collection-related Stub API failures as signature-specific, not as a
  general lack of `List` support. Ordinary typed lists can be stubbable. The
  observed failures involve fluent self-returning methods with
  `Iterable<Object>` or `List<Object>` parameters and concrete methods returning
  `Iterable<T>`; verify the exact signature on the project's Apex API version
  before applying a workaround.
- A single unsupported method can invalidate the generated stub class even when
  a test never calls that method. When a class must support `Test.createStub`,
  probe its complete public/virtual method surface after adding `Iterator`,
  `Iterable`, or generic collection overloads.
- These failures affect Stub API-generated test classes, not normal production
  dispatch.
- When an interface method accepts `Iterable<Object>` or `List<Object>` and a
  focused probe confirms that the matching fluent concrete signature breaks the
  Stub API, keep the typed interface contract. In the concrete implementation
  only, accept `Object` and immediately cast it to the contract type at the
  delegation boundary.

Interface contract:

```apex
public interface CollectionBuilder {
    CollectionBuilder addValues(Iterable<Object> values);
}
```

Concrete implementation:

```apex
public virtual class DefaultCollectionBuilder implements CollectionBuilder {
    private final List<Object> values = new List<Object>();

    /**
     * @param values Iterable of values; declared as `Object` for Stub API compatibility
     * @return this builder
     */
    public DefaultCollectionBuilder addValues(final Object values) {
        for (Object value : (Iterable<Object>) values) {
            this.values.add(value);
        }
        return this;
    }
}
```

This is an intentional Apex compatibility bridge: existing interface consumers
retain the typed method, concrete callers remain source-compatible because every
`Iterable<Object>` is also an `Object`, and the implementation avoids the Stub
API limitation.

- Document every weakened concrete parameter with ApexDoc that states its real
  runtime type, for example `@param values Iterable of values`. Explain
  separately that the concrete parameter is declared as `Object` for Stub API
  compatibility. Do not make callers infer the required type from an
  implementation cast.
- Return types cannot use the same `Object` bridge. Replacing an interface return
  such as `Iterable<Object>` with `Object` widens the contract and does not
  implement the interface. Instead, return a covariant concrete adapter that
  implements the typed interface, stores the original iterable, and delegates
  `iterator()` without copying or eagerly consuming it.

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

Use this bridge narrowly:

- Do not weaken the interface parameter to `Object`.
- Do not replace ordinary collection parameters without a reproducing Stub API
  test.
- Concrete callers lose compile-time parameter safety and invalid values fail at
  the cast. Interface-typed callers retain the typed contract.
- Stub providers observe `Object` as the concrete parameter type. Review argument
  matching and overload resolution, especially calls with `null`.
- Keep a regression test that both creates the concrete stub and invokes at least
  one bridged method. Stub creation verifies the complete method surface; method
  invocation verifies the provider's parameter and return handling.
- Source compatibility does not prove managed-package upgrade or binary
  compatibility. Validate that separately before changing a released public
  method signature.
