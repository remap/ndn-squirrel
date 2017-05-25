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
 * GeoTag has static methods that work with PacketExtensions to manipulate
 * GeoTag packet extensions.
 * Details are here:
 * https://docs.google.com/document/d/1HJUO5PWjbjElbC1rpQ037m__Z3v6sQe90RdlqG_z5l8/edit
 * @note This class is an experimental feature. The API may change.
 */
class GeoTag {
  /**
   * Make the payload value for a GeoTag packet extension which can be combined
   * with PacketExtensionCode.GeoTag to make the extension.
   * @param {integer} The X coordinate in meters. This is divided by 10 to get
   * the grid value.
   * @param {integer} The Y coordinate in meters. This is divided by 10 to get
   * the grid value.
   * @param {integer} The payload value, effectively an 8-digit decimal value.
   */
  static function makePayload(xMeters, yMeters)
  {
    return (xMeters / 10) * 10000 + (yMeters / 10);
  }
}
