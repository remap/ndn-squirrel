/**
 * Copyright (C) 2016 Regents of the University of California.
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

describe("TestEncryptedContent", function() {
  local encrypted = Buffer([
  0x82, 0x30, // EncryptedContent
    0x1c, 0x16, // KeyLocator
      0x07, 0x14, // Name
        0x08, 0x04,
          0x74, 0x65, 0x73, 0x74, // "test"
        0x08, 0x03,
          0x6b, 0x65, 0x79, // "key"
        0x08, 0x07,
          0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, // "locator"
    0x83, 0x01, // EncryptedAlgorithm
      0x03,
    0x85, 0x0a, // InitialVector
      0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
    0x84, 0x07, // EncryptedPayload
      0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
  ]);

  local encryptedNoIv = Buffer([
  0x82, 0x24, // EncryptedContent
    0x1c, 0x16, // KeyLocator
      0x07, 0x14, // Name
        0x08, 0x04,
          0x74, 0x65, 0x73, 0x74, // "test"
        0x08, 0x03,
          0x6b, 0x65, 0x79, // "key"
        0x08, 0x07,
          0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, // "locator"
    0x83, 0x01, // EncryptedAlgorithm
      0x03,
    0x84, 0x07, // EncryptedPayload
      0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
  ]);

  local message = Buffer([
    0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
  ]);

  local iv = Buffer([
    0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73
  ]);

  it("Constructor", function() {
    // Check default settings.
    local content = EncryptedContent();
    Assert.equal(content.getAlgorithmType(), null);
    Assert.ok(content.getPayload().isNull());
    Assert.ok(content.getInitialVector().isNull());
    Assert.equal(content.getKeyLocator().getType(), null);

    // Check an encrypted content with IV.
    local keyLocator = KeyLocator();
    keyLocator.setType(KeyLocatorType.KEYNAME);
    keyLocator.getKeyName().set("/test/key/locator");
    local rsaOaepContent = EncryptedContent();
    rsaOaepContent.setAlgorithmType(EncryptAlgorithmType.RsaOaep)
      .setKeyLocator(keyLocator).setPayload(Blob(message, false))
      .setInitialVector(Blob(iv, false));

    Assert.equal(rsaOaepContent.getAlgorithmType(), EncryptAlgorithmType.RsaOaep);
    Assert.ok(rsaOaepContent.getPayload().equals(Blob(message, false)));
    Assert.ok(rsaOaepContent.getInitialVector().equals(Blob(iv, false)));
    Assert.ok(rsaOaepContent.getKeyLocator().getType() != null);
    Assert.ok(rsaOaepContent.getKeyLocator().getKeyName().equals
              (Name("/test/key/locator")));

    // Encoding.
    local encryptedBlob = Blob(encrypted, false);
    local encoded = rsaOaepContent.wireEncode();

    Assert.ok(encryptedBlob.equals(encoded));

    // Decoding.
    local rsaOaepContent2 = EncryptedContent();
    rsaOaepContent2.wireDecode(encryptedBlob);
    Assert.equal(rsaOaepContent2.getAlgorithmType(), EncryptAlgorithmType.RsaOaep);
    Assert.ok(rsaOaepContent2.getPayload().equals(Blob(message, false)));
    Assert.ok(rsaOaepContent2.getInitialVector().equals(Blob(iv, false)));
    Assert.ok(rsaOaepContent2.getKeyLocator().getType() != null);
    Assert.ok(rsaOaepContent2.getKeyLocator().getKeyName().equals
              (Name("/test/key/locator")));

    // Check the no IV case.
    local rsaOaepContentNoIv = EncryptedContent();
    rsaOaepContentNoIv.setAlgorithmType(EncryptAlgorithmType.RsaOaep)
      .setKeyLocator(keyLocator).setPayload(Blob(message, false));
    Assert.equal(rsaOaepContentNoIv.getAlgorithmType(), EncryptAlgorithmType.RsaOaep);
    Assert.ok(rsaOaepContentNoIv.getPayload().equals(Blob(message, false)));
    Assert.ok(rsaOaepContentNoIv.getInitialVector().isNull());
    Assert.ok(rsaOaepContentNoIv.getKeyLocator().getType() != null);
    Assert.ok(rsaOaepContentNoIv.getKeyLocator().getKeyName().equals
              (Name("/test/key/locator")));

    // Encoding.
    local encryptedBlob2 = Blob(encryptedNoIv, false);
    local encodedNoIV = rsaOaepContentNoIv.wireEncode();
    Assert.ok(encryptedBlob2.equals(encodedNoIV));

    // Decoding.
    local rsaOaepContentNoIv2 = EncryptedContent();
    rsaOaepContentNoIv2.wireDecode(encryptedBlob2);
    Assert.equal(rsaOaepContentNoIv2.getAlgorithmType(), EncryptAlgorithmType.RsaOaep);
    Assert.ok(rsaOaepContentNoIv2.getPayload().equals(Blob(message, false)));
    Assert.ok(rsaOaepContentNoIv2.getInitialVector().isNull());
    Assert.ok(rsaOaepContentNoIv2.getKeyLocator().getType() != null);
    Assert.ok(rsaOaepContentNoIv2.getKeyLocator().getKeyName().equals
              (Name("/test/key/locator")));
  });

  it("DecodingError", function() {
    local encryptedContent = EncryptedContent();

    local errorBlob1 = Blob(Buffer([
      0x1f, 0x30, // Wrong EncryptedContent (0x82, 0x24)
        0x1c, 0x16, // KeyLocator
          0x07, 0x14, // Name
            0x08, 0x04,
              0x74, 0x65, 0x73, 0x74,
            0x08, 0x03,
              0x6b, 0x65, 0x79,
            0x08, 0x07,
              0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72,
        0x83, 0x01, // EncryptedAlgorithm
          0x00,
        0x85, 0x0a, // InitialVector
          0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
        0x84, 0x07, // EncryptedPayload
          0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob1); },
       "string");

    local errorBlob2 = Blob(Buffer([
      0x82, 0x30, // EncryptedContent
        0x1d, 0x16, // Wrong KeyLocator (0x1c, 0x16)
          0x07, 0x14, // Name
            0x08, 0x04,
              0x74, 0x65, 0x73, 0x74,
            0x08, 0x03,
              0x6b, 0x65, 0x79,
            0x08, 0x07,
              0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72,
        0x83, 0x01, // EncryptedAlgorithm
          0x00,
        0x85, 0x0a, // InitialVector
          0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
        0x84, 0x07, // EncryptedPayload
          0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob2); },
       "string");

    local errorBlob3 = Blob(Buffer([
      0x82, 0x30, // EncryptedContent
        0x1c, 0x16, // KeyLocator
          0x07, 0x14, // Name
            0x08, 0x04,
              0x74, 0x65, 0x73, 0x74,
            0x08, 0x03,
              0x6b, 0x65, 0x79,
            0x08, 0x07,
              0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72,
        0x1d, 0x01, // Wrong EncryptedAlgorithm (0x83, 0x01)
          0x00,
        0x85, 0x0a, // InitialVector
          0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
        0x84, 0x07, // EncryptedPayload
          0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob3); },
       "string");

    local errorBlob4 = Blob(Buffer([
      0x82, 0x30, // EncryptedContent
        0x1c, 0x16, // KeyLocator
          0x07, 0x14, // Name
            0x08, 0x04,
              0x74, 0x65, 0x73, 0x74, // "test"
            0x08, 0x03,
              0x6b, 0x65, 0x79, // "key"
            0x08, 0x07,
              0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, // "locator"
        0x83, 0x01, // EncryptedAlgorithm
          0x00,
        0x1f, 0x0a, // InitialVector (0x84, 0x0a)
          0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
        0x84, 0x07, // EncryptedPayload
          0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob4); },
       "string");

    local errorBlob5 = Blob(Buffer([
      0x82, 0x30, // EncryptedContent
        0x1c, 0x16, // KeyLocator
          0x07, 0x14, // Name
            0x08, 0x04,
              0x74, 0x65, 0x73, 0x74, // "test"
            0x08, 0x03,
              0x6b, 0x65, 0x79, // "key"
            0x08, 0x07,
              0x6c, 0x6f, 0x63, 0x61, 0x74, 0x6f, 0x72, // "locator"
        0x83, 0x01, // EncryptedAlgorithm
          0x00,
        0x85, 0x0a, // InitialVector
          0x72, 0x61, 0x6e, 0x64, 0x6f, 0x6d, 0x62, 0x69, 0x74, 0x73,
        0x21, 0x07, // EncryptedPayload (0x85, 0x07)
          0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob5); },
       "string");

    local errorBlob6 = Blob(Buffer([
      0x82, 0x00 // Empty EncryptedContent
    ]), false);
    Assert.throws
      (function() { encryptedContent.wireDecode(errorBlob6); },
       "string");
  });

  it("SetterGetter", function() {
    local content = EncryptedContent();
    Assert.equal(content.getAlgorithmType(), null);
    Assert.ok(content.getPayload().isNull());
    Assert.ok(content.getInitialVector().isNull());
    Assert.equal(content.getKeyLocator().getType(), null);

    content.setAlgorithmType(EncryptAlgorithmType.RsaOaep);
    Assert.equal(content.getAlgorithmType(), EncryptAlgorithmType.RsaOaep);
    Assert.ok(content.getPayload().isNull());
    Assert.ok(content.getInitialVector().isNull());
    Assert.equal(content.getKeyLocator().getType(), null);

    local keyLocator = KeyLocator();
    keyLocator.setType(KeyLocatorType.KEYNAME);
    keyLocator.getKeyName().set("/test/key/locator");
    content.setKeyLocator(keyLocator);
    Assert.ok(content.getKeyLocator().getType() != null);
    Assert.ok(content.getKeyLocator().getKeyName().equals
              (Name("/test/key/locator")));
    Assert.ok(content.getPayload().isNull());
    Assert.ok(content.getInitialVector().isNull());

    content.setPayload(Blob(message, false));
    Assert.ok(content.getPayload().equals(Blob(message, false)));

    content.setInitialVector(Blob(iv, false));
    Assert.ok(content.getInitialVector().equals(Blob(iv, false)));

    local encoded = content.wireEncode();
    local contentBlob = Blob(encrypted, false);
    Assert.ok(contentBlob.equals(encoded));
  });
});
