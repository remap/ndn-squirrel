/**
 * Copyright (C) 2018 Regents of the University of California.
 * @author: Jeff Thompson <jefft0@remap.ucla.edu>
 * @author: From ndn-cxx security https://github.com/named-data/ndn-cxx/blob/master/src/security/command-interest-signer.cpp
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
 * A CommandInterestPreparer keeps track of a timestamp and prepares a command
 * interest by adding a timestamp and nonce to the name of an Interest. This
 * class is primarily designed to be used by the CommandInterestSigner, but can
 * also be using in an application that defines custom signing methods not
 * supported by the KeyChain (such as HMAC-SHA1). See the Command Interest
 * documentation:
 * https://redmine.named-data.net/projects/ndn-cxx/wiki/CommandInterest
 */
class CommandInterestPreparer {
  lastUsedTimestampSeconds_ = 0;

  /**
   * Create a CommandInterestPreparer and initialize the timestamp to now.
   */
  constructor()
  {
    lastUsedTimestampSeconds_ = NdnCommon.getNowSeconds();
  }

  /**
   * Append a timestamp component and a random nonce component to interest's
   * name. This ensures that the timestamp is greater than the timestamp used in
   * the previous call.
   * @param {Interest} interest The interest whose name is append with components.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the SignatureInfo. If omitted, use WireFormat getDefaultWireFormat().
   */
  function prepareCommandInterestName(interest, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local timestamp = NdnCommon.getNowSeconds();
    while (timestamp <= lastUsedTimestampSeconds_)
      timestamp += 1;

    // Update the timestamp now. In the small chance that signing fails, it just
    // means that we have bumped the timestamp.
    lastUsedTimestampSeconds_ = timestamp;

    // The timestamp is encoded as a TLV nonNegativeInteger.
    // A timestamp in milliseconds requires a 64-bit integer, which Squirrel
    // doesn't support. So keep it in seconds.
    local encoder = TlvEncoder(8);
    encoder.writeNonNegativeInteger(timestamp);
    interest.getName().append(encoder.finish());

    // The random value is a TLV nonNegativeInteger too, but we know it is 8
    // bytes, so we don't need to call the nonNegativeInteger encoder.
    local nonce = Buffer(8);
    Crypto.generateRandomBytes(nonce);
    interest.getName().append(Blob(nonce, false));
  }
}
