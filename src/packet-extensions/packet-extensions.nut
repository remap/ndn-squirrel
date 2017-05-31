/**
 * Copyright (C) 2017 Regents of the University of California.
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

// A packet extensilno code is represented by its 5 bits in the most-significant
// bits of the first byte.
enum PacketExtensionCode {
  GeoTag = 0x28,
  // For the payoad of ErrorReporting, see ErrorReportingPayoad.
  ErrorReporting = 0xa8
}

enum ErrorReportingPayoad {
  TransmitFaied = 1
}

/**
 * A PacketExtensions holds the packet extensions that are prepended to a packet.
 * Each packet extension is a 4-byte value, and there can be multiple
 * extensions in the header prepended to the normal TLV packet.
 * Details are here:
 * https://docs.google.com/document/d/1jfi-3iExOlXjyF6BEIvAbnJa5jKM_rsisB70Jy8QtB0
 * @note This class is an experimental feature. The API may change.
 */
class PacketExtensions {
  /**
   * Get the size of the packet extensions header. This can be used to skip the
   * header for reading the actual packet value.
   * @param {Buffer} The Buffer with the packet, starting with possible headers.
   * @return {integer} The number of bytes in the packet extensions header, or 0
   * if there are no packet extension headers.
   */
  static function getNHeaderBytes(packet)
  {
    local i = 0;
    while (i < packet.len() && isExtension(packet.get(i)))
      // Skip this header and try the next.
      i += 4;

    return i;
  }

  /**
   * Check if this is the first byte of a packet extension. The first byte of a
   * packet extension either has the most significant bit set, or high 5 bites
   * is a GeoTag.
   * @param {integer} firstByte The first byte of a possible extension.
   * @return {boolean} True if it is the first byte of a packet extension.
   */
  static function isExtension(firstByte)
  {
    return (firstByte & 0x80) != 0 || 
            (firstByte & 0xf8) == PacketExtensionCode.GeoTag;
  }

  /**
   * Get the packet extension payload as follows. Get the 4 bytes in the packet
   * beginning at offset, mask off the most-significant 5 bits of the first
   * byte, and interpret the remainder as a 4-byte big-endian unsigned integer.
   * @param {Buffer} packet The Buffer with the extensions header.
   * @param {integer} offset The offset in the packet of the first byte of the
   * packet extension.
   * @return {integer} The payload as an integer as described above.
   */
  static function getPayload(packet, offset)
  {
    return ((packet.get(offset) & 0x07) << 24) +
            (packet.get(offset + 1) << 16) +
            (packet.get(offset + 2) << 8) +
             packet.get(offset + 3);
  }

  /**
   * Make a 4-byte packet extension from the given code and payload, suitable
   * for sending on the wire.
   * @param {integer} code The extension code byte value where the 5 bits of the
   * code are in the most-significant bits of the byte. For example,
   * PacketExtensionCode.GeoTag .
   * @param {integer} payload The 27-bit extension payload which is put
   * big-endian in the returned buffer.
   * @return {Blob} A Blob with the 4-byte extension.
   */
  static function makeExtension(code, payload)
  {
    // Use the high 5 bits of code and the low 27 bits of payload.
    local value = ((code & 0xf8) << 24) + (payload & 0x07ffffff);
    return Blob([(value >> 24) & 0xff,
                 (value >> 16) & 0xff,
                 (value >> 8) & 0xff,
                  value & 0xff]);
  }
}
