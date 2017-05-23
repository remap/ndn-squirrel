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

/**
 * A PacketExtensions holds the packet extensions that are prepended to a packet
 * as defined here:
 * https://docs.google.com/document/d/1jfi-3iExOlXjyF6BEIvAbnJa5jKM_rsisB70Jy8QtB0
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
    local nBytes = 0;
    while (PacketExtensions.isExtension(packet.get(nBytes)))
      // Skip this header and try the next.
      nBytes += 4;

    return nBytes;
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
    return (firstByte & 0x80) != 0 || (firstByte & 0xf8) == GEO_TAG;
  }

  // A code is represented by its 5 bits in the most-significant bits of the
  // first byte.
  static GEO_TAG = 0x28;
  static ERROR_REPORTING = 0xA8;
}
