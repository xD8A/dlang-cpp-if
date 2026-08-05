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

abstract class SomeItem
{
public:
    this();
    ~this();
    int getItemA() const;
    int getItemB() const;
    int getItemC() const;
    int getItemD() const;
    final int getItemE() const;

protected:
    void* d_ptr;
}


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
    final int getItemE() const { return asConstSomeItem().getItemE(); }
private:
    pragma(inline, true) const(SomeItem) asConstSomeItem() const
    {
        return cast(const(SomeItem))(cast(void*)(cast(byte*)&baseItemInterface - (void*).sizeof));
    }
}


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