/**
 * Copyright (C) 2017-2018 Regents of the University of California.
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
 * Note: This is not normally included in ndn-squirrel.nut. You must explicitly
 * include it in your application.
 * Details are here:
 * https://docs.google.com/document/d/1HJUO5PWjbjElbC1rpQ037m__Z3v6sQe90RdlqG_z5l8/edit
 * @note This class is an experimental feature. The API may change.
 */
class GeoTag {
  /**
   * Compute the figure of merit for the three geo tags.
   * @param {integer} geoSelf The geo tag of the self node which is
   * X * 10000 + Y where X and Y are in geo coordinate grid units.
   * @param {integer} geoSource The geo tag of the source node which is
   * X * 10000 + Y where X and Y are in geo coordinate grid units.
   * @param {integer} geoDest The geo tag of the destination node which is
   * X * 10000 + Y where X and Y are in geo coordinate grid units.
   * @return {float} The figure of merit which is -1.0 if
   * distance(geoSelf, geoDest) >= distance(geoSource, geoDest), otherwise a
   * value ranging from 0.0 to 1.0.
   */
  static function figureOfMerit(geoSelf, geoSource, geoDest)
  {
    local dSelfDest = distance(geoSelf, geoDest);
    local dSourceDest = distance(geoSource, geoDest);

    if (dSelfDest < dSourceDest)
      // Case A: This forwarder is moving the packet closer.
      return math.fabs(dSelfDest / dSourceDest - 1.0);
    else
      // Case B: This forwarder is moving the packet farther, or not moving it.
      return -1.0;
  }

  /**
   * Compute the distance between two geo tags.
   * @param {integer} geoTag1 The first geo tag which is X * 10000 + Y where
   * X and Y are in geo coordinate grid units.
   * @param {integer} geoTag2 The second geo tag which is X * 10000 + Y where
   * X and Y are in geo coordinate grid units.
   * @return {float} The distance in meters.
   */
  static function distance(geoTag1, geoTag2)
  {
    // Coord X and Y are integers.
    // Don't multiply by 10 to get meters. Keep grid units which are smaller.
    local coord1X = ((geoTag1 / 10000) % 10000);
    local coord2X = ((geoTag2 / 10000) % 10000);
    local coord1Y =  (geoTag1 % 10000);
    local coord2Y =  (geoTag2 % 10000);

    // The squares of up to 9999 still fit in a 32-bit integer.
    // Mutiply the final float by 10 to convert grid units to meters.
    return 10.0 * math.sqrt((coord1X - coord2X) * (coord1X - coord2X) +
                            (coord1Y - coord2Y) * (coord1Y - coord2Y));
  }
}
