#!/bin/sh
# Concatenate all NDN-Squirrel library files into ndn-squirrel.nut .
cat \
  src/util/imp-compatibility.nut \
  src/util/buffer.nut \
  src/util/blob.nut \
  src/util/change-counter.nut \
  src/util/crypto.nut \
  src/util/dynamic-blob-array.nut \
  src/util/ndn-common.nut \
  src/util/signed-blob.nut \
  src/name.nut \
  src/key-locator.nut \
  src/exclude.nut \
  src/interest.nut \
  src/interest-filter.nut \
  src/meta-info.nut \
  src/generic-signature.nut \
  src/hmac-with-sha256-signature.nut \
  src/sha256-with-rsa-signature.nut \
  src/data.nut \
  src/encoding/tlv/tlv.nut \
  src/encoding/tlv/tlv-decoder.nut \
  src/encoding/tlv/tlv-encoder.nut \
  src/encoding/tlv/tlv-structure-decoder.nut \
  src/encoding/element-reader.nut \
  src/encoding/wire-format.nut \
  src/encoding/tlv-0_2-wire-format.nut \
  src/encoding/tlv-wire-format.nut \
  src/encrypt/algo/encrypt-params.nut \
  src/encrypt/algo/aes-algorithm.nut \
  src/encrypt/decrypt-key.nut \
  src/encrypt/encrypt-key.nut \
  src/impl/interest-filter-table.nut \
  src/impl/pending-interest-table.nut \
  src/transport/transport.nut \
  src/transport/squirrel-object-transport.nut \
  src/transport/micro-forwarder-transport.nut \
  src/face.nut \
  > ndn-squirrel.nut
