#!/bin/sh
# Concatenate ndn-squirrel.nut and all needed for each example and put in "bin".
mkdir -p bin
./make-ndn-squirrel.sh
cat ndn-squirrel.nut \
  examples/test-encode-decode-benchmark.nut \
  > bin/test-encode-decode-benchmark.app.nut
cat ndn-squirrel.nut \
  examples/test-encode-decode-data.nut \
  > bin/test-encode-decode-data.app.nut
cat ndn-squirrel.nut \
  examples/test-encode-decode-interest.nut \
  > bin/test-encode-decode-interest.app.nut
cat ndn-squirrel.nut \
  contrib/kisi-inc/aes-squirrel/aes.class.nut \
  contrib/deldrid1/big.nut/big.class.nut \
  contrib/vukicevic/crunch/crunch.nut \
  examples/test-imp-echo-consumer.agent.nut \
  > bin/test-imp-echo-consumer.agent.app.nut
cat ndn-squirrel.nut \
  contrib/kisi-inc/aes-squirrel/aes.class.nut \
  contrib/deldrid1/big.nut/big.class.nut \
  contrib/vukicevic/crunch/crunch.nut \
  tools/micro-forwarder.nut \
  examples/test-imp-publish-async.device.nut \
  > bin/test-imp-publish-async.device.app.nut
cat ndn-squirrel.nut \
  tools/micro-forwarder.nut \
  examples/agent-device-stubs.nut \
  examples/test-micro-forwarder.nut \
  > bin/test-micro-forwarder.app.nut
