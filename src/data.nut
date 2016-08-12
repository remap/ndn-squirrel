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
 * The Data class represents an NDN Data packet.
 */
class Data {
  name_ = null;
  metaInfo_ = null;
  signature_ = null;
  content_ = null;
  changeCount_ = 0;

  /**
   * Create a new Data object from the optional value.
   * @param {Name|Data} value (optional) If the value is a Name, make a copy and
   * use it as the Data packet's name. If the value is another Data object, copy
   * its values. If the value is null or omitted, set all fields to defaut
   * values.
   */
  constructor(value = null)
  {
    if (value instanceof Data) {
      // The copy constructor.
      name_ = ChangeCounter(Name(value.getName()));
      metaInfo_ = ChangeCounter(MetaInfo(value.getMetaInfo()));
      signature_ = ChangeCounter(clone(value.getSignature()));
      content_ = value.content_;
    }
    else {
      name_ = ChangeCounter(value instanceof Name ? Name(value) : Name());
      metaInfo_ = ChangeCounter(MetaInfo());
      signature_ = ChangeCounter(Sha256WithRsaSignature());
      content_ = Blob();
    }
  }

  /**
   * Get the data packet's name.
   * @return {Name} The name. If not specified, the name size() is 0.
   */
  function getName() { return name_.get(); }

  /**
   * Get the data packet's meta info.
   * @return {MetaInfo} The meta info.
   */
  function getMetaInfo() { return metaInfo_.get(); }

  /**
   * Get the data packet's signature object.
   * @return {Signature} The signature object.
   */
  function getSignature() { return signature_.get(); }

  /**
   * Get the data packet's content.
   * @return {Blob} The content as a Blob, which isNull() if unspecified.
   */
  function getContent() { return content_; }

  // TODO getIncomingFaceId.
  // TODO getFullName.

  /**
   * Set name to a copy of the given Name.
   * @param {Name} name The Name which is copied.
   * @return {Data} This Data so that you can chain calls to update values.
   */
  function setName(name)
  {
    name_.set(name instanceof Name ? Name(name) : Name());
    ++changeCount_;
    return this;
  }

  /**
   * Set metaInfo to a copy of the given MetaInfo.
   * @param {MetaInfo} metaInfo The MetaInfo which is copied.
   * @return {Data} This Data so that you can chain calls to update values.
   */
  function setMetaInfo(metaInfo)
  {
    metaInfo_.set(metaInfo instanceof MetaInfo ? MetaInfo(metaInfo) : MetaInfo());
    ++changeCount_;
    return this;
  }

  /**
   * Set the signature to a copy of the given signature.
   * @param {Signature} signature The signature object which is cloned.
   * @return {Data} This Data so that you can chain calls to update values.
   */
  function setSignature(signature)
  {
    signature_.set(signature == null ?
      Sha256WithRsaSignature() : clone(signature));
    ++changeCount_;
    return this;
  }

  /**
   * Set the content to the given value.
   * @param {Blob|blob|Array<number>} content The content bytes. If content is
   * not a Blob, then create a new Blob to copy the bytes (otherwise take
   * another pointer to the same Blob).
   * @return {Data} This Data so that you can chain calls to update values.
   */
  function setContent(content)
  {
    content_ = content instanceof Blob ? content : Blob(content, true);
    ++changeCount_;
    return this;
  }

  /**
   * Encode this Data for a particular wire format.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   * @return {SignedBlob} The encoded buffer in a SignedBlob object.
   */
  function wireEncode(wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local result = wireFormat.encodeData(this);
    // To save memory, don't cache the encoding.
    // Debug: Make a SignedBlob.
    return result.encoding;
  }

  /**
   * Decode the input using a particular wire format and update this Data.
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
    wireFormat.decodeData(this, decodeBuffer);
    // To save memory, don't cache the encoding.
  }

  // TODO: setLpPacket.

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {number} The change count.
   */
  function getChangeCount()
  {
    // Make sure each of the checkChanged is called.
    local changed = name_.checkChanged();
    changed = metaInfo_.checkChanged() || changed;
    changed = signature_.checkChanged() || changed;
    if (changed)
      // A child object has changed, so update the change count.
      ++changeCount_;

    return changeCount_;
  }
}
