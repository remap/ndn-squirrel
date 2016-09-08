#!/bin/sh
# Concatenate mocha.nut and all unit tests and put in bin/unit-tests.app.nut .
mkdir -p bin
./make-ndn-squirrel.sh
cat ndn-squirrel.nut \
  contrib/aes-squirrel/aes.class.nut \
  tests/unit-tests/mocha.nut \
  tests/unit-tests/test-aes-algorithm.nut \
  tests/unit-tests/test-name-methods.nut \
  > bin/unit-tests.app.nut
