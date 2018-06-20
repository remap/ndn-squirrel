/**
 * Copyright (C) 2016-2018 Regents of the University of California.
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
 * An AsyncTransport extends Transport to communicate with a connection
 * object which supports a "write" method and a "setAsyncCallbacks" method which
 * registers a callback for onDataReceived which asynchronously supplies
 * incoming data. See the "connect" method for details.
 */
class AsyncTransport extends Transport {
  elementReader_ = null;
  connectionObject_ = null;

  /**
   * Connect to the connection object by calling
   * connectionInfo.getConnectionObject().setAsyncCallbacks(this) so that the
   * connection object asynchronously calls this.onDataReceived(data) on
   * receiving incoming data. (data is a Squirrel blob.) This reads an entire
   * packet element and calls elementListener.onReceivedElement(element). To 
   * send data, this calls connectionInfo.getConnectionObject().write(data)
   * where data is a Squirrel blob.
   * @param {AsyncTransportConnectionInfo} connectionInfo The ConnectionInfo with
   * the connection object. This assumes you have already configured the
   * connection object for communication as needed. (If not, you must configure
   * it when this calls setAsyncCallbacks.)
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
    connectionObject_ = connectionInfo.getConnectionObject();

    // Register to receive data.
    connectionObject_.setAsyncCallbacks(this);

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Write the bytes to the UART.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    connectionObject_.write(buffer.toBlob());
  }

  /** This is called asynchronously when the connection object receives data.
   * Pass the data to the elementReader_.
   * @param {blob} data The Squirrel blob with the received data.
   */
  function onDataReceived(data)
  {
    elementReader_.onReceivedData(Buffer.from(data));
  }
}

/**
 * An AsyncTransportConnectionInfo extends TransportConnectionInfo to hold the
 * object which has the "setAsyncCallbacks" method. See the "connect" method for
 * details.
 */
class AsyncTransportConnectionInfo extends TransportConnectionInfo {
  connectionObject_ = null;

  /**
   * Create a new AsyncTransportConnectionInfo with the given connection object.
   * See AsyncTransport.connect method for details.
   * @param {instance} connectionObject The connection object which has the
   * "setAsyncCallbacks" method.
   */
  constructor(connectionObject)
  {
    connectionObject_ = connectionObject;
  }

  /**
   * Get the connection object given to the constructor.
   * @return {instance} The connection object.
   */
  function getConnectionObject() { return connectionObject_; }
}
