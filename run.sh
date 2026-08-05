#!/bin/bash

g++ -std=c++17 -O2 -c some.cpp -o some.o && \
    ar rcs some.a some.o && \
    g++ -std=c++17 -O2 -I. test_some.cpp some.a -o test_some && \
    ./test_some
