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
 * An EncryptedContent holds an encryption type, a payload and other fields
 * representing encrypted content.
 */
class EncryptedContent {
  algorithmType_ = null;
  keyLocator_ = null;
  initialVector_ = null;
  payload_ = null;

  /**
   * Create a new EncryptedContent.
   * @param {EncryptedContent} value (optional) If value is another
   * EncryptedContent object, copy its values. Otherwise, create an
   * EncryptedContent with unspecified values.
   */
  constructor(value = null)
  {
    if (value instanceof EncryptedContent) {
      // Make a deep copy.
      algorithmType_ = value.algorithmType_;
      keyLocator_ = KeyLocator(value.keyLocator_);
      initialVector_ = value.initialVector_;
      payload_ = value.payload_;
    }
    else {
      algorithmType_ = null;
      keyLocator_ = KeyLocator();
      initialVector_ = Blob();
      payload_ = Blob();
    }
  }

  /**
   * Get the algorithm type from EncryptAlgorithmType.
   * @return {integer} The algorithm type from the EncryptAlgorithmType enum, or
   * null if not specified.
   */
  function getAlgorithmType() { return algorithmType_; }

  /**
   * Get the key locator.
   * @return {KeyLocator} The key locator. If not specified, getType() is null.
   */
  function getKeyLocator() { return keyLocator_; }

  /**
   * Get the initial vector.
   * @return {Blob} The initial vector. If not specified, isNull() is true.
   */
  function getInitialVector() { return initialVector_; }

  /**
   * Get the payload.
   * @return {Blob} The payload. If not specified, isNull() is true.
   */
  function getPayload() { return payload_; }

  /**
   * Set the algorithm type.
   * @param {integer} algorithmType The algorithm type from the
   * EncryptAlgorithmType enum. If not specified, set to null.
   * @return {EncryptedContent} This EncryptedContent so that you can chain
   * calls to update values.
   */
  function setAlgorithmType(algorithmType)
  {
    algorithmType_ = algorithmType;
    return this;
  }

  /**
   * Set the key locator.
   * @param {KeyLocator} keyLocator The key locator. This makes a copy of the
   * object. If not specified, set to the default KeyLocator().
   * @return {EncryptedContent} This EncryptedContent so that you can chain
   * calls to update values.
   */
  function setKeyLocator(keyLocator)
  {
    keyLocator_ = keyLocator instanceof KeyLocator ?
      KeyLocator(keyLocator) : KeyLocator();
    return this;
  }

  /**
   * Set the initial vector.
   * @param {Blob} initialVector The initial vector. If not specified, set to
   * the default Blob() where isNull() is true.
   * @return {EncryptedContent} This EncryptedContent so that you can chain
   * calls to update values.
   */
  function setInitialVector(initialVector)
  {
    initialVector_ = initialVector instanceof Blob ?
      initialVector : Blob(initialVector, true);
    return this;
  }

  /**
   * Set the encrypted payload.
   * @param {Blob} payload The payload. If not specified, set to the default
   * Blob() where isNull() is true.
   * @return {EncryptedContent} This EncryptedContent so that you can chain
   * calls to update values.
   */
  function setPayload(payload)
  {
    payload_ = payload instanceof Blob ? payload : Blob(payload, true);
    return this;
  }

  /**
   * Encode this EncryptedContent for a particular wire format.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   * @return {Blob} The encoded buffer in a Blob object.
   */
  function wireEncode(wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    return wireFormat.encodeEncryptedContent(this);
  }

  /**
   * Decode the input using a particular wire format and update this
   * EncryptedContent.
   * @param {Blob|Buffer} input The buffer with the bytes to decode.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * decode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   */
  function wireDecode(input, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    if (input instanceof Blob)
      wireFormat.decodeEncryptedContent(this, input.buf(), false);
    else
      wireFormat.decodeEncryptedContent(this, input, true);
  }
}
