#ifndef SOME_H
#define SOME_H

#include <memory>

class SomeObject
{
public:
    SomeObject();
    virtual ~SomeObject();
    virtual int getObjectA() const;
    virtual int getObjectB() const;
    int getObjectC() const;
protected:
    struct SomeObjectPrivate;
    std::unique_ptr<SomeObjectPrivate> d_ptr;
};

class SomeItem
{
public:
    SomeItem();
    virtual ~SomeItem();
    virtual int getItemA() const = 0;
    virtual int getItemB() const = 0;
    virtual int getItemC() const;
    virtual int getItemD() const;
    int getItemE() const;
protected:
    struct SomeItemPrivate;
    std::unique_ptr<SomeItemPrivate> d_ptr;
};

class SomeObjectItem : public SomeObject, public SomeItem
{
public:
    SomeObjectItem();
    ~SomeObjectItem() override;
    int getObjectB() const override;
    int getItemB() const override;
    int getItemD() const override;
};

class CustomObjectItem : public SomeObjectItem
{
public:
    CustomObjectItem();
    ~CustomObjectItem() override;
    int getItemA() const override;
    int getItemC() const override;
    int getItemZ() const;
protected:
    struct CustomObjectItemPrivate;
    std::unique_ptr<CustomObjectItemPrivate> d_ptr;
};

#endif
