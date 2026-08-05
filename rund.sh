#!/bin/bash

ldc2 -O2 test_some.d some.d some.a -L-lstdc++ -of=test_some_d && \
    ./test_some_d
