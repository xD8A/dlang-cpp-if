module some;

extern(C++):

class SomeObject
{
public:
    this();
    ~this();
    int getObjectA() const;
    int getObjectB() const;
    final int getObjectC() const;

protected:
    void* d_ptr;
}

static assert(__traits(getVirtualIndex, SomeObject.getObjectA) == 2);
static assert(__traits(getVirtualIndex, SomeObject.getObjectB) == 3);
static assert(__traits(getVirtualIndex, SomeObject.getObjectC) == -1);

abstract class SomeItem
{
public:
    this();
    ~this();
    int getItemA() const;
    int getItemB() const;
    int getItemC() const;
    int getItemD() const;
    int getItemF() const;   // dispatch probe: virtual, C++ base returns 16
    int getItemG() const;   // C++ implementation calls getItemF()
    final int getItemE() const;

protected:
    void* d_ptr;
}

static assert(__traits(getVirtualIndex, SomeItem.getItemA) == 2);
static assert(__traits(getVirtualIndex, SomeItem.getItemB) == 3);
static assert(__traits(getVirtualIndex, SomeItem.getItemC) == 4);
static assert(__traits(getVirtualIndex, SomeItem.getItemD) == 5);
static assert(__traits(getVirtualIndex, SomeItem.getItemF) == 6);
static assert(__traits(getVirtualIndex, SomeItem.getItemG) == 7);
static assert(__traits(getVirtualIndex, SomeItem.getItemE) == -1);


interface SomeItemInterface
{
    int getItemB() const;
    int getItemC() const;
    int getItemD() const;
}


static assert(__traits(classInstanceSize, SomeItem) == (void*).sizeof * 2);
struct SomeItemFakeInheritance
{
    static assert(__traits(classInstanceSize, SomeItem) % (void*).sizeof == 0);
    void*[__traits(classInstanceSize, SomeItem) / (void*).sizeof - 1] data;
}

abstract class SomeObjectItem : SomeObject, SomeItemInterface
{
    SomeItemFakeInheritance baseItemInterface;
public:
    this();
    ~this();
    override int getObjectB() const;
    override int getItemB() const;
    override int getItemD() const;
    int getItemA() const { assert(0); }
    override int getItemC() const { return asConstSomeItem().getItemC(); }
    int getItemF() const { assert(0); }
    final int getItemE() const { return asConstSomeItem().getItemE(); }
protected:
    final void installSecondaryVtable(void* classInit)
    {
        enum offset = 16;
        enum someItemSlots = 8;
        __gshared static void*[someItemSlots] table;
        __gshared static void* cachedInit;

        auto thisObj = cast(byte*)this;
        if (cachedInit != classInit)
        {
            auto cppVtbl = cast(void**)*cast(void***)(thisObj + offset);
            table[0 .. someItemSlots] = cppVtbl[0 .. someItemSlots];

            auto init = cast(byte*)classInit;
            auto dPrimary = cast(void**)*cast(void***)(init + 0);
            auto dThunk = cast(void**)*cast(void***)(init + offset);

            table[2] = dPrimary[6];
            table[3] = dThunk[0];
            table[4] = dThunk[1];
            table[5] = dThunk[2];
            table[6] = dPrimary[8];
            cachedInit = classInit;
        }
        *cast(void***)(thisObj + offset) = table.ptr;
    }
private:
    pragma(inline, true) const(SomeItem) asConstSomeItem() const
    {
        return cast(const(SomeItem))(cast(void*)(cast(byte*)&baseItemInterface - (void*).sizeof));
    }

    pragma(inline, true) SomeItem asSomeItem()
    {
        return cast(SomeItem)(cast(void*)(cast(byte*)&baseItemInterface - (void*).sizeof));
    }
}

static assert(__traits(getVirtualIndex, SomeObjectItem.getObjectB) == 3);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemB) == 4);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemD) == 5);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemA) == 6);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemC) == 7);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemF) == 8);
static assert(__traits(getVirtualIndex, SomeObjectItem.getItemE) == -1);


class CustomObjectItem : SomeObjectItem
{
public:
    this();
    ~this();
    override int getItemA() const;
    override int getItemC() const;
    final int getItemZ() const;

protected:
    void* d_ptr;
}

static assert(__traits(getVirtualIndex, CustomObjectItem.getItemA) == 6);
static assert(__traits(getVirtualIndex, CustomObjectItem.getItemC) == 7);
static assert(__traits(getVirtualIndex, CustomObjectItem.getItemZ) == -1);
