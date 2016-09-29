#!/bin/sh
# Concatenate mocha.nut and all unit tests and put in bin/unit-tests.app.nut .
mkdir -p bin
./make-ndn-squirrel.sh
cat ndn-squirrel.nut \
  contrib/kisi-inc/aes-squirrel/aes.class.nut \
  contrib/deldrid1/big.nut/big.class.nut \
  contrib/vukicevic/crunch/crunch.nut \
  tests/unit-tests/mocha.nut \
  tests/unit-tests/test-aes-algorithm.nut \
  tests/unit-tests/test-data-methods.nut \
  tests/unit-tests/test-encrypted-content.nut \
  tests/unit-tests/test-encryptor.nut \
  tests/unit-tests/test-interest-methods.nut \
  tests/unit-tests/test-name-methods.nut \
  tests/unit-tests/test-rsa-algorithm.nut \
  > bin/unit-tests.app.nut
