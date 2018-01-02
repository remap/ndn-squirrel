/**
 * Copyright (C) 2016-2018 Regents of the University of California.
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

  local TestDataRsaOaep = {
    testName = "TestDataRsaOaep",
    type = EncryptAlgorithmType.RsaOaep
  };

  local TestDataRsaPkcs = {
    testName = "TestDataRsaPkcs",
    type = EncryptAlgorithmType.RsaPkcs
  };

/* TODO: Implement RsaOaep.
  local encryptorRsaTestInputs = [TestDataRsaOaep, TestDataRsaPkcs];
*/
  local encryptorRsaTestInputs = [TestDataRsaPkcs];

  // TODO: Remove PRIVATE_KEY and PUBLIC_KEY when we implement generateKey.
  local PRIVATE_KEY =
    "30820277020100300d06092a864886f70d0101010500048202613082025d02010002818100" +
    "c2d8db0d4f9acb9936f678ac9b35a4448baf11755e593d660e12734af61c8127fde99ef1fe" +
    "dc3b15eaf0eb71223a3011f8dc7871af7dced81b53702c387e91ae0987a42d62a3c42fd187" +
    "7eb05eb9fca77748363c03d55f2481bce26bfc8b24fb8fc5b23e6286b20f82b439c13041b8" +
    "b6230e0c0fa690bffaf75db2be70bb96db0203010001028180589912c1f2b8886b9aba6814" +
    "d45e87db4348cfbf76af4d63e272314a9cae496c4de0b50d84bdcf801fdc7cb26cc5d8a5d3" +
    "6b2cb944fb07daec51fc679f28ae449166c198bc160c9e7f40f94b2b5493c4fb3c07ff3d9a" +
    "9f2c6646750319d21e157f6b775170ad6b55a99572a3cc745c8ce4f7d7fdaa4bdcc94be9bb" +
    "2ad858a901024100ea7b109b84b3fa808e1f2183257669c2ddb289141305c7e2008aebe290" +
    "5bc5d2c455801b821b6cb7ead47c04a470b68494b389f0901a83c0c580518122be87ab0241" +
    "00d4baa174e28d3af90a5ee00fd6a56081184df7f820f8941b5a7a821a82c02cfe581c1665" +
    "e2259e3ee0f87220e466c0582a97d6431474a997cac062c7e4773d91024100b542a915efc1" +
    "c9b63327719a960d31b8c7f4c9eed0bdb944c6329e22a881a92d4344ed2156b4a8988c59f1" +
    "fd0cb96cfe948d2de6df1f0016b71678eb20d6b4bd024100979928d6935cf259e7fa14d334" +
    "b44641b98056e68d1898f3a55708c0bbcd184369a71a8f20ca8e2b6147ac8da437557b7f5f" +
    "156258818b1a9172e8f26aee4f0102406ab2c28cbd7a97f57e52b1e18082af0faa44a99b91" +
    "c5d6729155df6106d8ad83d46b3192e5effdbdea3baed4c71d40af1a7da3c765937e167f30" +
    "29463363868d";

  local PUBLIC_KEY =
    "30819f300d06092a864886f70d010101050003818d0030818902818100c2d8db0d4f9acb99" +
    "36f678ac9b35a4448baf11755e593d660e12734af61c8127fde99ef1fedc3b15eaf0eb7122" +
    "3a3011f8dc7871af7dced81b53702c387e91ae0987a42d62a3c42fd1877eb05eb9fca77748" +
    "363c03d55f2481bce26bfc8b24fb8fc5b23e6286b20f82b439c13041b8b6230e0c0fa690bf" +
    "faf75db2be70bb96db0203010001";

  it("ContentAsymmetricEncryptSmall", function() {
    for (local i = 0; i < encryptorRsaTestInputs.len(); ++i) {
      local input = encryptorRsaTestInputs[i];

      local rawContent = Blob(Buffer([
        0x01, 0x23, 0x45, 0x67, 0x89, 0xab, 0xcd, 0xef,
        0xfe, 0xdc, 0xba, 0x98, 0x76, 0x54, 0x32, 0x10,
        0x63, 0x6f, 0x6e, 0x74, 0x65, 0x6e, 0x74, 0x73
      ]), false);

      local data = Data();
      local rsaParams = RsaKeyParams(1024);

      local keyName = Name("test");

/*    TODO: Implement generateKey.
      local decryptKey = RsaAlgorithm.generateKey(rsaParams);
      local encryptKey = RsaAlgorithm.deriveEncryptKey(decryptKey.getKeyBits());
*/
      local decryptKey = DecryptKey(Blob(Buffer(PRIVATE_KEY, "hex"), false));
      local encryptKey = EncryptKey(Blob(Buffer(PUBLIC_KEY,  "hex"), false));

      local eKey = encryptKey.getKeyBits();
      local dKey = decryptKey.getKeyBits();

      local encryptParams = EncryptParams(input.type);

      Encryptor.encryptData(data, rawContent, keyName, eKey, encryptParams);

      Assert.ok(data.getName().equals(Name("/FOR").append(keyName)),
                input.testName);

      local extractContent = EncryptedContent();
      extractContent.wireDecode(data.getContent());
      Assert.ok(keyName.equals(extractContent.getKeyLocator().getKeyName()),
                               input.testName);
      Assert.equal(extractContent.getInitialVector().size(), 0, input.testName);
      Assert.equal(extractContent.getAlgorithmType(), input.type, input.testName);

      local recovered = extractContent.getPayload();
      local decrypted = RsaAlgorithm.decrypt(dKey, recovered, encryptParams);
      Assert.ok(rawContent.equals(decrypted), input.testName);
    }
  });

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
