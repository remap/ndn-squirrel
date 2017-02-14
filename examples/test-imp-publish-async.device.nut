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

// Use hard-wired HMAC shared keys for testing. In a real application the signer
// ensures that the verifier knows the shared key and its keyName.
HMAC_KEY <- Blob(Buffer([
   0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15,
  16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31
]), false);

HMAC_KEY2 <- Blob(Buffer([
  32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47,
  48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 63
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
  data.getSignature().getKeyLocator().setKeyName(Name("/key1"));
  KeyChain.signWithHmacWithSha256(data, HMAC_KEY);

  consoleLog("Sending content " + content);
  face.putData(data);
}

/**
 * Simulate a uart object with another application on the other side of a serial
 * connection. We will remove this when we use the real serial connection.
 */
class SerialUartStub {
  inputBlob_ = null;

  /**
   * This is called by the MicroForwarder to send a packet. For the stub,
   * instead of sending we simulate a remote application responding to an
   * Interest for /testecho2.
   * @param {blob} value The bytes to send.
   */
  function write(value)
  {
    local interest = Interest();
    try {
      interest.wireDecode(Blob(value));
    } catch (ex) {
      // Ignore non-Interest packets.
      return;
    }

    if (!Name("/testecho2").match(interest.getName()))
      // Ignore an Interest for another prefix.
      return;

    // Make a Data packet with the same name as the Interest, add a message
    // content to the Data packet and sign it.
    local data = Data(interest.getName());
    local content = "Echo serial " + interest.getName().toUri();
    data.setContent(content);

    data.setSignature(HmacWithSha256Signature());
    // Use the signature object in the data object to avoid an extra copy.
    data.getSignature().getKeyLocator().setType(KeyLocatorType.KEYNAME);
    data.getSignature().getKeyLocator().setKeyName(Name("/key2"));
    KeyChain.signWithHmacWithSha256(data, HMAC_KEY2);

    // Simulate returning the Data packet by adding to inputBlob_ so that
    // readBlob returns it.
    consoleLog
      ("Simulated other device over serial connection sending content " + content);
    local response = data.wireEncode().buf().toBlob();
    if (inputBlob_ == null)
      inputBlob_ = response;
    else {
      // Append.
      inputBlob_.seek(inputBlob_.len());
      inputBlob_.writeblob(response);
    }
  }

  /**
   * This is called periodically by the MicroForwarder to receive an incoming
   * packet. For the stub we return the simulated incoming packet that was
   * created by write().
   * @return {blob} The bytes of the receive buffer, or an empty blob if the
   * receive there is no incoming data.
   */
  function readblob()
  {
    if (inputBlob_ == null)
      // Return a new empty blob since we don't know that the caller will do with it.
      return blob(0);
    else {
      local result = inputBlob_;
      inputBlob_ = null;
      result.seek(0);
      return result;
    }
  }
}

/**
 * Create a MicroForwarder with a route to the agent and another route over a
 * serial connection. Then create an application Face which automatically
 * connects to the MicroForwarder. Register to receive Interests and call
 * onInterest which sends a reply Data packet. You should run this on the Imp
 * Device, and run test-imp-echo-consumer.agent.nut on the Agent.
 */
function testPublish()
{
  // Enable logging. (Remove this to silence logging.)
  MicroForwarder.get().setLogLevel(1);
  MicroForwarder.get().addFace
    ("internal://agent", SquirrelObjectTransport(),
     SquirrelObjectTransportConnectionInfo(agent));

  // TODO: Configure the UART settings for the real serial connection.
  local serial = SerialUartStub();
  local uartTransport = UartTransport();
  local serialFaceId = MicroForwarder.get().addFace
    ("uart://serial", uartTransport, UartTransportConnectionInfo(serial));
  MicroForwarder.get().registerRoute(Name("/testecho2"), serialFaceId)

  local face = Face();
  local prefix = Name("/testecho");
  consoleLog("Register prefix " + prefix.toUri());
  face.registerPrefixUsingObject(prefix, onInterest);

  // Set this to true to use multi-hop forwarding, as opposed to single-hop.
  local useMultiHop = false;
  // Set the min and max values for the random delay.
  local minDelaySeconds = 1.0;
  local maxDelaySeconds = 2.0;

  // Set up the forwarding strategy for single-hop or multi-hop broadcast
  // (depending on useMultiHop).
  function canForward
    (interest, incomingFaceId, incomingFaceUri, outgoingFaceId, outgoingFaceUri,
     routePrefix)
  {
    local isForwardingToSameFace = (incomingFaceId == outgoingFaceId);

    if (incomingFaceUri == "uart://serial") {
      // Coming from the serial port.
      if (prefix.isPrefixOf(interest.getName())) {
        // The Interest is for the application, so let it go to the application
        // but don't forward to other faces.
        if (outgoingFaceUri == "internal://app")
          return true;
        else
          return false;
      }
      else {
        if (useMultiHop) {
          // For multi-hop, we only forward to the same broadcast serial port
          // (after a delay).
          if (outgoingFaceUri != "uart://serial")
            return false;
          else {
            // Forward with a delay.
            local delayRange = maxDelaySeconds - minDelaySeconds;
            local delaySeconds = minDelaySeconds + 
              ((1.0 * math.rand() / RAND_MAX) * delayRange);
            // Return a float value that the MicroForwarder interprets as a delay.
            return delaySeconds;
          }
        }
        else
          // For single-hop, we don't forward packets coming in the serial port.
          return false;
      }
    }

    if (incomingFaceUri == "internal://agent") {
      // Coming from the Agent.
      if (prefix.isPrefixOf(interest.getName())) {
        // The Interest is for the application, so let it go to the application
        // but don't forward to other faces.
        if (outgoingFaceUri == "internal://app")
          return true;
        else
          return false;
      }
      else
        // Not for the application, so forward to other faces including serial,
        // except don't forward to the same face.
        return !isForwardingToSameFace;
    }

    // Let other packets pass, except to the same face.
    return !isForwardingToSameFace;
  }
  MicroForwarder.get().setCanForward(canForward);
}

testPublish();
