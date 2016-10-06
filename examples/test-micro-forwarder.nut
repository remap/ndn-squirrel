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

// Use a hard-wired secret for testing. In a real application the signer
// ensures that the verifier knows the shared key and its keyName.
HMAC_KEY <- Blob(Buffer([
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
]), false);

/**
 * This is called by the library when an Interest is received. Make a Data
 * packet with the same name as the Interest, add a message content to the Data
 * packet and send it.
 */
function onInterest(prefix, interest, face, interestFilterId, filter)
{
  local data = Data(interest.getName());
  local content = "Echo " + interest.getName().toUri();
  data.setContent(content);

  data.setSignature(HmacWithSha256Signature());
  // Use the signature object in the data object to avoid an extra copy.
  data.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
  data.getSignature().getKeyLocator().setKeyName(Name("key1"));
  KeyChain.signWithHmacWithSha256(data, HMAC_KEY);

  consoleLog("Sending content " + content);
  face.putData(data);
}

/**
 * Create a MicroForwarder with a route to the simulated agent object from
 * agent-device-stubs.nut. Then create an application Face which automatically
 * connects to the MicroForwarder. Register to receive Interests and call
 * onInterest which sends a reply Data packet.
 */
function testPublish()
{
  MicroForwarder.get().addFace("internal://agent", agent);

  local face = Face();
  local prefix = Name("/testecho");
  consoleLog("Register prefix " + prefix.toUri());
  face.registerPrefixUsingObject(prefix, onInterest);
}

/**
 * This is called by the library when a Data packet is received for the
 * expressed Interest. Print the Data packet name and content to the console.
 */
function onData(interest, data)
{
  consoleLog("Got data packet with name " + data.getName().toUri());
  consoleLog(data.getContent().toRawStr());

  if (KeyChain.verifyDataWithHmacWithSha256(data, HMAC_KEY))
    consoleLog("Data signature verification: VERIFIED");
  else
    consoleLog("Data signature verification: FAILED");
}

/**
 * Create a Face to the simulated device object from agent-device-stubs.nut and
 * express and Interest with the onData callback which prints the content to the
 * console.
 */
function testConsume()
{
  local face = Face
    (SquirrelObjectTransport(), SquirrelObjectTransportConnectionInfo(device));

  local name = Name("/testecho");
  local word = "hello";
  name.append(word);
  consoleLog("Express name " + name.toUri());
  face.expressInterest(name, onData);
}

/**
 * Run testPublish and testConsume to test agent/device communication through
 * the MicroForwarder and simulated agent/device communication in one
 * stand-alone standard Squirrel application. (To test on a real agent and Imp
 * device, see test-imp-publish-async.device.nut and
 * test-imp-echo-consumer.agent.nut .)
 */
function main()
{
  testPublish();
  testConsume();
}

main();
