#include "some.h"

#include <cstdio>

namespace {

class TestObjectItem : public SomeObjectItem
{
public:
    int getItemA() const override { return 1; }
};

int g_failures = 0;

void check(const char* name, int actual, int expected)
{
    if (actual == expected)
        std::printf("PASS %-12s = %d\n", name, actual);
    else {
        std::printf("FAIL %-12s = %d (expected %d)\n", name, actual, expected);
        ++g_failures;
    }
}

} // namespace

int main()
{
    std::printf("=== SomeObject ===\n");
    SomeObject so;
    check("so.getObjectA", so.getObjectA(), 1);
    check("so.getObjectB", so.getObjectB(), 2);
    check("so.getObjectC", so.getObjectC(), 3);

    std::printf("=== SomeObjectItem (via TestObjectItem) ===\n");
    TestObjectItem ti;
    check("ti.getItemA", ti.getItemA(), 1);
    check("ti.getItemB", ti.getItemB(), 112);
    check("ti.getItemC", ti.getItemC(), 13);
    check("ti.getItemD", ti.getItemD(), 114);
    check("ti.getItemE", ti.getItemE(), 15);

    std::printf("=== CustomObjectItem ===\n");
    CustomObjectItem coi;
    check("coi.getObjectA", coi.getObjectA(), 1);
    check("coi.getObjectB", coi.getObjectB(), 102);
    check("coi.getObjectC", coi.getObjectC(), 3);
    check("coi.getItemA", coi.getItemA(), 1011);
    check("coi.getItemB", coi.getItemB(), 112);
    check("coi.getItemC", coi.getItemC(), 1013);
    check("coi.getItemD", coi.getItemD(), 114);
    check("coi.getItemZ", coi.getItemZ(), 10);

    std::printf("=== virtual dispatch via SomeObject* ===\n");
    SomeObject* pso = &coi;
    check("pso->getObjectA", pso->getObjectA(), 1);
    check("pso->getObjectB", pso->getObjectB(), 102);
    check("pso->getObjectC", pso->getObjectC(), 3);

    if (g_failures == 0) {
        std::printf("All tests passed\n");
        return 0;
    }
    std::printf("%d test(s) failed\n", g_failures);
    return 1;
}
