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
 * The Interest class represents an NDN Interest packet.
 */
class Interest {
  name_ = null;
  maxSuffixComponents_ = null;
  minSuffixComponents_ = null;
  keyLocator_ = null;
  exclude_ = null;
  childSelector_ = null;
  mustBeFresh_ = true;
  interestLifetimeMilliseconds_ = null;
  nonce_ = null;
  getNonceChangeCount_ = 0;
  changeCount_ = 0;

  /**
   * Create a new Interest object from the optional value.
   * @param {Name|Interest} value (optional) If the value is a Name, make a copy 
   * and use it as the Interest packet's name. If the value is another Interest
   * object, copy its values. If the value is null or omitted, set all fields to
   * defaut values.
   */
  constructor(value = null)
  {
    if (value instanceof Interest) {
      // The copy constructor.
      local interest = value;
      name_ = ChangeCounter(Name(interest.getName()));
      maxSuffixComponents_ = interest.maxSuffixComponents_;
      minSuffixComponents_ = interest.minSuffixComponents_;
      keyLocator_ = ChangeCounter(KeyLocator(interest.getKeyLocator()));
      exclude_ = ChangeCounter(Exclude(interest.getExclude()));
      childSelector_ = interest.childSelector_;
      mustBeFresh_ = interest.mustBeFresh_;
      interestLifetimeMilliseconds_ = interest.interestLifetimeMilliseconds_;
      nonce_ = interest.nonce_;
    }
    else {
      name_ = ChangeCounter(value instanceof Name ? Name(value) : Name());
      minSuffixComponents_ = null;
      maxSuffixComponents_ = null;
      keyLocator_ = ChangeCounter(KeyLocator());
      exclude_ = ChangeCounter(Exclude());
      childSelector_ = null;
      mustBeFresh_ = true;
      interestLifetimeMilliseconds_ = null;
      nonce_ = Blob();
    }
  }

  // TODO matchesName.
  // TODO matchesData.

  /**
   * Get the interest Name.
   * @return {Name} The name. The name size() may be 0 if not specified.
   */
  function getName() { return name_.get(); }

  /**
   * Get the min suffix components.
   * @return {integer} The min suffix components, or null if not specified.
   */
  function getMinSuffixComponents() { return minSuffixComponents_; }

  /**
   * Get the max suffix components.
   * @return {integer} The max suffix components, or null if not specified.
   */
  function getMaxSuffixComponents() { return maxSuffixComponents_; }

  /**
   * Get the interest key locator.
   * @return {KeyLocator} The key locator. If its getType() is null,
   * then the key locator is not specified.
   */
  function getKeyLocator() { return keyLocator_.get(); }

  /**
   * Get the exclude object.
   * @return {Exclude} The exclude object. If the exclude size() is zero, then
   * the exclude is not specified.
   */
  function getExclude() { return exclude_.get(); }

  /**
   * Get the child selector.
   * @return {integer} The child selector, or null if not specified.
   */
  function getChildSelector() { return childSelector_; }

  /**
   * Get the must be fresh flag. If not specified, the default is true.
   * @return {bool} The must be fresh flag.
   */
  function getMustBeFresh() { return mustBeFresh_; }

  /**
   * Return the nonce value from the incoming interest.  If you change any of
   * the fields in this Interest object, then the nonce value is cleared.
   * @return {Blob} The nonce. If not specified, the value isNull().
   */
  function getNonce()
  {
    if (getNonceChangeCount_ != getChangeCount()) {
      // The values have changed, so the existing nonce is invalidated.
      nonce_ = Blob();
      getNonceChangeCount_ = getChangeCount();
    }

    return nonce_;
  }

  /**
   * Get the interest lifetime.
   * @return {float} The interest lifetime in milliseconds, or null if not
   * specified.
   */
  function getInterestLifetimeMilliseconds() { return interestLifetimeMilliseconds_; }

  // TODO: hasLink.
  // TODO: getLink.
  // TODO: getLinkWireEncoding.
  // TODO: getSelectedDelegationIndex.
  // TODO: getIncomingFaceId.

  /**
   * Set the interest name.
   * Note: You can also call getName and change the name values directly.
   * @param {Name} name The interest name. This makes a copy of the name.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setName(name)
  {
    name_.set(name instanceof Name ? Name(name) : Name());
    ++changeCount_;
    return this;
  }

  /**
   * Set the min suffix components count.
   * @param {integer} minSuffixComponents The min suffix components count. If
   * not specified, set to null.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setMinSuffixComponents(minSuffixComponents)
  {
    minSuffixComponents_ = minSuffixComponents;
    ++changeCount_;
    return this;
  }

  /**
   * Set the max suffix components count.
   * @param {integer} maxSuffixComponents The max suffix components count. If not
   * specified, set to null.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setMaxSuffixComponents(maxSuffixComponents)
  {
    maxSuffixComponents_ = maxSuffixComponents;
    ++changeCount_;
    return this;
  }

  /**
   * Set this interest to use a copy of the given KeyLocator object.
   * Note: You can also call getKeyLocator and change the key locator directly.
   * @param {KeyLocator} keyLocator The KeyLocator object. This makes a copy of 
   * the object. If no key locator is specified, set to a new default
   * KeyLocator(), or to a KeyLocator with an unspecified type.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setKeyLocator(keyLocator)
  {
    keyLocator_.set
      (keyLocator instanceof KeyLocator ? KeyLocator(keyLocator) : KeyLocator());
    ++changeCount_;
    return this;
  }

  /**
   * Set this interest to use a copy of the given exclude object. Note: You can
   * also call getExclude and change the exclude entries directly.
   * @param {Exclude} exclude The Exclude object. This makes a copy of the object.
   * If no exclude is specified, set to a new default Exclude(), or to an Exclude
   * with size() 0.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setExclude(exclude)
  {
    exclude_.set(exclude instanceof Exclude ? Exclude(exclude) : Exclude());
    ++changeCount_;
    return this;
  }

  // TODO: setLinkWireEncoding.
  // TODO: unsetLink.
  // TODO: setSelectedDelegationIndex.

  /**
   * Set the child selector.
   * @param {integer} childSelector The child selector. If not specified, set to
   * null.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setChildSelector(childSelector)
  {
    childSelector_ = childSelector;
    ++changeCount_;
    return this;
  }

  /**
   * Set the MustBeFresh flag.
   * @param {bool} mustBeFresh True if the content must be fresh, otherwise
   * false. If you do not set this flag, the default value is true.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setMustBeFresh(mustBeFresh)
  {
    mustBeFresh_ = (mustBeFresh ? true : false);
    ++changeCount_;
    return this;
  }

  /**
   * Set the interest lifetime.
   * @param {float} interestLifetimeMilliseconds The interest lifetime in
   * milliseconds. If not specified, set to undefined.
   * @return {Interest} This Interest so that you can chain calls to update
   * values.
   */
  function setInterestLifetimeMilliseconds(interestLifetimeMilliseconds)
  {
    if (interestLifetimeMilliseconds == null || interestLifetimeMilliseconds < 0)
      interestLifetimeMilliseconds_ = null;
    else
      interestLifetimeMilliseconds_ = (typeof interestLifetimeMilliseconds == "float") ?
        interestLifetimeMilliseconds : interestLifetimeMilliseconds.tofloat();

    ++changeCount_;
    return this;
  }

  /**
   * @deprecated You should let the wire encoder generate a random nonce
   * internally before sending the interest.
   */
  function setNonce(nonce)
  {
    nonce_ = nonce instanceof Blob ? nonce : Blob(nonce, true);
    // Set _getNonceChangeCount so that the next call to getNonce() won't clear
    // nonce_.
    ++changeCount_;
    getNonceChangeCount_ = getChangeCount();
    return this;
  }

  // TODO: toUri.

  /**
   * Encode this Interest for a particular wire format.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   * @return {SignedBlob} The encoded buffer in a SignedBlob object.
   */
  function wireEncode(wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local result = wireFormat.encodeInterest(this);
    // To save memory, don't cache the encoding.
    return SignedBlob
      (result.encoding, result.signedPortionBeginOffset,
       result.signedPortionEndOffset);
  }

  /**
   * Decode the input using a particular wire format and update this Interest.
   * @param {Blob|blob} input The buffer with the bytes to decode. If input is a
   * Squirrel blob, this decodes starting from input[0], ignoring the location
   * of the blob pointer given by input.tell(), and this does not update the
   * blob pointer.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * decode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   */
  function wireDecode(input, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local decodeBuffer = input instanceof Blob ? input.buf() : input;
    wireFormat.decodeInterest(this, decodeBuffer);
    // To save memory, don't cache the encoding.
  }

  // TODO: refreshNonce.
  // TODO: setLpPacket.

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {integer} The change count.
   */
  function getChangeCount()
  {
    // Make sure each of the checkChanged is called.
    local changed = name_.checkChanged();
    changed = keyLocator_.checkChanged() || changed;
    changed = exclude_.checkChanged() || changed;
    if (changed)
      // A child object has changed, so update the change count.
      ++changeCount_;

    return changeCount_;
  }
}
