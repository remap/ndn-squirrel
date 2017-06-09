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
 * NdnCommon has static NDN utility methods and constants.
 */
class NdnCommon {
  /**
   * The practical limit of the size of a network-layer packet. If a packet is
   * larger than this, the library or application MAY drop it. This constant is
   * defined in this low-level class so that internal code can use it, but
   * applications should use the static API method
   * Face.getMaxNdnPacketSize() which is equivalent.
   */
  static MAX_NDN_PACKET_SIZE = 8800;

  /**
   * Get the current time in seconds.
   * @return {integer} The current time in seconds since 1/1/1970 UTC.
   */
  static function getNowSeconds() { return time(); }

  /**
   * Compute the HMAC with SHA-256 of data, as defined in
   * http://tools.ietf.org/html/rfc2104#section-2 .
   * @param {Buffer} key The key.
   * @param {Buffer} data The input byte buffer.
   * @return {Buffer} The HMAC result.
   */
  static function computeHmacWithSha256(key, data)
  {
    if (haveCrypto_)
      return Buffer.from(crypto.hmacsha256(data.toBlob(), key.toBlob()));
    else if (haveHttpHash_)
      return Buffer.from(http.hash.hmacsha256(data.toBlob(), key.toBlob()));
    else {
      // For testing, compute a simple int hash and repeat it.
      local hash = 0;
      for (local i = 0; i < key.len(); ++i)
        hash += 37 * key.get(i);
      for (local i = 0; i < data.len(); ++i)
        hash += 37 * data.get(i);

      local result = blob(32);
      // Write the 4-byte integer 8 times.
      for (local i = 0; i < 8; ++i)
        result.writen(hash, 'i');
      return Buffer.from(result);
    }
  }

  haveCrypto_ = "crypto" in getroottable();
  haveHttpHash_ = "http" in getroottable() && "hash" in ::http;
}

/**
 * Make a global function to log a message to the console which works with
 * standard Squirrel or on the Imp.
 * @param {string} message The message to log.
 */
if (!("consoleLog" in getroottable())) {
  consoleLog <- function(message) {
    if ("server" in getroottable())
      server.log(message);
    else
      print(message); print("\n");
  }
}
