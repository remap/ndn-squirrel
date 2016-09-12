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

describe("TestEncryptor", function() {
  local TestDataAesEcb = {
    testName = "TestDataAesEcb",
    keyName = Name("/test"),
    encryptParams = EncryptParams(EncryptAlgorithmType.AesEcb),
    plainText = Blob(Buffer([
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74, 0x73
      ]), false),
    key = Blob(Buffer([
        0xdd, 0x60, 0x77, 0xec, 0xa9, 0x6b, 0x23, 0x1b,
        0x40, 0x6b, 0x5a, 0xf8, 0x7d, 0x3d, 0x55, 0x32
      ]), false),
    encryptedContent = Blob(Buffer([
        0x82, 0x2f,
          0x1c, 0x08,
            0x07, 0x06,
              0x08, 0x04, 0x74, 0x65, 0x73, 0x74,
          0x83, 0x01,
            0x00,
          0x84, 0x20,
            0x13, 0x80, 0x1a, 0xc0, 0x4c, 0x75, 0xa7, 0x7f,
            0x43, 0x5e, 0xd7, 0xa6, 0x3f, 0xd3, 0x68, 0x94,
            0xe2, 0xcf, 0x54, 0xb1, 0xc2, 0xce, 0xad, 0x9b,
            0x56, 0x6e, 0x1c, 0xe6, 0x55, 0x1d, 0x79, 0x04
      ]), false)
  };

  local TestDataAesCbc = {
    testName = "TestDataAesCbc",
    keyName = Name("/test"),
    encryptParams = EncryptParams(EncryptAlgorithmType.AesCbc)
      .setInitialVector(Blob(Buffer([
        0x73, 0x6f, 0x6d, 0x65, 0x72, 0x61, 0x6e, 0x64,
        0x6f, 0x6d, 0x76, 0x65, 0x63, 0x74, 0x6f, 0x72
      ]), false)),
    plainText = Blob(Buffer([
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74, 0x73
      ]), false),
    key = Blob(Buffer([
        0xdd, 0x60, 0x77, 0xec, 0xa9, 0x6b, 0x23, 0x1b,
        0x40, 0x6b, 0x5a, 0xf8, 0x7d, 0x3d, 0x55, 0x32
      ]), false),
    encryptedContent = Blob(Buffer([
        0x82, 0x41, // EncryptedContent
          0x1c, 0x08, // KeyLocator /test
            0x07, 0x06,
              0x08, 0x04, 0x74, 0x65, 0x73, 0x74,
          0x83, 0x01, // EncryptedAlgorithm
            0x01, // AlgorithmAesCbc
          0x85, 0x10,
            0x73, 0x6f, 0x6d, 0x65, 0x72, 0x61, 0x6e, 0x64,
            0x6f, 0x6d, 0x76, 0x65, 0x63, 0x74, 0x6f, 0x72,
          0x84, 0x20, // EncryptedPayLoad
            0x6a, 0x6b, 0x58, 0x9c, 0x30, 0x3b, 0xd9, 0xa6,
            0xed, 0xd2, 0x12, 0xef, 0x29, 0xad, 0xc3, 0x60,
            0x1f, 0x1b, 0x6b, 0xc7, 0x03, 0xff, 0x53, 0x52,
            0x82, 0x6d, 0x82, 0x73, 0x05, 0xf9, 0x03, 0xdc
      ]), false)
  };

  local encryptorAesTestInputs = [TestDataAesEcb, TestDataAesCbc];

  it("ContentSymmetricEncrypt", function() {
    for (local i = 0; i < encryptorAesTestInputs.len(); ++i) {
      local input = encryptorAesTestInputs[i];

      local data = Data();
      Encryptor.encryptData
        (data, input.plainText, input.keyName, input.key, input.encryptParams);

      Assert.ok(data.getName().equals(Name("/FOR").append(input.keyName)),
                input.testName);

      Assert.ok(input.encryptedContent.equals(data.getContent()), input.testName);

      local content = EncryptedContent();
      content.wireDecode(data.getContent());
      local decryptedOutput = AesAlgorithm.decrypt
        (input.key, content.getPayload(), input.encryptParams);

      Assert.ok(input.plainText.equals(decryptedOutput), input.testName);
    }
  });

  // TODO: ContentAsymmetricEncryptSmall
  // TODO: ContentAsymmetricEncryptLarge

  // TODO: Implement DecryptContent in test-consumer.nut.
  it("SimpleDecryptContent", function() {
    local DATA_CONTENT = Buffer([
      0xcb, 0xe5, 0x6a, 0x80, 0x41, 0x24, 0x58, 0x23,
      0x84, 0x14, 0x15, 0x61, 0x80, 0xb9, 0x5e, 0xbd,
      0xce, 0x32, 0xb4, 0xbe, 0xbc, 0x91, 0x31, 0xd6,
      0x19, 0x00, 0x80, 0x8b, 0xfa, 0x00, 0x05, 0x9c
    ]);

    local AES_KEY = Buffer([
      0xdd, 0x60, 0x77, 0xec, 0xa9, 0x6b, 0x23, 0x1b,
      0x40, 0x6b, 0x5a, 0xf8, 0x7d, 0x3d, 0x55, 0x32
    ]);

    local INITIAL_VECTOR = Buffer([
      0x73, 0x6f, 0x6d, 0x65, 0x72, 0x61, 0x6e, 0x64,
      0x6f, 0x6d, 0x76, 0x65, 0x63, 0x74, 0x6f, 0x72
    ]);

    local cKeyName = Name("/Prefix/SAMPLE/Content/C-KEY/1");
    local contentName = Name("/Prefix/SAMPLE/Content");
    local fixtureCKeyBlob = Blob(AES_KEY, false);

    local contentData = Data(contentName);
    local encryptParams = EncryptParams(EncryptAlgorithmType.AesCbc);
    encryptParams.setInitialVector(Blob(INITIAL_VECTOR, false));
    Encryptor.encryptData
      (contentData, Blob(DATA_CONTENT, false), cKeyName, fixtureCKeyBlob,
       encryptParams);
    // For now, add a fake signature.
    contentData.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
    contentData.getSignature().getKeyLocator().setKeyName(Name("/key/name"));

    local consumer = Consumer();
    // Directly load the C-KEY.
    consumer.cKeyMap_[cKeyName.toUri()] <- fixtureCKeyBlob;
    consumer.decryptContent_(contentData, function(result) {
      Assert.ok(result.equals(Blob(DATA_CONTENT, false)));
    }, function(errorCode, message) { Assert.fail("", "", message); });
  });
});
