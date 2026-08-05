# C++ to D: Multiple Inheritance Interfacing

This repository demonstrates how to bind C++ classes that use **multiple
inheritance** to D. D classes support only **single class inheritance** plus
interfaces, so a C++ class with two or more class bases cannot be declared
directly in D. This guide documents a working pattern, the vtable-layout rules
behind it, and the tools used to verify it.

## Contents

- [1. The C++ hierarchy](#1-the-c-hierarchy)
- [2. D binding: step by step](#2-d-binding-step-by-step)
- [3. Why the vtable slot order matters](#3-why-the-vtable-slot-order-matters)
- [4. Verification and debugging](#4-verification-and-debugging)
- [5. Build and run](#5-build-and-run)
- [6. Pitfalls](#6-pitfalls)

## 1. The C++ hierarchy

The C++ side (`some.h` / `some.cpp`) defines:

```
SomeObject  (virtual dtor, virtual getObjectA/getObjectB, non-virtual getObjectC, d_ptr)
SomeItem    (abstract: pure getItemA/getItemB, virtual getItemC/getItemD,
             non-virtual getItemE, d_ptr)
SomeObjectItem : public SomeObject, public SomeItem   // MULTIPLE INHERITANCE
    overrides: getObjectB (SomeObject), getItemB/getItemD (SomeItem)
CustomObjectItem : public SomeObjectItem               // adds its own d_ptr
    overrides: getItemA, getItemC
```

Note the quirks that matter for binding:

- `SomeObjectItem` inherits **two polymorphic classes**, so its objects carry
  **two vtable pointers** (primary vptr for `SomeObject`, secondary vptr for
  `SomeItem`).
- `SomeItem` is *abstract*, so it cannot be a D class base that D
  instantiates; the D side needs a manual "fake subobject".
- Some methods are non-virtual in C++ (`getObjectC`, `getItemE`,
  `getItemZ`) — D must not put them into the vtable.

## 2. D binding: step by step

All declarations live under `extern(C++):` in `some.d` so that D uses the
C++ ABI (C++ name mangling, no D `Object` base, no D runtime vtable).

### 2.1 Bind simple single-inheritance classes directly

```d
extern(C++) class SomeObject
{
    this();
    ~this();
    int getObjectA() const;   // virtual: vtable slot
    int getObjectB() const;
    final int getObjectC() const;   // non-virtual in C++ -> final direct call
protected:
    void* d_ptr;              // layout only: matches C++ unique_ptr (8 bytes)
}
```

- `this()` / `~this()` link to the C++ mangled ctor/dtor
  (`_ZN10SomeObjectC1Ev`, `_ZN10SomeObjectD1Ev`).
- A D class method is virtual by default; the vtable slot index is assigned
  in **declaration order**, so declare virtuals in the same order as C++.
- `final` methods are not virtual: D calls them directly by their mangled
  name — exactly what a C++ non-virtual call does.
- `void* d_ptr` is not used by D; it exists only so `new SomeObject()`
  allocates the same size as C++ (vptr + 8 bytes).

### 2.2 Model the multiple-inheritance class

A D class can have **one class base + any number of interfaces**. So:

```
D class SomeObjectItem : SomeObject, SomeItemInterface
```

- `SomeObject` — the *primary* C++ base (its vptr is at offset 0).
- `SomeItemInterface` — an `extern(C++)` interface mirroring the virtual
  functions of the *secondary* base:

```d
interface SomeItemInterface
{
    int getItemB() const;
    int getItemC() const;
    int getItemD() const;
}
```

### 2.3 Fake subobject for layout

The secondary base occupies real memory after the primary base. Its size is
`classInstanceSize(SomeItem)` (vptr + d_ptr = 16 bytes on x86-64). Reserve
that space with a data field:

```d
static assert(__traits(classInstanceSize, SomeItem) == (void*).sizeof * 2);
struct SomeItemFakeInheritance
{
    void*[__traits(classInstanceSize, SomeItem) / (void*).sizeof - 1] data;
}
```

The D layout of `SomeObjectItem` then matches C++:
`[primary vptr][SomeObject.d_ptr][SomeItem subobject: vptr + d_ptr]`.

### 2.4 Align the virtual slot order (the critical part)

D dispatches *all* virtual calls through the **primary vptr** (offset 0)
using slot indices. For the `getItem*` family, D's slot indices must point
at the same functions that the C++ complete-object vtable stores there.

Empirically (verified with `objdump -r` and `dladdr`) the C++ complete-object
vtable for `CustomObjectItem` is:

```
[0] D2   [1] D0   [2] SomeObject::getObjectA
[3] SomeObjectItem::getObjectB
[4] SomeObjectItem::getItemB      <- secondary-base overrides, in order of
[5] SomeObjectItem::getItemD         first declaration down the hierarchy
[6] CustomObjectItem::getItemA    <- most-derived overrides follow
[7] CustomObjectItem::getItemC
[8] offset-to-top   [9] typeinfo
```

i.e. slots 4..7 are `[getItemB, getItemD, getItemA, getItemC]` — **not**
`[A, B, C, D]`. Since D assigns slots in declaration order, declare the
methods in `SomeObjectItem` in exactly that order:

```d
abstract class SomeObjectItem : SomeObject, SomeItemInterface
{
    SomeItemFakeInheritance baseItemInterface;
public:
    this();
    ~this();
    override int getObjectB() const;              // slot 3
    override int getItemB() const;                // slot 4
    override int getItemD() const;                // slot 5
    int getItemA() const { assert(0); }           // slot 6 (pure in C++)
    override int getItemC() const { return asConstSomeItem().getItemC(); }  // slot 7
    final int getItemE() const { return asConstSomeItem().getItemE(); }     // not virtual
private:
    pragma(inline, true) const(SomeItem) asConstSomeItem() const
    {
        return cast(const(SomeItem))(cast(void*)(cast(byte*)&baseItemInterface - (void*).sizeof));
    }
}
```

Rules that keep the mapping correct:

- Keep the D declaration order of virtuals identical to the C++ vtable slot
  order (re-verify with `__traits(getVirtualIndex, ...)` after any change).
- Methods that C++ does not override at a level still occupy the inherited
  slot; `CustomObjectItem` declares `override int getItemA() const;` and
  `override int getItemC() const;` which reuse slots 6 and 7.
- Never declare a *non-virtual* C++ method as virtual in D — mark it
  `final`, otherwise D inserts it into the vtable and shifts every following
  slot.

### 2.5 Reaching the secondary vtable

C++ dispatch for the secondary base goes through the **secondary vptr**
(object offset 16). D has no language support for it, so the binding walks
there manually:

- `asConstSomeItem()` computes the `SomeItem*` for the fake subobject
  (`&baseItemInterface - sizeof(void*)` points at the subobject vptr).
- Calling a virtual *through* that pointer (`asConstSomeItem().getItemC()`)
  dispatches through the real secondary vtable, so it reaches the most
  derived C++ override:
  - `CustomObjectItem::getItemC` → 1013
  - `TestObjectItem::getItemC` → 13 (SomeItem's own)
- Use the same pattern in D-defined derived classes whenever a method lives
  in the secondary vtable.

### 2.6 D-defined derived classes

A D test class mirrors the C++ `TestObjectItem`:

```d
extern(C++) class TestObjectItem : SomeObjectItem
{
    this() {}
    override int getItemA() const { return 1; }
}
```

D generates the full C++-ABI class: ctor chain calls
`SomeObjectItem::SomeObjectItem()` (the real C++ ctor, which also
initializes the fake subobject), and D emits a vtable whose slots match the
order fixed in 2.4 — the same order the C++ vtable uses.

## 3. Why the vtable slot order matters

Without the reordering in 2.4 the symptom is a **shifted dispatch**: every
virtual `getItem*` call lands on the neighbouring function

```
FAIL coi.getItemA = 112 (expected 1011)   // called SomeObjectItem::getItemB
FAIL coi.getItemB = 114 (expected 112)    // called SomeObjectItem::getItemD
FAIL coi.getItemC = 1011 (expected 1013)  // called CustomObjectItem::getItemA
FAIL coi.getItemD = 1013 (expected 114)   // called CustomObjectItem::getItemC
```

Root cause: D assigned slots in declaration order `[A, B, C, D]` while the
C++ complete-object vtable stores `[getItemB, getItemD, getItemA, getItemC]`
(overrides ordered by first declaration in the class hierarchy). Reordering
the D declarations makes the two layouts identical.

## 4. Verification and debugging

### 4.1 Runtime tests

`test_some.cpp` and `test_some.d` run the same checks (PASS/FAIL, exit code):

- `SomeObject` getters,
- `SomeItem` methods via a derived test class,
- `SomeObjectItem` overrides via `TestObjectItem`,
- `CustomObjectItem` full set, including non-virtual `getItemZ`,
- virtual dispatch through base pointers (`SomeObject*`, `SomeItem*`).

### 4.2 Compile-time probes

```d
pragma(msg, __traits(getVirtualIndex, SomeObjectItem.getItemA)); // slot index
static assert(__traits(classInstanceSize, SomeItem) == 16);
```

### 4.3 Layout dump

`dump_layout.sh` compiles the objects and produces `layout_cpp.txt` /
`layout_dlang.txt` using `objdump | c++filt` (for D symbols also
`c++filt -s dlang`). The vtable slots appear as **relocations**:

```
RELOCATION RECORDS FOR [.data.rel.ro._ZTV14SomeObjectItem]:
OFFSET           TYPE           VALUE
0000000000000020 R_X86_64_64    SomeObject::getObjectA() const
0000000000000028 R_X86_64_64    SomeObjectItem::getObjectB() const
0000000000000030 R_X86_64_64    SomeObjectItem::getItemB() const
...
```

The D side shows the generated tables (`__vtblZ`), instance initializers
(`__initZ`, which also reveal the interface subobject vptr at offset 0x10 —
`Thn16_`), and the thunk vtable for `SomeItemInterface`.

### 4.4 Runtime vtable inspection (C++)

For a fully linked binary, name every vtable entry with `dladdr`:

```cpp
Dl_info info;
dladdr(((void***)&o)[0][i], &info);
```

## 5. Build and run

```
./run.sh     # g++: some.a + test_some.cpp  -> ./test_some
./rund.sh    # ldc2: test_some.d + some.d + some.a -> ./test_some_d
./dump_layout.sh   # regenerate layout_cpp.txt / layout_dlang.txt
```

Linking D against the C++ library:

```
ldc2 -O2 test_some.d some.d some.a -L-lstdc++ -of=test_some_d
```

## 6. Pitfalls

1. **D has no multiple class inheritance.** Use one class base + interfaces,
   and reserve the secondary subobject manually.
2. **Vtable slot order is not source order in the C++ complete-object
   vtable.** Secondary-base overrides appear in order of first declaration
   down the hierarchy; align D declarations to the *actual* vtable, not to
   the C++ header's method order.
3. **Never bind a C++ non-virtual method as virtual in D.** Use `final`;
   a stray virtual slot shifts every following slot and produces silent
   wrong calls.
4. **Pure virtual functions** have no C++ definition; give them a D body
   (`assert(0)`) so the class stays abstract and the slot exists.
5. **Layout size matters.** `new` in D allocates by the D-computed instance
   size; keep `d_ptr` fields so the size matches the C++ object, otherwise
   the C++ constructor writes past the allocation.
6. **Interfaces must be `extern(C++)`** for the C++ ABI
   (`extern(C++)` classes cannot implement a plain D interface).
7. **`classinfo` is null** for `extern(C++)` classes — do not rely on
   `SomeClass.classinfo`; use `__traits(classInstanceSize, ...)` and
   `__traits(getVirtualIndex, ...)` instead.
8. **Mismatches are silent.** A wrong slot order does not crash; it calls a
   neighbouring method. Always run the value checks from section 4.1 after
   changing any declaration order.
