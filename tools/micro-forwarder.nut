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

/**
 * A MicroForwarder holds a PIT, FIB and faces to function as a simple NDN
 * forwarder. It has a single instance which you can access with
 * MicroForwarder.get().
 */
class MicroForwarder {
  PIT_ = null;   // array of PitEntry
  FIB_ = null;   // array of FibEntry
  faces_ = null; // array of ForwarderFace
  dataRetransmitQueue_ = null; // array of DataRetransmitEntry
  delayedCallTable_ = null; // WakeupDelayedCallTable
  canForward_ = null; // function
  logLevel_ = 0; // integer
  maxRetransmitRetries_ = 0;
  minRetransmitDelayMilliseconds_ = 6000;
  maxRetransmitDelayMilliseconds_ = 7000;

  debugEnable_ = true; // operant
  logEnable_ = false; // operant

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
    dataRetransmitQueue_ = [];
    delayedCallTable_ = WakeupDelayedCallTable();
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
   * Add a new face to communicate with the given transport. This immediately
   * connects using the connectionInfo.
   * @param {string} uri The URI to use in the faces/query and faces/list
   * commands.
   * @param {Transport} transport An object of a subclass of Transport to use
   * for communication. If the transport object has a "setOnReceivedObject"
   * method, then use it to set the onReceivedObject callback.
   * @param {TransportConnectionInfo} connectionInfo This must be a
   * ConnectionInfo from the same subclass of Transport as transport.
   * @return {integer} The new face ID.
   */
  function addFace(uri, transport, connectionInfo)
  {
    local face = null;
    local thisForwarder = this;
    if ("setOnReceivedObject" in transport)
      transport.setOnReceivedObject
        (function(obj) { thisForwarder.onReceivedObject(face, obj); });
    face = ForwarderFace(uri, transport);

    transport.connect
      (connectionInfo,
       { onReceivedElement = function(element) {
           thisForwarder.onReceivedElement(face, element); } },
       function(){});
    faces_.append(face);

    return face.faceId;
  }

  /**
   * Set the canForward callback. When the MicroForwarder receives an interest
   * which matches the routing prefix on a face, it calls canForward as
   * described below to check if it is OK to forward to the face. This can be
   * used to implement a simple forwarding strategy.
   * @param {function} canForward If not null, and the interest matches the
   * routePrefix of the outgoing face, then the MicroForwarder calls
   * canForward(interest, incomingFaceId, incomingFaceUri, outgoingFaceId,
   * outgoingFaceUri, routePrefix) where interest is the incoming Interest
   * object, incomingFaceId is the ID integer of the incoming face,
   * incomingFaceUri is the URI string of the incoming face, outgoingFaceId is
   * the ID integer of the outgoing face, outgoingFaceUri is the URI string of
   * the outgoing face, and routePrefix is the prefix Name of the matching
   * outgoing route. If the canForward callback returns true (or a float 0.0)
   * then immediately forward to the outgoing face. If it returns false (or a
   * negative float), then don't forward. If canForward returns a positive float
   * x, then forward after a delay of x seconds using imp.wakeup (only supported
   * on the Imp).
   * IMPORTANT: The canForward callback is called when the routePrefix matches,
   * even if the outgoing face is the same as the incoming face. So you must
   * check if incomingFaceId == outgoingFaceId and return false if you don't
   * want to forward to the same face.
   */
  function setCanForward(canForward) { canForward_ = canForward; }

  /**
   * Find or create the FIB entry with the given name and add the ForwarderFace
   * with the given faceId.
   * @param {Name} name The name of the FIB entry.
   * @param {integer} faceId The face ID of the face for the route.
   * @return {bool} True for success, or false if can't find the ForwarderFace
   * with faceId.
   */
  function registerRoute(name, faceId)
  {
    local nexthopFace = findFace_(faceId);
    if (nexthopFace == null)
      return false;

    // Check for a FIB entry for the name and add the face.
    for (local i = 0; i < FIB_.len(); ++i) {
      local fibEntry = FIB_[i];
      if (fibEntry.name.equals(name)) {
        // Make sure the face is not already added.
        if (fibEntry.faces.indexOf(nexthopFace) < 0)
          fibEntry.faces.push(nexthopFace);

        return true;
      }
    }

    // Make a new FIB entry.
    local fibEntry = FibEntry(name);
    fibEntry.faces.push(nexthopFace);
    FIB_.push(fibEntry);

    return true;
  }

  // Enable consoleLog statements, called from Operant code
  function enableDebug() { debugEnable_ = true; }
  function enableLog() { logEnable_ = true; }

  /**
   * Use PacketExtensions.makeExtension to prepend the extension to the
   * extensions header that is prepended to each outgoing Interest on the given
   * face. You can call this multiple times to prepend multiple extensions.
   * @param {integer} faceId The face ID of the face for outgoing Interests. If
   * there is not face with the faceId, do nothing.
   * @param {integer} code The extension code byte value where the 5 bits of the
   * code are in the most-significant bits of the byte. For example,
   * PacketExtensionCode.GeoTag .
   * @param {integer} payload The 27-bit extension payload.
   */
  function prependInterestExtension(faceId, code, payload)
  {
    local face = findFace_(faceId);
    if (face != null)
      face.prependInterestExtension(code, payload)
  }

  /**
   * Set the log level for consoleLog statements.
   * @param {integer} logLevel The log level value as follows. 0 (default) =
   * no logging. 1 = log information of incoming and outgoing Interest and Data
   * packets.
   */
  function setLogLevel(logLevel) { logLevel_ = logLevel; }

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
    local geoTag = null;
    local transmitFailed = false;
    if (debugEnable_) consoleLog("<DBUG> onReceivedElement </DBUG>");  // operant
    if (PacketExtensions.isExtension(element.get(0))) {
      local i = 0;
      for (;
           i < element.len() && PacketExtensions.isExtension(element.get(i));
           i += 4) {
        local code = (element.get(i) & 0xf8);
        local payload = PacketExtensions.getPayload(element, i);

        if ((code & 0x80) != 0) {
          // We are required to process this extension.

          if (code == PacketExtensionCode.ErrorReporting) {
            if (payload == ErrorReportingPayload.TransmitFailed)
            {
              if (debugEnable_) consoleLog("<DBUG> Transmit failed </DBUG>");  // operant
              transmitFailed = true;
            }
            else {
              // Error: Unrecognized error payload. Drop the packet.
              return;
            }
          }
          else {
            // Error: Unrecognized required header. Drop the packet.
            return;
          }
        }
        else {
          // This extension is optional.
          if (code == PacketExtensionCode.GeoTag) {
            if (geoTag == null)
              // Get the first GeoTag.
              geoTag = payload;
          }
        }
      }

      // Now strip the packet extensions header so we can decode.
      element = element.slice(i);
    }

    local interest = null;
    local data = null;
    // Use Buffer.get to avoid using the metamethod.
    if (element.get(0) == Tlv.Interest || element.get(0) == Tlv.Data) {
      local decoder = TlvDecoder(element);
      if (decoder.peekType(Tlv.Interest, element.len())) {
        interest = Interest();
        interest.wireDecode(element, TlvWireFormat.get());

        interest.setGeoTag(geoTag);
      }
      else if (decoder.peekType(Tlv.Data, element.len())) {
        data = Data();
        data.wireDecode(element, TlvWireFormat.get());
      }
    }

    local nowSeconds = NdnCommon.getNowSeconds();
    // Remove timed-out PIT entries
    // Iterate backwards so we can remove the entry and keep iterating.
    for (local i = PIT_.len() - 1; i >= 0; --i) {
      if (nowSeconds >= PIT_[i].timeoutEndSeconds) {
        removePitEntry_(i);
      }
    }
    // Remove timed-out Data retransmit queue entries.
    for (local i = dataRetransmitQueue_.len() - 1; i >= 0; --i) {
      if (nowSeconds >= dataRetransmitQueue_[i].timeoutEndSeconds_) {
        dataRetransmitQueue_[i].isRemoved_ = true;
        dataRetransmitQueue_.remove(i);
      }
    }

    // Now process as Interest or Data.
    if (interest != null) 
    {
      if (debugEnable_) consoleLog("<DBUG> Processing Interest " + interest.getName() + " </DBUG>");  // operant
      if (transmitFailed) 
      {
        // Find the PIT entry of the failed transmission.
        if (debugEnable_) consoleLog("<DBUG> Interest TX failed </DBUG>");  // operant
        for (local i = 0; i < PIT_.len(); ++i) {
          local entry = PIT_[i];
          if (entry.interest.getNonce().equals(interest.getNonce()) &&
              entry.interest.getName().equals(interest.getName())) {

            // This will only schedule if there are more retransmit tries.
            if (debugEnable_) consoleLog("<DBUG> Scheduling Interest retransmission of nonce: " + interest.getNonce().toHex() + " </DBUG>");  // operant
            entry.scheduleRetransmit(face, this);
            return;
          }
        }

        return;
      }

      if (localhostNamePrefix.match(interest.getName()))
      {
        // Ignore localhost.
        if (debugEnable_) consoleLog("<DBUG> Ignoring localhost </DBUG>");  // operant
        if (logEnable_) consoleLog("</MFWD></LOG>");  // operant
        return;
      }
        

      // First check for a duplicate nonce on any face.
      for (local i = 0; i < PIT_.len(); ++i) 
      {
        if (debugEnable_) consoleLog("<DBUG> Checking for duplicate nonce </DBUG>");  // operant
        local entry = PIT_[i];
        if (entry.interest.getNonce().equals(interest.getNonce())) {

          if (entry.retransmitFace_ != null &&
              entry.interest.getName().equals(interest.getName())) {
            // The Interest had a transmitFailed and was scheduled for
            // retransmission, but another forwarder has transmitted it, so
            // remove this PIT entry and drop this Interest.
            // Note that removePitEntry_ sets entry.isRemoved_ true so that
            // future retransmissions are also cancelled.
            // TODO: What if face != entry.retransmitFace_?
            // TODO: What if retransmission is scheduled on multiple faces?
            if (debugEnable_) consoleLog("<DBUG> PIT entry for Interest scheduled for retransmission removed; nonce: " + interest.getNonce().toHex() + " </DBUG>");  // operant
            removePitEntry_(i);
            return;
          }

          // Drop the duplicate nonce.
          if (debugEnable_) consoleLog("<DBUG> Interest already in PIT was dropped </DBUG>");  // operant
          if (logEnable_) {  // operant
      	    consoleLog("<DROP><INT> " +
              interest.getName().toUri() + "</INT><NONC>" + interest.getNonce().toHex() +
		          "</NONC><FACE>" + face.uri + "</FACE></DROP>");
          }
          return;
        }
      }

      // Check for a duplicate Interest.
      local timeoutEndSeconds;
      if (interest.getInterestLifetimeMilliseconds() != null)
        timeoutEndSeconds = nowSeconds + (interest.getInterestLifetimeMilliseconds() / 1000.0).tointeger();
      else
        // Use a default timeout.
        timeoutEndSeconds = nowSeconds + 4;
      for (local i = 0; i < PIT_.len(); ++i) {
        local entry = PIT_[i];
        // TODO: Check interest equality of appropriate selectors.

        if (entry.inFace_ == face &&
            entry.interest.getName().equals(interest.getName())) {
            if (debugEnable_) consoleLog("<DBUG> Duplicate Interest in PIT </DBUG>");  // operant
            // Duplicate PIT entry.
            // Update the interest timeout.
            if (timeoutEndSeconds > entry.timeoutEndSeconds)
            entry.timeoutEndSeconds = timeoutEndSeconds;
          return;
        }
      }

      // Add to the PIT.
      local pitEntry = PitEntry
        (interest, face, timeoutEndSeconds, maxRetransmitRetries_);
      PIT_.append(pitEntry);

      if (broadcastNamePrefix.match(interest.getName())) {
        // Special case: broadcast to all faces.
        for (local i = 0; i < faces_.len(); ++i) {
          local outFace = faces_[i];
          // Don't send the interest back to where it came from.
          if (outFace != face) {
            // For now, don't add an extensions header to broadcast Interests.
            pitEntry.outFace_ = outFace;
            outFace.sendBuffer(element);
          }
        }
      }
      else {
        // Send the interest to the faces in matching FIB entries.
        for (local i = 0; i < FIB_.len(); ++i) {
          local fibEntry = FIB_[i];

          // TODO: Need to check all for longest prefix match?
          if (fibEntry.name.match(interest.getName())) {
            for (local j = 0; j < fibEntry.faces.len(); ++j) {
              local outFace = fibEntry.faces[j];
              // If canForward_ is not defined, don't send the interest back to
              // where it came from.
              if (!(canForward_ == null && outFace == face)) {
                local outBuffer = element;
                if (outFace.interestExtensionsHeader != null)
                  // Prepend the extensions header.
                  outBuffer = Buffer.concat
                    ([outFace.interestExtensionsHeader.buf(), outBuffer]);

                local canForwardResult = true;
                if (canForward_ != null)
                  // Note that canForward_  is called even if outFace == face.
                  canForwardResult = canForward_
                    (interest, face.faceId, face.uri, outFace.faceId outFace.uri,
                     fibEntry.name);

                pitEntry.outFace_ = outFace;
                if (canForwardResult == true ||
                    typeof canForwardResult == "float" && canForwardResult == 0.0) 
                  {
                    // Forward now.
                    if (debugEnable_) consoleLog("<DBUG> Forwarding Interest immediately </DBUG>");  // operant
                    outFace.sendBuffer(outBuffer);
                  }
                  else if (typeof canForwardResult == "float" && canForwardResult > 0.0) {
                    // Forward after a delay.
                    if (debugEnable_) consoleLog("<DBUG> Forwarding Interest after delay of " + canForwardResult + "seconds </DBUG>");  // operant
                    if (logEnable_) {  // operant
                      consoleLog("</MFWD></LOG>");
                    }
                    imp.wakeup(canForwardResult, 
                             function() { outFace.sendBuffer(outBuffer); });
                }
              }
            }
          }
        }
      }
    }
    else if (data != null) {

      if (transmitFailed) {
        // Find the queue entry of the failed transmission.
        for (local i = 0; i < dataRetransmitQueue_.len(); ++i) {
          local entry = dataRetransmitQueue_[i];
          if (entry.data_.getName().equals(data.getName())) {
            // This will only schedule if there are more retransmit tries.
            entry.scheduleRetransmit(face, this);
            return;
          }
        }

        // This data packet was not scheduled for retransmit, so schedule it.
        local entry = DataRetransmitEntry(data, maxRetransmitRetries_);
        dataRetransmitQueue_.append(entry);
        entry.scheduleRetransmit(face, this);
        return;
      }

      // Send the data packet to the face for each matching PIT entry.
      // Iterate backwards so we can remove the entry and keep iterating.
      
      local foundMatchingPITEntry = false; // operant
      
      for (local i = PIT_.len() - 1; i >= 0; --i) {
        local entry = PIT_[i];

        // Note: entry.outFace_ is null when waiting to retransmit after a
        // failed transmission, so ignore the PIT entry.
        if (entry.inFace_ != null && entry.outFace_ != null &&
            entry.interest.matchesData(data)) {
          if (debugEnable_) consoleLog("<DBUG> Forwarding Data & removing PIT entry i=: " + i + " </DBUG>");  // operant
          // Remove the entry before sending.
          removePitEntry_(i);

          entry.inFace_.sendBuffer(element);
          entry.inFace_ = null;

        }
      }
      if (debugEnable_ == true && foundMatchingPITEntry == false) consoleLog("<DBUG> No matching PIT entry; Data dropped </DBUG>");  // operant
      if ( logEnable_) {  // operant
	        consoleLog("<DROP><DATA> " + data.getName().toUri() + "</DATA><FACE>" + face.uri + "</FACE></DROP>");
	        consoleLog("</MFWD></LOG>");
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
      local faceId;
      if ("faceId" in obj && obj.faceId != null)
        faceId = obj.faceId;
      else
        // Use the requesting face.
        faceId = face.faceId;

      if (!registerRoute(Name(obj.nameUri), faceId))
        // TODO: Send error reply?
        return;

      obj.statusCode <- 200;
      face.sendObject(obj);
    }
  }

  /**
   * If entry.nRetransmitRetries_ is still greater than zero, get the random
   * delay between minRetransmitDelayMilliseconds_ and
   * maxRetransmitDelayMilliseconds_, and use
   * delayedCallTable_.callLater to call entry.onRetransmit_() after the delay.
   * (This is an internal method, for example called by PitEntry.
   * @param {object} The object with integer nRetransmitRetries_ and the method
   * of no arguments onRetransmit_().
   */
  function delayedRetransmit(entry)
  {
    if (entry.nRetransmitRetries_ <= 0)
      return;

    local delayRangeMilliseconds =
      maxRetransmitDelayMilliseconds_ - minRetransmitDelayMilliseconds_;
    local delayMilliseconds =
      minRetransmitDelayMilliseconds_ +
      (1.0 * math.rand() / RAND_MAX) * delayRangeMilliseconds;

    // Set the delayed call.
    delayedCallTable_.callLater
      (delayMilliseconds, function() { entry.onRetransmit_(); });
  }

  /**
   * A private method to find the face in faces_ with the faceId.
   * @param {integer} The faceId.
   * @return {ForwarderFace} The ForwarderFace, or null if not found.
   */
  function findFace_(faceId)
  {
    local nexthopFace = null;
    for (local i = 0; i < faces_.len(); ++i) {
      if (faces_[i].faceId == faceId)
        return faces_[i];
    }

    return null;
  }

  /**
   * Mark the PitEntry at PIT_[i] as removed (in case something references it)
   * and remove it.
   */
  function removePitEntry_(i)
  {
    PIT_[i].isRemoved_ = true;
    PIT_.remove(i);
  }
}

// We use a global variable because static member variables are immutable.
MicroForwarder_instance <- null;

/**
 * A PitEntry is used in the PIT to record the face on which an Interest came 
 * in. (This is not to be confused with the entry object used by the application
 * library's PendingInterestTable class.)
 */
class PitEntry {
  interest = null;
  inFace_ = null;
  timeoutEndSeconds = null;
  isRemoved_ = false;
  // TODO: This should be a list for retries on multiple faces.
  nRetransmitRetries_ = 0;
  retransmitFace_ = null;
  outFace_ = null;

  debugEnable_ = true; // operant
  logEnable_ = false; // operant


  /**
   * Create a PitEntry for the interest and incoming face.
   * @param {Interest} interest The pending Interest.
   * @param {ForwarderFace} inFace The Interest's incoming face (and where the
   * matching Data packet will be sent).
   * @param {integer} timeoutEndSeconds The time in seconds (based on
   * NdnCommon.getNowSeconds()) when the interest times out.
   * @param {integer} nRetransmitRetries The initial number of retransmit
   * retries.
   */
  constructor(interest, inFace, timeoutEndSeconds, nRetransmitRetries)
  {
    this.interest = interest;
    this.inFace_ = inFace;
    this.timeoutEndSeconds = timeoutEndSeconds;
    nRetransmitRetries_ = nRetransmitRetries;
  }

  /**
   * Schedule to retransmit this interest after a random delay between
   * minRetransmitDelayMilliseconds_ and maxRetransmitDelayMilliseconds_. Since
   * we are scheduling a retransmit, assume the send to outFace_ failed and set
   * it to null. If already scheduled for retransmit, don't retransmit. If
   * nRetransmitRetries_ is zero, don't retransmit. If isRemoved_ becomes true
   * while waiting to retransmit, don't retransmit.
   * @param {ForwarderFace} The face on which to retransmit the interest.
   * @param {MicroForwarder} forwarder This calls forwarder.delayedRetransmit().
   */
  function scheduleRetransmit(retransmitFace, forwarder)
  {
    outFace_ = null;

    if (debugEnable_) consoleLog("<DBUG> Interest retransmission being scheduled; # of retries: " + nRetransmitRetries_ + " </DBUG>");  // operant

    if (retransmitFace_ != null)
      // Already scheduled for retransmit.
      return;

    if (nRetransmitRetries_ <= 0)
      return;



    retransmitFace_ = retransmitFace;
    forwarder.delayedRetransmit(this);
  }

  /**
   * This is the callback from delayedCallTable_.callLater. Decrement
   * nRetransmitRetries_ and retransmit the Interest on retransmitFace_,
   * including retransmitFace_.interestExtensionsHeader (if any). Set
   * outFace_ to retransmitFace_ to indicate that the packet is under
   * transmission, then set retransmitFace_ to null since we are no longer
   * waiting to transmit. If isRemoved_, do nothing.

   */
  function onRetransmit_()
  {
    if (isRemoved_)
      // This PitEntry was removed while waiting to retransmit.
      return;
  
    if (nRetransmitRetries_ <= 0 || retransmitFace_ == null)
      // We don't really expect this.
      return;

    nRetransmitRetries_ -= 1;

    // Retransmit.
    local outBuffer = interest.wireEncode().buf();
    if (retransmitFace_.interestExtensionsHeader != null)
      // Prepend the extensions header.
      outBuffer = Buffer.concat
        ([retransmitFace_.interestExtensionsHeader.buf(), outBuffer]);
    outFace_ = retransmitFace_;
    retransmitFace_ = null;
    try {
      outFace_.sendBuffer(outBuffer);
    } catch (ex) {
      // Log and ignore the exception so that we continue and try again.
      consoleLog("Error in sendBuffer: " + ex);
    }
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
  // extensionsHeader is a Blob with the encoded header, or null if none.
  interestExtensionsHeader = null;

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
    if (transport != null && "sendObject" in transport)
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

  /**
   * Use PacketExtensions.makeExtension to prepend the extension to the
   * extensions header that is prepended to each outgoing Interest. You can call
   * this multiple times to prepend multiple extensions.
   * @param {integer} code The extension code byte value where the 5 bits of the
   * code are in the most-significant bits of the byte. For example,
   * PacketExtensionCode.GeoTag .
   * @param {integer} payload The 27-bit extension payload.
   */
  function prependInterestExtension(code, payload)
  {
    local extension = PacketExtensions.makeExtension(code, payload);

    if (interestExtensionsHeader == null)
      // Set the first extension.
      interestExtensionsHeader = extension;
    else
      // Prepend the extension.
      interestExtensionsHeader = Blob
        (Buffer.concat([extension.buf(), interestExtensionsHeader.buf()]),
         false)
  }
}

/**
 * A DataRetransmitEntry is created to track the retransmission of a Data
 * packet.
 */
class DataRetransmitEntry {
  data_ = null;
  isRemoved_ = false;
  // TODO: This should be a list for retries on multiple faces.
  nRetransmitRetries_ = 0;
  retransmitFace_ = null;
  outFace_ = null;
  timeoutEndSeconds_ = 0;
  // TIMEOUT_SECONDS is enough time to get a transmit nack.
  static TIMEOUT_SECONDS = 4;

  /**
   * Create a DataRetransmitEntry for the Data packet. Then you should call
   * scheduleRetransmit.
   * @param {Data} The Data packet to retransmit.
   * @param {integer} nRetransmitRetries The initial number of retransmit
   * retries.
   */
  constructor(data, nRetransmitRetries)
  {
    data_ = data;
    nRetransmitRetries_ = nRetransmitRetries;
    timeoutEndSeconds_ = NdnCommon.getNowSeconds() + TIMEOUT_SECONDS;
  }

  /**
   * Schedule to retransmit the Data packet after a random delay between
   * minRetransmitDelayMilliseconds_ and maxRetransmitDelayMilliseconds_. Since
   * we are scheduling a retransmit, assume the send to outFace_ failed and set
   * it to null. If already scheduled for retransmit, don't retransmit. If
   * nRetransmitRetries_ is zero, don't retransmit. If isRemoved_ becomes true
   * while waiting to retransmit, don't retransmit.
   * @param {ForwarderFace} retransmitFace The face on which to retransmit the
   * Data packet.
   * @param {MicroForwarder} forwarder This calls forwarder.delayedRetransmit().
   */
  function scheduleRetransmit(retransmitFace, forwarder)
  {
    outFace_ = null;
  
    if (retransmitFace_ != null)
      // Already scheduled for retransmit.
      return;

    if (nRetransmitRetries_ <= 0)
      return;

    retransmitFace_ = retransmitFace;
    forwarder.delayedRetransmit(this);
  }

  /**
   * This is the callback from delayedCallTable_.callLater. Decrement
   * nRetransmitRetries_ and retransmit the Data on retransmitFace_. Set
   * outFace_ to retransmitFace_ to indicate that the packet is under
   * transmission, then set retransmitFace_ to null since we are no longer
   * waiting to transmit. Also reset timeoutEndSeconds_. If isRemoved_, do
   * nothing.
   */
  function onRetransmit_()
  {
    if (isRemoved_)
      // This entry was removed while waiting to retransmit.
      return;

    if (nRetransmitRetries_ <= 0 || retransmitFace_ == null)
      // We don't really expect this.
      return;

    nRetransmitRetries_ -= 1;

    outFace_ = retransmitFace_;
    retransmitFace_ = null;
    timeoutEndSeconds_ = NdnCommon.getNowSeconds() + TIMEOUT_SECONDS;
    try {
      outFace_.sendBuffer(data_.wireEncode().buf());
    } catch (ex) {
      // Log and ignore the exception so that we continue and try again.
      consoleLog("Error in sendBuffer: " + ex);
    }
  }
}

ForwarderFace_lastFaceId <- 0;
