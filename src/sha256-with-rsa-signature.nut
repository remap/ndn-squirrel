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
 * A Sha256WithRsaSignature holds the signature bits and other info representing
 * a SHA256-with-RSA signature in an interest or data packet.
 */
class Sha256WithRsaSignature {
  keyLocator_ = null;
  signature_ = null;
  changeCount_ = 0;

  /**
   * Create a new Sha256WithRsaSignature object, possibly copying values from
   * another object.
   * @param {Sha256WithRsaSignature} value (optional) If value is a
   * Sha256WithRsaSignature, copy its values.  If value is omitted, the keyLocator
   * is the default with unspecified values and the signature is unspecified.
   */
  constructor(value = null)
  {
    if (value instanceof Sha256WithRsaSignature) {
      // The copy constructor.
      keyLocator_ = ChangeCounter(KeyLocator(value.getKeyLocator()));
      signature_ = value.signature_;
    }
    else {
      keyLocator_ = ChangeCounter(KeyLocator());
      signature_ = Blob();
    }
  }

  /**
   * Implement the clone operator update this cloned object with values from the
   * original Sha256WithRsaSignature which was cloned.
   * param {Sha256WithRsaSignature} value The original Sha256WithRsaSignature
   */
  function _cloned(value)
  {
    keyLocator_ = ChangeCounter(KeyLocator(value.getKeyLocator()));
    // We don't need to copy the signature_ Blob.
  }

  /**
   * Get the key locator.
   * @return {KeyLocator} The key locator.
   */
  function getKeyLocator() { return keyLocator_.get(); }

  /**
   * Get the data packet's signature bytes.
   * @return {Blob} The signature bytes. If not specified, the value isNull().
   */
  function getSignature() { return signature_; }

  /**
   * Set the key locator to a copy of the given keyLocator.
   * @param {KeyLocator} keyLocator The KeyLocator to copy.
   */
  function setKeyLocator(keyLocator)
  {
    keyLocator_.set(keyLocator instanceof KeyLocator ?
      KeyLocator(keyLocator) : KeyLocator());
    ++changeCount_;
  }

  /**
   * Set the data packet's signature bytes.
   * @param {Blob} signature
   */
  function setSignature(signature)
  {
    signature_ = signature instanceof Blob ? signature : Blob(signature);
    ++changeCount_;
  }

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {integer} The change count.
   */
  function getChangeCount()
  {
    // Make sure each of the checkChanged is called.
    local changed = keyLocator_.checkChanged();
    if (changed)
      // A child object has changed, so update the change count.
      ++changeCount_;

    return changeCount_;
  }
}
