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
 * A NameComponentType specifies the recognized types of a name component.
 */
enum NameComponentType {
  IMPLICIT_SHA256_DIGEST = 1,
  GENERIC = 8
}

/**
 * A NameComponent holds a read-only name component value.
 */
class NameComponent {
  value_ = null;
  type_ = NameComponentType.GENERIC;

  /**
   * Create a new GENERIC NameComponent using the given value.
   * (To create an ImplicitSha256Digest component, use fromImplicitSha256Digest.)
   * @param {NameComponent|Blob|blob|Buffer|Array<integer>|string} value
   * (optional) If the value is a NameComponent or Blob, use its value directly,
   * otherwise use the value according to the Blob constructor. If the value is
   * null or omitted, create a zero-length component.
   * @throws string if value is a Blob and it isNull.
   */
  constructor(value = null)
  {
    if (value instanceof NameComponent) {
      // The copy constructor.
      value_ = value.value_;
      type_ = value.type_;
      return;
    }

    if (value == null)
      value_ = Blob([]);
    else if (value instanceof Blob)
      value_ = value;
    else
      // Blob will make a copy if needed.
      value_ = Blob(value);
  }

  /**
   * Get the component value.
   * @return {Blob} The component value.
   */
  function getValue() { return value_; }

  /**
   * Convert this component value to a string by escaping characters according
   * to the NDN URI Scheme.
   * This also adds "..." to a value with zero or more ".".
   * This adds a type code prefix as needed, such as "sha256digest=".
   * @return {string} The escaped string.
   */
  function toEscapedString()
  {
    if (type_ == NameComponentType.IMPLICIT_SHA256_DIGEST)
      return "sha256digest=" + value_.toHex();
    else
      return Name.toEscapedString(value_.buf());
  }

  // TODO isSegment.
  // TODO isSegmentOffset.
  // TODO isVersion.
  // TODO isTimestamp.
  // TODO isSequenceNumber.

  /**
   * Check if this component is a generic component.
   * @return {bool} True if this is an generic component.
   */
  function isGeneric()
  {
    return type_ == NameComponentType.GENERIC;
  }

  /**
   * Check if this component is an ImplicitSha256Digest component.
   * @return {bool} True if this is an ImplicitSha256Digest component.
   */
  function isImplicitSha256Digest()
  {
    return type_ == NameComponentType.IMPLICIT_SHA256_DIGEST;
  }

  // TODO toNumber.
  // TODO toNumberWithMarker.
  // TODO toSegment.
  // TODO toSegmentOffset.
  // TODO toVersion.
  // TODO toTimestamp.
  // TODO toSequenceNumber.

  /**
   * Create a component whose value is the nonNegativeInteger encoding of the
   * number.
   * @param {integer} number
   * @return {NameComponent}
   */
  static function fromNumber(number)
  {
    local encoder = TlvEncoder(8);
    encoder.writeNonNegativeInteger(number);
    return NameComponent(encoder.finish());
  };

  // TODO fromNumberWithMarker.
  // TODO fromSegment.
  // TODO fromSegmentOffset.
  // TODO fromVersion.
  // TODO fromTimestamp.
  // TODO fromSequenceNumber.

  /**
   * Create a component of type ImplicitSha256DigestComponent, so that
   * isImplicitSha256Digest() is true.
   * @param {Blob|blob|Buffer|Array<integer>} digest The SHA-256 digest value.
   * @return {NameComponent} The new NameComponent.
   * @throws string If the digest length is not 32 bytes.
   */
  static function fromImplicitSha256Digest(digest)
  {
    local digestBlob = digest instanceof Blob ? digest : Blob(digest, true);
    if (digestBlob.size() != 32)
      throw 
        "Name.Component.fromImplicitSha256Digest: The digest length must be 32 bytes";

    local result = NameComponent(digestBlob);
    result.type_ = NameComponentType.IMPLICIT_SHA256_DIGEST;
    return result;
  }

  // TODO getSuccessor.

  /**
   * Check if this is the same component as other.
   * @param {NameComponent} other The other Component to compare with.
   * @return {bool} True if the components are equal, otherwise false.
   */
  function equals(other)
  {
    return value_.equals(other.value_) && type_ == other.type_;
  }

  /**
   * Compare this to the other Component using NDN canonical ordering.
   * @param {NameComponent} other The other Component to compare with.
   * @return {integer} 0 if they compare equal, -1 if this comes before other in
   * the canonical ordering, or 1 if this comes after other in the canonical
   * ordering.
   * @see http://named-data.net/doc/0.2/technical/CanonicalOrder.html
   */
  function compare(other)
  {
    if (type_ < other.type_)
      return -1;
    if (type_ > other.type_)
      return 1;

    local blob1 = value_.buf();
    local blob2 = other.value_.buf();
    if (blob1.len() < blob2.len())
        return -1;
    if (blob1.len() > blob2.len())
        return 1;

    // The components are equal length. Just do a byte compare.
    // TODO: Does Squirrel have a native buffer compare?
    for (local i = 0; i < blob1.len(); ++i) {
      if (blob1[i] < blob2[i])
        return -1;
      if (blob1[i] > blob2[i])
        return 1;
    }

    return 0;
  }
}

/**
 * A Name holds an array of NameComponent and represents an NDN name.
 */
class Name {
  components_ = null;
  changeCount_ = 0;

  constructor(components = null)
  {
    local componentsType = typeof components;

    if (componentsType == "string") {
      components_ = [];
      set(components);
    }
    else if (components instanceof Name)
      // Don't need to deep-copy Component elements because they are read-only.
      components_ = components.components_.slice(0);
    else if (componentsType == "array")
      // Don't need to deep-copy Component elements because they are read-only.
      components_ = components.slice(0);
    else if (components == null)
      components_ = [];
    else
      throw "Name constructor: Unrecognized components type";
  }

  /**
   * Parse the uri according to the NDN URI Scheme and set the name with the
   * components.
   * @param {string} uri The URI string.
   */
  function set(uri)
  {
    clear();

    uri = strip(uri);
    if (uri.len() <= 0)
      return;

    local iColon = uri.find(":");
    if (iColon != null) {
      // Make sure the colon came before a "/".
      local iFirstSlash = uri.find("/");
      if (iFirstSlash == null || iColon < iFirstSlash)
        // Omit the leading protocol such as ndn:
        uri = strip(uri.slice(iColon + 1));
    }

    if (uri[0] == '/') {
      if (uri.len() >= 2 && uri[1] == '/') {
        // Strip the authority following "//".
        local iAfterAuthority = uri.find("/", 2);
        if (iAfterAuthority == null)
          // Unusual case: there was only an authority.
          return;
        else
          uri = strip(uri.slice(iAfterAuthority + 1));
      }
      else
        uri = strip(uri.slice(1));
    }

    // Note that Squirrel split does not return an empty entry between "//".
    local array = split(uri, "/");

    // Unescape the components.
    local sha256digestPrefix = "sha256digest=";
    for (local i = 0; i < array.len(); ++i) {
      local component;
      if (array[i].len() > sha256digestPrefix.len() &&
          array[i].slice(0, sha256digestPrefix.len()) == sha256digestPrefix) {
        local hexString = strip(array[i].slice(sha256digestPrefix.len()));
        component = NameComponent.fromImplicitSha256Digest
          (Blob(Buffer(hexString, "hex"), false));
      }
      else
        component = NameComponent(Name.fromEscapedString(array[i]));

      if (component.getValue().isNull()) {
        // Ignore the illegal componenent.  This also gets rid of a trailing '/'.
        array.remove(i);
        --i;
        continue;
      }
      else
        array[i] = component;
    }

    components_ = array;
    ++changeCount_;
  }

  /**
   * Append a GENERIC component to this Name.
   * @param {Name|NameComponent|Blob|Buffer|blob|Array<integer>|string} component
   * If component is a Name, append all its components. If component is a
   * NameComponent, append it as is. Otherwise use the value according to the 
   * Blob constructor. If component is a string, convert it directly as in the
   * Blob constructor (don't unescape it).
   * @return {Name} This Name object to allow chaining calls to add.
   */
  function append(component)
  {
    if (component instanceof Name) {
      local components;
      if (component == this)
        // Special case: We need to create a copy.
        components = components_.slice(0);
      else
        components = component.components_;

      for (local i = 0; i < components.len(); ++i)
        components_.append(components[i]);
    }
    else if (component instanceof NameComponent)
      // The Component is immutable, so use it as is.
      components_.append(component);
    else
      // Just use the NameComponent constructor.
      components_.append(NameComponent(component));

    ++changeCount_;
    return this;
  }

  /**
   * Clear all the components.
   */
  function clear()
  {
    components_ = [];
    ++changeCount_;
  }

  /**
   * Return the escaped name string according to NDN URI Scheme.
   * @param {bool} includeScheme (optional) If true, include the "ndn:" scheme
   * in the URI, e.g. "ndn:/example/name". If false, just return the path, e.g.
   * "/example/name". If omitted, then just return the path which is the default
   * case where toUri() is used for display.
   * @return {string} The URI string.
   */
  function toUri(includeScheme = false)
  {
    if (this.size() == 0)
      return includeScheme ? "ndn:/" : "/";

    local result = includeScheme ? "ndn:" : "";

    for (local i = 0; i < size(); ++i)
      result += "/"+ components_[i].toEscapedString();

    return result;
  }

  function _tostring() { return toUri(); }

  // TODO: appendSegment.
  // TODO: appendSegmentOffset.
  // TODO: appendVersion.
  // TODO: appendTimestamp.
  // TODO: appendSequenceNumber.

  /**
   * Append a component of type ImplicitSha256DigestComponent, so that
   * isImplicitSha256Digest() is true.
   * @param {Blob|blob|Buffer|Array<integer>} digest The SHA-256 digest value.
   * @return This name so that you can chain calls to append.
   * @throws string If the digest length is not 32 bytes.
   */
  function appendImplicitSha256Digest(digest)
  {
    return this.append(NameComponent.fromImplicitSha256Digest(digest));
  }

  /**
   * Get a new name, constructed as a subset of components.
   * @param {integer} iStartComponent The index if the first component to get.
   * If iStartComponent is -N then return return components starting from
   * name.size() - N.
   * @param {integer} (optional) nComponents The number of components starting 
   * at iStartComponent. If omitted or greater than the size of this name, get
   * until the end of the name.
   * @return {Name} A new name.
   */
  function getSubName(iStartComponent, nComponents = null)
  {
    if (iStartComponent < 0)
      iStartComponent = components_.len() - (-iStartComponent);

    if (nComponents == null)
      nComponents = components_.len() - iStartComponent;

    local result = Name();

    local iEnd = iStartComponent + nComponents;
    for (local i = iStartComponent; i < iEnd && i < components_.len(); ++i)
      result.components_.append(components_[i]);

    return result;
  }

  /**
   * Return a new Name with the first nComponents components of this Name.
   * @param {integer} nComponents The number of prefix components.  If
   * nComponents is -N then return the prefix up to name.size() - N. For example
   * getPrefix(-1) returns the name without the final component.
   * @return {Name} A new name.
   */
  function getPrefix(nComponents)
  {
    if (nComponents < 0)
      return getSubName(0, components_.len() + nComponents);
    else
      return getSubName(0, nComponents);
  }

  /**
   * Return the number of name components.
   * @return {integer}
   */
  function size() { return components_.len(); }

  /**
   * Get a NameComponent by index number.
   * @param {integer} i The index of the component, starting from 0. However,
   * if i is negative, return the component at size() - (-i).
   * @return {NameComponent} The name component at the index.
   */
  function get(i)
  {
    if (i >= 0)
      return components_[i];
    else
      // Negative index.
      return components_[components_.len() - (-i)];
  }

  /**
   * Encode this Name for a particular wire format.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   * @return {Blob} The encoded buffer in a Blob object.
   */
  function wireEncode(wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    return wireFormat.encodeName(this);
  }

  /**
   * Decode the input using a particular wire format and update this Name.
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
      wireFormat.decodeName(this, input.buf(), false);
    else
      wireFormat.decodeName(this, input, true);
  }

  /**
   * Check if this name has the same component count and components as the given
   * name.
   * @param {Name} The Name to check.
   * @return {bool} True if the names are equal, otherwise false.
   */
  function equals(name)
  {
    if (components_.len() != name.components_.len())
      return false;

    // Start from the last component because they are more likely to differ.
    for (local i = components_.len() - 1; i >= 0; --i) {
      if (!components_[i].equals(name.components_[i]))
        return false;
    }

    return true;
  }

  /**
   * Compare this to the other Name using NDN canonical ordering.  If the first
   * components of each name are not equal, this returns -1 if the first comes
   * before the second using the NDN canonical ordering for name components, or
   * 1 if it comes after. If they are equal, this compares the second components
   * of each name, etc.  If both names are the same up to the size of the
   * shorter name, this returns -1 if the first name is shorter than the second
   * or 1 if it is longer. For example, std::sort gives:
   * /a/b/d /a/b/cc /c /c/a /bb .  This is intuitive because all names with the
   * prefix /a are next to each other. But it may be also be counter-intuitive
   * because /c comes before /bb according to NDN canonical ordering since it is
   * shorter.
   * The first form of compare is simply compare(other). The second form is
   * compare(iStartComponent, nComponents, other [, iOtherStartComponent] [, nOtherComponents])
   * which is equivalent to
   * self.getSubName(iStartComponent, nComponents).compare
   * (other.getSubName(iOtherStartComponent, nOtherComponents)) .
   * @param {integer} iStartComponent The index if the first component of this
   * name to get. If iStartComponent is -N then compare components starting from
   * name.size() - N.
   * @param {integer} nComponents The number of components starting at
   * iStartComponent. If greater than the size of this name, compare until the end
   * of the name.
   * @param {Name} other The other Name to compare with.
   * @param {integer} iOtherStartComponent (optional) The index if the first
   * component of the other name to compare. If iOtherStartComponent is -N then
   * compare components starting from other.size() - N. If omitted, compare
   * starting from index 0.
   * @param {integer} nOtherComponents (optional) The number of components
   * starting at iOtherStartComponent. If omitted or greater than the size of
   * this name, compare until the end of the name.
   * @return {integer} 0 If they compare equal, -1 if self comes before other in
   * the canonical ordering, or 1 if self comes after other in the canonical
   * ordering.
   * @see http://named-data.net/doc/0.2/technical/CanonicalOrder.html
   */
  function compare
    (iStartComponent, nComponents = null, other = null,
     iOtherStartComponent = null, nOtherComponents = null)
  {
    if (iStartComponent instanceof Name) {
      // compare(other)
      other = iStartComponent;
      iStartComponent = 0;
      nComponents = size();
    }

    if (iOtherStartComponent == null)
      iOtherStartComponent = 0;
    if (nOtherComponents == null)
      nOtherComponents = other.size();

    if (iStartComponent < 0)
      iStartComponent = size() - (-iStartComponent);
    if (iOtherStartComponent < 0)
      iOtherStartComponent = other.size() - (-iOtherStartComponent);

    if (nComponents > size() - iStartComponent)
      nComponents = size() - iStartComponent;
    if (nOtherComponents > other.size() - iOtherStartComponent)
      nOtherComponents = other.size() - iOtherStartComponent;

    local count = nComponents < nOtherComponents ? nComponents : nOtherComponents;
    for (local i = 0; i < count; ++i) {
      local comparison = components_[iStartComponent + i].compare
        (other.components_[iOtherStartComponent + i]);
      if (comparison == 0)
        // The components at this index are equal, so check the next components.
        continue;

      // Otherwise, the result is based on the components at this index.
      return comparison;
    }

    // The components up to min(this.size(), other.size()) are equal, so the
    // shorter name is less.
    if (nComponents < nOtherComponents)
      return -1;
    else if (nComponents > nOtherComponents)
      return 1;
    else
      return 0;
  }

  /**
   * Return value as an escaped string according to NDN URI Scheme.
   * This does not add a type code prefix such as "sha256digest=".
   * @param {Buffer} value The value to escape.
   * @return {string} The escaped string.
   */
  static function toEscapedString(value)
  {
    // TODO: Does Squirrel have a StringBuffer?
    local result = "";
    local gotNonDot = false;
    for (local i = 0; i < value.len(); ++i) {
      if (value[i] != 0x2e) {
        gotNonDot = true;
        break;
      }
    }

    if (!gotNonDot) {
      // Special case for a component of zero or more periods. Add 3 periods.
      result = "...";
      for (local i = 0; i < value.len(); ++i)
        result += ".";
    }
    else {
      for (local i = 0; i < value.len(); ++i) {
        local x = value[i];
        // Check for 0-9, A-Z, a-z, (+), (-), (.), (_)
        if (x >= 0x30 && x <= 0x39 || x >= 0x41 && x <= 0x5a ||
            x >= 0x61 && x <= 0x7a || x == 0x2b || x == 0x2d ||
            x == 0x2e || x == 0x5f)
          result += x.tochar();
        else
          result += "%" + ::format("%02X", x);
      }
    }
  
    return result;
  }

  /**
   * Make a blob value by decoding the escapedString according to NDN URI 
   * Scheme. If escapedString is "", "." or ".." then return an isNull() Blob,
   * which means to skip the component in the name.
   * This does not check for a type code prefix such as "sha256digest=".
   * @param {string} escapedString The escaped string to decode.
   * @return {Blob} The unescaped Blob value. If the escapedString is not a
   * valid escaped component, then the Blob isNull().
   */
  static function fromEscapedString(escapedString)
  {
    local value = Name.unescape_(strip(escapedString));

    // Check for all dots.
    local gotNonDot = false;
    for (local i = 0; i < value.len(); ++i) {
      if (value[i] != '.') {
        gotNonDot = true;
        break;
      }
    }

    if (!gotNonDot) {
      // Special case for value of only periods.
      if (value.len() <= 2)
        // Zero, one or two periods is illegal.  Ignore this componenent to be
        //   consistent with the C implementation.
        return Blob();
      else
        // Remove 3 periods.
        return Blob(value.slice(3), false);
    }
    else
      return Blob(value, false);
  };

  /**
   * Return a copy of str, converting each escaped "%XX" to the char value.
   * @param {string} str The escaped string.
   * return {Buffer} The unescaped string as a Buffer.
   */
  static function unescape_(str)
  {
    local result = blob(str.len());

    for (local i = 0; i < str.len(); ++i) {
      if (str[i] == '%' && i + 2 < str.len()) {
        local hi = Buffer.fromHexChar(str[i + 1]);
        local lo = Buffer.fromHexChar(str[i + 2]);

        if (hi < 0 || lo < 0) {
          // Invalid hex characters, so just keep the escaped string.
          result.writen(str[i], 'b');
          result.writen(str[i + 1], 'b');
          result.writen(str[i + 2], 'b');
        }
        else
          result.writen(16 * hi + lo, 'b');

        // Skip ahead past the escaped value.
        i += 2;
      }
      else
        // Just copy through.
        result.writen(str[i], 'b');
    }

    return Buffer.from(result, 0, result.tell());
  }

  // TODO: getSuccessor

  /**
   * Return true if the N components of this name are the same as the first N
   * components of the given name.
   * @param {Name} name The name to check.
   * @return {bool} true if this matches the given name. This always returns
   * true if this name is empty.
   */
  function match(name)
  {
    local i_name = components_;
    local o_name = name.components_;

    // This name is longer than the name we are checking it against.
    if (i_name.len() > o_name.len())
      return false;

    // Check if at least one of given components doesn't match. Check from last
    // to first since the last components are more likely to differ.
    for (local i = i_name.len() - 1; i >= 0; --i) {
      if (!i_name[i].equals(o_name[i]))
        return false;
    }

    return true;
  }

  /**
   * Return true if the N components of this name are the same as the first N
   * components of the given name.
   * @param {Name} name The name to check.
   * @return {bool} true if this matches the given name. This always returns
   * true if this name is empty.
   */
  function isPrefixOf(name) { return match(name); }

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
