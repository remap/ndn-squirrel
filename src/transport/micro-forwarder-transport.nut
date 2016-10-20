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
 * A MicroForwarderTransport extends Transport to communicate with a
 * MicroForwarder object. This also supports "on" and "send" methods so that
 * this can be used by SquirrelObjectTransport as the connection object (see
 * connect).
 */
class MicroForwarderTransport extends Transport {
  elementReader_ = null;
  onReceivedObject_ = null;
  onCallbacks_ = null; // array of function which takes a Squirrel object.

  /**
   * Create a MicroForwarderTransport.
   * @param {function} onReceivedObject (optional) If supplied and the received
   * object is not a blob then just call onReceivedObject(obj).
   */
  constructor(onReceivedObject = null) {
    onReceivedObject_ = onReceivedObject;
    onCallbacks_ = [];
  }

  /**
   * Connect to connectionInfo.getForwarder() by calling its addFace and using
   * this as the connection object. If a received object is a Squirrel blob,
   * make a Buffer from it and use it to read an entire packet element and call
   * elementListener.onReceivedElement(element). Otherwise just call
   * onReceivedObject(obj) using the callback given to the constructor.
   * @param {MicroForwarderTransportConnectionInfo} connectionInfo The
   * ConnectionInfo with the MicroForwarder object.
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
    connectionInfo.getForwarder().addFace
      ("internal://app", SquirrelObjectTransport(),
       SquirrelObjectTransportConnectionInfo(this));

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Send the object to the MicroForwarder over the connection created by
   * connect (and to anyone else who called on("NDN", callback)).
   * @param {blob|table} obj The object to send. If it is a blob then it is
   * processed by the MicroForwarder like an NDN packet.
   */
  function sendObject(obj) 
  {
    if (onCallbacks_.len() == null)
      // There should have been at least one callback added during connect.
      throw "not connected";

    foreach (callback in onCallbacks_)
      callback(obj);
  }

  /**
   * This is overloaded with the following two forms:
   * send(buffer) - Convert the buffer to a Squirrel blob and send it to the
   * MicroForwarder over the connection created by connect (and to anyone else
   * who called on("NDN", callback)).
   * send(messageName, obj) - When the MicroForwarder calls send, if it is a
   * Squirrel blob then make a Buffer from it and use it to read an entire
   * packet element and call elementListener_.onReceivedElement(element),
   * otherwise just call onReceivedObject(obj) using the callback given to the
   * constructor.
   * @param {Buffer} buffer The bytes to send.
   * @param {string} messageName The name of the message if calling
   * send(messageName, obj). If messageName is not "NDN", do nothing.
   * @param {blob|table} obj The object if calling send(messageName, obj).
   */
  function send(arg1, obj = null)
  {
    if (arg1 instanceof Buffer)
      sendObject(arg1.toBlob());
    else {
      if (arg1 != "NDN")
        // The messageName is not "NDN". Ignore.
        return;

      if (typeof obj == "blob") {
        try {
          elementReader_.onReceivedData(Buffer.from(obj));
        } catch (ex) {
          consoleLog("Error in onReceivedData: " + ex);
        }
      }
      else {
        if (onReceivedObject_ != null) {
          try {
            onReceivedObject_(obj);
          } catch (ex) {
            consoleLog("Error in onReceivedObject: " + ex);
          }
        }
      }
    }
  }

  function on(messageName, callback)
  {
    if (messageName != "NDN")
      return;
    onCallbacks_.append(callback);
  }
}

/**
 * A MicroForwarderTransportConnectionInfo extends TransportConnectionInfo to
 * hold the MicroForwarder object to connect to.
 */
class MicroForwarderTransportConnectionInfo extends TransportConnectionInfo {
  forwarder_ = null;

  /**
   * Create a new MicroForwarderTransportConnectionInfo with the forwarder
   * object.
   * @param {MicroForwarder} forwarder (optional) The MicroForwarder to
   * communicate with. If omitted or null, use the static MicroForwarder.get().
   */
  constructor(forwarder = null)
  {
    forwarder_ = forwarder != null ? forwarder : MicroForwarder.get();
  }

  /**
   * Get the MicroForwarder object given to the constructor.
   * @return {MicroForwarder} The MicroForwarder object.
   */
  function getForwarder() { return forwarder_; }
}
