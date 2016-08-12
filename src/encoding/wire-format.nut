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
 * WireFormat is an abstract base class for encoding and decoding Interest,
 * Data, etc. with a specific wire format. You should use a derived class such
 * as TlvWireFormat.
 */
class WireFormat {
  /**
   * Encode interest as NDN-TLV and return the encoding.
   * @param {Name} name The Name to encode.
   * @return {Blobl} A Blob containing the encoding.
   * @throws Error This always throws an "unimplemented" error. The derived
   * class should override.
   */
  function encodeName(name) { throw "unimplemented"; }

  /**
   * Decode input as an NDN-TLV name and set the fields of the Name object.
   * @param {Name} name The Name object whose fields are updated.
   * @param {blob} input The Squirrel blob with the bytes to decode.  This
   * decodes starting from input[0], ignoring the location of the blob pointer
   * given by input.tell(). This does not update the blob pointer.
   * @throws Error This always throws an "unimplemented" error. The derived
   * class should override.
   */
  function decodeName(name, input) { throw "unimplemented"; }

  // TODO encodeInterest
  // TODO decodeInterest

  /**
   * Encode data as NDN-TLV and return the encoding and signed offsets.
   * @param {Data} data The Data object to encode.
   * @return {table} A table with fields (encoding, signedPortionBeginOffset,
   * signedPortionEndOffset) where encoding is a Blob containing the encoding,
   * signedPortionBeginOffset is the offset in the encoding of the beginning of
   * the signed portion, and signedPortionEndOffset is the offset in the
   * encoding of the end of the signed portion.
   * @throws Error This always throws an "unimplemented" error. The derived
   * class should override.
   */
  function encodeData(data) { throw "unimplemented"; }

  /**
   * Decode input as an NDN-TLV data packet, set the fields in the data object,
   * and return the signed offsets.
   * @param {Data} data The Data object whose fields are updated.
   * @param {blob} input The Squirrel blob with the bytes to decode.  This
   * decodes starting from input[0], ignoring the location of the blob pointer
   * given by input.tell(). This does not update the blob pointer.
   * @return {table} A table with fields (signedPortionBeginOffset,
   * signedPortionEndOffset) where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion.
   * @throws Error This always throws an "unimplemented" error. The derived
   * class should override.
   */
  function decodeData(data, input) { throw "unimplemented"; }

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
