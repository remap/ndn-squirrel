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

enum FaceConnectStatus_ { UNCONNECTED, CONNECT_REQUESTED, CONNECT_COMPLETE }

/**
 * A Face provides the top-level interface to the library. It holds a connection
 * to a forwarder and supports interest / data exchange.
 */
class Face {
  transport_ = null;
  connectionInfo_ = null;
  pendingInterestTable_ = null;
  interestFilterTable_ = null;
  registeredPrefixTable_ = null;
  delayedCallTable_ = null;
  connectStatus_ = FaceConnectStatus_.UNCONNECTED;
  lastEntryId_ = 0;
  doingProcessEvents_ = false;
  timeoutPrefix_ = Name("/local/timeout");
  nonceTemplate_ = Blob(Buffer(4), false);

  /**
   * Create a new Face. The constructor has the forms Face() or
   * Face(transport, connectionInfo). If the default Face() constructor is
   * used, create a MicroForwarderTransport connection to the static instance
   * MicroForwarder.get(). Otherwise connect using the given transport and
   * connectionInfo.
   * @param {Transport} transport (optional) An object of a subclass of
   * Transport to use for communication. If supplied, you must also supply a
   * connectionInfo.
   * @param {TransportConnectionInfo} connectionInfo (optional) This must be a
   * ConnectionInfo from the same subclass of Transport as transport.
   */
  constructor(transport = null, connectionInfo = null)
  {
    if (transport == null) {
      transport_ = MicroForwarderTransport();
      connectionInfo_ = MicroForwarderTransportConnectionInfo();
    }
    else {
      transport_ = transport;
      connectionInfo_ = connectionInfo;
    }

    pendingInterestTable_ = PendingInterestTable();
    interestFilterTable_ = InterestFilterTable();
// TODO    registeredPrefixTable_ = RegisteredPrefixTable(interestFilterTable_);
    delayedCallTable_ = DelayedCallTable()
  }

  /**
   * Send the interest through the transport, read the entire response and call
   * onData, onTimeout or onNetworkNack as described below.
   * There are two forms of expressInterest. The first form takes the exact
   * interest (including lifetime):
   * expressInterest(interest, onData [, onTimeout] [, onNetworkNack] [, wireFormat]).
   * The second form creates the interest from a name and optional interest template:
   * expressInterest(name [, template], onData [, onTimeout] [, onNetworkNack] [, wireFormat]).
   * @param {Interest} interest The Interest to send which includes the interest
   * lifetime for the timeout.
   * @param {function} onData When a matching data packet is received, this
   * calls onData(interest, data) where interest is the interest given to
   * expressInterest and data is the received Data object. NOTE: You must not
   * change the interest object - if you need to change it then make a copy.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {function} onTimeout (optional) If the interest times out according
   * to the interest lifetime, this calls onTimeout(interest) where interest is
   * the interest given to expressInterest.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {function} onNetworkNack (optional) When a network Nack packet for
   * the interest is received and onNetworkNack is not null, this calls
   * onNetworkNack(interest, networkNack) and does not call onTimeout. interest
   * is the sent Interest and networkNack is the received NetworkNack. If
   * onNetworkNack is supplied, then onTimeout must be supplied too. However, if 
   * a network Nack is received and onNetworkNack is null, do nothing and wait
   * for the interest to time out. (Therefore, an application which does not yet
   * process a network Nack reason treats a Nack the same as a timeout.)
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {Name} name The Name for the interest. (only used for the second
   * form of expressInterest).
   * @param {Interest} template (optional) If not omitted, copy the interest 
   * selectors from this Interest. If omitted, use a default interest lifetime.
   * (only used for the second form of expressInterest).
   * @param {WireFormat} (optional) A WireFormat object used to encode the
   * message. If omitted, use WireFormat.getDefaultWireFormat().
   * @return {integer} The pending interest ID which can be used with
   * removePendingInterest.
   * @throws string If the encoded interest size exceeds
   * Face.getMaxNdnPacketSize().
   */
  function expressInterest
    (interestOrName, arg2 = null, arg3 = null, arg4 = null, arg5 = null,
     arg6 = null)
  {
    local interestCopy;
    if (interestOrName instanceof Interest)
      // Just use a copy of the interest.
      interestCopy = Interest(interestOrName);
    else {
      // The first argument is a name. Make the interest from the name and
      // possible template.
      if (arg2 instanceof Interest) {
        local template = arg2;
        // Copy the template.
        interestCopy = Interest(template);
        interestCopy.setName(interestOrName);

        // Shift the remaining args to be processed below.
        arg2 = arg3;
        arg3 = arg4;
        arg4 = arg5;
        arg5 = arg6;
      }
      else {
        // No template.
        interestCopy = Interest(interestOrName);
        // Use a default timeout.
        interestCopy.setInterestLifetimeMilliseconds(4000.0);
      }
    }

    local onData = arg2;
    local onTimeout;
    local onNetworkNack;
    local wireFormat;
    // arg3,       arg4,          arg5 may be:
    // OnTimeout,  OnNetworkNack, WireFormat
    // OnTimeout,  OnNetworkNack, null
    // OnTimeout,  WireFormat,    null
    // OnTimeout,  null,          null
    // WireFormat, null,          null
    // null,       null,          null
    if (typeof arg3 == "function")
      onTimeout = arg3;
    else
      onTimeout = function() {};

    if (typeof arg4 == "function")
      onNetworkNack = arg4;
    else
      onNetworkNack = null;

    if (arg3 instanceof WireFormat)
      wireFormat = arg3;
    else if (arg4 instanceof WireFormat)
      wireFormat = arg4;
    else if (arg5 instanceof WireFormat)
      wireFormat = arg5;
    else
      wireFormat = WireFormat.getDefaultWireFormat();

    local pendingInterestId = getNextEntryId();

    // Set the nonce in our copy of the Interest so it is saved in the PIT.
    interestCopy.setNonce(Face.nonceTemplate_);
    interestCopy.refreshNonce();

    // TODO: Handle async connect.
    connectSync();
    expressInterestHelper_
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack,
       wireFormat);

    return pendingInterestId;
  }

  /**
   * Do the work of reconnectAndExpressInterest once we know we are connected.
   * Add to the pendingInterestTable_ and call transport_.send to send the
   * interest.
   * @param {integer} pendingInterestId The getNextEntryId() for the pending
   * interest ID which expressInterest got so it could return it to the caller.
   * @param {Interest} interestCopy The Interest to send, which has already
   * been copied.
   * @param {function} onData A function object to call when a matching data
   * packet is received.
   * @param {function} onTimeout A function to call if the interest times out.
   * If onTimeout is null, this does not use it.
   * @param {function} onNetworkNack A function to call when a network Nack
   * packet is received. If onNetworkNack is null, this does not use it.
   * @param {WireFormat} wireFormat A WireFormat object used to encode the
   * message.
   */
  function expressInterestHelper_
    (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack,
     wireFormat)
  {
    local pendingInterest = pendingInterestTable_.add
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack);
    if (pendingInterest == null)
      // removePendingInterest was already called with the pendingInterestId.
      return;

    if (onTimeout != null ||
        interestCopy.getInterestLifetimeMilliseconds() != null &&
        interestCopy.getInterestLifetimeMilliseconds() >= 0.0) {
      // Set up the timeout.
      local delayMilliseconds = interestCopy.getInterestLifetimeMilliseconds()
      if (delayMilliseconds == null || delayMilliseconds < 0.0)
        // Use a default timeout delay.
        delayMilliseconds = 4000.0;

      local thisFace = this;
      callLater
        (delayMilliseconds,
         function() { thisFace.processInterestTimeout_(pendingInterest); });
   }

    // Special case: For timeoutPrefix we don't actually send the interest.
    if (!Face.timeoutPrefix_.match(interestCopy.getName())) {
      local encoding = interestCopy.wireEncode(wireFormat);
      if (encoding.size() > Face.getMaxNdnPacketSize())
        throw
          "The encoded interest size exceeds the maximum limit getMaxNdnPacketSize()";

      transport_.send(encoding.buf());
    }
  }

  // TODO: setCommandSigningInfo
  // TODO: setCommandCertificateName
  // TODO: makeCommandInterest

  /**
   * Add an entry to the local interest filter table to call the onInterest
   * callback for a matching incoming Interest. This method only modifies the
   * library's local callback table and does not register the prefix with the
   * forwarder. It will always succeed. To register a prefix with the forwarder,
   * use registerPrefix. There are two forms of setInterestFilter.
   * The first form uses the exact given InterestFilter:
   * setInterestFilter(filter, onInterest).
   * The second form creates an InterestFilter from the given prefix Name:
   * setInterestFilter(prefix, onInterest).
   * @param {InterestFilter} filter The InterestFilter with a prefix and 
   * optional regex filter used to match the name of an incoming Interest. This
   * makes a copy of filter.
   * @param {Name} prefix The Name prefix used to match the name of an incoming
   * Interest.
   * @param {function} onInterest When an Interest is received which matches the
   * filter, this calls
   * onInterest(prefix, interest, face, interestFilterId, filter).
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   */
  function setInterestFilter(filterOrPrefix, onInterest)
  {
    local interestFilterId = getNextEntryId();
    interestFilterTable_.setInterestFilter
      (interestFilterId, InterestFilter(filterOrPrefix), onInterest, this);
    return interestFilterId;
  }

  /**
   * The OnInterest callback calls this to put a Data packet which satisfies an
   * Interest.
   * @param {Data} data The Data packet which satisfies the interest.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the Data packet. If omitted, use WireFormat.getDefaultWireFormat().
   * @throws Error If the encoded Data packet size exceeds getMaxNdnPacketSize().
   */
  function putData(data, wireFormat = null)
  {
    local encoding = data.wireEncode(wireFormat);
    if (encoding.size() > Face.getMaxNdnPacketSize())
      throw
        "The encoded Data packet size exceeds the maximum limit getMaxNdnPacketSize()";

    transport_.send(encoding.buf());
  }

  /**
   * Call callbacks such as onTimeout. This returns immediately if there is
   * nothing to process. This blocks while calling the callbacks. You should
   * repeatedly call this from an event loop, with calls to sleep as needed so
   * that the loop doesn't use 100% of the CPU. Since processEvents modifies the
   * pending interest table, your application should make sure that it calls
   * processEvents in the same thread as expressInterest (which also modifies
   * the pending interest table).
   * If you call this from an main event loop, you may want to catch and
   * log/disregard all exceptions.
   */
  function processEvents()
  {
    if (doingProcessEvents_)
      // Avoid loops where a callback eventually calls processEvents again.
      return;

    doingProcessEvents_ = true;
    try {
      delayedCallTable_.callTimedOut();
      doingProcessEvents_ = false;
    } catch (ex) {
      doingProcessEvents_ = false;
      throw ex;
    }
  }

  /**
   * This is a simple form of registerPrefix to register with a local forwarder
   * where the transport (such as MicroForwarderTransport) supports "sendObject"
   * to communicate using Squirrel objects, avoiding the time and code space
   * to encode/decode control packets. Register the prefix with the forwarder
   * and call onInterest when a matching interest is received.
   * @param {Name} prefix The Name prefix.
   * @param {function} onInterest (optional) If not null, this creates an
   * interest filter from prefix so that when an Interest is received which
   * matches the filter, this calls
   * onInterest(prefix, interest, face, interestFilterId, filter).
   * NOTE: You must not change the prefix object - if you need to change it then
   * make a copy. If onInterest is null, it is ignored and you must call
   * setInterestFilter.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   */
  function registerPrefixUsingObject(prefix, onInterest = null)
  {
    // TODO: Handle async connect.
    connectSync();

    // TODO: Handle async register.
    transport_.sendObject({
      type = "rib/register",
      nameUri = prefix.toUri()
    });

    if (onInterest != null)
      setInterestFilter(InterestFilter(prefix), onInterest);
  }

  /**
   * Get the practical limit of the size of a network-layer packet. If a packet
   * is larger than this, the library or application MAY drop it.
   * @return {integer} The maximum NDN packet size.
   */
  static function getMaxNdnPacketSize() { return NdnCommon.MAX_NDN_PACKET_SIZE; }

  /**
   * Call callback() after the given delay. This is not part of the public API 
   * of Face.
   * @param {float} delayMilliseconds The delay in milliseconds.
   * @param {float} callback This calls callback() after the delay.
   */
  function callLater(delayMilliseconds, callback)
  {
    delayedCallTable_.callLater(delayMilliseconds, callback);
  }

  /**
   * This is used in callLater for when the pending interest expires. If the
   * pendingInterest is still in the pendingInterestTable_, remove it and call
   * its onTimeout callback.
   */
  function processInterestTimeout_(pendingInterest)
  {
    if (pendingInterestTable_.removeEntry(pendingInterest))
      pendingInterest.callTimeout();
  }

  /**
   * An internal method to get the next unique entry ID for the pending interest
   * table, interest filter table, etc. Most entry IDs are for the pending
   * interest table (there usually are not many interest filter table entries)
   * so we use a common pool to only have to have one method which is called by
   * Face.
   *
   * @return {integer} The next entry ID.
   */
  function getNextEntryId() { return ++lastEntryId_; }

  /**
   * If connectionStatus_ is not already CONNECT_COMPLETE, do a synchronous
   * transport_connect and set the status to CONNECT_COMPLETE.
   */
  function connectSync()
  {
    if (connectStatus_ != FaceConnectStatus_.CONNECT_COMPLETE) {
      transport_.connect(connectionInfo_, this, null);
      connectStatus_ = FaceConnectStatus_.CONNECT_COMPLETE;
    }
  }

  /**
   * This is called by the transport's ElementReader to process an entire
   * received element such as a Data or Interest packet.
   * @param {Buffer} element The bytes of the incoming element.
   */
  function onReceivedElement(element)
  {
    // Clear timed-out Interests in case the application doesn't call processEvents.
    processEvents();

    // We don't expect packets with extensions to arrive at the client, but
    // strip the extensions header anyway. (Buffer.slice does nothing if
    // nHeaderBytes is zero.)
    element = element.slice(PacketExtensions.getNHeaderBytes(element));

    local lpPacket = null;
    // Use Buffer.get to avoid using the metamethod.
    if (element.get(0) == Tlv.LpPacket_LpPacket)
      // TODO: Support LpPacket.
      throw "not supported";

    // First, decode as Interest or Data.
    local interest = null;
    local data = null;
    if (element.get(0) == Tlv.Interest || element.get(0) == Tlv.Data) {
      local decoder = TlvDecoder (element);
      if (decoder.peekType(Tlv.Interest, element.len())) {
        interest = Interest();
        interest.wireDecode(element, TlvWireFormat.get());

        if (lpPacket != null)
          interest.setLpPacket(lpPacket);
      }
      else if (decoder.peekType(Tlv.Data, element.len())) {
        data = Data();
        data.wireDecode(element, TlvWireFormat.get());

        if (lpPacket != null)
          data.setLpPacket(lpPacket);
      }
    }

    if (lpPacket != null) {
      // We have decoded the fragment, so remove the wire encoding to save memory.
      lpPacket.setFragmentWireEncoding(Blob());

      // TODO: Check for NetworkNack.
    }

    // Now process as Interest or Data.
    if (interest != null) {
      // Call all interest filter callbacks which match.
      local matchedFilters = [];
      interestFilterTable_.getMatchedFilters(interest, matchedFilters);
      foreach (entry in matchedFilters) {
        try {
          entry.getOnInterest()
            (entry.getFilter().getPrefix(), interest, this,
             entry.getInterestFilterId(), entry.getFilter());
        } catch (ex) {
          consoleLog("Error in onInterest: " + ex);
        }
      }
    }
    else if (data != null) {
      local pendingInterests = [];
      pendingInterestTable_.extractEntriesForExpressedInterest
        (data, pendingInterests);
      // Process each matching PIT entry (if any).
      foreach (pendingInterest in pendingInterests) {
        try {
          pendingInterest.getOnData()(pendingInterest.getInterest(), data);
        } catch (ex) {
          consoleLog("Error in onData: " + ex);
        }
      }
    }
  }
}
