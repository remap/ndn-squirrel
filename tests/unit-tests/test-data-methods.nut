/**
 * Copyright (C) 2016-2017 Regents of the University of California.
 * @author: Jeff Thompson <jefft0@remap.ucla.edu>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * A copy of the GNU Lesser General Public License is in the file COPYING.
 */

local codedData = Buffer([
0x06, 0xCE, // NDN Data
  0x07, 0x0A, 0x08, 0x03, 0x6E, 0x64, 0x6E, 0x08, 0x03, 0x61, 0x62, 0x63, // Name
  0x14, 0x0A, // MetaInfo
    0x19, 0x02, 0x13, 0x88, // FreshnessPeriod
    0x1A, 0x04, // FinalBlockId
      0x08, 0x02, 0x00, 0x09, // NameComponent
  0x15, 0x08, 0x53, 0x55, 0x43, 0x43, 0x45, 0x53, 0x53, 0x21, // Content
  0x16, 0x28, // SignatureInfo
    0x1B, 0x01, 0x01, // SignatureType
    0x1C, 0x23, // KeyLocator
      0x07, 0x21, // Name
        0x08, 0x08, 0x74, 0x65, 0x73, 0x74, 0x6E, 0x61, 0x6D, 0x65,
        0x08, 0x03, 0x4B, 0x45, 0x59,
        0x08, 0x07, 0x44, 0x53, 0x4B, 0x2D, 0x31, 0x32, 0x33,
        0x08, 0x07, 0x49, 0x44, 0x2D, 0x43, 0x45, 0x52, 0x54,
  0x17, 0x80, // SignatureValue
    0x1A, 0x03, 0xC3, 0x9C, 0x4F, 0xC5, 0x5C, 0x36, 0xA2, 0xE7, 0x9C, 0xEE, 0x52, 0xFE, 0x45, 0xA7,
    0xE1, 0x0C, 0xFB, 0x95, 0xAC, 0xB4, 0x9B, 0xCC, 0xB6, 0xA0, 0xC3, 0x4A, 0xAA, 0x45, 0xBF, 0xBF,
    0xDF, 0x0B, 0x51, 0xD5, 0xA4, 0x8B, 0xF2, 0xAB, 0x45, 0x97, 0x1C, 0x24, 0xD8, 0xE2, 0xC2, 0x8A,
    0x4D, 0x40, 0x12, 0xD7, 0x77, 0x01, 0xEB, 0x74, 0x35, 0xF1, 0x4D, 0xDD, 0xD0, 0xF3, 0xA6, 0x9A,
    0xB7, 0xA4, 0xF1, 0x7F, 0xA7, 0x84, 0x34, 0xD7, 0x08, 0x25, 0x52, 0x80, 0x8B, 0x6C, 0x42, 0x93,
    0x04, 0x1E, 0x07, 0x1F, 0x4F, 0x76, 0x43, 0x18, 0xF2, 0xF8, 0x51, 0x1A, 0x56, 0xAF, 0xE6, 0xA9,
    0x31, 0xCB, 0x6C, 0x1C, 0x0A, 0xA4, 0x01, 0x10, 0xFC, 0xC8, 0x66, 0xCE, 0x2E, 0x9C, 0x0B, 0x2D,
    0x7F, 0xB4, 0x64, 0xA0, 0xEE, 0x22, 0x82, 0xC8, 0x34, 0xF7, 0x9A, 0xF5, 0x51, 0x12, 0x2A, 0x84,
1
]);

local experimentalSignatureType = 100;
local experimentalSignatureInfo = Buffer([
0x16, 0x08, // SignatureInfo
  0x1B, 0x01, experimentalSignatureType, // SignatureType
  0x81, 0x03, 1, 2, 3 // Experimental info
]);

local experimentalSignatureInfoNoSignatureType = Buffer([
0x16, 0x05, // SignatureInfo
  0x81, 0x03, 1, 2, 3 // Experimental info
]);

local experimentalSignatureInfoBadTlv = Buffer([
0x16, 0x08, // SignatureInfo
  0x1B, 0x01, experimentalSignatureType, // SignatureType
  0x81, 0x10, 1, 2, 3 // Bad TLV encoding (length 0x10 does not match the value length.
]);

function dumpData(data)
{
  function dump(s1, s2 = null)
  {
    local result = s1;
    if (s2)
      result += " " + s2;

    return result;
  }

  local result = [];
  result.append(dump("name:", data.getName().toUri()));
  if (data.getContent().size() > 0) {
    result.append(dump("content (raw):", data.getContent().buf().toString("raw")));
    result.append(dump("content (hex):", data.getContent().toHex()));
  }
  else
    result.append(dump("content: <empty>"));
  if (!(data.getMetaInfo().getType() == ContentType.BLOB)) {
    result.append(dump("metaInfo.type:",
      data.getMetaInfo().getType() == ContentType.LINK ? "LINK" :
      (data.getMetaInfo().getType() == ContentType.KEY ? "KEY" : "unknown")));
  }
  result.append(dump("metaInfo.freshnessPeriod (milliseconds):",
    data.getMetaInfo().getFreshnessPeriod() >= 0 ?
      data.getMetaInfo().getFreshnessPeriod() : "<none>"));
  result.append(dump("metaInfo.finalBlockId:",
    data.getMetaInfo().getFinalBlockId().getValue().size() > 0 ?
      data.getMetaInfo().getFinalBlockId().toEscapedString() : "<none>"));
  local signature = data.getSignature();
  if (signature instanceof Sha256WithRsaSignature) {
    result.append(dump("signature.signature:",
      signature.getSignature().size() == 0 ? "<none>" :
        signature.getSignature().toHex()));
    if (signature.getKeyLocator().getType() != null) {
      if (signature.getKeyLocator().getType() == KeyLocatorType.KEY_LOCATOR_DIGEST)
        result.append(dump("signature.keyLocator: KeyLocatorDigest:",
          signature.getKeyLocator().getKeyData().toHex()));
      else if (signature.getKeyLocator().getType() == KeyLocatorType.KEYNAME)
        result.append(dump("signature.keyLocator: KeyName:",
          signature.getKeyLocator().getKeyName().toUri()));
      else
        result.append(dump("signature.keyLocator: <unrecognized KeyLocatorType"));
    }
    else
      result.append(dump("signature.keyLocator: <none>"));
  }
  return result;
}

// Ignoring signature, see if two data dumps are equal.
function dataDumpsEqual(dump1, dump2)
{
  /**
   * Return a copy of the strings array, removing any string that start with prefix.
   */
  function removeStartingWith(strings, prefix)
  {
    local result = [];
    for (local i = 0; i < strings.len(); ++i) {
      if (strings[i].len() < prefix.len() ||
          strings[i].slice(0, prefix.len()) != prefix)
        result.append(strings[i]);
    }

    return result;
  }

  local prefix = "signature.signature:";
  dump1 = removeStartingWith(dump1, prefix);
  dump2 = removeStartingWith(dump2, prefix);

  if (dump1.len() != dump2.len())
    return false;
  for (local i = 0; i < dump1.len(); ++i) {
    if (dump1[i] != dump2[i])
      return false;
  }
  return true;
}

describe("TestDataMethods", function() {
  local freshData = null;

  function createFreshData()
  {
    local freshData = Data(Name("/ndn/abc"));
    freshData.setContent(Blob("SUCCESS!"));
    freshData.getMetaInfo().setFreshnessPeriod(5000);
    freshData.getMetaInfo().setFinalBlockId(Name("/%00%09").get(0));

    return freshData;
  }

  local initialDump = ["name: /ndn/abc",
    "content (raw): SUCCESS!",
    "content (hex): 5355434345535321",
    "metaInfo.freshnessPeriod (milliseconds): 5000",
    "metaInfo.finalBlockId: %00%09",
    "signature.signature: 1a03c39c4fc55c36a2e79cee52fe45a7e10cfb95acb49bccb6a0c34aaa45bfbfdf0b51d5a48bf2ab45971c24d8e2c28a4d4012d77701eb7435f14dddd0f3a69ab7a4f17fa78434d7082552808b6c4293041e071f4f764318f2f8511a56afe6a931cb6c1c0aa40110fcc866ce2e9c0b2d7fb464a0ee2282c834f79af551122a84",
    "signature.keyLocator: KeyName: /testname/KEY/DSK-123/ID-CERT"];

  beforeEach(function() {
    freshData = createFreshData();
  });

  it("Dump", function() {
    local data = Data();
    data.wireDecode(Blob(codedData, false));
    Assert.deepEqual(dumpData(data), initialDump,
      "Initial dump does not have expected format");
  });

  it("EncodeDecode", function() {
    local data = Data();
    data.wireDecode(Blob(codedData, false));
    // Set the content again to clear the cached encoding so we encode again.
    data.setContent(data.getContent());
    local encoding = data.wireEncode();

    local reDecodedData = Data();
    reDecodedData.wireDecode(encoding);
    Assert.deepEqual(dumpData(reDecodedData), initialDump,
      "Re-decoded data does not match original dump");
  });

  it("EmptySignature", function() {
    // make sure nothing is set in the signature of newly created data
    local data = Data();
    local signature = data.getSignature();
    Assert.equal(signature.getKeyLocator().getType(), null,
      "Key locator type on unsigned data should not be set");
    Assert.ok(signature.getSignature().isNull(),
      "Non-empty signature on unsigned data");
  });

  it("CopyFields", function() {
    local data = Data(freshData.getName());
    data.setContent(freshData.getContent());
    data.setMetaInfo(freshData.getMetaInfo());

/*  TODO: Test with the real signData.
    credentials.signData(data);
*/
    // Imitate signData.
    data.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
    data.getSignature().getKeyLocator().setKeyName(Name("/testname/KEY/DSK-123/ID-CERT"));
    data.getSignature().setSignature(Buffer
      ("1a03c39c4fc55c36a2e79cee52fe45a7e10cfb95acb49bccb6a0c34aaa45bfbfdf0b51d5a48bf2ab45971c24d8e2c28a4d4012d77701eb7435f14dddd0f3a69ab7a4f17fa78434d7082552808b6c4293041e071f4f764318f2f8511a56afe6a931cb6c1c0aa40110fcc866ce2e9c0b2d7fb464a0ee2282c834f79af551122a84",
       "hex"));

    local freshDump = dumpData(data);
    Assert.ok(dataDumpsEqual(freshDump, initialDump),
      "Freshly created data does not match original dump");
  });

  // TODO: Verify
  // TODO: VerifyEcdsa
  // TODO: VerifyDigestSha256

  it("GenericSignature", function() {
    // Test correct encoding.
    local signature = GenericSignature();
    signature.setSignatureInfoEncoding
      (Blob(experimentalSignatureInfo, false), null);
    local signatureValue = Blob([1, 2, 3, 4], false);
    signature.setSignature(signatureValue);

    freshData.setSignature(signature);
    local encoding = freshData.wireEncode();

    local decodedData = Data();
    decodedData.wireDecode(encoding);

    local decodedSignature = decodedData.getSignature();
    Assert.equal(decodedSignature.getTypeCode(), experimentalSignatureType);
    Assert.ok(Blob(experimentalSignatureInfo, false).equals
              (decodedSignature.getSignatureInfoEncoding()));
    Assert.ok(signatureValue.equals(decodedSignature.getSignature()));

    // Test bad encoding.
    signature = GenericSignature();
    signature.setSignatureInfoEncoding
      (Blob(experimentalSignatureInfoNoSignatureType, false), null);
    signature.setSignature(signatureValue);
    freshData.setSignature(signature);
    local gotError = true;
    try {
      freshData.wireEncode();
      gotError = false;
    } catch (ex) {}
    if (!gotError)
      Assert.fail("", "",
        "Expected encoding error for experimentalSignatureInfoNoSignatureType");

    signature = GenericSignature();
    signature.setSignatureInfoEncoding
      (Blob(experimentalSignatureInfoBadTlv, false), null);
    signature.setSignature(signatureValue);
    freshData.setSignature(signature);
    gotError = true;
    try {
      freshData.wireEncode();
      gotError = false;
    } catch (ex) {}
    if (!gotError)
      Assert.fail("", "",
        "Expected encoding error for experimentalSignatureInfoBadTlv");
  });

  // TODO: FullName (need Sha256.
});
