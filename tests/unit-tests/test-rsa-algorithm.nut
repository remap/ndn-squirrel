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

describe("TestRsaAlgorithm", function() {
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

  // plaintext: RSA-Encrypt-Test
  local PLAINTEXT = Buffer([
    0x52, 0x53, 0x41, 0x2d, 0x45, 0x6e, 0x63, 0x72,
    0x79, 0x70, 0x74, 0x2d, 0x54, 0x65, 0x73, 0x74
  ]);

  local CIPHERTEXT_OAEP = Buffer([
    0x33, 0xfb, 0x32, 0xd4, 0x2d, 0x45, 0x75, 0x3f, 0x34, 0xde, 0x3b,
    0xaa, 0x80, 0x5f, 0x74, 0x6f, 0xf0, 0x3f, 0x01, 0x31, 0xdd, 0x2b,
    0x85, 0x02, 0x1b, 0xed, 0x2d, 0x16, 0x1b, 0x96, 0xe5, 0x77, 0xde,
    0xcd, 0x44, 0xe5, 0x3c, 0x32, 0xb6, 0x9a, 0xa9, 0x5d, 0xaa, 0x4b,
    0x94, 0xe2, 0xac, 0x4a, 0x4e, 0xf5, 0x35, 0x21, 0xd0, 0x03, 0x4a,
    0xa7, 0x53, 0xae, 0x13, 0x08, 0x63, 0x38, 0x2c, 0x92, 0xe3, 0x44,
    0x64, 0xbf, 0x33, 0x84, 0x8e, 0x51, 0x9d, 0xb9, 0x85, 0x83, 0xf6,
    0x8e, 0x09, 0xc1, 0x72, 0xb9, 0x90, 0x5d, 0x48, 0x63, 0xec, 0xd0,
    0xcc, 0xfa, 0xab, 0x44, 0x2b, 0xaa, 0xa6, 0xb6, 0xca, 0xec, 0x2b,
    0x5f, 0xbe, 0x77, 0xa5, 0x52, 0xeb, 0x0a, 0xaa, 0xf2, 0x2a, 0x19,
    0x62, 0x80, 0x14, 0x87, 0x42, 0x35, 0xd0, 0xb6, 0xa3, 0x47, 0x4e,
    0xb6, 0x1a, 0x88, 0xa3, 0x16, 0xb2, 0x19
  ]);

  local CIPHERTEXT_PKCS = Buffer([
    0xaf, 0x64, 0xf0, 0x12, 0x87, 0xcb, 0x29, 0x02, 0x8b, 0x3e, 0xb2,
    0xca, 0xfd, 0xf1, 0xcc, 0xef, 0x1e, 0xab, 0xb5, 0x6e, 0x4b, 0xa8,
    0x3b, 0x28, 0xb4, 0x3d, 0x9d, 0x49, 0xb1, 0xc5, 0xad, 0x44, 0xad,
    0x75, 0x5c, 0x18, 0x6b, 0x71, 0x4a, 0xbc, 0xf0, 0x73, 0xeb, 0xf6,
    0x4d, 0x0a, 0x37, 0xaa, 0xfe, 0x77, 0x1d, 0xc4, 0x43, 0xfa, 0xb1,
    0x2d, 0x59, 0xe6, 0xd9, 0x2e, 0xf2, 0x2f, 0xd5, 0x48, 0x4b, 0x8b,
    0x44, 0x94, 0xf9, 0x94, 0x92, 0x38, 0x82, 0x22, 0x41, 0x57, 0xbf,
    0xf9, 0x2c, 0xd8, 0x00, 0xb4, 0x68, 0x3c, 0xdd, 0xf2, 0xe4, 0xc8,
    0x64, 0x69, 0x05, 0x41, 0x58, 0x7c, 0x75, 0x68, 0x12, 0x98, 0x7b,
    0x87, 0x22, 0x0f, 0x38, 0x25, 0x5c, 0xf3, 0x36, 0x94, 0x86, 0x98,
    0x30, 0x68, 0x0d, 0x44, 0xa4, 0x52, 0x73, 0x2a, 0x62, 0xf2, 0xf0,
    0x15, 0xee, 0x94, 0x46, 0xc9, 0x7a, 0x52
  ]);

  it("EncryptionDecryption", function() {
    local encryptParams = EncryptParams(EncryptAlgorithmType.RsaOaep, 0);

    local privateKeyBlob = Blob(Buffer(PRIVATE_KEY, "hex"), false);
    local publicKeyBlob = Blob(Buffer(PUBLIC_KEY, "hex"), false);

    local decryptKey = DecryptKey(privateKeyBlob);
/*  TODO: Implement deriveEncryptKey.
    local encryptKey = RsaAlgorithm.deriveEncryptKey(decryptKey.getKeyBits());
*/  local encryptKey = EncryptKey(publicKeyBlob);

    local encodedPublic = publicKeyBlob;
    local derivedPublicKey = encryptKey.getKeyBits();

/* TODO: Implement deriveEncryptKey.
    Assert.ok(encodedPublic.equals(derivedPublicKey));
*/

    local plainBlob = Blob(PLAINTEXT, false);
/*  TODO: Implement RsaOaep.
    local encryptBlob = RsaAlgorithm.encrypt
      (encryptKey.getKeyBits(), plainBlob, encryptParams);
    local receivedBlob = RsaAlgorithm.decrypt
      (decryptKey.getKeyBits(), encryptBlob, encryptParams);

    Assert.ok(plainBlob.equals(receivedBlob));

    local cipherBlob = Blob(CIPHERTEXT_OAEP, false);
    local decryptedBlob = RsaAlgorithm.decrypt
      (decryptKey.getKeyBits(), cipherBlob, encryptParams);

    Assert.ok(plainBlob.equals(decryptedBlob));
*/

    // Now test RsaPkcs.
    encryptParams = EncryptParams(EncryptAlgorithmType.RsaPkcs, 0);
    local encryptBlob = RsaAlgorithm.encrypt
      (encryptKey.getKeyBits(), plainBlob, encryptParams);
    local receivedBlob = RsaAlgorithm.decrypt
      (decryptKey.getKeyBits(), encryptBlob, encryptParams);

    Assert.ok(plainBlob.equals(receivedBlob));

    local cipherBlob = Blob(CIPHERTEXT_PKCS, false);
    local decryptedBlob = RsaAlgorithm.decrypt
      (decryptKey.getKeyBits(), cipherBlob, encryptParams);

    Assert.ok(plainBlob.equals(decryptedBlob));
  });
});
