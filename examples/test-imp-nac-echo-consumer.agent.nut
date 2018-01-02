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

// This depends on ontrib/kisi-inc/aes-squirrel/aes.class.nut and
// contrib/vukicevic/crunch/crunch.nut .

TEST_RSA_D_KEY <-
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

// Use a hard-wired secret for testing. In a real application the signer
// ensures that the verifier knows the shared key and its keyName.
HMAC_KEY <- Blob(Buffer([
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
]), false);

/**
 * This is called by the library when a Data packet is received for the
 * expressed Interest. Get the encrypted content value from the Data packet and
 * express an Interest for the content key.
 */
function onData(interest, data, face)
{
  local encryptedContent = EncryptedContent();
  encryptedContent.wireDecode(data.getContent());
  local contentKeyName = encryptedContent.getKeyLocator().getKeyName();
  consoleLog("Got data packet with name " + data.getName().toUri());

  if (KeyChain.verifyDataWithHmacWithSha256(data, HMAC_KEY))
    consoleLog("Data signature verification: VERIFIED");
  else
    consoleLog("Data signature verification: FAILED");

  // Now fetch the encrypted content key.
  consoleLog("Express contentKeyName " + contentKeyName.toUri());
  face.expressInterest
    (contentKeyName,
     function(interest2, data2) {
       onContentKeyData(interest2, data2, data, contentKeyName); },
     onTimeout);
}

/**
 * This is called by the library when the expressed Interest times out. Print
 * the Interest name to the console.
 */
function onTimeout(interest)
{
  consoleLog("Time out for interest " + interest.getName().toUri());
}

/**
 * This is called by the library when a content key Data packet is received for
 * the Interest expressed above in onData. Use the D-KEY to recover the
 * content key, decrypt the content and print it.
 */
function onContentKeyData(interest, data, contentData, contentKeyName)
{
  local encryptedCKeyContent = EncryptedContent();
  encryptedCKeyContent.wireDecode(data.getContent());
  consoleLog("Got content key data packet with name " + data.getName().toUri());
  // TODO: Check that encryptedCKeyContent.getKeyLocator().getKeyName() is the
  // expected /testecho/D-KEY/1.
  local contentKey = RsaAlgorithm.decrypt
    (Blob(Buffer(TEST_RSA_D_KEY, "hex"), false),
     encryptedCKeyContent.getPayload(),
     EncryptParams(EncryptAlgorithmType.RsaPkcs));

  // Use Consumer to decrypt contentData and call the give callback.
  local consumer = Consumer();
  // Directly load the C-KEY.
  consumer.cKeyMap_[contentKeyName.toUri()] <- contentKey;
  consumer.decryptContent_(contentData, function(content) {
    consoleLog("Content: " + content.toRawStr());
  }, function(errorCode, message) { consoleLog("Decrypt failed: " + message); });
}

/**
 * Create a Face to the device object and express and Interest with the onData
 * callback which decrypts the content and prints it to the console.
 */
function testConsume()
{
  local face = Face
    (SquirrelObjectTransport(), SquirrelObjectTransportConnectionInfo(device));

  local name = Name("/testecho");
  local word = "hello";
  name.append(word);
  consoleLog("Express name " + name.toUri());
  face.expressInterest
    (name, function(interest, data) { onData(interest, data, face); },
     onTimeout);

  // Use a wakeup loop to repeatedly call processEvents to check for Interest timeouts.
  function checkTimeout()
  {
    face.processEvents();

    local intervalSeconds = 1;
    imp.wakeup(intervalSeconds, checkTimeout);
  }
  checkTimeout();
}

// You should run this on the Agent, and run test-imp-nac-publish-async.device.app.nut
// on the Imp Device. ("nac" means "name-based access control".)
// Use a wakeup delay to let the Agent connect to the Device.
imp.wakeup(1, function() { testConsume(); });
