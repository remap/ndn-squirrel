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
 * A SquirrelObjectTransport extends Transport to communicate with a connection
 * object which supports "on" and "send" methods, such as an Imp agent or device
 * object. This can send a blob as well as another type of Squirrel object.
 */
class SquirrelObjectTransport extends Transport {
  elementReader_ = null;
  onReceivedObject_ = null;
  connection_ = null;

  /**
   * Create a SquirrelObjectTransport.
   * @param {function} onReceivedObject (optional) If supplied and the received
   * object is not a blob then just call onReceivedObject(obj).
   */
  constructor(onReceivedObject = null) {
    onReceivedObject_ = onReceivedObject;
  }

  /**
   * Connect to the connection object given by connectionInfo.getConnnection(),
   * communicating with connection.on and connection.send using the message name
   * "NDN". If a received object is a Squirrel blob, make a Buffer from it and
   * use it to read an entire packet element and call
   * elementListener.onReceivedElement(element). Otherwise just call
   * onReceivedObject(obj) using the callback given to the constructor.
   * @param {SquirrelObjectTransportConnectionInfo} connectionInfo The
   * ConnectionInfo with the connection object.
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
    connection_ = connectionInfo.getConnnection();

    // Add a listener to wait for a message object.
    local thisTransport = this;
    connection_.on("NDN", function(obj) {
      if (typeof obj == "blob") {
        try {
          thisTransport.elementReader_.onReceivedData(Buffer.from(obj));
        } catch (ex) {
          consoleLog("Error in onReceivedData: " + ex);
        }
      }
      else {
        if (thisTransport.onReceivedObject_ != null) {
          try {
            thisTransport.onReceivedObject_(obj);
          } catch (ex) {
            consoleLog("Error in onReceivedObject: " + ex);
          }
        }
      }
    });

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Send the object over the connection created by connect, using the message
   * name "NDN".
   * @param {blob|table} obj The object to send. If it is a blob then it is
   * processed like an NDN packet.
   */
  function sendObject(obj) 
  {
    if (connection_ == null)
      throw "not connected";
    connection_.send("NDN", obj);
  }

  /**
   * Convert the buffer to a Squirrel blob and send it over the connection
   * created by connect.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    sendObject(buffer.toBlob());
  }
}

/**
 * An SquirrelObjectTransportConnectionInfo extends TransportConnectionInfo to
 * hold the connection object.
 */
class SquirrelObjectTransportConnectionInfo extends TransportConnectionInfo {
  connection_ = null;

  /**
   * Create a new SquirrelObjectTransportConnectionInfo with the connection
   * object.
   * @param {instance} connection The connection object which supports "on" and
   * "send" methods, such as an Imp agent or device object.
   */
  constructor(connection)
  {
    connection_ = connection;
  }

  /**
   * Get the connection object given to the constructor.
   * @return {instance} The connection object.
   */
  function getConnnection() { return connection_; }
}
