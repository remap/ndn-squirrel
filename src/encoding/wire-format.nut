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
 * WireFormat is an abstract base class for encoding and decoding Interest,
 * Data, etc. with a specific wire format. You should use a derived class such
 * as TlvWireFormat.
 */
class WireFormat {
  /**
   * Set the static default WireFormat used by default encoding and decoding
   * methods.
   * @param {WireFormat} wireFormat An object of a subclass of WireFormat.
   */
  static function setDefaultWireFormat(wireFormat)
  {
    ::WireFormat_defaultWireFormat = wireFormat;
  }

  /**
   * Return the default WireFormat used by default encoding and decoding methods
   * which was set with setDefaultWireFormat.
   * @return {WireFormat} An object of a subclass of WireFormat.
   */
  static function getDefaultWireFormat()
  {
    return WireFormat_defaultWireFormat;
  }
}

// We use a global variable because static member variables are immutable.
WireFormat_defaultWireFormat <- null;
