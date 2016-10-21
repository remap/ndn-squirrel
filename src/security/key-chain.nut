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
 * A KeyChain provides a set of interfaces to the security library such as
 * identity management, policy configuration and packet signing and verification.
 * Note: This class is an experimental feature. See the API docs for more detail at
 * http://named-data.net/doc/ndn-ccl-api/key-chain.html .
 */
class KeyChain {
  /**
   * Wire encode the target, compute an HmacWithSha256 and update the signature
   * value.
   * Note: This method is an experimental feature. The API may change.
   * @param {Data} target If this is a Data object, update its signature and
   * wire encoding.
   * @param {Blob} key The key for the HmacWithSha256.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the target. If omitted, use WireFormat getDefaultWireFormat().
   */
  static function signWithHmacWithSha256(target, key, wireFormat = null)
  {
    if (target instanceof Data) {
      local data = target;
      // Encode once to get the signed portion.
      local encoding = data.wireEncode(wireFormat);
      local signatureBytes = NdnCommon.computeHmacWithSha256
        (key.buf(), encoding.signedBuf());
      data.getSignature().setSignature(Blob(signatureBytes, false));
    }
    else
      throw "Unrecognized target type";
  }

  /**
   * Compute a new HmacWithSha256 for the target and verify it against the
   * signature value.
   * Note: This method is an experimental feature. The API may change.
   * @param {Data} target The Data object to verify.
   * @param {Blob} key The key for the HmacWithSha256.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the target. If omitted, use WireFormat getDefaultWireFormat().
   * @return {bool} True if the signature verifies, otherwise false.
   */
  static function verifyDataWithHmacWithSha256(data, key, wireFormat = null)
  {
    // wireEncode returns the cached encoding if available.
    local encoding = data.wireEncode(wireFormat);
    local newSignatureBytes = Blob(NdnCommon.computeHmacWithSha256
      (key.buf(), encoding.signedBuf()), false);

    // Use the flexible Blob.equals operator.
    return newSignatureBytes.equals(data.getSignature().getSignature());
  };
}
