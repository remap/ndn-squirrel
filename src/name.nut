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
   * @param {NameComponent|Blob|blob|Array<number>|string} value (optional) If
   * the value is a NameComponent or Blob, use its value directly, otherwise use
   * the value according to the Blob constructor. If the value is null or
   * omitted, create a zero-length component.
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
    else if (value instanceof Blob) {
      if (value.isNull())
        throw "NameComponent: The Blob value may not be null";
      value_ = value;
    }
    else
      // Blob will make a copy if needed.
      value_ = Blob(value);
  }

  /**
   * Get the component value.
   * @return {Blob} The component value.
   */
  function getValue() { return this.value_; }


  /**
   * Check if this component is an ImplicitSha256Digest component.
   * @return {bool} True if this is an ImplicitSha256Digest component.
   */
  function isImplicitSha256Digest()
  {
    return type_ == NameComponentType.IMPLICIT_SHA256_DIGEST;
  }

  /**
   * Create a component of type ImplicitSha256DigestComponent, so that
   * isImplicitSha256Digest() is true.
   * @param {Blob|blob|Array<number>} digest The SHA-256 digest value.
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
  };

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
   * Append a GENERIC component to this Name.
   * @param {Name|NameComponent|Blob|blob|Array<number>|string} component If
   * component is a Name, append all its components. If component is a
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
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
