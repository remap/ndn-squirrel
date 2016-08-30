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
 * An AgentDeviceTransport extends Transport to use an Imp agent or device
 * object for communication, using the message name "NDN".
 */
class AgentDeviceTransport extends Transport {
  elementReader_ = null;
  onReceivedObject_ = null;
  connection_ = null;

  /**
   * Create an AgentDeviceTransport.
   * @param {function} onReceivedObject (optional) If supplied and the received
   * object is not a blob then just call onReceivedObject(obj).
   */
  constructor(onReceivedObject = null) {
    onReceivedObject_ = onReceivedObject;
  }

  /**
   * Connect to the Imp agent or device object, communicating with
   * connectionInfo.getConnnection().on and connectionInfo.getConnnection().send.
   * If a received object is a Squirrel blob, make a Buffer from it and use it
   * to read an entire packet element and call
   * elementListener.onReceivedElement(element). Otherwise just call
   * onReceivedObject(obj) using the callback given to the constructor.
   * @param {AgentDeviceTransportConnectionInfo} connectionInfo The
   * ConnectionInfo with the agent or device connection object.
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
      if (typeof obj == "blob")
        thisTransport.elementReader_.onReceivedData(Buffer.from(obj));
      else {
        if (thisTransport.onReceivedObject_ != null)
          thisTransport.onReceivedObject_(obj);
      }
    });

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
    local output = blob(buffer.len());
    buffer.copy(output);
    sendObject(output);
  }
}

/**
 * An AgentDeviceTransportConnectionInfo extends TransportConnectionInfo to hold
 * the connection object.
 */
class AgentDeviceTransportConnectionInfo extends TransportConnectionInfo {
  connection_ = null;

  /**
   * Create a new AgentDeviceTransportConnectionInfo with the connection object.
   * @param {instance} connection This is the Imp agent or device object.
   */
  constructor(connection)
  {
    connection_ = connection;
  }

  /**
   * Get the connection object given to the constructor.
   * @return {instance} The Imp agent or device object.
   */
  function getConnnection() { return connection_; }
}
