#!/bin/sh
# Concatenate ndn-squirrel.nut and all needed for each example and put in "bin".
mkdir -p bin
./make-ndn-squirrel.sh
cat ndn-squirrel.nut \
  examples/test-encode-decode-benchmark.nut \
  > bin/test-encode-decode-benchmark.nut
cat ndn-squirrel.nut \
  examples/test-encode-decode-data.nut \
  > bin/test-encode-decode-data.nut
cat ndn-squirrel.nut \
  examples/test-encode-decode-interest.nut \
  > bin/test-encode-decode-interest.nut
cat ndn-squirrel.nut \
  examples/test-imp-echo-consumer.nut \
  > bin/test-imp-echo-consumer.nut
cat ndn-squirrel.nut \
  tools/micro-forwarder.nut \
  examples/test-imp-publish-async.nut \
  > bin/test-imp-publish-async.nut
