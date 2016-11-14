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
 * A UartTransport extends Transport to communicate with a connection
 * object which supports "write" and "readblob" methods, such as an Imp uart
 * object.
 */
class UartTransport extends Transport {
  elementReader_ = null;
  uart_ = null;
  readInterval_ = 0

  /**
   * Create a UartTransport in the unconnected state.
   * @param {float} (optional) The interval in seconds for polling the UART to
   * read. If omitted, use a default value.
   */
  constructor(readInterval = 0.5)
  {
    readInterval_ = readInterval;
  }

  /**
   * Connect to the connection object given by connectionInfo.getUart(),
   * communicating with getUart().write() and getUart().readblob(). Read an
   * entire packet element and call elementListener.onReceivedElement(element).
   * This starts a timer using imp.wakeup to repeatedly read the input according
   * to the readInterval given to the constructor.
   * @param {UartTransportConnectionInfo} connectionInfo The ConnectionInfo with 
   * the uart object. This assumes you have already called configure() as needed.
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
    uart_ = connectionInfo.getUart();

    // This will start the read timer.
    read();

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Write the bytes to the UART.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    uart_.write(buffer.toBlob());
  }

  /**
   * Read bytes from the uart_ and pass to the elementReader_, then use
   * imp.wakeup to call this again after readInterval_ seconds.
   */
  function read()
  {
    // Loop until there is no more data in the receive buffer.
    while (true) {
      local input = uart_.readblob();
      if (input.len() <= 0)
        break;

      elementReader_.onReceivedData(Buffer.from(input));
    }

    // Restart the read timer.
    // TODO: How to close the connection?
    local thisTransport = this;
    imp.wakeup(readInterval_, function() { thisTransport.read(); });
  }
}

/**
 * An UartTransportConnectionInfo extends TransportConnectionInfo to hold the
 * uart object.
 */
class UartTransportConnectionInfo extends TransportConnectionInfo {
  uart_ = null;

  /**
   * Create a new UartTransportConnectionInfo with the uart object.
   * @param {instance} uart The uart object which supports "write" and
   * "readblob" methods, such as hardware.uart0.
   */
  constructor(uart)
  {
    uart_ = uart;
  }

  /**
   * Get the uart object given to the constructor.
   * @return {instance} The uart object.
   */
  function getUart() { return uart_; }
}
