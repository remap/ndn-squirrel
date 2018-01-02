/**
 * Copyright (C) 2016-2018 Regents of the University of California.
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
 * A KeyLocatorType specifies the key locator type in a KeyLocator object.
 */
enum KeyLocatorType {
  KEYNAME = 1,
  KEY_LOCATOR_DIGEST =  2
}

/**
 * The KeyLocator class represents an NDN KeyLocator which is used in a
 * Sha256WithRsaSignature and Interest selectors.
 */
class KeyLocator {
  type_ = null;
  keyName_ = null;
  keyData_ = null;
  changeCount_ = 0;

  /**
   * Create a new KeyLocator.
   * @param {KeyLocator} keyLocator (optional) If keyLocator is another
   * KeyLocator object, copy its values. Otherwise, set all fields to defaut
   * values.
   */
  constructor(keyLocator = null)
  {
    if (keyLocator instanceof KeyLocator) {
      // The copy constructor.
      type_ = keyLocator.type_;
      keyName_ = ChangeCounter(Name(keyLocator.getKeyName()));
      keyData_ = keyLocator.keyData_;
    }
    else {
      type_ = null;
      keyName_ = ChangeCounter(Name());
      keyData_ = Blob();
    }
  }

  /**
   * Get the key locator type. If KeyLocatorType.KEYNAME, you may also call
   * getKeyName().  If KeyLocatorType.KEY_LOCATOR_DIGEST, you may also call
   * getKeyData() to get the digest.
   * @return {integer} The key locator type as a KeyLocatorType enum value,
   * or null if not specified.
   */
  function getType() { return type_; }

  /**
   * Get the key name. This is meaningful if getType() is KeyLocatorType.KEYNAME.
   * @return {Name} The key name. If not specified, the Name is empty.
   */
  function getKeyName() { return keyName_.get(); }

  /**
   * Get the key data. If getType() is KeyLocatorType.KEY_LOCATOR_DIGEST, this is
   * the digest bytes.
   * @return {Blob} The key data, or an isNull Blob if not specified.
   */
  function getKeyData() { return keyData_; }

  /**
   * Set the key locator type.  If KeyLocatorType.KEYNAME, you must also
   * setKeyName().  If KeyLocatorType.KEY_LOCATOR_DIGEST, you must also
   * setKeyData() to the digest.
   * @param {integer} type The key locator type as a KeyLocatorType enum value.
   * If null, the type is unspecified.
   */
  function setType(type)
  {
    type_ = type;
    ++changeCount_;
  }

  /**
   * Set key name to a copy of the given Name.  This is the name if getType()
   * is KeyLocatorType.KEYNAME.
   * @param {Name} name The key name which is copied.
   */
  function setKeyName(name)
  {
    keyName_.set(name instanceof Name ? Name(name) : Name());
    ++changeCount_;
  }

  /**
   * Set the key data to the given value. This is the digest bytes if getType()
   * is KeyLocatorType.KEY_LOCATOR_DIGEST.
   * @param {Blob} keyData A Blob with the key data bytes.
   */
  function setKeyData(keyData)
  {
    keyData_ = keyData instanceof Blob ? keyData : Blob(keyData);
    ++changeCount_;
  }

  /**
   * Clear the keyData and set the type to not specified.
   */
  function clear()
  {
    type_ = null;
    keyName_.set(Name());
    keyData_ = Blob();
    ++changeCount_;
  }

  /**
   * Check if this key locator has the same values as the given key locator.
   * @param {KeyLocator} other The other key locator to check.
   * @return {bool} true if the key locators are equal, otherwise false.
   */
  function equals(other)
{
    if (type_ != other.type_)
      return false;

    if (type_ == KeyLocatorType.KEYNAME) {
      if (!getKeyName().equals(other.getKeyName()))
        return false;
    }
    else if (type_ == KeyLocatorType.KEY_LOCATOR_DIGEST) {
      if (!getKeyData().equals(other.getKeyData()))
        return false;
    }

    return true;
  }

  /**
   * If the signature is a type that has a KeyLocator (so that,
   * getFromSignature will succeed), return true.
   * Note: This is a static method of KeyLocator instead of a method of
   * Signature so that the Signature base class does not need to be overloaded
   * with all the different kinds of information that various signature
   * algorithms may use.
   * @param {Signature} signature An object of a subclass of Signature.
   * @return {bool} True if the signature is a type that has a KeyLocator,
   * otherwise false.
   */
  static function canGetFromSignature(signature)
  {
    return signature instanceof Sha256WithRsaSignature ||
           signature instanceof HmacWithSha256Signature;
  }

  /**
   * If the signature is a type that has a KeyLocator, then return it. Otherwise
   * throw an error.
   * @param {Signature} signature An object of a subclass of Signature.
   * @return {KeyLocator} The signature's KeyLocator. It is an error if
   * signature doesn't have a KeyLocator.
   */
  static function getFromSignature(signature)
  {
    if (signature instanceof Sha256WithRsaSignature ||
        signature instanceof HmacWithSha256Signature)
      return signature.getKeyLocator();
    else
      throw
        "KeyLocator.getFromSignature: Signature type does not have a KeyLocator";
  }

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {integer} The change count.
   */
  function getChangeCount()
  {
    // Make sure each of the checkChanged is called.
    local changed = keyName_.checkChanged();
    if (changed)
      // A child object has changed, so update the change count.
      ++changeCount_;

    return changeCount_;
  }
}
