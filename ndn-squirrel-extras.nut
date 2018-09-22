/**
 * Copyright (C) 2018 Regents of the University of California.
 * @author: Jeff Thompson <jefft0@remap.ucla.edu>
 * @author: From ndn-cxx security https://github.com/named-data/ndn-cxx/blob/master/src/security/command-interest-signer.cpp
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
 * A CommandInterestPreparer keeps track of a timestamp and prepares a command
 * interest by adding a timestamp and nonce to the name of an Interest. This
 * class is primarily designed to be used by the CommandInterestSigner, but can
 * also be using in an application that defines custom signing methods not
 * supported by the KeyChain (such as HMAC-SHA1). See the Command Interest
 * documentation:
 * https://redmine.named-data.net/projects/ndn-cxx/wiki/CommandInterest
 */
class CommandInterestPreparer {
  lastUsedTimestampSeconds_ = 0;

  /**
   * Create a CommandInterestPreparer and initialize the timestamp to now.
   */
  constructor()
  {
    lastUsedTimestampSeconds_ = NdnCommon.getNowSeconds();
  }

  /**
   * Append a timestamp component and a random nonce component to interest's
   * name. This ensures that the timestamp is greater than the timestamp used in
   * the previous call.
   * @param {Interest} interest The interest whose name is append with components.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the SignatureInfo. If omitted, use WireFormat getDefaultWireFormat().
   */
  function prepareCommandInterestName(interest, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local timestamp = NdnCommon.getNowSeconds();
    while (timestamp <= lastUsedTimestampSeconds_)
      timestamp += 1;

    // Update the timestamp now. In the small chance that signing fails, it just
    // means that we have bumped the timestamp.
    lastUsedTimestampSeconds_ = timestamp;

    // The timestamp is encoded as a TLV nonNegativeInteger.
    // A timestamp in milliseconds requires a 64-bit integer, which Squirrel
    // doesn't support. So keep it in seconds.
    local encoder = TlvEncoder(8);
    encoder.writeNonNegativeInteger(timestamp);
    interest.getName().append(encoder.finish());

    // The random value is a TLV nonNegativeInteger too, but we know it is 8
    // bytes, so we don't need to call the nonNegativeInteger encoder.
    local nonce = Buffer(8);
    Crypto.generateRandomBytes(nonce);
    interest.getName().append(Blob(nonce, false));
  }
}
/**
 * Copyright (C) 2018 Regents of the University of California.
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
 * An HttpTransport extends Transport to send bytes using an HTTP object which
 * has the "post" method. This does not listen for other nodes to initiate an
 * incoming HTTP connection. See the "connect" method for details.
 */
class HttpTransport extends Transport {
  elementReader_ = null;
  connectionInfo_ = null;

  /**
   * When the send method is called, it calls
   * connectionInfo.getHttp().post(connectionInfo.getUrl(), connectionInfo.getHeaders(), buffer)
   * where buffer is the buffer given to the send method, converted to a Squirrel
   * blob for the body of the POST message. The "post" method returns
   * an object which has a method sendasync where this calls
   * sendasync(doneCallback, null, connectionInfo.getTimeoutSeconds()).
   * When the HTTP response is received, the system calls
   * doneCallback(response) where response.body
   * is the raw string of the response. This converts the response to a Buffer
   * and calls elementListener.onReceivedElement(). In this way this Transport
   * can be used to POST a packet to an HTTP server and receive the response,
   * but it does not listen for other nodes to initiate an incoming HTTP
   * connection. This follows the API of the Imp http.post method, but another
   * object for connectionInfo.getHttp() can be set up to behave the same way.
   * https://developer.electricimp.com/api/http/post
   * @param {HttpTransportConnectionInfo} connectionInfo The ConnectionInfo with
   * the HTTP object and parameters for calling its "post" method.
   * @param {instance} elementListener The elementListener with function
   * onReceivedElement which must remain valid during the life of this object.
   * @param {function} onOpenCallback Once connected, call onOpenCallback().
   * @param {function} onClosedCallback (optional) If the connection is closed 
   * by the remote host, call onClosedCallback(). If omitted or null, don't call
   * it.
   */
  function connect
    (connectionInfo, elementListener, onOpenCallback, onClosedCallback = null)
  {
    elementReader_ = ElementReader(elementListener);
    connectionInfo_ = connectionInfo;

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Make the HTTP post connection, write the bytes to it and wait for the
   * reply.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    // Each connection is separate, so use a local callback.
    local thisTransport = this;
    local doneCallback = function(response) {
      local encoding = Blob(response.body);
      thisTransport.elementReader_.onReceivedData(Buffer(response.body));
    }

    connectionInfo_.getHttp().post
      (connectionInfo_.getUrl(), connectionInfo_.getHeaders(), buffer.toBlob())
      .sendasync(doneCallback, null, connectionInfo_.getTimeoutSeconds());
  }
}

/**
 * An HttpTransportConnectionInfo extends TransportConnectionInfo to hold the
 * object which has the HTTP "post" method and parameters for calling it. See
 * the "connect" method for details.
 */
class HttpTransportConnectionInfo extends TransportConnectionInfo {
  http_ = null;
  url_ = null;
  headers_ = null;
  timeoutSeconds_ = 0;

  /**
   * Create a new HttpTransportConnectionInfo with the given connection object.
   * See HttpTransport.connect method for details.
   * @param {instance} http The HTTP object which has the "post" method. See the
   * "connect" method for details.
   * @param {string} url The URL for calling "post".
   * @param {table} headers (optional) The table of additional HTTP headers for
   * calling "post". If omitted, use { "Content-Type" : "application/binary" }.
   * @param {integer|float} timeoutSeconds (optional) The timeout in seconds for
   * calling sendasync. If omitted, use 600 seconds (10 minutes).
   */
  constructor(http, url, headers = null, timeoutSeconds = null)
  {
    local arg3 = headers;
    local arg4 = timeoutSeconds;
    // arg3,           arg4 may be:
    // headers,        timeoutSeconds
    // headers,        null
    // timeoutSeconds, null
    // null,           null
    if (typeof arg3 == "table")
      headers = arg3;
    else
      headers = { "Content-Type" : "application/binary" };

    if (typeof arg3 == "integer" || typeof arg3 == "float")
      timeoutSeconds = arg3;
    else if (typeof arg4 == "integer" || typeof arg4 == "float")
      timeoutSeconds = arg4;
    else
      timeoutSeconds = 600;

    http_ = http;
    url_ = url;
    headers_ = headers;
    timeoutSeconds_ = timeoutSeconds;
  }

  /**
   * Get the HTTP object given to the constructor.
   * @return {instance} The HTTP object.
   */
  function getHttp() { return http_; }

  /**
   * Get the URL given to the constructor.
   * @return {string} The URL.
   */
  function getUrl() { return url_; }

  /**
   * Get the headers table given to the constructor.
   * @return {table} The headers.
   */
  function getHeaders() { return headers_; }

  /**
   * Get the timeout given to the constructor.
   * @return {integer|float} The timeout in seconds.
   */
  function getTimeoutSeconds() { return timeoutSeconds_; }
}
