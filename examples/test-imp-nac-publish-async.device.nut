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

// This depends on ontrib/kisi-inc/aes-squirrel/aes.class.nut and
// contrib/vukicevic/crunch/crunch.nut .

TEST_RSA_E_KEY <-
  "30819f300d06092a864886f70d010101050003818d0030818902818100c2d8db0d4f9acb99" +
  "36f678ac9b35a4448baf11755e593d660e12734af61c8127fde99ef1fedc3b15eaf0eb7122" +
  "3a3011f8dc7871af7dced81b53702c387e91ae0987a42d62a3c42fd1877eb05eb9fca77748" +
  "363c03d55f2481bce26bfc8b24fb8fc5b23e6286b20f82b439c13041b8b6230e0c0fa690bf" +
  "faf75db2be70bb96db0203010001";

// Use a hard-wired secret for testing. In a real application the signer
// ensures that the verifier knows the shared key and its keyName.
HMAC_KEY <- Blob(Buffer([
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
]), false);

contentKey <- null;
contentKeyName <- null;
contentKeyData <- null;

/**
 * This is called by the library when an Interest is received. Make a Data
 * packet with the same name as the Interest, add a message content to the Data
 * packet and send it.
 */
function onInterest(prefix, interest, face, interestFilterId, filter)
{
  if (contentKey == null) {
    // Generate the contentKey and encrypt it with the recipient's E-KEY to make
    // the contentKeyData packet which is meant for the recipient's D-KEY.
    contentKey = AesAlgorithm.generateKey(AesKeyParams(128)).getKeyBits();
    contentKeyName = Name("/testecho/C-KEY/1");

    contentKeyData = Data(contentKeyName);
    Encryptor.encryptData
      (contentKeyData, contentKey, Name("/testecho/D-KEY/1"),
       Blob(Buffer(TEST_RSA_E_KEY, "hex"), false),
       EncryptParams(EncryptAlgorithmType.RsaPkcs));

    contentKeyData.setSignature(HmacWithSha256Signature());
    // Use the signature object in the data object to avoid an extra copy.
    contentKeyData.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
    contentKeyData.getSignature().getKeyLocator().setKeyName(Name("key1"));
    KeyChain.signWithHmacWithSha256(contentKeyData, HMAC_KEY);

    consoleLog("Generated contentKeyData " + contentKeyData.getName().toUri());
  }

  if (interest.matchesData(contentKeyData)) {
    // This is a request for the Data packet with the contentKey.
    consoleLog("Sending contentKeyData " + contentKeyData.getName());
    face.putData(contentKeyData);
    return;
  }

  // Encrypt a message with the contentKey.
  local data = Data(interest.getName());
  local content = "Encrypted echo " + interest.getName().toUri();
  // Encrypt with AesCbc and an auto-generated initialization vector.
  Encryptor.encryptData
    (data, Blob(content), contentKeyName, contentKey,
     EncryptParams(EncryptAlgorithmType.AesCbc, 16));

  data.setSignature(HmacWithSha256Signature());
  // Use the signature object in the data object to avoid an extra copy.
  data.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
  data.getSignature().getKeyLocator().setKeyName(Name("key1"));
  KeyChain.signWithHmacWithSha256(data, HMAC_KEY);

  consoleLog("Sending " + data.getName() + " with content: " + content);
  face.putData(data);
}

/**
 * Create a MicroForwarder with a route to the agent object. Then create an
 * application Face which automatically connects to the MicroForwarder. Register
 * to receive Interests and call onInterest which sends a reply Data packet.
 */
function testPublish()
{
  MicroForwarder.get().addFace
    ("internal://agent", SquirrelObjectTransport(),
     SquirrelObjectTransportConnectionInfo(agent));

  local face = Face();
  local prefix = Name("/testecho");
  consoleLog("Register prefix " + prefix.toUri());
  face.registerPrefixUsingObject(prefix, onInterest);
}

// You should run this on the Imp Device, and run
// test-imp-nac-echo-consumer.agent.app.nut on the Agent.
// ("nac" means "name-based access control".)
testPublish();
