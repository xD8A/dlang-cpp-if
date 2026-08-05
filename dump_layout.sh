#!/bin/bash
set -e

g++ -std=c++17 -O2 -c some.cpp -o some.o
ldc2 -O2 -c some.d -of=some_d.o
ldc2 -O2 -c test_some.d -of=test_some_d.o

{
echo "===== CPP LAYOUT: some.o (g++ -std=c++17 -O2) ====="
echo ""
echo "===== 1. SECTION LAYOUT ====="
objdump -h some.o
echo ""
echo "===== 2. VTABLE SLOTS (objdump -r, relocations per vtable section) ====="
objdump -r some.o | awk '/^RELOCATION RECORDS FOR \[\.data\.rel\.ro(_\.local)?\._ZTV/{print; getline; print; p=1; next} p&&/^RELOCATION RECORDS/{p=0} p{print}' | c++filt
echo ""
echo "===== 3. VTABLE RAW BYTES ====="
for s in $(objdump -h some.o | grep -oE '\.data\.rel\.ro(\.local)?\.[^ ]*_ZTV[^ ]*'); do
  echo "--- $s ---"
  objdump -s -j "$s" some.o
done
echo ""
echo "===== 4. CLASS SYMBOLS (objdump -t | c++filt) ====="
objdump -t some.o | c++filt | grep -E 'Some(Object|Item)|CustomObjectItem|Some(Object|Item)Private|vtable|typeinfo'
} > layout_cpp.txt

{
echo "===== DLANG LAYOUT: some_d.o + test_some_d.o (ldc2 -O2) ====="
echo ""
echo "===== 1. some_d.o SECTION LAYOUT ====="
objdump -h some_d.o
echo ""
echo "===== 2. some_d.o VTABLE SLOTS (objdump -r | c++filt) ====="
objdump -r some_d.o | awk '/^RELOCATION RECORDS FOR \[[^]]*(__vtblZ|__initZ)/{print; getline; print; p=1; next} p&&/^RELOCATION RECORDS/{p=0} p{print}' | c++filt -s dlang | c++filt
echo ""
echo "===== 3. some_d.o CLASS DATA RAW (__initZ / __vtblZ) ====="
for s in $(objdump -h some_d.o | grep -oE '\.(data\.rel\.ro|rodata)\.[^ ]*(__initZ|__vtblZ)' | grep -E 'SomeObject|SomeItem'); do
  echo "--- $s ---"
  objdump -s -j "$s" some_d.o
done
echo ""
echo "===== 4. some_d.o CLASS SYMBOLS ====="
objdump -t some_d.o | c++filt -s dlang | c++filt | grep -E 'Some(Object|Item)|vtable|Class|initializer'
echo ""
echo "===== 5. test_some_d.o D-GENERATED VTABLE SLOTS ====="
objdump -r test_some_d.o | awk '/^RELOCATION RECORDS FOR \[[^]]*(__vtblZ|__initZ|SomeItemInterface)/{print; getline; print; p=1; next} p&&/^RELOCATION RECORDS/{p=0} p{print}' | c++filt -s dlang | c++filt
echo ""
echo "===== 6. test_some_d.o CLASS SYMBOLS ====="
objdump -t test_some_d.o | c++filt -s dlang | c++filt | grep -E 'TestItem|TestObjectItem|SomeItemInterface|vtable|Class|initializer'
} > layout_dlang.txt

echo "OK: layout_cpp.txt, layout_dlang.txt"
