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
 * Create a MicroForwarder with a route to the agent. Then create an application
 * Face which automatically connects to the MicroForwarder. Register to receive
 * Interests and call onInterest which sends a reply Data packet. You should run
 * this on the Imp Device, and run test-imp-echo-consumer.agent.nut on the Agent.
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

testPublish();
