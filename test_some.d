import std.stdio;
import some;

extern(C++) class TestItem : SomeItem
{
    this() {}
    override int getItemA() const { return 1; }
    override int getItemB() const { return 2; }
}

extern(C++) class TestObjectItem : SomeObjectItem
{
    this() { super(); }
    override int getItemA() const { return 1; }
    override int getItemC() const { return 2; }
    override int getItemF() const { return 1; }
    final void install()
    {
        installSecondaryVtable(cast(void*)__traits(initSymbol, TestObjectItem));
    }
}

int failures;

void check(string name, int actual, int expected)
{
    if (actual == expected)
        writefln("PASS %-12s = %d", name, actual);
    else {
        writefln("FAIL %-12s = %d (expected %d)", name, actual, expected);
        ++failures;
    }
}

int main()
{
    writeln("=== SomeObject ===");
    auto so = new SomeObject();
    check("so.getObjectA", so.getObjectA(), 1);
    check("so.getObjectB", so.getObjectB(), 2);
    check("so.getObjectC", so.getObjectC(), 3);

    writeln("=== SomeItem (via TestItem) ===");
    auto ti = new TestItem();
    check("ti.getItemA", ti.getItemA(), 1);
    check("ti.getItemB", ti.getItemB(), 2);
    check("ti.getItemC", ti.getItemC(), 13);
    check("ti.getItemD", ti.getItemD(), 14);
    check("ti.getItemE", ti.getItemE(), 15);
    check("ti.getItemF", ti.getItemF(), 16);

    writeln("=== SomeObjectItem (via TestObjectItem) ===");
    auto toi = new TestObjectItem();
    check("toi.getItemA", toi.getItemA(), 1);
    check("toi.getItemB", toi.getItemB(), 112);
    check("toi.getItemC", toi.getItemC(), 2);
    check("toi.getItemD", toi.getItemD(), 114);
    check("toi.getItemE", toi.getItemE(), 15);
    check("toi.getItemF", toi.getItemF(), 1);   // D dispatch via primary vptr

    writeln("=== secondary vptr WITHOUT install (C++ tables) ===");
    SomeItem psi2 = cast(SomeItem)(cast(void*)(cast(byte*)&toi.baseItemInterface - (void*).sizeof));
    check("psi2.getItemB", psi2.getItemB(), 112);
    check("psi2.getItemC", psi2.getItemC(), 13);
    check("psi2.getItemD", psi2.getItemD(), 114);
    check("psi2.getItemE", psi2.getItemE(), 15);
    check("psi2.getItemF", psi2.getItemF(), 16);  // C++ SomeItem base implementation
    check("psi2.getItemG", psi2.getItemG(), 16);  // C++ getItemG -> internal getItemF -> C++ 16

    writeln("=== installSecondaryVtable ===");
    toi.install();

    writeln("=== secondary vptr WITH install (D entries) ===");
    check("psi2.getItemA", psi2.getItemA(), 1);   // D override reachable via secondary vptr
    check("psi2.getItemB", psi2.getItemB(), 112);
    check("psi2.getItemC", psi2.getItemC(), 2);   // D override reachable via secondary vptr
    check("psi2.getItemD", psi2.getItemD(), 114);
    check("psi2.getItemE", psi2.getItemE(), 15);
    check("psi2.getItemF", psi2.getItemF(), 1);   // D override reachable via secondary vptr
    check("psi2.getItemG", psi2.getItemG(), 1);   // C++ getItemG -> internal getItemF -> D override 1

    writeln("=== CustomObjectItem ===");
    auto coi = new CustomObjectItem();
    check("coi.getObjectA", coi.getObjectA(), 1);
    check("coi.getObjectB", coi.getObjectB(), 102);
    check("coi.getObjectC", coi.getObjectC(), 3);
    check("coi.getItemA", coi.getItemA(), 1011);
    check("coi.getItemB", coi.getItemB(), 112);
    check("coi.getItemC", coi.getItemC(), 1013);
    check("coi.getItemD", coi.getItemD(), 114);
    check("coi.getItemZ", coi.getItemZ(), 10);

    writeln("=== virtual dispatch via SomeObject* ===");
    SomeObject pso = coi;
    check("pso.getObjectA", pso.getObjectA(), 1);
    check("pso.getObjectB", pso.getObjectB(), 102);
    check("pso.getObjectC", pso.getObjectC(), 3);

    writeln("=== virtual dispatch via SomeItem* ===");
    SomeItem psi = ti;
    check("psi.getItemA", psi.getItemA(), 1);
    check("psi.getItemB", psi.getItemB(), 2);
    check("psi.getItemC", psi.getItemC(), 13);

    if (failures == 0) {
        writeln("All tests passed");
        return 0;
    }
    writefln("%d test(s) failed", failures);
    return 1;
}
