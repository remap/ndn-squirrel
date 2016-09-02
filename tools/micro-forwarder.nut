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

/**
 * A MicroForwarder holds a PIT, FIB and faces to function as a simple NDN
 * forwarder. It has a single instance which you can access with
 * MicroForwarder.get().
 */
class MicroForwarder {
  PIT_ = null;   // array of PitEntry
  FIB_ = null;   // array of FibEntry
  faces_ = null; // array of ForwarderFace

  static localhostNamePrefix = Name("/localhost");
  static broadcastNamePrefix = Name("/ndn/broadcast");

  /**
   * Create a new MicroForwarder. You must call addFace(). If running on the Imp
   * device, call addFace("internal://agent", agent).
   * Normally you do not create a MicroForwader, but use the static get().
   */
  constructor()
  {
    PIT_ = [];
    FIB_ = [];
    faces_ = [];
  }

  /**
   * Get a singleton instance of a MicroForwarder.
   * @return {MicroForwarder} The singleton instance.
   */
  static function get()
  {
    if (MicroForwarder_instance == null)
      ::MicroForwarder_instance = MicroForwarder();
    return MicroForwarder_instance;
  }

  /**
   * Add a new face to use a SquirrelObjectTransport, communicating with
   * connnection.on and connection.send.
   * @param {string} uri The URI to use in the faces/query and faces/list
   * commands.
   * @param {instance} connection An object which supports "on" and "send"
   * methods, such as an Imp agent or device object. If running on the Imp
   * device, this should be the agent object.
   */
  function addFace(uri, connection)
  {
    local face = null;
    local thisForwarder = this;
    local transport = SquirrelObjectTransport
      (function(obj) { thisForwarder.onReceivedObject(face, obj); });
    face = ForwarderFace(uri, transport);

    transport.connect
      (SquirrelObjectTransportConnectionInfo(connection),
       { onReceivedElement = function(element) {
           thisForwarder.onReceivedElement(face, element); } },
       function(){});
    faces_.append(face);
  }

  /**
   * This is called by the listener when an entire TLV element is received.
   * If it is an Interest, look in the FIB for forwarding. If it is a Data packet,
   * look in the PIT to match an Interest.
   * @param {ForwarderFace} face The ForwarderFace with the transport that
   * received the element.
   * @param {Buffer} element The received element.
   */
  function onReceivedElement(face, element)
  {
    local interest = null;
    local data = null;
    if (element[0] == Tlv.Interest || element[0] == Tlv.Data) {
      local decoder = TlvDecoder(element);
      if (decoder.peekType(Tlv.Interest, element.len())) {
        interest = Interest();
        interest.wireDecode(element, TlvWireFormat.get());
      }
      else if (decoder.peekType(Tlv.Data, element.len())) {
        data = Data();
        data.wireDecode(element, TlvWireFormat.get());
      }
    }

    // Now process as Interest or Data.
    if (interest != null) {
      if (localhostNamePrefix.match(interest.getName()))
        // Ignore localhost.
        return;

      for (local i = 0; i < PIT_.len(); ++i) {
        // TODO: Check interest equality of appropriate selectors.
        if (PIT_[i].face == face &&
            PIT_[i].interest.getName().equals(interest.getName())) {
          // Duplicate PIT entry.
          // TODO: Update the interest timeout?
          return;
        }
      }

      // Add to the PIT.
      local pitEntry = PitEntry(interest, face);
      PIT_.append(pitEntry);
/*    TODO: Implement timeout.
      // Set the interest timeout timer.
      local timeoutCallback = function() {
        // Remove the face's entry from the PIT
        local index = PIT_.find(pitEntry);
        if (index != null)
          PIT_.remove(index);
      };
      local timeoutMilliseconds = (interest.getInterestLifetimeMilliseconds() || 4000);
      setTimeout(timeoutCallback, timeoutMilliseconds);
*/

      if (broadcastNamePrefix.match(interest.getName())) {
        // Special case: broadcast to all faces.
        for (local i = 0; i < faces_.len(); ++i) {
          local outFace = faces_[i];
          // Don't send the interest back to where it came from.
          if (outFace != face)
            outFace.sendBuffer(element);
        }
      }
      else {
        // Send the interest to the faces in matching FIB entries.
        for (local i = 0; i < FIB_.len(); ++i) {
          local fibEntry = FIB_[i];

          // TODO: Need to do longest prefix match?
          if (fibEntry.name.match(interest.getName())) {
            for (local j = 0; j < fibEntry.faces.len(); ++j) {
              local outFace = fibEntry.faces[j];
              // Don't send the interest back to where it came from.
              if (outFace != face)
                outFace.sendBuffer(element);
            }
          }
        }
      }
    }
    else if (data != null) {
      // Send the data packet to the face for each matching PIT entry.
      // Iterate backwards so we can remove the entry and keep iterating.
      for (local i = PIT_.len() - 1; i >= 0; --i) {
        if (PIT_[i].face != face && PIT_[i].face != null &&
            PIT_[i].interest.matchesData(data)) {
          PIT_[i].face.sendBuffer(element);
          PIT_[i].face = null;

          // Remove the entry.
          PIT_.remove(i);
        }
      }
    }
  }

  /**
   * This is called when an object is received on a local face.
   * @param {ForwarderFace} face The ForwarderFace with the transport that
   * received the object.
   * @param {table} obj A Squirrel table where obj.type is a string.
   */
  function onReceivedObject(face, obj)
  {
    if (!(typeof obj == "table" && "type" in obj))
      return;

    if (obj.type == "rib/register") {
      local nexthopFace = null;
      if (!("faceId" in obj) || obj.faceId == null)
        // Use the requesting face.
        nexthopFace = face;
      else {
        // Find the face with the faceId.
        for (local i = 0; i < faces_.len(); ++i) {
          if (faces_[i].faceId == obj.faceId) {
            nexthopFace = faces_[i];
            break;
          }
        }

        if (nexthopFace == null) {
          // TODO: Send error reply.
          return;
        }
      }

      local name = Name(obj.nameUri);
      // Check for a FIB entry for the name and add the face.
      local foundFibEntry = false;
      for (local i = 0; i < FIB_.len(); ++i) {
        local fibEntry = FIB_[i];
        if (fibEntry.name.equals(name)) {
          // Make sure the face is not already added.
          if (fibEntry.faces.indexOf(nexthopFace) < 0)
            fibEntry.faces.push(nexthopFace);

          foundFibEntry = true;
          break;
        }
      }

      if (!foundFibEntry) {
        // Make a new FIB entry.
        local fibEntry = FibEntry(name);
        fibEntry.faces.push(nexthopFace);
        FIB_.push(fibEntry);
      }

      obj.statusCode <- 200;
      face.sendObject(obj);
    }
  }
}

// We use a global variable because static member variables are immutable.
MicroForwarder_instance <- null;

/**
 * A PitEntry is used in the PIT to record the face on which an Interest came 
 * in. (This is not to be confused with the entry object used by the application
 * library's PendingInterestTable class.)
 * @param {Interest} interest
 * @param {ForwarderFace} face
 */
class PitEntry {
  interest = null;
  face = null;

  constructor(interest, face)
  {
    this.interest = interest;
    this.face = face;
  }
}

/**
 * A FibEntry is used in the FIB to match a registered name with related faces.
 * @param {Name} name The registered name for this FIB entry.
 */
class FibEntry {
  name = null;
  faces = null; // array of ForwarderFace

  constructor (name)
  {
    this.name = name;
    this.faces = [];
  }
}

/**
 * A ForwarderFace is used by the faces list to represent a connection using the
 * given Transport.
 */
class ForwarderFace {
  uri = null;
  transport = null;
  faceId = null;

  /**
   * Create a ForwarderFace and set the faceId to a unique value.
   * @param {string} uri The URI to use in the faces/query and faces/list
   * commands.
   * @param {Transport} transport Communicate using the Transport object. You
   * must call transport.connect with an elementListener object whose
   * onReceivedElement(element) calls
   * microForwarder.onReceivedElement(face, element), with this face. If available
   * the transport's onReceivedObject(obj) should call
   * microForwarder.onReceivedObject(face, obj), with this face.
   */
  constructor(uri, transport)
  {
    this.uri = uri;
    this.transport = transport;
    this.faceId = ++ForwarderFace_lastFaceId;
  }

  /**
   * Check if this face is still enabled.
   * @returns {bool} True if this face is still enabled.
   */
  function isEnabled() { return transport != null; }

  /**
   * Disable this face so that isEnabled() returns false.
   */
  function disable() { transport = null; };

  /**
   * Send the object to the transport, if this face is still enabled.
   * @param {object} obj The object to send.
   */
  function sendObject(obj)
  {
    if (transport != null && transport.sendObject != null)
      transport.sendObject(obj);
  }

  /**
   * Send the buffer to the transport, if this face is still enabled.
   * @param {Buffer} buffer The bytes to send.
   */
  function sendBuffer(buffer)
  {
    if (this.transport != null)
      this.transport.send(buffer);
  }
}

ForwarderFace_lastFaceId <- 0;
