#include "some.h"

struct SomeObject::SomeObjectPrivate
{
    int a = 1;
    int b = 2;
    int c = 3;
};

SomeObject::SomeObject()
    : d_ptr(std::make_unique<SomeObjectPrivate>())
{
}

SomeObject::~SomeObject() = default;

int SomeObject::getObjectA() const { return d_ptr->a; }
int SomeObject::getObjectB() const { return d_ptr->b; }
int SomeObject::getObjectC() const { return d_ptr->c; }

struct SomeItem::SomeItemPrivate
{
    int c = 13;
    int d = 14;
    int e = 15;
    int f = 16;
};

SomeItem::SomeItem()
    : d_ptr(std::make_unique<SomeItemPrivate>())
{
}

SomeItem::~SomeItem() = default;

int SomeItem::getItemC() const { return d_ptr->c; }
int SomeItem::getItemD() const { return d_ptr->d; }
int SomeItem::getItemF() const { return d_ptr->f; }
int SomeItem::getItemG() const { return getItemF(); }   // virtual call, dispatches via the SomeItem vptr
int SomeItem::getItemE() const { return d_ptr->e; }

SomeObjectItem::SomeObjectItem() = default;
SomeObjectItem::~SomeObjectItem() = default;

int SomeObjectItem::getObjectB() const { return 102; }
int SomeObjectItem::getItemB() const { return 112; }
int SomeObjectItem::getItemD() const { return 114; }

struct CustomObjectItem::CustomObjectItemPrivate
{
    int z = 10;
};

CustomObjectItem::CustomObjectItem()
    : d_ptr(std::make_unique<CustomObjectItemPrivate>())
{
}

CustomObjectItem::~CustomObjectItem() = default;

int CustomObjectItem::getItemA() const { return 1011; }
int CustomObjectItem::getItemC() const { return 1013; }
int CustomObjectItem::getItemZ() const { return d_ptr->z; }
