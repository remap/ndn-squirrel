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
 * Standard Squirrel code should include this first to use Electric Imp Squirrel
 * code written with math.abs(x), etc.
 */
if (!("math" in getroottable())) {
  // We are not on the Imp, so define math.
  math <- {
    function abs(x) { return ::abs(x); }
    function acos(x) { return ::acos(x); }
    function asin(x) { return ::asin(x); }
    function atan(x) { return ::atan(x); }
    function atan2(x, y) { return ::atan2(x, y); }
    function ceil(x) { return ::ceil(x); }
    function cos(x) { return ::cos(x); }
    function exp(x) { return ::exp(x); }
    function fabs(x) { return ::fabs(x); }
    function floor(x) { return ::floor(x); }
    function log(x) { return ::log(x); }
    function log10(x) { return ::log10(x); }
    function pow(x, y) { return ::pow(x, y); }
    function rand() { return ::rand(); }
    function sin(x) { return ::sin(x); }
    function sqrt(x) { return ::sqrt(x); }
    function tan(x) { return ::tan(x); }
  }
}
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
 * A Buffer wraps a Squirrel blob and provides an API imitating the Node.js
 * Buffer class, especially where the slice method returns a view onto the
 * same underlying blob array instead of making a copy. The size of the
 * underlying Squirrel blob is fixed and can't be resized.
 */
class Buffer {
  blob_ = ::blob(0);
  offset_ = 0;
  len_ = 0;

  /**
   * Create a new Buffer based on the value.
   * @param {integer|Buffer|blob|array<integer>|string} value If value is an
   * integer, create a new underlying blob of the given size. If value is a
   * Buffer, copy its bytes into a new underlying blob of size value.len(). (If
   * you want a new Buffer without copying, use value.size().) If value is a
   * Squirrel blob, copy its bytes into a new underlying blob. (If you want a
   * new Buffer without copying the blob, use Buffer.from(value).) If value is a
   * byte array, copy into a new underlying blob. If value is a string, treat it
   * as "raw" and copy to a new underlying blob without UTF-8 encoding.
   * @param {string} encoding (optional) If value is a string, convert it to a
   * byte array as follows. If encoding is "raw" or omitted, copy value to a new
   * underlying blob without UTF-8 encoding. If encoding is "hex", value must be
   * a sequence of pairs of hexadecimal digits, so convert them to integers.
   * @throws string if the encoding is unrecognized or a hex string has invalid
   * characters (or is not a multiple of 2 in length).
   */
  constructor(value, encoding = "raw")
  {
    local valueType = typeof value;

    if (valueType == "blob") {
      // Copy.
      if (value.len() > 0) {
        // Copy the value blob. Set and restore its read/write pointer.
        local savePointer = value.tell();
        value.seek(0);
        blob_ = value.readblob(value.len());
        value.seek(savePointer);

        len_ = value.len();
      }
    }
    else if (valueType == "integer") {
      if (value > 0) {
        blob_ = ::blob(value);
        len_ = value;
      }
    }
    else if (valueType == "array") {
      // Assume the array has integer values.
      blob_ = ::blob(value.len());
      foreach (x in value)
        blob_.writen(x, 'b');

      len_ = value.len();
    }
    else if (valueType == "string") {
      if (encoding == "raw") {
        // Just copy the string. Don't UTF-8 decode.
        blob_ = ::blob(value.len());
        // Don't use writestring since Standard Squirrel doesn't have it.
        foreach (x in value)
          blob_.writen(x, 'b');

        len_ = value.len();
      }
      else if (encoding == "hex") {
        if (value.len() % 2 != 0)
          throw "Invalid hex value";
        len_ = value.len() / 2;
        blob_ = ::blob(len_);

        local iBlob = 0;
        for (local i = 0; i < value.len(); i += 2) {
          local hi = ::Buffer.fromHexChar(value[i]);
          local lo = ::Buffer.fromHexChar(value[i + 1]);
          if (hi < 0 || lo < 0)
            throw "Invalid hex value";

          blob_[iBlob++] = 16 * hi + lo;
        }
      }
      else
        throw "Unrecognized encoding";
    }
    else if (value instanceof ::Buffer) {
      if (value.len_ > 0) {
        // Copy only the bytes we needed from the value's blob.
        value.blob_.seek(value.offset_);
        blob_ = value.blob_.readblob(value.len_);

        len_ = value.len_;
      }
    }
    else
      throw "Unrecognized type";
  }

  /**
   * Get a new Buffer which wraps the given Squirrel blob, sharing its array.
   * @param {blob} blob The Squirrel blob to use for the new Buffer.
   * @param {integer} offset (optional) The index where the new Buffer will
   * start. If omitted, use 0.
   * @param {integer} len (optional) The number of bytes from the given blob
   * that this Buffer will share. If omitted, use blob.len() - offset.
   * @return {Buffer} A new Buffer.
   */
  static function from(blob, offset = 0, len = null)
  {
    if (len == null)
      len = blob.len() - offset;

    // TODO: Do a bounds check?
    // First create a Buffer with default values, then set the blob_ and len_.
    local result = Buffer(0);
    result.blob_ = blob;
    result.offset_ = offset;
    result.len_ = len;
    return result;
  }

  /**
   * Get the length of this Buffer.
   * @return {integer} The length.
   */
  function len() { return len_; }

  /**
   * Copy bytes from a region of this Buffer to a region in target even if the
   * target region overlaps this Buffer.
   * @param {Buffer|blob|array} target The Buffer or Squirrel blob or array of
   * integers to copy to.
   * @param {integer} targetStart (optional) The start index in target to copy
   * to. If omitted, use 0.
   * @param {integer} sourceStart (optional) The start index in this Buffer to
   * copy from. If omitted, use 0.
   * @param {integer} sourceEnd (optional) The end index in this Buffer to copy
   * from (not inclusive). If omitted, use len().
   * @return {integer} The number of bytes copied.
   */
  function copy(target, targetStart = 0, sourceStart = 0, sourceEnd = null)
  {
    if (sourceEnd == null)
      sourceEnd = len_;

    local nBytes = sourceEnd - sourceStart;

    // Get the index in the source and target blobs.
    local iSource = offset_ + sourceStart;
    local targetBlob;
    local iTarget;
    if (target instanceof ::Buffer) {
      targetBlob = target.blob_;
      iTarget = target.offset_ + targetStart;
    }
    else if (typeof target == "array") {
      // Special case. Just copy bytes to the array and return.
      iTarget = targetStart;
      local iEnd = offset_ + sourceEnd;
      while (iSource < iEnd)
        target[iTarget++] = blob_[iSource++];
      return nBytes;
    }
    else {
      targetBlob = target;
      iTarget = targetStart;
    }

    if (targetBlob == blob_) {
      // We are copying within the same blob.
      if (iTarget > iSource && iTarget < offset_ + sourceEnd)
        // Copying to the target will overwrite the source.
        throw "Buffer.copy: Overlapping copy is not supported yet";
    }

    if (iSource == 0 && sourceEnd == blob_.len()) {
      // We can use writeblob to copy the entire blob_.
      // Set and restore its read/write pointer.
      local savePointer = targetBlob.tell();
      targetBlob.seek(iTarget);
      targetBlob.writeblob(blob_);
      targetBlob.seek(savePointer);
    }
    else {
      // Don't use blob's readblob since it makes its own copy.
      // TODO: Does Squirrel have a memcpy?
      local iEnd = offset_ + sourceEnd;
      while (iSource < iEnd)
        targetBlob[iTarget++] = blob_[iSource++];
    }

    return nBytes;
  }

  /**
   * Get a new Buffer that references the same underlying blob array as the
   * original, but offset and cropped by the start and end indices. Note that
   * modifying the new Buffer slice will modify the original Buffer because the
   * allocated blob array portions of the two objects overlap.
   * @param {integer} start (optional) The index where the new Buffer will start.
   * If omitted, use 0.
   * @param {integer} end (optional) The index where the new Buffer will end
   * (not inclusive). If omitted, use len().
   */
  function slice(start = 0, end = null)
  {
    if (end == null)
      end = len_;

    if (start == 0 && end == len_)
      return this;

    // TODO: Do a bounds check?
    local result = ::Buffer.from(blob_);
    // Fix offset_ and len_.
    result.offset_ = offset_ + start;
    result.len_ = end - start;
    return result;
  }

  /**
   * Return a new Buffer which is the result of concatenating all the Buffer 
   * instances in the list together.
   * @param {Array<Buffer>} list An array of Buffer instances to concat. If the
   * list has no items, return a new zero-length Buffer.
   * @param {integer} (optional) totalLength The total length of the Buffer
   * instances in list when concatenated. If omitted, calculate the total
   * length, but this causes an additional loop to be executed, so it is faster
   * to provide the length explicitly if it is already known. If the total
   * length is zero, return a new zero-length Buffer.
   * @return {Buffer} A new Buffer.
   */
  static function concat(list, totalLength = null)
  {
    if (list.len() == 1)
      // A simple case.
      return ::Buffer(list[0]);
  
    if (totalLength == null) {
      totalLength = 0;
      foreach (buffer in list)
        totalLength += buffer.len();
    }

    local result = ::blob(totalLength);
    local offset = 0;
    foreach (buffer in list) {
      buffer.copy(result, offset);
      offset += buffer.len();
    }

    return ::Buffer.from(result);
  }

  /**
   * Get a string with the bytes in the blob array using the given encoding.
   * @param {string} encoding If encoding is "hex", return the hex
   * representation of the bytes in the blob array. If encoding is "raw",
   * return the bytes of the byte array as a raw str of the same length. (This
   * does not do any character encoding such as UTF-8.)
   * @return {string} The encoded string.
   */
  function toString(encoding)
  {
    if (encoding == "hex") {
      // TODO: Does Squirrel have a StringBuffer?
      local result = "";
      for (local i = 0; i < len_; ++i)
        result += ::format("%02x", get(i));

      return result;
    }
    else if (encoding == "raw") {
      // Don't use readstring since Standard Squirrel doesn't have it.
      local result = "";
      // TODO: Does Squirrel have a StringBuffer?
      for (local i = 0; i < len_; ++i)
        result += get(i).tochar();

      return result;
    }
    else
      throw "Unrecognized encoding";
  }

  /**
   * Return a copy of the bytes of the array as a Squirrel blob.
   * @return {blob} A new Squirrel blob with the copied bytes.
   */
  function toBlob()
  {
    if (len_ <= 0)
      return ::blob(0);

    blob_.seek(offset_);
    return blob_.readblob(len_);
  }

  /**
   * A utility function to convert the hex character to an integer from 0 to 15.
   * @param {integer} c The integer character.
   * @return (integer} The hex value, or -1 if x is not a hex character.
   */
  static function fromHexChar(c)
  {
    if (c >= '0' && c <= '9')
      return c - '0';
    else if (c >= 'A' && c <= 'F')
      return c - 'A' + 10;
    else if (c >= 'a' && c <= 'f')
      return c - 'a' + 10;
    else
      return -1;
  }

  /**
   * Get the value at the index.
   * @param {integer} i The zero-based index into the buffer array.
   * @return {integer} The value at the index.
   */
  function get(i) { return blob_[offset_ + i]; }

  /**
   * Set the value at the index.
   * @param {integer} i The zero-based index into the buffer array.
   * @param {integer} value The value to set.
   */
  function set(i, value) { blob_[offset_ + i] = value; }

  function _get(i)
  {
    // Note: In this class, we always reference globals with :: to avoid
    // invoking this _get metamethod.

    if (typeof i == "integer")
      // TODO: Do a bounds check?
      return blob_[offset_ + i];
    else
      throw "Unrecognized type";
  }

  function _set(i, value)
  {
    if (typeof i == "integer")
      // TODO: Do a bounds check?
      blob_[offset_ + i] = value;
    else
      throw "Unrecognized type";
  }

  function _nexti(previdx)
  {
    if (len_ <= 0)
      return null;
    else if (previdx == null)
      return 0;
    else if (previdx == len_ - 1)
      return null;
    else
      return previdx + 1;
  }
}
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
 * A Blob holds an immutable byte array implemented as a Buffer. This should be
 * treated like a string which is a pointer to an immutable string. (It is OK to
 * pass a pointer to the string because the new owner can’t change the bytes of
 * the string.)  Instead you must call buf() to get the byte array which reminds
 * you that you should not change the contents.  Also remember that buf() can
 * return null.
 */
class Blob {
  buffer_ = null;

  /**
   * Create a new Blob which holds an immutable array of bytes.
   * @param {Blob|SignedBlob|Buffer|blob|array<integer>|string} value (optional)
   * If value is a Blob or SignedBlob, take another pointer to its Buffer
   * without copying. If value is a Buffer or Squirrel blob, optionally copy.
   * If value is a byte array, copy to create a new Buffer. If value is a string,
   * treat it as "raw" and copy to a byte array without UTF-8 encoding.  If
   * omitted, buf() will return null.
   * @param {bool} copy (optional) If true, copy the contents of value into a 
   * new Buffer. If value is a Squirrel blob, copy the entire array, ignoring
   * the location of its blob pointer given by value.tell().  If copy is false,
   * and value is a Buffer or Squirrel blob, just use it without copying. If
   * omitted, then copy the contents (unless value is already a Blob).
   * IMPORTANT: If copy is false, if you keep a pointer to the value then you
   * must treat the value as immutable and promise not to change it.
   */
  constructor(value = null, copy = true)
  {
    if (value == null)
      buffer_ = null;
    else if (value instanceof Blob)
      // Use the existing buffer. Don't need to check for copy.
      buffer_ = value.buffer_;
    else {
      if (copy)
        // We are copying, so just make another Buffer.
        buffer_ = Buffer(value);
      else {
        if (value instanceof Buffer)
          // We can use it as-is.
          buffer_ = value;
        else if (typeof value == "blob")
          buffer_ = Buffer.from(value);
        else
          // We need a Buffer, so copy.
          buffer_ = Buffer(value);
      }
    }
  }

  /**
   * Return the length of the immutable byte array.
   * @return {integer} The length of the array.  If buf() is null, return 0.
   */
  function size()
  {
    if (buffer_ != null)
      return buffer_.len();
    else
      return 0;
  }

  /**
   * Return the immutable byte array.  DO NOT change the contents of the buffer.
   * If you need to change it, make a copy.
   * @return {Buffer} The Buffer holding the immutable byte array, or null.
   */
  function buf() { return buffer_; }

  /**
   * Return true if the array is null, otherwise false.
   * @return {bool} True if the array is null.
   */
  function isNull() { return buffer_ == null; }

  /**
   * Return the hex representation of the bytes in the byte array.
   * @return {string} The hex string.
   */
  function toHex()
  {
    if (buffer_ == null)
      return "";
    else
      return buffer_.toString("hex");
  }

  /**
   * Return the bytes of the byte array as a raw str of the same length. This
   * does not do any character encoding such as UTF-8.
   * @return The buffer as a string, or "" if isNull().
   */
  function toRawStr()
  {
    if (buffer_ == null)
      return "";
    else
      return buffer_.toString("raw");
  }

  /**
   * Check if the value of this Blob equals the other blob.
   * @param {Blob} other The other Blob to check.
   * @return {bool} if this isNull and other isNull or if the bytes of this Blob
   * equal the bytes of the other.
   */
  function equals(other)
  {
    if (isNull())
      return other.isNull();
    else if (other.isNull())
      return false;
    else {
      if (buffer_.len() != other.buffer_.len())
        return false;

      // TODO: Does Squirrel have a native buffer compare?
      for (local i = 0; i < buffer_.len(); ++i) {
        if (buffer_.get(i) != other.buffer_.get(i))
          return false;
      }

      return true;
    }
  }
}
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
 * A ChangeCounter keeps a target object whose change count is tracked by a
 * local change count.  You can set to a new target which updates the local
 * change count, and you can call checkChanged to check if the target (or one of
 * the target's targets) has been changed. The target object must have a method
 * getChangeCount.
 */
class ChangeCounter {
  target_ = null;
  changeCount_ = 0;

  /**
   * Create a new ChangeCounter to track the given target. If target is not null,
   * this sets the local change counter to target.getChangeCount().
   * @param {instance} target The target to track, as an object with the method
   * getChangeCount().
   */
  constructor(target)
  {
    target_ = target;
    changeCount_ = (target == null ? 0 : target.getChangeCount());
  }

  /**
   * Get the target object. If the target is changed, then checkChanged will
   * detect it.
   * @return {instance} The target, as an object with the method
   * getChangeCount().
   */
  function get() { return target_; }

  /**
   * Set the target to the given target. If target is not null, this sets the
   * local change counter to target.getChangeCount().
   * @param {instance} target The target to track, as an object with the method
   * getChangeCount().
   */
  function set(target)
  {
    target_ = target;
     changeCount_ = (target == null ? 0 : target.getChangeCount());
  }

  /**
   * If the target's change count is different than the local change count, then
   * update the local change count and return true. Otherwise return false,
   * meaning that the target has not changed. Also, if the target is null,
   * simply return false. This is useful since the target (or one of the
   * target's targets) may be changed and you need to find out.
   * @return {bool} True if the change count has been updated, false if not.
   */
  function checkChanged()
  {
    if (target_ == null)
      return false;

    local targetChangeCount = target_.getChangeCount();
    if (changeCount_ != targetChangeCount) {
      changeCount_ = targetChangeCount;
      return true;
    }
    else
      return false;
  }
}
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
 * Crypto has static methods for basic cryptography operations.
 */
class Crypto {
  /**
   * Fill the value with random bytes. Note: If not on the Imp, you must seed
   * with srand().
   * @param {Buffer|blob} value Write the random bytes to this array from
   * startIndex to endIndex. If this is a Squirrel blob, it ignores the location
   * of the blob pointer given by value.tell() and does not update the blob
   * pointer.
   * @param startIndex (optional) The index of the first byte in value to set.
   * If omitted, start from index 0.
   * @param endIndex (optional) Set bytes in value up to endIndex - 1. If
   * omitted, set up to value.len() - 1.
   */
  static function generateRandomBytes(value, startIndex = 0, endIndex = null)
  {
    if (endIndex == null)
      endIndex = value.len();

    local valueIsBuffer = (value instanceof Buffer);
    for (local i = startIndex; i < endIndex; ++i) {
      local x = ((1.0 * math.rand() / RAND_MAX) * 256).tointeger();
      if (valueIsBuffer)
        // Use Buffer.set to avoid using the metamethod.
        value.set(i, x);
      else
        value[i] = x;
    }
  }

  /**
   * Get the Crunch object, creating it if necessary. (To save memory, we don't
   * want to create it until needed.)
   * @return {Crunch} The Crunch object.
   */
  static function getCrunch()
  {
    if (::Crypto_crunch_ == null)
      ::Crypto_crunch_ = Crunch();
    return ::Crypto_crunch_;
  }
}

Crypto_crunch_ <- null;
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
 * A DynamicBlobArray holds a Squirrel blob and provides methods to ensure a
 * minimum length, resizing if necessary.
 */
class DynamicBlobArray {
  array_ = null;        // blob

  /**
   * Create a new DynamicBlobArray with an initial length.
   * @param initialLength (optional) The initial length of the allocated array.
   * If omitted, use a default
   */
  constructor(initialLength = 16)
  {
    array_ = blob(initialLength);
  }

  /**
   * Ensure that the array has the minimal length, resizing it if necessary.
   * The new length of the array may be greater than the given length.
   * @param {integer} length The minimum length for the array.
   */
  function ensureLength(length)
  {
    // array_.len() is always the full length of the array.
    if (array_.len() >= length)
      return;

    // See if double is enough.
    local newLength = array_.len() * 2;
    if (length > newLength)
      // The needed length is much greater, so use it.
      newLength = length;

    // Instead of using resize, we manually copy to a new blob so that
    // array_.len() will be the full length.
    local newArray = blob(newLength);
    newArray.writeblob(array_);
    array_ = newArray;
  }

  /**
   * Copy the given buffer into this object's array, using ensureLength to make
   * sure there is enough room.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   * @param {integer} offset The offset in this object's array to copy to.
   * @return {integer} The new offset which is offset + buffer.length.
   */
  function copy(buffer, offset)
  {
    ensureLength(offset + buffer.len());
    buffer.copy(array_, offset);

    return offset + buffer.len();
  }

  /**
   * Ensure that the array has the minimal length. If necessary, reallocate the
   * array and shift existing data to the back of the new array. The new length
   * of the array may be greater than the given length.
   * @param {integer} length The minimum length for the array.
   */
  function ensureLengthFromBack(length)
  {
    // array_.len() is always the full length of the array.
    if (array_.len() >= length)
      return;

    // See if double is enough.
    local newLength = array_.len() * 2;
    if (length > newLength)
      // The needed length is much greater, so use it.
      newLength = length;

    local newArray = blob(newLength);
    // Copy to the back of newArray.
    newArray.seek(newArray.len() - array_.len());
    newArray.writeblob(array_);
    array_ = newArray;
  }

  /**
   * First call ensureLengthFromBack to make sure the bytearray has
   * offsetFromBack bytes, then copy the given buffer into this object's array
   * starting offsetFromBack bytes from the back of the array.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   * @param {integer} offset The offset from the back of the array to start
   * copying.
   */
  function copyFromBack(buffer, offsetFromBack)
  {
    ensureLengthFromBack(offsetFromBack);
    buffer.copy(array_, array_.len() - offsetFromBack);
  }

  /**
   * Wrap this object's array in a Buffer slice starting lengthFromBack from the
   * back of this object's array and make a Blob. Finally, set this object's
   * array to null to prevent further use.
   * @param {integer} lengthFromBack The final length of the allocated array.
   * @return {Blob} A new NDN Blob with the bytes from the array.
   */
  function finishFromBack(lengthFromBack)
  {
    local result = Blob
      (Buffer.from(array_, array_.len() - lengthFromBack), false);
    array_ = null;
    return result;
  }
}
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
  MAX_NDN_PACKET_SIZE = 8800;

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
 * A SignedBlob extends Blob to keep the offsets of a signed portion (e.g., the
 * bytes of Data packet). This inherits from Blob, including Blob.size and
 * Blob.buf.
 */
class SignedBlob extends Blob {
  signedBuffer_ = null;
  signedPortionBeginOffset_ = 0;
  signedPortionEndOffset_ = 0;

  /**
   * Create a new SignedBlob using the given optional value and offsets.
   * @param {Blob|SignedBlob|Buffer|blob|array<integer>|string} value (optional)
   * If value is a Blob or SignedBlob, take another pointer to its Buffer
   * without copying. If value is a Buffer or Squirrel blob, optionally copy.
   * If value is a byte array, copy to create a new Buffer. If value is a string,
   * treat it as "raw" and copy to a byte array without UTF-8 encoding.  If
   * omitted, buf() will return null.
   * @param {integer} signedPortionBeginOffset (optional) The offset in the
   * encoding of the beginning of the signed portion. If omitted, set to 0.
   * @param {integer} signedPortionEndOffset (optional) The offset in the
   * encoding of the end of the signed portion. If omitted, set to 0.
   */
  constructor
    (value = null, signedPortionBeginOffset = null,
     signedPortionEndOffset = null)
  {
    // Call the base constructor.
    base.constructor(value);

    if (buffer_ == null) {
      // Offsets are already 0 by default.
    }
    else if (value instanceof SignedBlob) {
      // Copy the SignedBlob, allowing override for offsets.
      signedPortionBeginOffset_ = signedPortionBeginOffset == null ?
        value.signedPortionBeginOffset_ : signedPortionBeginOffset;
      signedPortionEndOffset_ = signedPortionEndOffset == null ?
        value.signedPortionEndOffset_ : signedPortionEndOffset;
    }
    else {
      if (signedPortionBeginOffset != null)
        signedPortionBeginOffset_ = signedPortionBeginOffset;
      if (signedPortionEndOffset != null)
        signedPortionEndOffset_ = signedPortionEndOffset;
    }

    if (buffer_ != null)
      signedBuffer_ = buffer_.slice
        (signedPortionBeginOffset_, signedPortionEndOffset_);
  }

  /**
   * Return the length of the signed portion of the immutable byte array.
   * @return {integer} The length of the signed portion. If signedBuf() is null,
   * return 0.
   */
  function signedSize()
  {
    if (signedBuffer_ != null)
      return signedBuffer_.len();
    else
      return 0;
  }

  /**
   * Return a the signed portion of the immutable byte array.
   * @return {Buffer} A Buffer which is the signed portion. If the array is
   * null, return null.
   */
  function signedBuf() { return signedBuffer_; }

  /**
   * Return the offset in the array of the beginning of the signed portion.
   * @return {integer} The offset in the array.
   */
  function getSignedPortionBeginOffset() { return signedPortionBeginOffset_; }

  /**
   * Return the offset in the array of the end of the signed portion.
   * @return {integer} The offset in the array.
   */
  function getSignedPortionEndOffset() { return signedPortionEndOffset_; }
}
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

  /**
   * Interpret this name component as a network-ordered number and return an
   * integer.
   * @return {integer} The integer number.
   */
  function toNumber()
  {
    local buf = value_.buf();
    local result = 0;
    for (local i = 0; i < buf.len(); ++i) {
      result = result << 8;
      result += buf.get(i);
    }
  
    return result;
  }

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

    local buffer1 = value_.buf();
    local buffer2 = other.value_.buf();
    if (buffer1.len() < buffer2.len())
        return -1;
    if (buffer1.len() > buffer2.len())
        return 1;

    // The components are equal length. Just do a byte compare.
    // TODO: Does Squirrel have a native buffer compare?
    for (local i = 0; i < buffer1.len(); ++i) {
      // Use Buffer.get to avoid using the metamethod.
      if (buffer1.get(i) < buffer2.get(i))
        return -1;
      if (buffer1.get(i) > buffer2.get(i))
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
      // Use Buffer.get to avoid using the metamethod.
      if (value.get(i) != 0x2e) {
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
        local x = value.get(i);
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
      // Use Buffer.get to avoid using the metamethod.
      if (value.get(i) != '.') {
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
 * An ExcludeType specifies the type of an ExcludeEntry.
 */
enum ExcludeType {
  COMPONENT, ANY
}

/**
 * An ExcludeEntry holds an ExcludeType, and if it is a COMPONENT, it holds
 * the component value.
 */
class ExcludeEntry {
  type_ = 0;
  component_ = null;

  /**
   * Create a new Exclude.Entry.
   * @param {NameComponent|Blob|Buffer|blob|Array<integer>|string} (optional) If
   * value is omitted or null, create an ExcludeEntry of type ExcludeType.ANY.
   * Otherwise creat an ExcludeEntry of type ExcludeType.COMPONENT with the value.
   * If the value is a NameComponent or Blob, use its value directly, otherwise
   * use the value according to the Blob constructor.
   */
  constructor(value = null)
  {
    if (value == null)
      type_ = ExcludeType.ANY;
    else {
      type_ = ExcludeType.COMPONENT;
      component_ = value instanceof NameComponent ? value : NameComponent(value);
    }
  }

  /**
   * Get the type of this entry.
   * @return {integer} The Exclude type as an ExcludeType enum value.
   */
  function getType() { return type_; }

  /**
   * Get the component value for this entry (if it is of type ExcludeType.COMPONENT).
   * @return {NameComponent} The component value, or null if this entry is not
   * of type ExcludeType.COMPONENT.
   */
  function getComponent() { return component_; }
}

/**
 * The Exclude class is used by Interest and holds an array of ExcludeEntry to
 * represent the fields of an NDN Exclude selector.
 */
class Exclude {
  entries_ = null;
  changeCount_ = 0;

  /**
   * Create a new Exclude.
   * @param {Exclude} exclude (optional) If exclude is another Exclude
   * object, copy its values. Otherwise, set all fields to defaut values.
   */
  constructor(exclude = null)
  {
    if (exclude instanceof Exclude)
      // The copy constructor.
      entries_ = exclude.entries_.slice(0);
    else
      entries_ = [];
  }

  /**
   * Get the number of entries.
   * @return {integer} The number of entries.
   */
  function size() { return entries_.len(); }

  /**
   * Get the entry at the given index.
   * @param {integer} i The index of the entry, starting from 0.
   * @return {ExcludeEntry} The entry at the index.
   */
  function get(i) { return entries_[i]; }

  /**
   * Append a new entry of type Exclude.Type.ANY.
   * @return This Exclude so that you can chain calls to append.
   */
  function appendAny()
  {
    entries_.append(ExcludeEntry());
    ++changeCount_;
    return this;
  }

  /**
   * Append a new entry of type ExcludeType.COMPONENT with the give component.
   * @param component {NameComponent|Blob|Buffer|blob|Array<integer>|string} The
   * component value for the entry. If component is a NameComponent or Blob, use
   * its value directly, otherwise use the value according to the Blob
   * constructor.
   * @return This Exclude so that you can chain calls to append.
   */
  function appendComponent(component)
  {
    entries_.append(ExcludeEntry(component));
    ++changeCount_;
    return this;
  }

  /**
   * Clear all the entries.
   */
  function clear()
  {
    ++changeCount_;
    entries_ = [];
  }

  /**
   * Return a string with elements separated by "," and Exclude.ANY shown as "*".
   * @return {string} The URI string.
   */
  function toUri()
  {
    if (entries_.len() == 0)
      return "";

    local result = "";
    for (local i = 0; i < entries_.len(); ++i) {
      if (i > 0)
        result += ",";

      if (entries_[i].getType() == ExcludeType.ANY)
        result += "*";
      else
        result += entries_[i].getComponent().toEscapedString();
    }

    return result;
  }

  // TODO: matches.

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
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

  /**
   * Check if the given Data packet can satisfy this Interest. This method
   * considers the Name, MinSuffixComponents, MaxSuffixComponents,
   * PublisherPublicKeyLocator, and Exclude. It does not consider the
   * ChildSelector or MustBeFresh. This uses the given wireFormat to get the
   * Data packet encoding for the full Name.
   * @param {Data} data The Data packet to check.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the Data packet to get its full Name. If omitted, use
   * WireFormat.getDefaultWireFormat().
   * @return {bool} True if the given Data packet can satisfy this Interest.
   */
  function matchesData(data, wireFormat = null)
  {
    // Imitate ndn-cxx Interest::matchesData.
    local interestNameLength = getName().size();
    local dataName = data.getName();
    local fullNameLength = dataName.size() + 1;

    // Check MinSuffixComponents.
    local hasMinSuffixComponents = (getMinSuffixComponents() != null);
    local minSuffixComponents =
      hasMinSuffixComponents ? getMinSuffixComponents() : 0;
    if (!(interestNameLength + minSuffixComponents <= fullNameLength))
      return false;

    // Check MaxSuffixComponents.
    local hasMaxSuffixComponents = (getMaxSuffixComponents() != null);
    if (hasMaxSuffixComponents &&
        !(interestNameLength + getMaxSuffixComponents() >= fullNameLength))
      return false;

    // Check the prefix.
    if (interestNameLength == fullNameLength) {
      if (getName().get(-1).isImplicitSha256Digest()) {
        if (!getName().equals(data.getFullName(wireFormat)))
          return false;
      }
      else
        // The Interest Name is the same length as the Data full Name, but the
        //   last component isn't a digest so there's no possibility of matching.
        return false;
    }
    else {
      // The Interest Name should be a strict prefix of the Data full Name.
      if (!getName().isPrefixOf(dataName))
        return false;
    }

    // Check the Exclude.
    // The Exclude won't be violated if the Interest Name is the same as the
    //   Data full Name.
    if (getExclude().size() > 0 && fullNameLength > interestNameLength) {
      if (interestNameLength == fullNameLength - 1) {
        // The component to exclude is the digest.
        if (getExclude().matches
            (data.getFullName(wireFormat).get(interestNameLength)))
          return false;
      }
      else {
        // The component to exclude is not the digest.
        if (getExclude().matches(dataName.get(interestNameLength)))
          return false;
      }
    }

    // Check the KeyLocator.
    local publisherPublicKeyLocator = getKeyLocator();
    if (publisherPublicKeyLocator.getType()) {
      local signature = data.getSignature();
      if (!KeyLocator.canGetFromSignature(signature))
        // No KeyLocator in the Data packet.
        return false;
      if (!publisherPublicKeyLocator.equals
          (KeyLocator.getFromSignature(signature)))
        return false;
    }

    return true;
  }

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
    // Set getNonceChangeCount_ so that the next call to getNonce() won't clear
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
      wireFormat.decodeInterest(this, input.buf(), false);
    else
      wireFormat.decodeInterest(this, input, true);
    // To save memory, don't cache the encoding.
  }

  /**
   * Update the bytes of the nonce with new random values. This ensures that the
   * new nonce value is different than the current one. If the current nonce is
   * not specified, this does nothing.
   */
  function refreshNonce()
  {
    local currentNonce = getNonce();
    if (currentNonce.size() == 0)
      return;

    local newNonce;
    while (true) {
      local buffer = Buffer(currentNonce.size());
      Crypto.generateRandomBytes(buffer);
      newNonce = Blob(buffer, false);
      if (!newNonce.equals(currentNonce))
        break;
    }

    nonce_ = newNonce;
    // Set getNonceChangeCount_ so that the next call to getNonce() won't clear
    // this.nonce_.
    ++changeCount_;
    getNonceChangeCount_ = getChangeCount();
  }

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
 * An InterestFilter holds a Name prefix and optional regex match expression for
 * use in Face.setInterestFilter.
 */
class InterestFilter {
  prefix_ = null;
  regexFilter_ = null;
  regexFilterPattern_ = null;

  /**
   * Create an InterestFilter to match any Interest whose name starts with the
   * given prefix. If the optional regexFilter is provided then the remaining
   * components match the regexFilter regular expression as described in
   * doesMatch.
   * @param {InterestFilter|Name|string} prefix If prefix is another
   * InterestFilter copy its values. If prefix is a Name then this makes a copy
   * of the Name. Otherwise this creates a Name from the URI string.
   * @param {string} regexFilter (optional) The regular expression for matching
   * the remaining name components.
   */
  constructor(prefix, regexFilter = null)
  {
    if (prefix instanceof InterestFilter) {
      // The copy constructor.
      local interestFilter = prefix;
      prefix_ = Name(interestFilter.prefix_);
      regexFilter_ = interestFilter.regexFilter_;
      regexFilterPattern_ = interestFilter.regexFilterPattern_;
    }
    else {
      prefix_ = Name(prefix);
      if (regexFilter != null) {
/*      TODO: Support regex.
        regexFilter_ = regexFilter;
        regexFilterPattern_ = InterestFilter.makePattern(regexFilter);
*/
        throw "not supported";
      }
    }
  }
  
  /**
   * Check if the given name matches this filter. Match if name starts with this
   * filter's prefix. If this filter has the optional regexFilter then the
   * remaining components match the regexFilter regular expression.
   * For example, the following InterestFilter:
   *
   *    InterestFilter("/hello", "<world><>+")
   *
   * will match all Interests, whose name has the prefix `/hello` which is
   * followed by a component `world` and has at least one more component after it.
   * Examples:
   *
   *    /hello/world/!
   *    /hello/world/x/y/z
   *
   * Note that the regular expression will need to match all remaining components
   * (e.g., there are implicit heading `^` and trailing `$` symbols in the
   * regular expression).
   * @param {Name} name The name to check against this filter.
   * @return {bool} True if name matches this filter, otherwise false.
   */
  function doesMatch(name)
  {
    if (name.size() < prefix_.size())
      return false;

/*  TODO: Support regex. The constructor already rejected a regexFilter.
    if (hasRegexFilter()) {
      // Perform a prefix match and regular expression match for the remaining
      // components.
      if (!prefix_.match(name))
        return false;

      return null != NdnRegexMatcher.match
        (this.regexFilterPattern, name.getSubName(this.prefix.size()));
    }
    else
*/
      // Just perform a prefix match.
      return prefix_.match(name);
  }

  /**
   * Get the prefix given to the constructor.
   * @return {Name} The prefix Name which you should not modify.
   */
  function getPrefix() { return prefix_; }

  // TODO: hasRegexFilter
  // TODO: getRegexFilter
}
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
 * A ContentType specifies the content type in a MetaInfo object. If the
 * content type in the packet is not a recognized enum value, then we use
 * ContentType.OTHER_CODE and you can call MetaInfo.getOtherTypeCode(). We do
 * this to keep the recognized content type values independent of packet
 * encoding formats.
 */
enum ContentType {
  BLOB = 0,
  LINK = 1,
  KEY =  2,
  NACK = 3,
  OTHER_CODE = 0x7fff
}

/**
 * The MetaInfo class is used by Data and represents the fields of an NDN
 * MetaInfo. The MetaInfo type specifies the type of the content in the Data
 * packet (usually BLOB).
 */
class MetaInfo {
  type_ = 0;
  otherTypeCode_ = 0;
  freshnessPeriod_ = null;
  finalBlockId_ = null;
  changeCount_ = 0;

  /**
   * Create a new MetaInfo.
   * @param {MetaInfo} metaInfo (optional) If metaInfo is another MetaInfo
   * object, copy its values. Otherwise, set all fields to defaut values.
   */
  constructor(metaInfo = null)
  {
    if (metaInfo instanceof MetaInfo) {
      // The copy constructor.
      type_ = metaInfo.type_;
      otherTypeCode_ = metaInfo.otherTypeCode_;
      freshnessPeriod_ = metaInfo.freshnessPeriod_;
      finalBlockId_ = metaInfo.finalBlockId_;
    }
    else {
      type_ = ContentType.BLOB;
      otherTypeCode_ = -1;
      freshnessPeriod_ = null;
      finalBlockId_ = NameComponent();
    }
  }

  /**
   * Get the content type.
   * @return {integer} The content type as a ContentType enum value. If
   * this is ContentType.OTHER_CODE, then call getOtherTypeCode() to get the
   * unrecognized content type code.
   */
  function getType() { return type_; }

  /**
   * Get the content type code from the packet which is other than a recognized
   * ContentType enum value. This is only meaningful if getType() is
   * ContentType.OTHER_CODE.
   * @return {integer} The type code.
   */
  function getOtherTypeCode() { return otherTypeCode_; }

  /**
   * Get the freshness period.
   * @return {float} The freshness period in milliseconds, or null if not
   * specified.
   */
  function getFreshnessPeriod() { return freshnessPeriod_; }

  /**
   * Get the final block ID.
   * @return {NameComponent} The final block ID as a NameComponent. If the
   * NameComponent getValue().size() is 0, then the final block ID is not
   * specified.
   */
  function getFinalBlockId() { return finalBlockId_; }

  /**
   * Set the content type.
   * @param {integer} type The content type as a ContentType enum value. If
   * null, this uses ContentType.BLOB. If the packet's content type is not a
   * recognized ContentType enum value, use ContentType.OTHER_CODE and call
   * setOtherTypeCode().
   */
  function setType(type)
  {
    type_ = (type == null || type < 0) ? ContentType.BLOB : type;
    ++changeCount_;
  }

  /**
   * Set the packet’s content type code to use when the content type enum is
   * ContentType.OTHER_CODE. If the packet’s content type code is a recognized
   * enum value, just call setType().
   * @param {integer} otherTypeCode The packet’s unrecognized content type code,
   * which must be non-negative.
   */
  function setOtherTypeCode(otherTypeCode)
  {
    if (otherTypeCode < 0)
      throw "MetaInfo other type code must be non-negative";

    otherTypeCode_ = otherTypeCode;
    ++changeCount_;
  }

  /**
   * Set the freshness period.
   * @param {float} freshnessPeriod The freshness period in milliseconds, or null
   * for not specified.
   */
  function setFreshnessPeriod(freshnessPeriod)
  {
    if (freshnessPeriod == null || freshnessPeriod < 0)
      freshnessPeriod_ = null;
    else
      freshnessPeriod_ = (typeof freshnessPeriod == "float") ?
        freshnessPeriod : freshnessPeriod.tofloat();
    
    ++changeCount_;
  }

  /**
   * Set the final block ID.
   * @param {NameComponent} finalBlockId The final block ID as a NameComponent.
   * If not specified, set to a new default NameComponent(), or to a
   * NameComponent where getValue().size() is 0.
   */
  function setFinalBlockId(finalBlockId)
  {
    finalBlockId_ = finalBlockId instanceof NameComponent ?
      finalBlockId : NameComponent(finalBlockId);
    ++changeCount_;
  }

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
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
 * A GenericSignature extends Signature and holds the encoding bytes of the
 * SignatureInfo so that the application can process experimental signature
 * types. When decoding a packet, if the type of SignatureInfo is not
 * recognized, the library creates a GenericSignature.
 */
class GenericSignature {
  signature_ = null;
  signatureInfoEncoding_ = null;
  typeCode_ = null;
  changeCount_ = 0;

  /**
   * Create a new GenericSignature object, possibly copying values from another
   * object.
   * @param {GenericSignature} value (optional) If value is a GenericSignature,
   * copy its values.  If value is omitted, the signature is unspecified.
   */
  constructor(value = null)
  {
    if (value instanceof GenericSignature) {
      // The copy constructor.
      signature_ = value.signature_;
      signatureInfoEncoding_ = value.signatureInfoEncoding_;
      typeCode_ = value.typeCode_;
    }
    else {
      signature_ = Blob();
      signatureInfoEncoding_ = Blob();
      typeCode_ = null;
    }
  }

  /**
   * Get the data packet's signature bytes.
   * @return {Blob} The signature bytes. If not specified, the value isNull().
   */
  function getSignature() { return signature_; }

  /**
   * Get the bytes of the entire signature info encoding (including the type
   * code).
   * @return {Blob} The encoding bytes. If not specified, the value isNull().
   */
  function getSignatureInfoEncoding() { return signatureInfoEncoding_; }

  /**
   * Get the type code of the signature type. When wire decode calls
   * setSignatureInfoEncoding, it sets the type code. Note that the type code
   * is ignored during wire encode, which simply uses getSignatureInfoEncoding()
   * where the encoding already has the type code.
   * @return {integer} The type code, or null if not known.
   */
  function getTypeCode () { return typeCode_; }

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
   * Set the bytes of the entire signature info encoding (including the type
   * code).
   * @param {Blob} signatureInfoEncoding A Blob with the encoding bytes.
   * @param {integer} (optional) The type code of the signature type, or null if
   * not known. (When a GenericSignature is created by wire decoding, it sets
   * the typeCode.)
   */
  function setSignatureInfoEncoding(signatureInfoEncoding, typeCode = null)
  {
    signatureInfoEncoding_ = signatureInfoEncoding instanceof Blob ?
      signatureInfoEncoding : Blob(signatureInfoEncoding);
    typeCode_ = typeCode;
    ++changeCount_;
  }

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
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
 * An HmacWithSha256Signature holds the signature bits and other info
 * representing an HmacWithSha256 signature in a packet.
 */
class HmacWithSha256Signature {
  keyLocator_ = null;
  signature_ = null;
  changeCount_ = 0;

  /**
   * Create a new HmacWithSha256Signature object, possibly copying values from
   * another object.
   * @param {HmacWithSha256Signature} value (optional) If value is a
   * HmacWithSha256Signature, copy its values.  If value is omitted, the
   * keyLocator is the default with unspecified values and the signature is
   * unspecified.
   */
  constructor(value = null)
  {
    if (value instanceof HmacWithSha256Signature) {
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
   * Implement the clone operator to update this cloned object with values from
   * the original HmacWithSha256Signature which was cloned.
   * param {HmacWithSha256Signature} value The original HmacWithSha256Signature.
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
   * Implement the clone operator to update this cloned object with values from
   * the original Sha256WithRsaSignature which was cloned.
   * param {Sha256WithRsaSignature} value The original Sha256WithRsaSignature.
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
   * @param {Blob|Buffer|blob|Array<integer>} content The content bytes. If
   * content is not a Blob, then create a new Blob to copy the bytes (otherwise
   * take another pointer to the same Blob).
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
    return SignedBlob
      (result.encoding, result.signedPortionBeginOffset,
       result.signedPortionEndOffset);
  }

  /**
   * Decode the input using a particular wire format and update this Data.
   * @param {Blob|Buffer} input The buffer with the bytes to decode.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * decode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   */
  function wireDecode(input, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    local decodeBuffer;
    if (input instanceof Blob)
      wireFormat.decodeData(this, input.buf(), false);
    else
      wireFormat.decodeData(this, input, true);
    // To save memory, don't cache the encoding.
  }

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
    changed = metaInfo_.checkChanged() || changed;
    changed = signature_.checkChanged() || changed;
    if (changed)
      // A child object has changed, so update the change count.
      ++changeCount_;

    return changeCount_;
  }
}
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
 * The DerNodeType enum defines the known DER node types.
 */
enum DerNodeType {
  Eoc = 0,
  Boolean = 1,
  Integer = 2,
  BitString = 3,
  OctetString = 4,
  Null = 5,
  ObjectIdentifier = 6,
  ObjectDescriptor = 7,
  External = 40,
  Real = 9,
  Enumerated = 10,
  EmbeddedPdv = 43,
  Utf8String = 12,
  RelativeOid = 13,
  Sequence = 48,
  Set = 49,
  NumericString = 18,
  PrintableString = 19,
  T61String = 20,
  VideoTexString = 21,
  Ia5String = 22,
  UtcTime = 23,
  GeneralizedTime = 24,
  GraphicString = 25,
  VisibleString = 26,
  GeneralString = 27,
  UniversalString = 28,
  CharacterString = 29,
  BmpString = 30
}
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
 * DerNode implements the DER node types used in encoding/decoding DER-formatted
 * data.
 */
class DerNode {
  nodeType_ = 0;
  parent_ = null;
  header_ = null;
  payload_ = null;
  payloadPosition_ = 0;

  /**
   * Create a generic DER node with the given nodeType. This is a private
   * constructor used by one of the public DerNode subclasses defined below.
   * @param {integer} nodeType The DER type from the DerNodeType enum.
   */
  constructor(nodeType)
  {
    nodeType_ = nodeType;
    header_ = Buffer(0);
    payload_ = DynamicBlobArray(0);
  }

  /**
   * Return the number of bytes in the DER encoding.
   * @return {integer} The number of bytes.
   */
  function getSize()
  {
    return header_.len() + payloadPosition_;
  }

  /**
   * Encode the given size and update the header.
   * @param {integer} size
   */
  function encodeHeader(size)
  {
    local buffer = DynamicBlobArray(10);
    local bufferPosition = 0;
    buffer.array_[bufferPosition++] = nodeType_;
    if (size < 0)
      // We don't expect this to happen since this is an internal method and
      // always called with the non-negative size() of some buffer.
      throw "DER object has negative length";
    else if (size <= 127)
      buffer.array_[bufferPosition++] = size & 0xff;
    else {
      local tempBuf = DynamicBlobArray(10);
      // We encode backwards from the back.

      local val = size;
      local n = 0;
      while (val != 0) {
        ++n;
        tempBuf.ensureLengthFromBack(n);
        tempBuf.array_[tempBuf.array_.len() - n] = val & 0xff;
        val = val >> 8;
      }
      local nTempBufBytes = n + 1;
      tempBuf.ensureLengthFromBack(nTempBufBytes);
      tempBuf.array_[tempBuf.array_.len() - nTempBufBytes] = ((1<<7) | n) & 0xff;

      buffer.copy(Buffer.from
        (tempBuf.array_, tempBuf.array_.len() - nTempBufBytes), bufferPosition);
      bufferPosition += nTempBufBytes;
    }

    header_ = Buffer.from(buffer.array_, 0, bufferPosition);
  }

  /**
   * Extract the header from an input buffer and return the size.
   * @param {Buffer} inputBuf The input buffer to read from.
   * @param {integer} startIdx The offset into the buffer.
   * @return {integer} The parsed size in the header.
   */
  function decodeHeader(inputBuf, startIdx)
  {
    local idx = startIdx;

    // Use Buffer.get to avoid using the metamethod.
    local nodeType = inputBuf.get(idx) & 0xff;
    idx += 1;

    nodeType_ = nodeType;

    local sizeLen = inputBuf.get(idx) & 0xff;
    idx += 1;

    local header = DynamicBlobArray(10);
    local headerPosition = 0;
    header.array_[headerPosition++] = nodeType;
    header.array_[headerPosition++] = sizeLen;

    local size = sizeLen;
    local isLongFormat = (sizeLen & (1 << 7)) != 0;
    if (isLongFormat) {
      local lenCount = sizeLen & ((1<<7) - 1);
      size = 0;
      while (lenCount > 0) {
        local b = inputBuf.get(idx);
        idx += 1;
        header.ensureLength(headerPosition + 1);
        header.array_[headerPosition++] = b;
        size = 256 * size + (b & 0xff);
        lenCount -= 1;
      }
    }

    header_ = Buffer.from(header.array_, 0, headerPosition);
    return size;
  }

  // TODO: encode

  /**
   * Decode and store the data from an input buffer.
   * @param {Buffer} inputBuf The input buffer to read from. This reads from
   * startIdx (regardless of the buffer's position) and does not change the
   * position.
   * @param {integer} startIdx The offset into the buffer.
   */
  function decode(inputBuf, startIdx)
  {
    local idx = startIdx;
    local payloadSize = decodeHeader(inputBuf, idx);
    local skipBytes = header_.len();
    if (payloadSize > 0) {
      idx += skipBytes;
      payloadAppend(inputBuf.slice(idx, idx + payloadSize));
    }
  }

  /**
   * Copy buffer to payload_ at payloadPosition_ and update payloadPosition_.
   * @param {Buffer} buffer The buffer to copy.
   */
  function payloadAppend(buffer)
  {
    payloadPosition_ = payload_.copy(buffer, payloadPosition_);
  }

  /**
   * Parse the data from the input buffer recursively and return the root as an
   * object of a subclass of DerNode.
   * @param {Buffer} inputBuf The input buffer to read from.
   * @param {integer} startIdx (optional) The offset into the buffer. If
   * omitted, use 0.
   * @return {DerNode} An object of a subclass of DerNode.
   */
  static function parse(inputBuf, startIdx = 0)
  {
    // Use Buffer.get to avoid using the metamethod.
    local nodeType = inputBuf.get(startIdx) & 0xff;
    // Don't increment idx. We're just peeking.

    local newNode;
    if (nodeType == DerNodeType.Boolean)
      newNode = DerNode_DerBoolean();
    else if (nodeType == DerNodeType.Integer)
      newNode = DerNode_DerInteger();
    else if (nodeType == DerNodeType.BitString)
      newNode = DerNode_DerBitString();
    else if (nodeType == DerNodeType.OctetString)
      newNode = DerNode_DerOctetString();
    else if (nodeType == DerNodeType.Null)
      newNode = DerNode_DerNull();
    else if (nodeType == DerNodeType.ObjectIdentifier)
      newNode = DerNode_DerOid();
    else if (nodeType == DerNodeType.Sequence)
      newNode = DerNode_DerSequence();
    else if (nodeType == DerNodeType.PrintableString)
      newNode = DerNode_DerPrintableString();
    else if (nodeType == DerNodeType.GeneralizedTime)
      newNode = DerNode_DerGeneralizedTime();
    else
      throw "Unimplemented DER type " + nodeType;

    newNode.decode(inputBuf, startIdx);
    return newNode;
  }

  /**
   * Convert the encoded data to a standard representation. Overridden by some
   * subclasses (e.g. DerBoolean).
   * @return {Blob} The encoded data as a Blob.
   */
  function toVal() { return encode(); }

  /**
   * Get a copy of the payload bytes.
   * @return {Blob} A copy of the payload.
   */
  function getPayload()
  {
    payload_.array_.seek(0);
    return Blob(payload_.array_.readblob(payloadPosition_), false);
  }

  /**
   * If this object is a DerNode_DerSequence, get the children of this node.
   * Otherwise, throw an exception. (DerSequence overrides to implement this
   * method.)
   * @return {Array<DerNode>} The children as an array of DerNode.
   * @throws string if this object is not a Dernode_DerSequence.
   */
  function getChildren() { throw "not implemented"; }

  /**
   * Check that index is in bounds for the children list, return children[index].
   * @param {Array<DerNode>} children The list of DerNode, usually returned by
   * another call to getChildren.
   * @param {integer} index The index of the children.
   * @return {DerNode_DerSequence} children[index].
   * @throws string if index is out of bounds or if children[index] is not a
   * DerNode_DerSequence.
   */
  static function getSequence(children, index)
  {
    if (index < 0 || index >= children.len())
      throw "Child index is out of bounds";

    if (!(children[index] instanceof DerNode_DerSequence))
      throw "Child DerNode is not a DerSequence";

    return children[index];
  }
}

/**
 * A DerNode_DerStructure extends DerNode to hold other DerNodes.
 */
class DerNode_DerStructure extends DerNode {
  childChanged_ = false;
  nodeList_ = null;
  size_ = 0;

  /**
   * Create a DerNode_DerStructure with the given nodeType. This is a private
   * constructor. To create an object, use DerNode_DerSequence.
   * @param {integer} nodeType One of the defined DER DerNodeType constants.
   */
  constructor(nodeType)
  {
    // Call the base constructor.
    base.constructor(nodeType);

    nodeList_ = []; // Of DerNode.
  }

  /**
   * Get the total length of the encoding, including children.
   * @return {integer} The total (header + payload) length.
   */
  function getSize()
  {
    if (childChanged_) {
      updateSize();
      childChanged_ = false;
    }

    encodeHeader(size_);
    return size_ + header_.len();
  };

  /**
   * Get the children of this node.
   * @return {Array<DerNode>} The children as an array of DerNode.
   */
  function getChildren() { return nodeList_; }

  function updateSize()
  {
    local newSize = 0;

    for (local i = 0; i < nodeList_.len(); ++i) {
      local n = nodeList_[i];
      newSize += n.getSize();
    }

    size_ = newSize;
    childChanged_ = false;
  };

  /**
   * Add a child to this node.
   * @param {DerNode} node The child node to add.
   * @param {bool} (optional) notifyParent Set to true to cause any containing
   * nodes to update their size.  If omitted, use false.
   */
  function addChild(node, notifyParent = false)
  {
    node.parent_ = this;
    nodeList_.append(node);

    if (notifyParent) {
      if (parent_ != null)
        parent_.setChildChanged();
    }

    childChanged_ = true;
  }

  /**
   * Mark the child list as dirty, so that we update size when necessary.
   */
  function setChildChanged()
  {
    if (parent_ != null)
      parent_.setChildChanged();
    childChanged_ = true;
  }

  // TODO: encode

  /**
   * Override the base decode to decode and store the data from an input
   * buffer. Recursively populates child nodes.
   * @param {Buffer} inputBuf The input buffer to read from.
   * @param {integer} startIdx The offset into the buffer.
   */
  function decode(inputBuf, startIdx)
  {
    local idx = startIdx;
    size_ = decodeHeader(inputBuf, idx);
    idx += header_.len();

    local accSize = 0;
    while (accSize < size_) {
      local node = DerNode.parse(inputBuf, idx);
      local size = node.getSize();
      idx += size;
      accSize += size;
      addChild(node, false);
    }
  }
}

////////
// Now for all the node types...
////////

/**
 * A DerNode_DerByteString extends DerNode to handle byte strings.
 */
class DerNode_DerByteString extends DerNode {
  /**
   * Create a DerNode_DerByteString with the given inputData and nodeType. This
   * is a private constructor used by one of the public subclasses such as
   * DerOctetString or DerPrintableString.
   * @param {Buffer} inputData An input buffer containing the string to encode.
   * @param {integer} nodeType One of the defined DER DerNodeType constants.
   */
  constructor(inputData = null, nodeType = null)
  {
    // Call the base constructor.
    base.constructor(nodeType);

    if (inputData != null) {
      payloadAppend(inputData);
      encodeHeader(inputData.len());
    }
  }

  /**
   * Override to return just the byte string.
   * @return {Blob} The byte string as a copy of the payload buffer.
   */
  function toVal() { return getPayload(); }
}

// TODO: DerNode_DerBoolean

/**
 * DerNode_DerInteger extends DerNode to encode an integer value.
 */
class DerNode_DerInteger extends DerNode {
  /**
   * Create a DerNode_DerInteger for the value.
   * @param {integer|Buffer} integer The value to encode. If integer is a Buffer
   * byte array of a positive integer, you must ensure that the first byte is
   * less than 0x80.
   */
  constructor(integer = null)
  {
    // Call the base constructor.
    base.constructor(DerNodeType.Integer);

    if (integer != null) {
      if (Buffer.isBuffer(integer)) {
        if (integer.len() > 0 && integer.get(0) >= 0x80)
          throw "Negative integers are not currently supported";

        if (integer.len() == 0)
          payloadAppend(Buffer([0]));
        else
          payloadAppend(integer);
      }
      else {
        if (integer < 0)
          throw "Negative integers are not currently supported";

        // Convert the integer to bytes the easy/slow way.
        local temp = DynamicBlobArray(10);
        // We encode backwards from the back.
        local length = 0;
        while (true) {
          ++length;
          temp.ensureLengthFromBack(length);
          temp.array_[temp.array_.len() - length] = integer & 0xff;
          integer = integer >> 8;

          if (integer <= 0)
            // We check for 0 at the end so we encode one byte if it is 0.
            break;
        }

        if (temp.array_[temp.array_.len() - length] >= 0x80) {
          // Make it a non-negative integer.
          ++length;
          temp.ensureLengthFromBack(length);
          temp.array_[temp.array_.len() - length] = 0;
        }

        payloadAppend(Buffer.from(temp.array_, temp.array_.len() - length));
      }

      encodeHeader(payloadPosition_);
    }
  }

  function toVal()
  {
    if (payloadPosition_ > 0 && payload_.array[0] >= 0x80)
      throw "Negative integers are not currently supported";

    local result = 0;
    for (local i = 0; i < payloadPosition_; ++i) {
      result = result << 8;
      result += payload_.array_[i];
    }

    return result;
  }

  /**
   * Return an array of bytes, removing the leading zero, if any.
   * @return {Array<integer>} The array of bytes.
   */
  function toUnsignedArray()
  {
    local iFrom = (payloadPosition_ > 1 && payload_.array_[0] == 0) ? 1 : 0;
    local result = array(payloadPosition_ - iFrom);
    local iTo = 0;
    while (iFrom < payloadPosition_)
      result[iTo++] = payload_.array_[iFrom++];

    return result;
  }
}

/**
 * A DerNode_DerBitString extends DerNode to handle a bit string.
 */
class DerNode_DerBitString extends DerNode {
  /**
   * Create a DerBitString with the given padding and inputBuf.
   * @param {Buffer} inputBuf An input buffer containing the bit octets to encode.
   * @param {integer} paddingLen The number of bits of padding at the end of the
   * bit string. Should be less than 8.
   */
  constructor(inputBuf = null, paddingLen = null)
  {
    // Call the base constructor.
    base.constructor(DerNodeType.BitString);

    if (inputBuf != null) {
      payload_.ensureLength(payloadPosition_ + 1);
      payload_.array_[payloadPosition_++] = paddingLen & 0xff;
      payloadAppend(inputBuf);
      encodeHeader(payloadPosition_);
    }
  }
}

/**
 * DerNode_DerOctetString extends DerNode_DerByteString to encode a string of
 * bytes.
 */
class DerNode_DerOctetString extends DerNode_DerByteString {
  /**
   * Create a DerOctetString for the inputData.
   * @param {Buffer} inputData An input buffer containing the string to encode.
   */
  constructor(inputData = null)
  {
    // Call the base constructor.
    base.constructor(inputData, DerNodeType.OctetString);
  }
}

/**
 * A DerNode_DerNull extends DerNode to encode a null value.
 */
class DerNode_DerNull extends DerNode {
  /**
   * Create a DerNull.
   */
  constructor()
  {
    // Call the base constructor.
    base.constructor(DerNodeType.Null);

    encodeHeader(0);
  }
}

/**
 * A DerNode_DerOid extends DerNode to represent an object identifier.
 */
class DerNode_DerOid extends DerNode {
  /**
   * Create a DerOid with the given object identifier. The object identifier
   * string must begin with 0,1, or 2 and must contain at least 2 digits.
   * @param {string|OID} oid The OID string or OID object to encode.
   */
  constructor(oid = null)
  {
    // Call the base constructor.
    base.constructor(DerNodeType.ObjectIdentifier);

    if (oid != null) {
      // TODO: Implement oid decoding.
      throw "not implemented";
    }
  }

  // TODO: prepareEncoding
  // TODO: encode128
  // TODO: decode128
  // TODO: toVal
}

/**
 * A DerNode_DerSequence extends DerNode_DerStructure to contains an ordered
 * sequence of other nodes.
 */
class DerNode_DerSequence extends DerNode_DerStructure {
  /**
   * Create a DerSequence.
   */
  constructor()
  {
    // Call the base constructor.
    base.constructor(DerNodeType.Sequence);
  }
}

// TODO: DerNode_DerPrintableString
// TODO: DerNode_DerGeneralizedTime
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

enum Tlv {
  Interest =         5,
  Data =             6,
  Name =             7,
  ImplicitSha256DigestComponent = 1,
  NameComponent =    8,
  Selectors =        9,
  Nonce =            10,
  // <Unassigned> =      11,
  InterestLifetime = 12,
  MinSuffixComponents = 13,
  MaxSuffixComponents = 14,
  PublisherPublicKeyLocator = 15,
  Exclude =          16,
  ChildSelector =    17,
  MustBeFresh =      18,
  Any =              19,
  MetaInfo =         20,
  Content =          21,
  SignatureInfo =    22,
  SignatureValue =   23,
  ContentType =      24,
  FreshnessPeriod =  25,
  FinalBlockId =     26,
  SignatureType =    27,
  KeyLocator =       28,
  KeyLocatorDigest = 29,
  SelectedDelegation = 32,
  FaceInstance =     128,
  ForwardingEntry =  129,
  StatusResponse =   130,
  Action =           131,
  FaceID =           132,
  IPProto =          133,
  Host =             134,
  Port =             135,
  MulticastInterface = 136,
  MulticastTTL =     137,
  ForwardingFlags =  138,
  StatusCode =       139,
  StatusText =       140,

  SignatureType_DigestSha256 = 0,
  SignatureType_SignatureSha256WithRsa = 1,
  SignatureType_SignatureSha256WithEcdsa = 3,
  SignatureType_SignatureHmacWithSha256 = 4,

  ContentType_Default = 0,
  ContentType_Link =    1,
  ContentType_Key =     2,

  NfdCommand_ControlResponse = 101,
  NfdCommand_StatusCode =      102,
  NfdCommand_StatusText =      103,

  ControlParameters_ControlParameters =   104,
  ControlParameters_FaceId =              105,
  ControlParameters_Uri =                 114,
  ControlParameters_LocalControlFeature = 110,
  ControlParameters_Origin =              111,
  ControlParameters_Cost =                106,
  ControlParameters_Flags =               108,
  ControlParameters_Strategy =            107,
  ControlParameters_ExpirationPeriod =    109,

  LpPacket_LpPacket =        100,
  LpPacket_Fragment =         80,
  LpPacket_Sequence =         81,
  LpPacket_FragIndex =        82,
  LpPacket_FragCount =        83,
  LpPacket_Nack =            800,
  LpPacket_NackReason =      801,
  LpPacket_NextHopFaceId =   816,
  LpPacket_IncomingFaceId =  817,
  LpPacket_CachePolicy =     820,
  LpPacket_CachePolicyType = 821,
  LpPacket_IGNORE_MIN =      800,
  LpPacket_IGNORE_MAX =      959,

  Link_Preference = 30,
  Link_Delegation = 31,

  Encrypt_EncryptedContent = 130,
  Encrypt_EncryptionAlgorithm = 131,
  Encrypt_EncryptedPayload = 132,
  Encrypt_InitialVector = 133,

  // For RepetitiveInterval.
  Encrypt_StartDate = 134,
  Encrypt_EndDate = 135,
  Encrypt_IntervalStartHour = 136,
  Encrypt_IntervalEndHour = 137,
  Encrypt_NRepeats = 138,
  Encrypt_RepeatUnit = 139,
  Encrypt_RepetitiveInterval = 140,

  // For Schedule.
  Encrypt_WhiteIntervalList = 141,
  Encrypt_BlackIntervalList = 142,
  Encrypt_Schedule = 143
}
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
 * A TlvDecoder has methods to decode an input according to NDN-TLV.
 */
class TlvDecoder {
  input_ = null;
  offset_ = 0;

  /**
   * Create a new TlvDecoder for decoding the input in the NDN-TLV wire format.
   * @param {Buffer} input The Buffer with the bytes to decode.
   */
  constructor(input)
  {
    input_ = input;
  }

  /**
   * Decode VAR-NUMBER in NDN-TLV and return it. Update the offset.
   * @return {integer} The decoded VAR-NUMBER.
   */
  function readVarNumber()
  {
    // Use Buffer.get to avoid using the metamethod.
    local firstOctet = input_.get(offset_);
    offset_ += 1;
    if (firstOctet < 253)
      return firstOctet;
    else
      return readExtendedVarNumber_(firstOctet);
  }

  /**
   * A private method to do the work of readVarNumber, given the firstOctet
   * which is >= 253.
   * @param {integer} firstOctet The first octet which is >= 253, used to decode
   * the remaining bytes.
   * @return {integer} The decoded VAR-NUMBER.
   * @throws string if the VAR-NUMBER is 64-bit or read past the end of the
   * input.
   */
  function readExtendedVarNumber_(firstOctet)
  {
    local result;
    // This is a private function so we know firstOctet >= 253.
    if (firstOctet == 253) {
      // Use Buffer.get to avoid using the metamethod.
      result = ((input_.get(offset_) << 8) +
                 input_.get(offset_ + 1));
      offset_ += 2;
    }
    else if (firstOctet == 254) {
      // Use abs because << 24 can set the high bit of the 32-bit int making it negative.
      result = (math.abs(input_.get(offset_) << 24) +
                        (input_.get(offset_ + 1) << 16) +
                        (input_.get(offset_ + 2) << 8) +
                         input_.get(offset_ + 3));
      offset_ += 4;
    }
    else
      throw "Decoding a 64-bit VAR-NUMBER is not supported";

    return result;
  }

  /**
   * Decode the type and length from this's input starting at offset, expecting
   * the type to be expectedType and return the length. Update offset.  Also make
   * sure the decoded length does not exceed the number of bytes remaining in the
   * input.
   * @param {integer} expectedType The expected type.
   * @return {integer} The length of the TLV.
   * @throws string if (did not get the expected TLV type or the TLV length
   * exceeds the buffer length.
   */
  function readTypeAndLength(expectedType)
  {
    local type = readVarNumber();
    if (type != expectedType)
      throw "Did not get the expected TLV type";

    local length = readVarNumber();
    if (offset_ + length > input_.len())
      throw "TLV length exceeds the buffer length";

    return length;
  }

  /**
   * Decode the type and length from the input starting at offset, expecting the
   * type to be expectedType.  Update offset.  Also make sure the decoded length
   * does not exceed the number of bytes remaining in the input. Return the offset
   * of the end of this parent TLV, which is used in decoding optional nested
   * TLVs. After reading all nested TLVs, call finishNestedTlvs.
   * @param {integer} expectedType The expected type.
   * @return {integer} The offset of the end of the parent TLV.
   * @throws string if did not get the expected TLV type or the TLV length
   * exceeds the buffer length.
   */
  function readNestedTlvsStart(expectedType)
  {
    return readTypeAndLength(expectedType) + offset_;
  }

  /**
   * Call this after reading all nested TLVs to skip any remaining unrecognized
   * TLVs and to check if the offset after the final nested TLV matches the
   * endOffset returned by readNestedTlvsStart.
   * @param {integer} endOffset The offset of the end of the parent TLV, returned
   * by readNestedTlvsStart.
   * @throws string if the TLV length does not equal the total length of the
   * nested TLVs.
   */
  function finishNestedTlvs(endOffset)
  {
    // We expect offset to be endOffset, so check this first.
    if (offset_ == endOffset)
      return;

    // Skip remaining TLVs.
    while (offset_ < endOffset) {
      // Skip the type VAR-NUMBER.
      readVarNumber();
      // Read the length and update offset.
      local length = readVarNumber();
      offset_ += length;

      if (offset_ > input_.len())
        throw "TLV length exceeds the buffer length";
    }

    if (offset_ != endOffset)
      throw "TLV length does not equal the total length of the nested TLVs";
  }

  /**
   * Decode the type from this's input starting at offset, and if it is the
   * expectedType, then return true, else false.  However, if this's offset is
   * greater than or equal to endOffset, then return false and don't try to read
   * the type. Do not update offset.
   * @param {integer} expectedType The expected type.
   * @param {integer} endOffset The offset of the end of the parent TLV, returned
   * by readNestedTlvsStart.
   * @return {bool} true if the type of the next TLV is the expectedType,
   * otherwise false.
   */
  function peekType(expectedType, endOffset)
  {
    if (offset_ >= endOffset)
      // No more sub TLVs to look at.
      return false;
    else {
      local saveOffset = offset_;
      local type = readVarNumber();
      // Restore offset.
      offset_ = saveOffset;

      return type == expectedType;
    }
  }

  /**
   * Decode a non-negative integer in NDN-TLV and return it. Update offset by
   * length.
   * @param {integer} length The number of bytes in the encoded integer.
   * @return {integer} The integer.
   * @throws string if the VAR-NUMBER is 64-bit or if length is an invalid
   * length for a TLV non-negative integer.
   */
  function readNonNegativeInteger(length)
  {
    local result;
    if (length == 1)
      // Use Buffer.get to avoid using the metamethod.
      result = input_.get(offset_);
    else if (length == 2)
      result = ((input_.get(offset_) << 8) +
                 input_.get(offset_ + 1));
    else if (length == 4)
      // Use abs because << 24 can set the high bit of the 32-bit int making it negative.
      result = (math.abs(input_.get(offset_) << 24) +
                        (input_.get(offset_ + 1) << 16) +
                        (input_.get(offset_ + 2) << 8) +
                         input_.get(offset_ + 3));
    else if (length == 8)
      throw "Decoding a 64-bit VAR-NUMBER is not supported";
    else
      throw "Invalid length for a TLV nonNegativeInteger";

    offset_ += length;
    return result;
  }

  /**
   * Decode the type and length from this's input starting at offset, expecting
   * the type to be expectedType. Then decode a non-negative integer in NDN-TLV
   * and return it.  Update offset.
   * @param {integer} expectedType The expected type.
   * @return {integer} The integer.
   * @throws string if did not get the expected TLV type or can't decode the
   * value.
   */
  function readNonNegativeIntegerTlv(expectedType)
  {
    local length = readTypeAndLength(expectedType);
    return readNonNegativeInteger(length);
  }
  
  /**
   * Peek at the next TLV, and if it has the expectedType then call
   * readNonNegativeIntegerTlv and return the integer.  Otherwise, return null.
   * However, if this's offset is greater than or equal to endOffset, then return
   * null and don't try to read the type.
   * @param {integer} expectedType The expected type.
   * @param {integer} endOffset The offset of the end of the parent TLV, returned
   * by readNestedTlvsStart.
   * @return {integer} The integer or null if the next TLV doesn't have the
   * expected type.
   */
  function readOptionalNonNegativeIntegerTlv(expectedType, endOffset)
  {
    if (peekType(expectedType, endOffset))
      return readNonNegativeIntegerTlv(expectedType);
    else
      return null;
  }

  /**
   * Decode the type and length from this's input starting at offset, expecting
   * the type to be expectedType. Then return an array of the bytes in the value.
   * Update offset.
   * @param {integer} expectedType The expected type.
   * @return {Buffer} The bytes in the value as a Buffer. This is a slice onto a
   * portion of the input Buffer.
   * @throws string if did not get the expected TLV type.
   */
  function readBlobTlv(expectedType)
  {
    local length = readTypeAndLength(expectedType);
    local result = getSlice(offset_, offset_ + length);

    // readTypeAndLength already checked if length exceeds the input buffer.
    offset_ += length;
    return result;
  }

  /**
   * Peek at the next TLV, and if it has the expectedType then call readBlobTlv
   * and return the value.  Otherwise, return null. However, if this's offset is
   * greater than or equal to endOffset, then return null and don't try to read
   * the type.
   * @param {integer} expectedType The expected type.
   * @param {integer} endOffset The offset of the end of the parent TLV, returned
   * by readNestedTlvsStart.
   * @return {Buffer} The bytes in the value as Buffer or null if the next TLV
   * doesn't have the expected type. This is a slice onto a portion of the input
   * Buffer.
   */
  function readOptionalBlobTlv(expectedType, endOffset)
  {
    if (peekType(expectedType, endOffset))
      return readBlobTlv(expectedType);
    else
      return null;
  }

  /**
   * Peek at the next TLV, and if it has the expectedType then read a type and
   * value, ignoring the value, and return true. Otherwise, return false.
   * However, if this's offset is greater than or equal to endOffset, then return
   * false and don't try to read the type.
   * @param {integer} expectedType The expected type.
   * @param {integer} endOffset The offset of the end of the parent TLV, returned
   * by readNestedTlvsStart.
   * @return {bool} true, or else false if the next TLV doesn't have the
   * expected type.
   */
  function readBooleanTlv(expectedType, endOffset)
  {
    if (peekType(expectedType, endOffset)) {
      local length = readTypeAndLength(expectedType);
      // We expect the length to be 0, but update offset anyway.
      offset_ += length;
      return true;
    }
    else
      return false;
  }

  /**
   * Get the offset into the input, used for the next read.
   * @return {integer} The offset.
   */
  function getOffset() { return offset_; }

  /**
   * Set the offset into the input, used for the next read.
   * @param {integer} offset The new offset.
   */
  function seek(offset) { offset_ = offset; }

  /**
   * Return a slice of the input for the given offset range.
   * @param {integer} beginOffset The offset in the input of the beginning of
   * the slice.
   * @param {integer} endOffset The offset in the input of the end of the slice
   * (not inclusive).
   * @return {Buffer} The bytes in the value as a Buffer. This is a slice onto a
   * portion of the input Buffer.
   */
  function getSlice(beginOffset, endOffset)
  {
    return input_.slice(beginOffset, endOffset);
  }
}
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
 * A TlvEncoder holds an output buffer and has methods to output NDN-TLV.
 */
class TlvEncoder {
  output_ = null;
  // length is the number of bytes that have been written to the back of
  // output_.array_.
  length_ = 0;

  /**
   * Create a new TlvEncoder to use a DynamicBlobArray with the initialSize.
   * When done, you should call getOutput().
   * @param initialSize {integer} (optional) The initial size of output buffer.
   * If omitted, use a default value.
   */
  constructor(initialSize = 16)
  {
    output_ = DynamicBlobArray(initialSize);
  }

  /**
   * Get the number of bytes that have been written to the output.  You can
   * save this number, write sub TLVs, then subtract the new length from this
   * to get the total length of the sub TLVs.
   * @return {integer} The number of bytes that have been written to the output.
   */
  function getLength() { return length_; }

  /**
   * Encode varNumber as a VAR-NUMBER in NDN-TLV and write it to the output just
    * before array_.len() from the back. Advance length_.
   * @param {integer} varNumber The number to encode.
   */
  function writeVarNumber(varNumber)
  {
    if (varNumber < 0)
      throw "TlvEncoder: Can't have a negative VAR-NUMBER";

    if (varNumber < 253) {
      length_ += 1;
      output_.ensureLengthFromBack(length_);
      output_.array_[output_.array_.len() - length_] = varNumber & 0xff;
    }
    else if (varNumber <= 0xffff) {
      length_ += 3;
      output_.ensureLengthFromBack(length_);
      local array = output_.array_;
      local offset = array.len() - length_;
      array[offset] = 253;
      array[offset + 1] = (varNumber >> 8) & 0xff;
      array[offset + 2] = varNumber & 0xff;
    }
    else {
      length_ += 5;
      output_.ensureLengthFromBack(length_);
      local array = array;
      local offset = array.len() - length_;
      array[offset] = 254;
      array[offset + 1] = (varNumber >> 24) & 0xff;
      array[offset + 2] = (varNumber >> 16) & 0xff;
      array[offset + 3] = (varNumber >> 8) & 0xff;
      array[offset + 4] = varNumber & 0xff;
    }
    // TODO: Can Squirrel have a 64-bit integer?
  }

  /**
   * Write the type and length to the output just before array_.len() from the
   * back. Advance length_.
   * @param {integer} type the type of the TLV.
   * @param {integer} length The length of the TLV.
   */
  function writeTypeAndLength(type, length)
  {
    // Write backwards.
    writeVarNumber(length);
    writeVarNumber(type);
  }

  /**
   * Encode value as a non-negative integer in NDN-TLV and write it to the 
   * output just before array_.len() from the back. This does not write a type
   * or length for the value. Advance length_.
   * @param {integer} value The integer to encode.
   */
  function writeNonNegativeInteger(value)
  {
    if (value < 0)
      throw "TlvEncoder: Non-negative integer cannot be negative";

    if (value <= 0xff) {
      length_ += 1;
      output_.ensureLengthFromBack(length_);
      output_.array_[output_.array_.len() - length_] = value & 0xff;
    }
    else if (value <= 0xffff) {
      length_ += 2;
      output_.ensureLengthFromBack(length_);
      local array = output_.array_;
      local offset = array.len() - length_;
      array[offset]     = (value >> 8) & 0xff;
      array[offset + 1] = value & 0xff;
    }
    else {
      length_ += 4;
      output_.ensureLengthFromBack(length_);
      local array = output_.array_;
      local offset = array.len() - length_;
      array[offset]     = (value >> 24) & 0xff;
      array[offset + 1] = (value >> 16) & 0xff;
      array[offset + 2] = (value >> 8) & 0xff;
      array[offset + 3] = value & 0xff;
    }
    // TODO: Can Squirrel have a 64-bit integer?
  }

  /**
   * Write the type, then the length of the encoded value then encode value as a
   * non-negative integer and write it to the output just before array_.len() 
   * from the back. Advance length_. (If you want to just write the non-negative
   * integer, use writeNonNegativeInteger.)
   * @param {integer} type the type of the TLV.
   * @param {integer} value The integer to encode.
   */
  function writeNonNegativeIntegerTlv(type, value)
  {
    // Write backwards.
    local saveLength = length_;
    writeNonNegativeInteger(value);
    writeTypeAndLength(type, length_ - saveLength);
  }

  /**
   * If value is negative or null then do nothing, otherwise call
   * writeNonNegativeIntegerTlv.
   * @param {integer} type the type of the TLV.
   * @param {integer} value Negative or null for none, otherwise the integer to
   * encode.
   */
  function writeOptionalNonNegativeIntegerTlv(type, value)
  {
    if (value != null && value >= 0)
      return writeNonNegativeIntegerTlv(type, value);
  }

  /**
   * If value is negative or null then do nothing, otherwise call
   * writeNonNegativeIntegerTlv.
   * @param {integer} type the type of the TLV.
   * @param {float} value Negative or null for none, otherwise use round(value).
   */
  function writeOptionalNonNegativeIntegerTlvFromFloat(type, value)
  {
    if (value != null && value >= 0.0)
      // math doesn't have round, so use floor.
      return writeNonNegativeIntegerTlv(type, math.floor(value + 0.5).tointeger());
  }

  /**
   * Copy the bytes of the buffer to the output just before array_.len() from 
   * the back. Advance length_. Note that this does not encode a type and
   * length; for that see writeBlobTlv.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   */
  function writeBuffer(buffer)
  {
    if (buffer == null)
      return;

    length_ += buffer.len();
    output_.copyFromBack(buffer, length_);
  }

  /**
   * Write the type, then the length of the blob then the blob value to the 
   * output just before array_.len() from the back. Advance length_.
   * @param {integer} type the type of the TLV.
   * @param {Buffer} value A Buffer with the bytes to copy.
   */
  function writeBlobTlv(type, value)
  {
    if (value == null) {
      writeTypeAndLength(type, 0);
      return;
    }

    // Write backwards.
    writeBuffer(value);
    writeTypeAndLength(type, value.len());
  }

  /**
   * If value is null or 0 length then do nothing, otherwise call writeBlobTlv.
   * @param {integer} type the type of the TLV.
   * @param {Buffer} value A Buffer with the bytes to copy.
   */
  function writeOptionalBlobTlv(type, value)
  {
    if (value != null && value.len() > 0)
      writeBlobTlv(type, value);
  }

  /**
   * Transfer the encoding bytes to a Blob and return the Blob. Set this
   * object's output array to null to prevent further use.
   * @return {Blob} A new NDN Blob with the output.
   */
  function finish()
  {
    return output_.finishFromBack(length_);
  }
}
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

const TlvStructureDecoder_READ_TYPE =         0;
const TlvStructureDecoder_READ_TYPE_BYTES =   1;
const TlvStructureDecoder_READ_LENGTH =       2;
const TlvStructureDecoder_READ_LENGTH_BYTES = 3;
const TlvStructureDecoder_READ_VALUE_BYTES =  4;

/**
 * A TlvStructureDecoder finds the end of an NDN-TLV element, even if the
 * element is supplied in parts.
 */
class TlvStructureDecoder {
  gotElementEnd_ = false;
  offset_ = 0;
  state_ = TlvStructureDecoder_READ_TYPE;
  headerLength_ = 0;
  useHeaderBuffer_ = false;
  // 8 bytes is enough to hold the extended bytes in the length encoding
  // where it is an 8-byte number.
  headerBuffer_ = null;
  nBytesToRead_ = 0;
  firstOctet_ = 0;

  constructor() {
    headerBuffer_ = Buffer(8);
  }

  /**
   * Continue scanning input starting from offset_ to find the element end. If the
   * end of the element which started at offset 0 is found, this returns true and
   * getOffset() is the length of the element. Otherwise, this returns false which
   * means you should read more into input and call again.
   * @param {Buffer} input The input buffer. You have to pass in input each time
   * because the buffer could be reallocated.
   * @return {bool} True if found the element end, false if not.
   */
  function findElementEnd(input)
  {
    if (gotElementEnd_)
      // Someone is calling when we already got the end.
      return true;

    local decoder = TlvDecoder(input);

    while (true) {
      if (offset_ >= input.len())
        // All the cases assume we have some input. Return and wait for more.
        return false;

      if (state_ == TlvStructureDecoder_READ_TYPE) {
        // Use Buffer.get to avoid using the metamethod.
        local firstOctet = input.get(offset_);
        offset_ += 1;
        if (firstOctet < 253)
          // The value is simple, so we can skip straight to reading the length.
          state_ = TlvStructureDecoder_READ_LENGTH;
        else {
          // Set up to skip the type bytes.
          if (firstOctet == 253)
            nBytesToRead_ = 2;
          else if (firstOctet == 254)
            nBytesToRead_ = 4;
          else
            // value == 255.
            nBytesToRead_ = 8;

          state_ = TlvStructureDecoder_READ_TYPE_BYTES;
        }
      }
      else if (state_ == TlvStructureDecoder_READ_TYPE_BYTES) {
        local nRemainingBytes = input.len() - offset_;
        if (nRemainingBytes < nBytesToRead_) {
          // Need more.
          offset_ += nRemainingBytes;
          nBytesToRead_ -= nRemainingBytes;
          return false;
        }

        // Got the type bytes. Move on to read the length.
        offset_ += nBytesToRead_;
        state_ = TlvStructureDecoder_READ_LENGTH;
      }
      else if (state_ == TlvStructureDecoder_READ_LENGTH) {
        // Use Buffer.get to avoid using the metamethod.
        local firstOctet = input.get(offset_);
        offset_ += 1;
        if (firstOctet < 253) {
          // The value is simple, so we can skip straight to reading
          //  the value bytes.
          nBytesToRead_ = firstOctet;
          if (nBytesToRead_ == 0) {
            // No value bytes to read. We're finished.
            gotElementEnd_ = true;
            return true;
          }

          state_ = TlvStructureDecoder_READ_VALUE_BYTES;
        }
        else {
          // We need to read the bytes in the extended encoding of
          //  the length.
          if (firstOctet == 253)
            nBytesToRead_ = 2;
          else if (firstOctet == 254)
            nBytesToRead_ = 4;
          else
            // value == 255.
            nBytesToRead_ = 8;

          // We need to use firstOctet in the next state.
          firstOctet_ = firstOctet;
          state_ = TlvStructureDecoder_READ_LENGTH_BYTES;
        }
      }
      else if (state_ == TlvStructureDecoder_READ_LENGTH_BYTES) {
        local nRemainingBytes = input.len() - offset_;
        if (!useHeaderBuffer_ && nRemainingBytes >= nBytesToRead_) {
          // We don't have to use the headerBuffer. Set nBytesToRead.
          decoder.seek(offset_);

          nBytesToRead_ = decoder.readExtendedVarNumber_(firstOctet_);
          // Update offset_ to the decoder's offset after reading.
          offset_ = decoder.getOffset();
        }
        else {
          useHeaderBuffer_ = true;

          local nNeededBytes = nBytesToRead_ - headerLength_;
          if (nNeededBytes > nRemainingBytes) {
            // We can't get all of the header bytes from this input.
            // Save in headerBuffer.
            if (headerLength_ + nRemainingBytes > headerBuffer_.len())
              // We don't expect this to happen.
              throw "Cannot store more header bytes than the size of headerBuffer";
            input.slice(offset_, offset_ + nRemainingBytes).copy
              (headerBuffer_, headerLength_);
            offset_ += nRemainingBytes;
            headerLength_ += nRemainingBytes;

            return false;
          }

          // Copy the remaining bytes into headerBuffer, read the
          //   length and set nBytesToRead.
          if (headerLength_ + nNeededBytes > headerBuffer_.len())
            // We don't expect this to happen.
            throw "Cannot store more header bytes than the size of headerBuffer";
          input.slice(offset_, offset_ + nNeededBytes).copy
            (headerBuffer_, headerLength_);
          offset_ += nNeededBytes;

          // Use a local decoder just for the headerBuffer.
          local bufferDecoder = TlvDecoder(headerBuffer_);
          // Replace nBytesToRead with the length of the value.
          nBytesToRead_ = bufferDecoder.readExtendedVarNumber_(firstOctet_);
        }

        if (nBytesToRead_ == 0) {
          // No value bytes to read. We're finished.
          gotElementEnd_ = true;
          return true;
        }

        // Get ready to read the value bytes.
        state_ = TlvStructureDecoder_READ_VALUE_BYTES;
      }
      else if (state_ == TlvStructureDecoder_READ_VALUE_BYTES) {
        local nRemainingBytes = input.len() - offset_;
        if (nRemainingBytes < nBytesToRead_) {
          // Need more.
          offset_ += nRemainingBytes;
          nBytesToRead_ -= nRemainingBytes;
          return false;
        }

        // Got the bytes. We're finished.
        offset_ += nBytesToRead_;
        gotElementEnd_ = true;
        return true;
      }
      else
        // We don't expect this to happen.
        throw "Unrecognized state";
    }
  }

  /**
   * Get the current offset into the input buffer.
   * @return {integer} The offset.
   */
  function getOffset() { return offset_; }

  /**
   * Set the offset into the input, used for the next read.
   * @param {integer} offset The new offset.
   */
  function seek(offset) { offset_ = offset; }
}
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
 * An ElementReader lets you call onReceivedData multiple times which uses a
 * TlvStructureDecoder to detect the end of a TLV element and calls
 * elementListener.onReceivedElement(element) with the element.  This handles
 * the case where a single call to onReceivedData may contain multiple elements.
 */
class ElementReader {
  elementListener_ = null;
  dataParts_ = null;
  tlvStructureDecoder_ = null;

  /**
   * Create a new ElementReader with the elementListener.
   * @param {instance} elementListener An object with an onReceivedElement
   * method.
   */
  constructor(elementListener)
  {
    elementListener_ = elementListener;
    dataParts_ = [];
    tlvStructureDecoder_ = TlvStructureDecoder();
  }

  /**
   * Continue to read data until the end of an element, then call
   * elementListener_.onReceivedElement(element). The Buffer passed to
   * onReceivedElement is only valid during this call.  If you need the data
   * later, you must copy.
   * @param {Buffer} data The Buffer with the incoming element's bytes.
   */
  function onReceivedData(data)
  {
    // Process multiple elements in the data.
    while (true) {
      local gotElementEnd;
      local offset;

      try {
        if (dataParts_.len() == 0) {
          // This is the beginning of an element.
          if (data.len() <= 0)
            // Wait for more data.
            return;
        }

        // Scan the input to check if a whole TLV element has been read.
        tlvStructureDecoder_.seek(0);
        gotElementEnd = tlvStructureDecoder_.findElementEnd(data);
        offset = tlvStructureDecoder_.getOffset();
      } catch (ex) {
        // Reset to read a new element on the next call.
        dataParts_ = [];
        tlvStructureDecoder_ = TlvStructureDecoder();

        throw ex;
      }

      if (gotElementEnd) {
        // Got the remainder of an element.  Report to the caller.
        local element;
        if (dataParts_.len() == 0)
          element = data.slice(0, offset);
        else {
          dataParts_.push(data.slice(0, offset));
          element = Buffer.concat(dataParts_);
          dataParts_ = [];
        }

        // Reset to read a new element. Do this before calling onReceivedElement
        // in case it throws an exception.
        data = data.slice(offset, data.len());
        tlvStructureDecoder_ = TlvStructureDecoder();

        elementListener_.onReceivedElement(element);
        if (data.len() == 0)
          // No more data in the packet.
          return;

        // else loop back to decode.
      }
      else {
        // Save a copy. We will call concat later.
        local totalLength = data.len();
        for (local i = 0; i < dataParts_.len(); ++i)
          totalLength += dataParts_[i].len();
        if (totalLength > NdnCommon.MAX_NDN_PACKET_SIZE) {
          // Reset to read a new element on the next call.
          dataParts_ = [];
          tlvStructureDecoder_ = TlvStructureDecoder();

          throw "The incoming packet exceeds the maximum limit Face.getMaxNdnPacketSize()";
        }

        dataParts_.push(Buffer(data));
        return;
      }
    }
  }
}
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
 * WireFormat is an abstract base class for encoding and decoding Interest,
 * Data, etc. with a specific wire format. You should use a derived class such
 * as TlvWireFormat.
 */
class WireFormat {
  /**
   * Set the static default WireFormat used by default encoding and decoding
   * methods.
   * @param {WireFormat} wireFormat An object of a subclass of WireFormat.
   */
  static function setDefaultWireFormat(wireFormat)
  {
    ::WireFormat_defaultWireFormat = wireFormat;
  }

  /**
   * Return the default WireFormat used by default encoding and decoding methods
   * which was set with setDefaultWireFormat.
   * @return {WireFormat} An object of a subclass of WireFormat.
   */
  static function getDefaultWireFormat()
  {
    return WireFormat_defaultWireFormat;
  }
}

// We use a global variable because static member variables are immutable.
WireFormat_defaultWireFormat <- null;
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
 * A Tlv0_2WireFormat extends WireFormat and has methods for encoding and
 * decoding with the NDN-TLV wire format, version 0.2.
 */
class Tlv0_2WireFormat extends WireFormat {
  /**
   * Encode interest as NDN-TLV and return the encoding.
   * @param {Name} name The Name to encode.
   * @return {Blobl} A Blob containing the encoding.
   */
  function encodeName(name)
  {
    local encoder = TlvEncoder(100);
    encodeName_(name, encoder);
    return encoder.finish();
  }

  /**
   * Decode input as an NDN-TLV name and set the fields of the Name object.
   * @param {Name} name The Name object whose fields are updated.
   * @param {Buffer} input The Buffer with the bytes to decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   */
  function decodeName(name, input, copy = true)
  {
    local decoder = TlvDecoder(input);
    decodeName_(name, decoder, copy);
  }

  /**
   * Encode interest as NDN-TLV and return the encoding and signed offsets.
   * @param {Interest} interest The Interest object to encode.
   * @return {table} A table with fields (encoding, signedPortionBeginOffset,
   * signedPortionEndOffset) where encoding is a Blob containing the encoding,
   * signedPortionBeginOffset is the offset in the encoding of the beginning of
   * the signed portion, and signedPortionEndOffset is the offset in the
   * encoding of the end of the signed portion. The signed portion starts from
   * the first name component and ends just before the final name component
   * (which is assumed to be a signature for a signed interest).
   */
  function encodeInterest(interest)
  {
    local encoder = TlvEncoder(100);
    local saveLength = encoder.getLength();

    // Encode backwards.
/* TODO: Link.
    encoder.writeOptionalNonNegativeIntegerTlv
      (Tlv.SelectedDelegation, interest.getSelectedDelegationIndex());
    local linkWireEncoding = interest.getLinkWireEncoding(this);
    if (!linkWireEncoding.isNull())
      // Encode the entire link as is.
      encoder.writeBuffer(linkWireEncoding.buf());
*/

    encoder.writeOptionalNonNegativeIntegerTlvFromFloat
      (Tlv.InterestLifetime, interest.getInterestLifetimeMilliseconds());

    // Encode the Nonce as 4 bytes.
    if (interest.getNonce().size() == 0)
    {
      // This is the most common case. Generate a nonce.
      local nonce = Buffer(4);
      Crypto.generateRandomBytes(nonce);
      encoder.writeBlobTlv(Tlv.Nonce, nonce);
    }
    else if (interest.getNonce().size() < 4) {
      local nonce = Buffer(4);
      // Copy existing nonce bytes.
      interest.getNonce().buf().copy(nonce);

      // Generate random bytes for remaining bytes in the nonce.
      Crypto.generateRandomBytes(nonce.slice(interest.getNonce().size()));
      encoder.writeBlobTlv(Tlv.Nonce, nonce);
    }
    else if (interest.getNonce().size() == 4)
      // Use the nonce as-is.
      encoder.writeBlobTlv(Tlv.Nonce, interest.getNonce().buf());
    else
      // Truncate.
      encoder.writeBlobTlv(Tlv.Nonce, interest.getNonce().buf().slice(0, 4));

    encodeSelectors_(interest, encoder);
    local tempOffsets = encodeName_(interest.getName(), encoder);
    local signedPortionBeginOffsetFromBack =
      encoder.getLength() - tempOffsets.signedPortionBeginOffset;
    local signedPortionEndOffsetFromBack =
      encoder.getLength() - tempOffsets.signedPortionEndOffset;

    encoder.writeTypeAndLength(Tlv.Interest, encoder.getLength() - saveLength);
    local signedPortionBeginOffset =
      encoder.getLength() - signedPortionBeginOffsetFromBack;
    local signedPortionEndOffset =
      encoder.getLength() - signedPortionEndOffsetFromBack;

    return { encoding = encoder.finish(),
             signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * Decode input as an NDN-TLV interest packet, set the fields in the interest
   * object, and return the signed offsets.
   * @param {Interest} interest The Interest object whose fields are updated.
   * @param {Buffer} input The Buffer with the bytes to decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   * @return {table} A table with fields (signedPortionBeginOffset,
   * signedPortionEndOffset) where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion. The signed
   * portion starts from the first name component and ends just before the final
   * name component (which is assumed to be a signature for a signed interest).
   */
  function decodeInterest(interest, input, copy = true)
  {
    local decoder = TlvDecoder(input);

    local endOffset = decoder.readNestedTlvsStart(Tlv.Interest);
    local offsets = decodeName_(interest.getName(), decoder, copy);
    if (decoder.peekType(Tlv.Selectors, endOffset))
      decodeSelectors_(interest, decoder, copy);
    // Require a Nonce, but don't force it to be 4 bytes.
    local nonce = decoder.readBlobTlv(Tlv.Nonce);
    interest.setInterestLifetimeMilliseconds
      (decoder.readOptionalNonNegativeIntegerTlv(Tlv.InterestLifetime, endOffset));

/* TODO Link.
    if (decoder.peekType(Tlv.Data, endOffset)) {
      // Get the bytes of the Link TLV.
      local linkBeginOffset = decoder.getOffset();
      local linkEndOffset = decoder.readNestedTlvsStart(Tlv.Data);
      decoder.seek(linkEndOffset);

      interest.setLinkWireEncoding
        (Blob(decoder.getSlice(linkBeginOffset, linkEndOffset), copy), this);
    }
    else
      interest.unsetLink();
    interest.setSelectedDelegationIndex
      (decoder.readOptionalNonNegativeIntegerTlv(Tlv.SelectedDelegation, endOffset));
    if (interest.getSelectedDelegationIndex() != null &&
        interest.getSelectedDelegationIndex() >= 0 && !interest.hasLink())
      throw "Interest has a selected delegation, but no link object";
*/

    // Set the nonce last because setting other interest fields clears it.
    interest.setNonce(Blob(nonce, copy));

    decoder.finishNestedTlvs(endOffset);
    return offsets;
  }

  /**
   * Encode data as NDN-TLV and return the encoding and signed offsets.
   * @param {Data} data The Data object to encode.
   * @return {table} A table with fields (encoding, signedPortionBeginOffset,
   * signedPortionEndOffset) where encoding is a Blob containing the encoding,
   * signedPortionBeginOffset is the offset in the encoding of the beginning of
   * the signed portion, and signedPortionEndOffset is the offset in the
   * encoding of the end of the signed portion.
   */
  function encodeData(data)
  {
    local encoder = TlvEncoder(500);
    local saveLength = encoder.getLength();

    // Encode backwards.
    encoder.writeBlobTlv
      (Tlv.SignatureValue, data.getSignature().getSignature().buf());
    local signedPortionEndOffsetFromBack = encoder.getLength();

    encodeSignatureInfo_(data.getSignature(), encoder);
    encoder.writeBlobTlv(Tlv.Content, data.getContent().buf());
    encodeMetaInfo_(data.getMetaInfo(), encoder);
    encodeName_(data.getName(), encoder);
    local signedPortionBeginOffsetFromBack = encoder.getLength();

    encoder.writeTypeAndLength(Tlv.Data, encoder.getLength() - saveLength);
    local signedPortionBeginOffset =
      encoder.getLength() - signedPortionBeginOffsetFromBack;
    local signedPortionEndOffset =
      encoder.getLength() - signedPortionEndOffsetFromBack;

    return { encoding = encoder.finish(),
             signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * Decode input as an NDN-TLV data packet, set the fields in the data object,
   * and return the signed offsets.
   * @param {Data} data The Data object whose fields are updated.
   * @param {Buffer} input The Buffer with the bytes to decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   * @return {table} A table with fields (signedPortionBeginOffset,
   * signedPortionEndOffset) where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion.
   */
  function decodeData(data, input, copy = true)
  {
    local decoder = TlvDecoder(input);

    local endOffset = decoder.readNestedTlvsStart(Tlv.Data);
    local signedPortionBeginOffset = decoder.getOffset();

    decodeName_(data.getName(), decoder, copy);
    decodeMetaInfo_(data.getMetaInfo(), decoder, copy);
    data.setContent(Blob(decoder.readBlobTlv(Tlv.Content), copy));
    decodeSignatureInfo_(data, decoder, copy);

    local signedPortionEndOffset = decoder.getOffset();
    data.getSignature().setSignature
      (Blob(decoder.readBlobTlv(Tlv.SignatureValue), copy));

    decoder.finishNestedTlvs(endOffset);
    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * Encode signature as an NDN-TLV SignatureInfo and return the encoding.
   * @param {Signature} signature An object of a subclass of Signature to encode.
   * @return {Blob} A Blob containing the encoding.
   */
  function encodeSignatureInfo(signature)
  {
    local encoder = TlvEncoder(100);
    encodeSignatureInfo_(signature, encoder);
    return encoder.finish();
  }

  /**
   * Encode the signatureValue in the Signature object as an NDN-TLV
   * SignatureValue (the signature bits) and return the encoding.
   * @param {Signature} signature An object of a subclass of Signature with the
   * signature value to encode.
   * @return {Blob} A Blob containing the encoding.
   */
  function encodeSignatureValue(signature)
  {
    local encoder = TlvEncoder(100);
    encoder.writeBlobTlv(Tlv.SignatureValue, signature.getSignature().buf());
    return encoder.finish();
  }

  /**
   * Decode signatureInfo as an NDN-TLV SignatureInfo and signatureValue as the
   * related SignatureValue, and return a new object which is a subclass of
   * Signature.
   * @param {Buffer} signatureInfo The Buffer with the SignatureInfo bytes to
   * decode.
   * @param {Buffer} signatureValue The Buffer with the SignatureValue bytes to
   * decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   * @return {Signature} A new object which is a subclass of Signature.
   */
  function decodeSignatureInfoAndValue(signatureInfo, signatureValue, copy = true)
  {
    // Use a SignatureHolder to imitate a Data object for decodeSignatureInfo_.
    local signatureHolder = Tlv0_2WireFormat_SignatureHolder();
    local decoder = TlvDecoder(signatureInfo);
    decodeSignatureInfo_(signatureHolder, decoder, copy);

    decoder = TlvDecoder(signatureValue);
    signatureHolder.getSignature().setSignature
      (Blob(decoder.readBlobTlv(Tlv.SignatureValue), copy));

    return signatureHolder.getSignature();
  }

  /**
   * Decode input as an NDN-TLV LpPacket and set the fields of the lpPacket
   * object.
   * @param {LpPacket} lpPacket The LpPacket object whose fields are updated.
   * @param {Buffer} input The Buffer with the bytes to decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   */
  function decodeLpPacket(lpPacket, input, copy = true)
  {
    lpPacket.clear();

    local decoder = TlvDecoder(input);
    local endOffset = decoder.readNestedTlvsStart(Tlv.LpPacket_LpPacket);

    while (decoder.getOffset() < endOffset) {
      // Imitate TlvDecoder.readTypeAndLength.
      local fieldType = decoder.readVarNumber();
      local fieldLength = decoder.readVarNumber();
      local fieldEndOffset = decoder.getOffset() + fieldLength;
      if (fieldEndOffset > input.length)
        throw "TLV length exceeds the buffer length";

      if (fieldType == Tlv.LpPacket_Fragment) {
        // Set the fragment to the bytes of the TLV value.
        lpPacket.setFragmentWireEncoding
          (Blob(decoder.getSlice(decoder.getOffset(), fieldEndOffset), copy));
        decoder.seek(fieldEndOffset);

        // The fragment is supposed to be the last field.
        break;
      }
/**   TODO: Support Nack and IncomingFaceid
      else if (fieldType == Tlv.LpPacket_Nack) {
        local networkNack = NetworkNack();
        local code = decoder.readOptionalNonNegativeIntegerTlv
          (Tlv.LpPacket_NackReason, fieldEndOffset);
        local reason;
        // The enum numeric values are the same as this wire format, so use as is.
        if (code < 0 || code == NetworkNack.Reason.NONE)
          // This includes an omitted NackReason.
          networkNack.setReason(NetworkNack.Reason.NONE);
        else if (code == NetworkNack.Reason.CONGESTION ||
                 code == NetworkNack.Reason.DUPLICATE ||
                 code == NetworkNack.Reason.NO_ROUTE)
          networkNack.setReason(code);
        else {
          // Unrecognized reason.
          networkNack.setReason(NetworkNack.Reason.OTHER_CODE);
          networkNack.setOtherReasonCode(code);
        }

        lpPacket.addHeaderField(networkNack);
      }
      else if (fieldType == Tlv.LpPacket_IncomingFaceId) {
        local incomingFaceId = new IncomingFaceId();
        incomingFaceId.setFaceId(decoder.readNonNegativeInteger(fieldLength));
        lpPacket.addHeaderField(incomingFaceId);
      }
*/
      else {
        // Unrecognized field type. The conditions for ignoring are here:
        // http://redmine.named-data.net/projects/nfd/wiki/NDNLPv2
        local canIgnore =
          (fieldType >= Tlv.LpPacket_IGNORE_MIN &&
           fieldType <= Tlv.LpPacket_IGNORE_MAX &&
           (fieldType & 0x01) == 1);
        if (!canIgnore)
          throw "Did not get the expected TLV type";

        // Ignore.
        decoder.seek(fieldEndOffset);
      }

      decoder.finishNestedTlvs(fieldEndOffset);
    }

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * Encode the EncryptedContent in NDN-TLV and return the encoding.
   * @param {EncryptedContent} encryptedContent The EncryptedContent object to
   * encode.
   * @return {Blobl} A Blob containing the encoding.
   */
  function encodeEncryptedContent(encryptedContent)
  {
    local encoder = TlvEncoder(100);
    local saveLength = encoder.getLength();

    // Encode backwards.
    encoder.writeBlobTlv
      (Tlv.Encrypt_EncryptedPayload, encryptedContent.getPayload().buf());
    encoder.writeOptionalBlobTlv
      (Tlv.Encrypt_InitialVector, encryptedContent.getInitialVector().buf());
    // Assume the algorithmType value is the same as the TLV type.
    encoder.writeNonNegativeIntegerTlv
      (Tlv.Encrypt_EncryptionAlgorithm, encryptedContent.getAlgorithmType());
    Tlv0_2WireFormat.encodeKeyLocator_
      (Tlv.KeyLocator, encryptedContent.getKeyLocator(), encoder);

    encoder.writeTypeAndLength
      (Tlv.Encrypt_EncryptedContent, encoder.getLength() - saveLength);

    return encoder.finish();
  }

  /**
   * Decode input as an EncryptedContent in NDN-TLV and set the fields of the
   * encryptedContent object.
   * @param {EncryptedContent} encryptedContent The EncryptedContent object
   * whose fields are updated.
   * @param {Buffer} input The Buffer with the bytes to decode.
   * @param {bool} copy (optional) If true, copy from the input when making new
   * Blob values. If false, then Blob values share memory with the input, which
   * must remain unchanged while the Blob values are used. If omitted, use true.
   */
  function decodeEncryptedContent(encryptedContent, input, copy = true)
  {
    local decoder = TlvDecoder(input);
    local endOffset = decoder.
      readNestedTlvsStart(Tlv.Encrypt_EncryptedContent);

    Tlv0_2WireFormat.decodeKeyLocator_
      (Tlv.KeyLocator, encryptedContent.getKeyLocator(), decoder, copy);
    encryptedContent.setAlgorithmType
      (decoder.readNonNegativeIntegerTlv(Tlv.Encrypt_EncryptionAlgorithm));
    encryptedContent.setInitialVector
      (Blob(decoder.readOptionalBlobTlv
       (Tlv.Encrypt_InitialVector, endOffset), copy));
    encryptedContent.setPayload
      (Blob(decoder.readBlobTlv(Tlv.Encrypt_EncryptedPayload), copy));

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * Get a singleton instance of a Tlv0_2WireFormat.  To always use the
   * preferred version NDN-TLV, you should use TlvWireFormat.get().
   * @return {Tlv0_2WireFormat} The singleton instance.
   */
  static function get()
  {
    if (Tlv0_2WireFormat_instance == null)
      ::Tlv0_2WireFormat_instance = Tlv0_2WireFormat();
    return Tlv0_2WireFormat_instance;
  }

  /**
   * Encode the name component to the encoder as NDN-TLV. This handles different
   * component types such as ImplicitSha256DigestComponent.
   * @param {NameComponent} component The name component to encode.
   * @param {TlvEncoder} encoder The TlvEncoder which receives the encoding.
   */
  static function encodeNameComponent_(component, encoder)
  {
    local type = component.isImplicitSha256Digest() ?
      Tlv.ImplicitSha256DigestComponent : Tlv.NameComponent;
    encoder.writeBlobTlv(type, component.getValue().buf());
  }

  /**
   * Decode the name component as NDN-TLV and return the component. This handles
   * different component types such as ImplicitSha256DigestComponent.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeNameComponent_(decoder, copy)
  {
    local savePosition = decoder.getOffset();
    local type = decoder.readVarNumber();
    // Restore the position.
    decoder.seek(savePosition);

    local value = Blob(decoder.readBlobTlv(type), copy);
    if (type == Tlv.ImplicitSha256DigestComponent)
      return NameComponent.fromImplicitSha256Digest(value);
    else
      return NameComponent(value);
  }

  /**
   * Encode the name to the encoder.
   * @param {Name} name The name to encode.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   * @return {table} A table with fields signedPortionBeginOffset and
   * signedPortionEndOffset where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion. The signed
   * portion starts from the first name component and ends just before the final
   * name component (which is assumed to be a signature for a signed interest).
   */
  static function encodeName_(name, encoder)
  {
    local saveLength = encoder.getLength();

    // Encode the components backwards.
    local signedPortionEndOffsetFromBack;
    for (local i = name.size() - 1; i >= 0; --i) {
      encodeNameComponent_(name.get(i), encoder);
      if (i == name.size() - 1)
        signedPortionEndOffsetFromBack = encoder.getLength();
    }

    local signedPortionBeginOffsetFromBack = encoder.getLength();
    encoder.writeTypeAndLength(Tlv.Name, encoder.getLength() - saveLength);

    local signedPortionBeginOffset =
      encoder.getLength() - signedPortionBeginOffsetFromBack;
    local signedPortionEndOffset;
    if (name.size() == 0)
      // There is no "final component", so set signedPortionEndOffset arbitrarily.
      signedPortionEndOffset = signedPortionBeginOffset;
    else
      signedPortionEndOffset = encoder.getLength() - signedPortionEndOffsetFromBack;

    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * Clear the name, decode a Name from the decoder and set the fields of the
   * name object.
   * @param {Name} name The name object whose fields are updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   * @return {table} A table with fields signedPortionBeginOffset and
   * signedPortionEndOffset where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion. The signed
   * portion starts from the first name component and ends just before the final
   * name component (which is assumed to be a signature for a signed interest).
   */
  static function decodeName_(name, decoder, copy)
  {
    name.clear();

    local endOffset = decoder.readNestedTlvsStart(Tlv.Name);
    local signedPortionBeginOffset = decoder.getOffset();
    // In case there are no components, set signedPortionEndOffset arbitrarily.
    local signedPortionEndOffset = signedPortionBeginOffset;

    while (decoder.getOffset() < endOffset) {
      signedPortionEndOffset = decoder.getOffset();
      name.append(decodeNameComponent_(decoder, copy));
    }

    decoder.finishNestedTlvs(endOffset);

    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * An internal method to encode the interest Selectors in NDN-TLV. If no
   * selectors are written, do not output a Selectors TLV.
   * @param {Interest} interest The Interest object with the selectors to encode.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   */
  static function encodeSelectors_(interest, encoder)
  {
    local saveLength = encoder.getLength();

    // Encode backwards.
    if (interest.getMustBeFresh())
      encoder.writeTypeAndLength(Tlv.MustBeFresh, 0);
    // else MustBeFresh == false, so nothing to encode.
    encoder.writeOptionalNonNegativeIntegerTlv
      (Tlv.ChildSelector, interest.getChildSelector());
    if (interest.getExclude().size() > 0)
      encodeExclude_(interest.getExclude(), encoder);

    if (interest.getKeyLocator().getType() != null)
      encodeKeyLocator_
        (Tlv.PublisherPublicKeyLocator, interest.getKeyLocator(), encoder);

    encoder.writeOptionalNonNegativeIntegerTlv
      (Tlv.MaxSuffixComponents, interest.getMaxSuffixComponents());
    encoder.writeOptionalNonNegativeIntegerTlv
      (Tlv.MinSuffixComponents, interest.getMinSuffixComponents());

    // Only output the type and length if values were written.
    if (encoder.getLength() != saveLength)
      encoder.writeTypeAndLength(Tlv.Selectors, encoder.getLength() - saveLength);
  }

  /**
   * Decode an NDN-TLV Selectors from the decoder and set the fields of
   * the Interest object.
   * @param {Interest} interest The Interest object whose fields are
   * updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeSelectors_(interest, decoder, copy)
  {
    local endOffset = decoder.readNestedTlvsStart(Tlv.Selectors);

    interest.setMinSuffixComponents(decoder.readOptionalNonNegativeIntegerTlv
      (Tlv.MinSuffixComponents, endOffset));
    interest.setMaxSuffixComponents(decoder.readOptionalNonNegativeIntegerTlv
      (Tlv.MaxSuffixComponents, endOffset));

    if (decoder.peekType(Tlv.PublisherPublicKeyLocator, endOffset))
      decodeKeyLocator_
        (Tlv.PublisherPublicKeyLocator, interest.getKeyLocator(), decoder, copy);
    else
      interest.getKeyLocator().clear();

    if (decoder.peekType(Tlv.Exclude, endOffset))
      decodeExclude_(interest.getExclude(), decoder, copy);
    else
      interest.getExclude().clear();

    interest.setChildSelector(decoder.readOptionalNonNegativeIntegerTlv
      (Tlv.ChildSelector, endOffset));
    interest.setMustBeFresh(decoder.readBooleanTlv(Tlv.MustBeFresh, endOffset));

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * An internal method to encode exclude as an Exclude in NDN-TLV.
   * @param {Exclude} exclude The Exclude object.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   */
  static function encodeExclude_(exclude, encoder)
  {
    local saveLength = encoder.getLength();

    // TODO: Do we want to order the components (except for ANY)?
    // Encode the entries backwards.
    for (local i = exclude.size() - 1; i >= 0; --i) {
      local entry = exclude.get(i);

      if (entry.getType() == ExcludeType.COMPONENT)
        encodeNameComponent_(entry.getComponent(), encoder);
      else if (entry.getType() == ExcludeType.ANY)
        encoder.writeTypeAndLength(Tlv.Any, 0);
      else
        throw "Unrecognized ExcludeType";
    }

    encoder.writeTypeAndLength(Tlv.Exclude, encoder.getLength() - saveLength);
  }

  /**
   * Clear the exclude, decode an NDN-TLV Exclude from the decoder and set the
   * fields of the Exclude object.
   * @param {Exclude} exclude The Exclude object whose fields are
   * updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeExclude_(exclude, decoder, copy)
  {
    local endOffset = decoder.readNestedTlvsStart(Tlv.Exclude);

    exclude.clear();
    while (decoder.getOffset() < endOffset) {
      if (decoder.peekType(Tlv.Any, endOffset)) {
        // Read past the Any TLV.
        decoder.readBooleanTlv(Tlv.Any, endOffset);
        exclude.appendAny();
      }
      else
        exclude.appendComponent(decodeNameComponent_(decoder, copy));
    }

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * An internal method to encode keyLocator as a KeyLocator in NDN-TLV with the
   * given type.
   * @param {integer} type The type for the TLV.
   * @param {KeyLocator} keyLocator The KeyLocator object.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   */
  static function encodeKeyLocator_(type, keyLocator, encoder)
  {
    local saveLength = encoder.getLength();

    // Encode backwards.
    if (keyLocator.getType() == KeyLocatorType.KEYNAME)
      encodeName_(keyLocator.getKeyName(), encoder);
    else if (keyLocator.getType() == KeyLocatorType.KEY_LOCATOR_DIGEST &&
             keyLocator.getKeyData().size() > 0)
      encoder.writeBlobTlv(Tlv.KeyLocatorDigest, keyLocator.getKeyData().buf());
    else
      throw "Unrecognized KeyLocator type ";

    encoder.writeTypeAndLength(type, encoder.getLength() - saveLength);
  }

  /**
   * Clear the name, decode a KeyLocator from the decoder and set the fields of
   * the keyLocator object.
   * @param {integer} expectedType The expected type of the TLV.
   * @param {KeyLocator} keyLocator The KeyLocator object whose fields are
   * updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeKeyLocator_(expectedType, keyLocator, decoder, copy)
  {
    local endOffset = decoder.readNestedTlvsStart(expectedType);

    keyLocator.clear();

    if (decoder.getOffset() == endOffset)
      // The KeyLocator is omitted, so leave the fields as none.
      return;

    if (decoder.peekType(Tlv.Name, endOffset)) {
      // KeyLocator is a Name.
      keyLocator.setType(KeyLocatorType.KEYNAME);
      decodeName_(keyLocator.getKeyName(), decoder, copy);
    }
    else if (decoder.peekType(Tlv.KeyLocatorDigest, endOffset)) {
      // KeyLocator is a KeyLocatorDigest.
      keyLocator.setType(KeyLocatorType.KEY_LOCATOR_DIGEST);
      keyLocator.setKeyData(Blob(decoder.readBlobTlv(Tlv.KeyLocatorDigest), copy));
    }
    else
      throw "decodeKeyLocator: Unrecognized key locator type";

    decoder.finishNestedTlvs(endOffset);
  }
  
  /**
   * An internal method to encode signature as the appropriate form of
   * SignatureInfo in NDN-TLV.
   * @param {Signature} signature An object of a subclass of Signature.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   */
  static function encodeSignatureInfo_(signature, encoder)
  {
    if (signature instanceof GenericSignature) {
      // Handle GenericSignature separately since it has the entire encoding.
      local encoding = signature.getSignatureInfoEncoding();

      // Do a test decoding to sanity check that it is valid TLV.
      try {
        local decoder = TlvDecoder(encoding.buf());
        local endOffset = decoder.readNestedTlvsStart(Tlv.SignatureInfo);
        decoder.readNonNegativeIntegerTlv(Tlv.SignatureType);
        decoder.finishNestedTlvs(endOffset);
      } catch (ex) {
        throw
          "The GenericSignature encoding is not a valid NDN-TLV SignatureInfo: " +
           ex;
      }

      encoder.writeBuffer(encoding.buf());
      return;
    }

    local saveLength = encoder.getLength();

    // Encode backwards.
    if (signature instanceof Sha256WithRsaSignature) {
      encodeKeyLocator_
        (Tlv.KeyLocator, signature.getKeyLocator(), encoder);
      encoder.writeNonNegativeIntegerTlv
        (Tlv.SignatureType, Tlv.SignatureType_SignatureSha256WithRsa);
    }
    // TODO: Sha256WithEcdsaSignature.
    else if (signature instanceof HmacWithSha256Signature) {
      encodeKeyLocator_
        (Tlv.KeyLocator, signature.getKeyLocator(), encoder);
      encoder.writeNonNegativeIntegerTlv
        (Tlv.SignatureType, Tlv.SignatureType_SignatureHmacWithSha256);
    }
    // TODO: DigestSha256Signature.
    else
      throw "encodeSignatureInfo: Unrecognized Signature object type";

    encoder.writeTypeAndLength
      (Tlv.SignatureInfo, encoder.getLength() - saveLength);
  }

  /**
   * Decode an NDN-TLV SignatureInfo from the decoder and set the Data object
   * with a new Signature object.
   * @param {Data} data This calls data.setSignature with a new Signature object.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeSignatureInfo_(data, decoder, copy)
  {
    local beginOffset = decoder.getOffset();
    local endOffset = decoder.readNestedTlvsStart(Tlv.SignatureInfo);

    local signatureType = decoder.readNonNegativeIntegerTlv(Tlv.SignatureType);
    if (signatureType == Tlv.SignatureType_SignatureSha256WithRsa) {
      data.setSignature(Sha256WithRsaSignature());
      // Modify data's signature object because if we create an object
      //   and set it, then data will have to copy all the fields.
      local signatureInfo = data.getSignature();
      decodeKeyLocator_
        (Tlv.KeyLocator, signatureInfo.getKeyLocator(), decoder, copy);
    }
    else if (signatureType == Tlv.SignatureType_SignatureHmacWithSha256) {
      data.setSignature(HmacWithSha256Signature());
      local signatureInfo = data.getSignature();
      decodeKeyLocator_
        (Tlv.KeyLocator, signatureInfo.getKeyLocator(), decoder, copy);
    }
    else if (signatureType == Tlv.SignatureType_DigestSha256)
      data.setSignature(DigestSha256Signature());
    else {
      data.setSignature(GenericSignature());
      local signatureInfo = data.getSignature();

      // Get the bytes of the SignatureInfo TLV.
      signatureInfo.setSignatureInfoEncoding
        (Blob(decoder.getSlice(beginOffset, endOffset), copy), signatureType);
    }

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * An internal method to encode metaInfo as a MetaInfo in NDN-TLV.
   * @param {MetaInfo} metaInfo The MetaInfo object.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   */
  static function encodeMetaInfo_(metaInfo, encoder)
  {
    local saveLength = encoder.getLength();

    // Encode backwards.
    local finalBlockIdBuf = metaInfo.getFinalBlockId().getValue().buf();
    if (finalBlockIdBuf != null && finalBlockIdBuf.len() > 0) {
      // The FinalBlockId has an inner NameComponent.
      local finalBlockIdSaveLength = encoder.getLength();
      encodeNameComponent_(metaInfo.getFinalBlockId(), encoder);
      encoder.writeTypeAndLength
        (Tlv.FinalBlockId, encoder.getLength() - finalBlockIdSaveLength);
    }

    encoder.writeOptionalNonNegativeIntegerTlvFromFloat
      (Tlv.FreshnessPeriod, metaInfo.getFreshnessPeriod());
    if (!(metaInfo.getType() == null || metaInfo.getType() < 0 ||
          metaInfo.getType() == ContentType.BLOB)) {
      // Not the default, so we need to encode the type.
      if (metaInfo.getType() == ContentType.LINK ||
          metaInfo.getType() == ContentType.KEY ||
          metaInfo.getType() == ContentType.NACK)
        // The ContentType enum is set up with the correct integer for each
        // NDN-TLV ContentType.
        encoder.writeNonNegativeIntegerTlv(Tlv.ContentType, metaInfo.getType());
      else if (metaInfo.getType() == ContentType.OTHER_CODE)
        encoder.writeNonNegativeIntegerTlv
            (Tlv.ContentType, metaInfo.getOtherTypeCode());
      else
        // We don't expect this to happen.
        throw "Unrecognized ContentType";
    }

    encoder.writeTypeAndLength(Tlv.MetaInfo, encoder.getLength() - saveLength);
  }

  /**
   * Clear the name, decode a MetaInfo from the decoder and set the fields of
   * the metaInfo object.
   * @param {MetaInfo} metaInfo The MetaInfo object whose fields are updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @param {bool} copy If true, copy from the input when making new Blob
   * values. If false, then Blob values share memory with the input, which must
   * remain unchanged while the Blob values are used.
   */
  static function decodeMetaInfo_(metaInfo, decoder, copy)
  {
    local endOffset = decoder.readNestedTlvsStart(Tlv.MetaInfo);

    local type = decoder.readOptionalNonNegativeIntegerTlv
      (Tlv.ContentType, endOffset);
    if (type == null || type < 0 || type == ContentType.BLOB)
      metaInfo.setType(ContentType.BLOB);
    else if (type == ContentType.LINK ||
             type == ContentType.KEY ||
             type == ContentType.NACK)
      // The ContentType enum is set up with the correct integer for each
      // NDN-TLV ContentType.
      metaInfo.setType(type);
    else {
      // Unrecognized content type.
      metaInfo.setType(ContentType.OTHER_CODE);
      metaInfo.setOtherTypeCode(type);
    }

    metaInfo.setFreshnessPeriod
      (decoder.readOptionalNonNegativeIntegerTlv(Tlv.FreshnessPeriod, endOffset));
    if (decoder.peekType(Tlv.FinalBlockId, endOffset)) {
      local finalBlockIdEndOffset = decoder.readNestedTlvsStart(Tlv.FinalBlockId);
      metaInfo.setFinalBlockId(decodeNameComponent_(decoder, copy));
      decoder.finishNestedTlvs(finalBlockIdEndOffset);
    }
    else
      metaInfo.setFinalBlockId(null);

    decoder.finishNestedTlvs(endOffset);
  }
}

// Tlv0_2WireFormat_SignatureHolder is used by decodeSignatureInfoAndValue.
class Tlv0_2WireFormat_SignatureHolder
{
  signature_ = null;

  function setSignature(signature) { signature_ = signature; }

  function getSignature() { return signature_; }
}

// We use a global variable because static member variables are immutable.
Tlv0_2WireFormat_instance <- null;
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
 * A TlvWireFormat extends WireFormat to override its methods to
 * implement encoding and decoding using the preferred implementation of NDN-TLV.
 */
class TlvWireFormat extends Tlv0_2WireFormat {
  /**
   * Get a singleton instance of a TlvWireFormat.  Assuming that the default
   * wire format was set with WireFormat.setDefaultWireFormat(TlvWireFormat.get()),
   * you can check if this is the default wire encoding with
   * if WireFormat.getDefaultWireFormat() == TlvWireFormat.get().
   * @return {TlvWireFormat} The singleton instance.
   */
  static function get()
  {
    if (TlvWireFormat_instance == null)
      ::TlvWireFormat_instance = TlvWireFormat();
    return TlvWireFormat_instance;
  }
}

// We use a global variable because static member variables are immutable.
TlvWireFormat_instance <- null;

// On loading this code, make this the default wire format.
WireFormat.setDefaultWireFormat(TlvWireFormat.get());
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

// These correspond to the TLV codes.
enum EncryptAlgorithmType {
  AesEcb = 0,
  AesCbc = 1,
  RsaPkcs = 2,
  RsaOaep = 3
}

/**
 * An EncryptParams holds an algorithm type and other parameters used to encrypt
 * and decrypt.
 */
class EncryptParams {
  algorithmType_ = 0;
  initialVector_ = null;

  /**
   * Create an EncryptParams with the given parameters.
   * @param {integer} algorithmType The algorithm type from the
   * EncryptAlgorithmType enum, or null if not specified.
   * @param {integer} initialVectorLength (optional) The initial vector length,
   * or 0 if the initial vector is not specified. If omitted, the initial
   * vector is not specified.
   * @note This class is an experimental feature. The API may change.
   */
  constructor(algorithmType, initialVectorLength = null)
  {
    algorithmType_ = algorithmType;

    if (initialVectorLength != null && initialVectorLength > 0) {
      local initialVector = Buffer(initialVectorLength);
      Crypto.generateRandomBytes(initialVector);
      initialVector_ = Blob(initialVector, false);
    }
    else
      initialVector_ = Blob();
  }

  /**
   * Get the algorithmType.
   * @return {integer} The algorithm type from the EncryptAlgorithmType enum,
   * or null if not specified.
   */
  function getAlgorithmType() { return algorithmType_; }

  /**
   * Get the initial vector.
   * @return {Blob} The initial vector. If not specified, isNull() is true.
   */
  function getInitialVector() { return initialVector_; }

  /**
   * Set the algorithm type.
   * @param {integer} algorithmType The algorithm type from the
   * EncryptAlgorithmType enum. If not specified, set to null.
   * @return {EncryptParams} This EncryptParams so that you can chain calls to
   * update values.
   */
  function setAlgorithmType(algorithmType)
  {
    algorithmType_ = algorithmType;
    return this;
  }

  /**
   * Set the initial vector.
   * @param {Blob} initialVector The initial vector. If not specified, set to
   * the default Blob() where isNull() is true.
   * @return {EncryptParams} This EncryptParams so that you can chain calls to
   * update values.
   */
  function setInitialVector(initialVector)
  {
    this.initialVector_ =
      initialVector instanceof Blob ? initialVector : Blob(initialVector, true);
    return this;
  }
}
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

// This requires contrib/kisi-inc/aes-squirrel/aes.class.nut .

/**
 * The AesAlgorithm class provides static methods to manipulate keys, encrypt
 * and decrypt using the AES symmetric key cipher.
 * @note This class is an experimental feature. The API may change.
 */
class AesAlgorithm {
  static BLOCK_SIZE = 16;

  /**
   * Generate a new random decrypt key for AES based on the given params.
   * @param {AesKeyParams} params The key params with the key size (in bits).
   * @return {DecryptKey} The new decrypt key.
   */
  static function generateKey(params)
  {
    // Convert the key bit size to bytes.
    local key = blob(params.getKeySize() / 8); 
    Crypto.generateRandomBytes(key);

    return DecryptKey(Blob(key, false));
  }

  /**
   * Derive a new encrypt key from the given decrypt key value.
   * @param {Blob} keyBits The key value of the decrypt key.
   * @return {EncryptKey} The new encrypt key.
   */
  static function deriveEncryptKey(keyBits) { return EncryptKey(keyBits); }

  /**
   * Decrypt the encryptedData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value.
   * @param {Blob} encryptedData The data to decrypt.
   * @param {EncryptParams} params This decrypts according to
   * params.getAlgorithmType() and other params as needed such as
   * params.getInitialVector().
   * @return {Blob} The decrypted data.
   */
  static function decrypt(keyBits, encryptedData, params)
  {
    local paddedData;
    if (params.getAlgorithmType() == EncryptAlgorithmType.AesEcb) {
      local cipher = AES(keyBits.buf().toBlob());
      // For the aes-squirrel package, we have to process each ECB block.
      local input = encryptedData.buf().toBlob();
      paddedData = blob(input.len());

      for (local i = 0; i < paddedData.len(); i += 16) {
        // TODO: Do we really have to copy once with readblob and again with writeblob?
        input.seek(i);
        paddedData.writeblob(cipher.decrypt(input.readblob(16)));
      }
    }
    else if (params.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      local cipher = AES_CBC
        (keyBits.buf().toBlob(), params.getInitialVector().buf().toBlob());
      paddedData = cipher.decrypt(encryptedData.buf().toBlob());
    }
    else
      throw "Unsupported encryption mode";

    // For the aes-squirrel package, we have to remove the padding.
    local padLength = paddedData[paddedData.len() - 1];
    return Blob
      (Buffer.from(paddedData).slice(0, paddedData.len() - padLength), false);
  }

  /**
   * Encrypt the plainData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value.
   * @param {Blob} plainData The data to encrypt.
   * @param {EncryptParams} params This encrypts according to
   * params.getAlgorithmType() and other params as needed such as
   * params.getInitialVector().
   * @return {Blob} The encrypted data.
   */
  static function encrypt(keyBits, plainData, params)
  {
    // For the aes-squirrel package, we have to do the padding.
    local padLength = 16 - (plainData.size() % 16);
    local paddedData = blob(plainData.size() + padLength);
    plainData.buf().copy(paddedData);
    for (local i = 0; i < padLength; ++i)
      paddedData[plainData.size() + i] = padLength;

    local encrypted;
    if (params.getAlgorithmType() == EncryptAlgorithmType.AesEcb) {
      local cipher = AES(keyBits.buf().toBlob());
      // For the aes-squirrel package, we have to process each ECB block.
      encrypted = blob(paddedData.len());

      for (local i = 0; i < paddedData.len(); i += 16) {
        // TODO: Do we really have to copy once with readblob and again with writeblob?
        paddedData.seek(i);
        encrypted.writeblob(cipher.encrypt(paddedData.readblob(16)));
      }
    }
    else if (params.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      if (params.getInitialVector().size() != AesAlgorithm.BLOCK_SIZE)
        throw "Incorrect initial vector size";

      local cipher = AES_CBC
        (keyBits.buf().toBlob(), params.getInitialVector().buf().toBlob());
      encrypted = cipher.encrypt(paddedData);
    }
    else
      throw "Unsupported encryption mode";

    return Blob(Buffer.from(encrypted), false);
  }
}
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
 * Encryptor has static constants and utility methods for encryption, such as
 * encryptData.
 */
class Encryptor {
  NAME_COMPONENT_FOR = NameComponent("FOR");
  NAME_COMPONENT_READ = NameComponent("READ");
  NAME_COMPONENT_SAMPLE = NameComponent("SAMPLE");
  NAME_COMPONENT_ACCESS = NameComponent("ACCESS");
  NAME_COMPONENT_E_KEY = NameComponent("E-KEY");
  NAME_COMPONENT_D_KEY = NameComponent("D-KEY");
  NAME_COMPONENT_C_KEY = NameComponent("C-KEY");

  /**
   * Prepare an encrypted data packet by encrypting the payload using the key
   * according to the params. In addition, this prepares the encoded
   * EncryptedContent with the encryption result using keyName and params. The
   * encoding is set as the content of the data packet. If params defines an
   * asymmetric encryption algorithm and the payload is larger than the maximum
   * plaintext size, this encrypts the payload with a symmetric key that is
   * asymmetrically encrypted and provided as a nonce in the content of the data
   * packet. The packet's /<dataName>/ is updated to be <dataName>/FOR/<keyName>.
   * @param {Data} data The data packet which is updated.
   * @param {Blob} payload The payload to encrypt.
   * @param {Name} keyName The key name for the EncryptedContent.
   * @param {Blob} key The encryption key value.
   * @param {EncryptParams} params The parameters for encryption.
   */
  static function encryptData(data, payload, keyName, key, params)
  {
    data.getName().append(Encryptor.NAME_COMPONENT_FOR).append(keyName);

    local algorithmType = params.getAlgorithmType();

    if (algorithmType == EncryptAlgorithmType.AesCbc ||
        algorithmType == EncryptAlgorithmType.AesEcb) {
      local content = Encryptor.encryptSymmetric_(payload, key, keyName, params);
      data.setContent(content.wireEncode(TlvWireFormat.get()));
    }
    else if (algorithmType == EncryptAlgorithmType.RsaPkcs ||
             algorithmType == EncryptAlgorithmType.RsaOaep) {
      // TODO: Support payload larger than the maximum plaintext size.
      local content = Encryptor.encryptAsymmetric_(payload, key, keyName, params);
      data.setContent(content.wireEncode(TlvWireFormat.get()));
    }
    else
      throw "Unsupported encryption method";
  }

  /**
   * Encrypt the payload using the symmetric key according to params, and return
   * an EncryptedContent.
   * @param {Blob} payload The data to encrypt.
   * @param {Blob} key The key value.
   * @param {Name} keyName The key name for the EncryptedContent key locator.
   * @param {EncryptParams} params The parameters for encryption.
   * @return {EncryptedContent} A new EncryptedContent.
   */
  static function encryptSymmetric_(payload, key, keyName, params)
  {
    local algorithmType = params.getAlgorithmType();
    local initialVector = params.getInitialVector();
    local keyLocator = KeyLocator();
    keyLocator.setType(KeyLocatorType.KEYNAME);
    keyLocator.setKeyName(keyName);

    if (algorithmType == EncryptAlgorithmType.AesCbc ||
        algorithmType == EncryptAlgorithmType.AesEcb) {
      if (algorithmType == EncryptAlgorithmType.AesCbc) {
        if (initialVector.size() != AesAlgorithm.BLOCK_SIZE)
          throw "Incorrect initial vector size";
      }

      local encryptedPayload = AesAlgorithm.encrypt(key, payload, params);

      local result = EncryptedContent();
      result.setAlgorithmType(algorithmType);
      result.setKeyLocator(keyLocator);
      result.setPayload(encryptedPayload);
      result.setInitialVector(initialVector);
      return result;
    }
    else
      throw "Unsupported encryption method";
  }

  /**
   * Encrypt the payload using the asymmetric key according to params, and
   * return an EncryptedContent.
   * @param {Blob} payload The data to encrypt. The size should be within range
   * of the key.
   * @param {Blob} key The key value.
   * @param {Name} keyName The key name for the EncryptedContent key locator.
   * @param {EncryptParams} params The parameters for encryption.
   * @return {EncryptedContent} A new EncryptedContent.
   */
  static function encryptAsymmetric_(payload, key, keyName, params)
  {
    local algorithmType = params.getAlgorithmType();
    local keyLocator = KeyLocator();
    keyLocator.setType(KeyLocatorType.KEYNAME);
    keyLocator.setKeyName(keyName);

    if (algorithmType == EncryptAlgorithmType.RsaPkcs ||
        algorithmType == EncryptAlgorithmType.RsaOaep) {
      local encryptedPayload = RsaAlgorithm.encrypt(key, payload, params);

      local result = EncryptedContent();
      result.setAlgorithmType(algorithmType);
      result.setKeyLocator(keyLocator);
      result.setPayload(encryptedPayload);
      return result;
    }
    else
      throw "Unsupported encryption method";
  }
}
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

// This requires contrib/vukicevic/crunch/crunch.nut .

/**
 * The RsaAlgorithm class provides static methods to manipulate keys, encrypt
 * and decrypt using RSA.
 * @note This class is an experimental feature. The API may change.
 */
class RsaAlgorithm {
  /**
   * Generate a new random decrypt key for RSA based on the given params.
   * @param {RsaKeyParams} params The key params with the key size (in bits).
   * @return {DecryptKey} The new decrypt key (containing a PKCS8-encoded
   * private key).
   */
  static function generateKey(params)
  {
    // TODO: Implement
    throw "not implemented"
  }

  /**
   * Derive a new encrypt key from the given decrypt key value.
   * @param {Blob} keyBits The key value of the decrypt key (PKCS8-encoded
   * private key).
   * @return {EncryptKey} The new encrypt key.
   */
  static function deriveEncryptKey(keyBits)
  {
    // TODO: Implement
    throw "not implemented"
  }

  /**
   * Decrypt the encryptedData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value (PKCS8-encoded private key).
   * @param {Blob} encryptedData The data to decrypt.
   * @param {EncryptParams} params This decrypts according to
   * params.getAlgorithmType().
   * @return {Blob} The decrypted data.
   */
  static function decrypt(keyBits, encryptedData, params)
  {
    // keyBits is PKCS #8 but we need the inner RSAPrivateKey.
    local rsaPrivateKeyDer = RsaAlgorithm.getRsaPrivateKeyDer(keyBits);

    // Decode the PKCS #1 RSAPrivateKey.
    local parsedNode = DerNode.parse(rsaPrivateKeyDer.buf(), 0);
    local children = parsedNode.getChildren();
    local n = children[1].toUnsignedArray();
    local e = children[2].toUnsignedArray();
    local d = children[3].toUnsignedArray();
    local p = children[4].toUnsignedArray();
    local q = children[5].toUnsignedArray();
    local dp1 = children[6].toUnsignedArray();
    local dq1 = children[7].toUnsignedArray();

    local crunch = Crypto.getCrunch();
    // Apparently, we can't use the private key's coefficient which is inv(q, p);
    local u = crunch.inv(p, q);
    local encryptedArray = array(encryptedData.buf().len());
    encryptedData.buf().copy(encryptedArray);
    local padded = crunch.gar(encryptedArray, p, q, d, u, dp1, dq1);

    // We have to remove the padding.
    // Note that Crunch strips the leading zero.
    if (padded[0] != 0x02)
      return "Invalid decrypted value";
    local iEndZero = padded.find(0x00);
    if (iEndZero == null)
      return "Invalid decrypted value";
    local iFrom = iEndZero + 1;
    local plainData = blob(padded.len() - iFrom);
    local iTo = 0;
    while (iFrom < padded.len())
      plainData[iTo++] = padded[iFrom++];

    return Blob(Buffer.from(plainData), false);
  }

  /**
   * Encrypt the plainData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value (DER-encoded public key).
   * @param {Blob} plainData The data to encrypt.
   * @param {EncryptParams} params This encrypts according to
   * params.getAlgorithmType().
   * @return {Blob} The encrypted data.
   */
  static function encrypt(keyBits, plainData, params)
  {
    // keyBits is SubjectPublicKeyInfo but we need the inner RSAPublicKey.
    local rsaPublicKeyDer = RsaAlgorithm.getRsaPublicKeyDer(keyBits);

    // Decode the PKCS #1 RSAPublicKey.
    // TODO: Decode keyBits.
    local parsedNode = DerNode.parse(rsaPublicKeyDer.buf(), 0);
    local children = parsedNode.getChildren();
    local n = children[0].toUnsignedArray();
    local e = children[1].toUnsignedArray();

    // We have to do the padding.
    local padded = array(n.len());
    if (params.getAlgorithmType() == EncryptAlgorithmType.RsaPkcs) {
      padded[0] = 0x00;
      padded[1] = 0x02;

      // Fill with random non-zero bytes up to the end zero.
      local iEndZero = n.len() - 1 - plainData.size();
      if (iEndZero < 2)
        throw "Plain data size is too large";
      for (local i = 2; i < iEndZero; ++i) {
        local x = 0;
        while (x == 0)
          x = ((1.0 * math.rand() / RAND_MAX) * 256).tointeger();
        padded[i] = x;
      }

      padded[iEndZero] = 0x00;
      plainData.buf().copy(padded, iEndZero + 1);
    }
    else
      throw "Unsupported padding scheme";

    return Blob(Crypto.getCrunch().exp(padded, e, n));
  }

  /**
   * Decode the SubjectPublicKeyInfo, check that the algorithm is RSA, and
   * return the inner RSAPublicKey DER.
   * @param {Blob} The DER-encoded SubjectPublicKeyInfo.
   * @param {Blob} The DER-encoded RSAPublicKey.
   */
  static function getRsaPublicKeyDer(subjectPublicKeyInfo)
  {
    local parsedNode = DerNode.parse(subjectPublicKeyInfo.buf(), 0);
    local children = parsedNode.getChildren();
    local algorithmIdChildren = DerNode.getSequence(children, 0).getChildren();
/*  TODO: Finish implementing DerNode_DerOid
    local oidString = algorithmIdChildren[0].toVal();

    if (oidString != PrivateKeyStorage.RSA_ENCRYPTION_OID)
      throw "The PKCS #8 private key is not RSA_ENCRYPTION";
*/

    local payload = children[1].getPayload();
    // Remove the leading zero.
    return Blob(payload.buf().slice(1), false);
  }

  /**
   * Decode the PKCS #8 private key, check that the algorithm is RSA, and return
   * the inner RSAPrivateKey DER.
   * @param {Blob} The DER-encoded PKCS #8 private key.
   * @param {Blob} The DER-encoded RSAPrivateKey.
   */
  static function getRsaPrivateKeyDer(pkcs8PrivateKeyDer)
  {
    local parsedNode = DerNode.parse(pkcs8PrivateKeyDer.buf(), 0);
    local children = parsedNode.getChildren();
    local algorithmIdChildren = DerNode.getSequence(children, 1).getChildren();
/*  TODO: Finish implementing DerNode_DerOid
    local oidString = algorithmIdChildren[0].toVal();

    if (oidString != PrivateKeyStorage.RSA_ENCRYPTION_OID)
      throw "The PKCS #8 private key is not RSA_ENCRYPTION";
*/

    return children[2].getPayload();
  }
}
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
 * A Consumer manages fetched group keys used to decrypt a data packet in the
 * group-based encryption protocol.
 * @note This class is an experimental feature. The API may change.
 */
class Consumer {
  // The map key is the C-KEY name URI string. The value is the encoded key Blob.
  // (Use a string because we can't use the Name object as the key in Squirrel.)
  cKeyMap_ = null;

  constructor()
  {
    cKeyMap_ = {};
  }

  /**
   * Decrypt encryptedContent using keyBits.
   * @param {Blob|EncryptedContent} encryptedContent The EncryptedContent to
   * decrypt, or a Blob which is first decoded as an EncryptedContent.
   * @param {Blob} keyBits The key value.
   * @param {function} onPlainText When encryptedBlob is decrypted, this calls
   * onPlainText(decryptedBlob) with the decrypted blob.
   * @param {function} onError This calls onError(errorCode, message) for an
   * error.
   */
  static function decrypt_(encryptedContent, keyBits, onPlainText, onError)
  {
    if (encryptedContent instanceof Blob) {
      // Decode as EncryptedContent.
      local encryptedBlob = encryptedContent;
      encryptedContent = EncryptedContent();
      encryptedContent.wireDecode(encryptedBlob);
    }

    local payload = encryptedContent.getPayload();

    if (encryptedContent.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      // Prepare the parameters.
      local decryptParams = EncryptParams(EncryptAlgorithmType.AesCbc);
      decryptParams.setInitialVector(encryptedContent.getInitialVector());

      // Decrypt the content.
      local content = AesAlgorithm.decrypt(keyBits, payload, decryptParams);
      try {
        onPlainText(content);
      } catch (ex) {
        consoleLog("Error in onPlainText: " + ex);
      }
    }
    // TODO: Support RsaOaep.
    else {
      try {
        onError(EncryptError.ErrorCode.UnsupportedEncryptionScheme,
                "" + encryptedContent.getAlgorithmType());
      } catch (ex) {
        consoleLog("Error in onError: " + ex);
      }
    }
  }

  /**
   * Decrypt the data packet.
   * @param {Data} data The data packet. This does not verify the packet.
   * @param {function} onPlainText When the data packet is decrypted, this calls
   * onPlainText(decryptedBlob) with the decrypted Blob.
   * @param {function} onError This calls onError(errorCode, message) for an
   * error, where errorCode is an error code from EncryptError.ErrorCode.
   */
  function decryptContent_(data, onPlainText, onError)
  {
    // Get the encrypted content.
    local dataEncryptedContent = EncryptedContent();
    try {
      dataEncryptedContent.wireDecode(data.getContent());
    } catch (ex) {
      try {
        onError(EncryptError.ErrorCode.InvalidEncryptedFormat,
                "Error decoding EncryptedContent: " + ex);
      } catch (ex) {
        consoleLog("Error in onError: " + ex);
      }
      return;
    }
    local cKeyName = dataEncryptedContent.getKeyLocator().getKeyName();

    // Check if the content key is already in the store.
    if (cKeyName.toUri() in cKeyMap_)
      Consumer.decrypt_
        (dataEncryptedContent, cKeyMap_[cKeyName.toUri()], onPlainText, onError);
    else {
      Consumer.Error.callOnError
        (onError, "Can't find the C-KEY named cKeyName.toUri()", "");
/* TODO: Implment retrieving the C-KEY.
      // Retrieve the C-KEY Data from the network.
      var interestName = new Name(cKeyName);
      interestName.append(Encryptor.NAME_COMPONENT_FOR).append(this.groupName_);
      var interest = new Interest(interestName);

      // Prepare the callback functions.
      var thisConsumer = this;
      var onData = function(cKeyInterest, cKeyData) {
        // The Interest has no selectors, so assume the library correctly
        // matched with the Data name before calling onData.

        try {
          thisConsumer.keyChain_.verifyData(cKeyData, function(validCKeyData) {
            thisConsumer.decryptCKey_(validCKeyData, function(cKeyBits) {
              thisConsumer.cKeyMap_[cKeyName.toUri()] = cKeyBits;
              Consumer.decrypt_
                (dataEncryptedContent, cKeyBits, onPlainText, onError);
            }, onError);
          }, function(d) {
            onError(EncryptError.ErrorCode.Validation, "verifyData failed");
          });
        } catch (ex) {
          Consumer.Error.callOnError(onError, ex, "verifyData error: ");
        }
      };

      var onTimeout = function(dKeyInterest) {
        // We should re-try at least once.
        try {
          thisConsumer.face_.expressInterest
            (interest, onData, function(contentInterest) {
            onError(EncryptError.ErrorCode.Timeout, interest.getName().toUri());
           });
        } catch (ex) {
          Consumer.Error.callOnError(onError, ex, "expressInterest error: ");
        }
      };

      // Express the Interest.
      try {
        thisConsumer.face_.expressInterest(interest, onData, onTimeout);
      } catch (ex) {
        Consumer.Error.callOnError(onError, ex, "expressInterest error: ");
      }
*/
    }
  }
}
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
 * A DecryptKey supplies the key for decrypt.
 * @note This class is an experimental feature. The API may change.
 */
class DecryptKey {
  keyBits_ = null;

  /**
   * Create a DecryptKey with the given key value.
   * @param {Blob|DecryptKey} value If value is another DecryptKey then copy it.
   * Otherwise, value is the key value.
   */
  constructor(value)
  {
    if (value instanceof DecryptKey)
      // The copy constructor.
      keyBits_ = value.keyBits_;
    else {
      local keyBits = value;
      keyBits_ = keyBits instanceof Blob ? keyBits : Blob(keyBits, true);
    }
  }

  /**
   * Get the key value.
   * @return {Blob} The key value.
   */
  function getKeyBits() { return keyBits_; }
}
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
 * An EncryptKey supplies the key for encrypt.
 * @note This class is an experimental feature. The API may change.
 */
class EncryptKey {
  keyBits_ = null;

  /**
   * Create an EncryptKey with the given key value.
   * @param {Blob|EncryptKey} value If value is another EncryptKey then copy it.
   * Otherwise, value is the key value.
   */
  constructor(value)
  {
    if (value instanceof EncryptKey)
      // The copy constructor.
      keyBits_ = value.keyBits_;
    else {
      local keyBits = value;
      keyBits_ = keyBits instanceof Blob ? keyBits : Blob(keyBits, true);
    }
  }

  /**
   * Get the key value.
   * @return {Blob} The key value.
   */
  function getKeyBits() { return keyBits_; }
}
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
 * EncryptError holds the ErrorCode values for errors from the encrypt library.
 */
class EncryptError {
  ErrorCode = {
    Timeout =                     1,
    Validation =                  2,
    UnsupportedEncryptionScheme = 32,
    InvalidEncryptedFormat =      33,
    NoDecryptKey =                34,
    EncryptionFailure =           35,
    General =                     100
  }
}
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
 * PrivateKeyStorage is an abstract class which declares methods for working
 * with a private key storage. You should use a subclass.
 */
class PrivateKeyStorage {
  RSA_ENCRYPTION_OID = "1.2.840.113549.1.1.1";
  EC_ENCRYPTION_OID = "1.2.840.10045.2.1";
}
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
 * This module defines constants used by the security library.
 */

/**
 * The KeyType enum is used by the Sqlite key storage, so don't change them.
 * Make these the same as ndn-cxx in case the storage file is shared.
 */
enum KeyType {
  RSA = 0,
  ECDSA = 1,
  AES = 128
}

enum KeyClass {
  PUBLIC = 1,
  PRIVATE = 2,
  SYMMETRIC = 3
}

enum DigestAlgorithm {
  SHA256 = 1
}
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
 * KeyParams is a base class for key parameters. Its subclasses are used to
 * store parameters for key generation. You should create one of the subclasses,
 * for example RsaKeyParams.
 */
class KeyParams {
  keyType_ = 0;

  constructor(keyType)
  {
    keyType_ = keyType;
  }

  function getKeyType() { return keyType_; }
}

class RsaKeyParams extends KeyParams {
  size_ = 0;

  constructor(size = null)
  {
    base.constructor(RsaKeyParams.getType());

    if (size == null)
      size = RsaKeyParams.getDefaultSize();
    size_ = size;
  }

  function getKeySize() { return size_; }

  static function getDefaultSize() { return 2048; }

  static function getType() { return KeyType.RSA; }
}

class AesKeyParams extends KeyParams {
  size_ = 0;

  constructor(size = null)
  {
    base.constructor(AesKeyParams.getType());

    if (size == null)
      size = AesKeyParams.getDefaultSize();
    size_ = size;
  }

  function getKeySize() { return size_; }

  static function getDefaultSize() { return 64; }

  static function getType() { return KeyType.AES; }
}
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
/**
 * Copyright (C) 2017 Regents of the University of California.
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
 * A DelayedCallTable which is an internal class used by the Face implementation
 * of callLater to store callbacks and call them when they time out.
 */
class DelayedCallTable {
  table_ = null;          // Array of DelayedCallTableEntry

  constructor()
  {
    table_ = [];
  }

  /*
   * Call callback() after the given delay. This adds to the delayed call table
   * which is used by callTimedOut().
   * @param {float} delayMilliseconds: The delay in milliseconds.
   * @param {function} callback This calls callback() after the delay.
   */
  function callLater(delayMilliseconds, callback)
  {
    local entry = DelayedCallTableEntry(delayMilliseconds, callback);
    // Insert into table_, sorted on getCallTimeSeconds().
    // Search from the back since we expect it to go there.
    local i = table_.len() - 1;
    while (i >= 0) {
      if (table_[i].getCallTimeSeconds() <= entry.getCallTimeSeconds())
        break;
      --i;
    }

    // Element i is the greatest less than or equal to entry.getCallTimeSeconds(), so
    // insert after it.
    table_.insert(i + 1, entry);
  }

  /**
   * Call and remove timed-out callback entries. Since callLater does a sorted
   * insert into the delayed call table, the check for timed-out entries is
   * quick and does not require searching the entire table.
   */
  function callTimedOut()
  {
    local nowSeconds = NdnCommon.getNowSeconds();
    // table_ is sorted on _callTime, so we only need to process the timed-out
    // entries at the front, then quit.
    while (table_.len() > 0 && table_[0].getCallTimeSeconds() <= nowSeconds) {
      local entry = table_[0];
      table_.remove(0);
      entry.callCallback();
    }
  }
}

/**
 * DelayedCallTableEntry holds the callback and other fields for an entry in the
 * delayed call table.
 */
class DelayedCallTableEntry {
  callback_ = null;
  callTimeSeconds_ = 0.0;

  /*
   * Create a new DelayedCallTableEntry and set the call time based on the
   * current time and the delayMilliseconds.
   * @param {float} delayMilliseconds: The delay in milliseconds.
   * @param {function} callback This calls callback() after the delay.
   */
  constructor(delayMilliseconds, callback)
  {
    callback_ = callback;
    local nowSeconds = NdnCommon.getNowSeconds();
    callTimeSeconds_ = nowSeconds + (delayMilliseconds / 1000.0).tointeger();
  }

  /**
   * Get the time at which the callback should be called.
   * @return {float} The call time in seconds, based on NdnCommon.getNowSeconds().
   */
  function getCallTimeSeconds() { return callTimeSeconds_; }

  /**
   * Call the callback given to the constructor. This does not catch exceptions.
   */
  function callCallback() { callback_(); }
}
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
 * An InterestFilterTable is an internal class to hold a list of entries with
 * an interest Filter and its OnInterestCallback.
 */
class InterestFilterTable {
  table_ = null; // Array of InterestFilterTableEntry

  constructor()
  {
    table_ = [];
  }

  /**
   * Add a new entry to the table.
   * @param {integer} interestFilterId The ID from Node.getNextEntryId().
   * @param {InterestFilter} filter The InterestFilter for this entry.
   * @param {function} onInterest The callback to call.
   * @param {Face} face The face on which was called registerPrefix or
   * setInterestFilter which is passed to the onInterest callback.
   */
  function setInterestFilter(interestFilterId, filter, onInterest, face)
  {
    table_.append(InterestFilterTableEntry
      (interestFilterId, filter, onInterest, face));
  }

  /**
   * Find all entries from the interest filter table where the interest conforms
   * to the entry's filter, and add to the matchedFilters list.
   * @param {Interest} interest The interest which may match the filter in
   * multiple entries.
   * @param {Array<InterestFilterTableEntry>} matchedFilters Add each matching
   * InterestFilterTableEntry from the interest filter table.  The caller
   * should pass in an empty array.
   */
  function getMatchedFilters(interest, matchedFilters)
  {
    foreach (entry in table_) {
      if (entry.getFilter().doesMatch(interest.getName()))
        matchedFilters.append(entry);
    }
  }

  // TODO: unsetInterestFilter
}

/**
 * InterestFilterTable.Entry holds an interestFilterId, an InterestFilter and
 * the OnInterestCallback with its related Face.
 */
class InterestFilterTableEntry {
  interestFilterId_ = 0;
  filter_ = null;
  onInterest_ = null;
  face_ = null;

  /**
   * Create a new InterestFilterTableEntry with the given values.
   * @param {integer} interestFilterId The ID from getNextEntryId().
   * @param {InterestFilter} filter The InterestFilter for this entry.
   * @param {function} onInterest The callback to call.
   * @param {Face} face The face on which was called registerPrefix or
   * setInterestFilter which is passed to the onInterest callback.
   */
  constructor(interestFilterId, filter, onInterest, face)
  {
    interestFilterId_ = interestFilterId;
    filter_ = filter;
    onInterest_ = onInterest;
    face_ = face;
  }

  /**
   * Get the interestFilterId given to the constructor.
   * @return {integer} The interestFilterId.
   */
  function getInterestFilterId () { return interestFilterId_; }

  /**
   * Get the InterestFilter given to the constructor.
   * @return {InterestFilter} The InterestFilter.
   */
  function getFilter() { return filter_; }

  /**
   * Get the onInterest callback given to the constructor.
   * @return {function} The onInterest callback.
   */
  function getOnInterest() { return onInterest_; }

  /**
   * Get the Face given to the constructor.
   * @return {Face} The Face.
   */
  function getFace() { return face_; }
}
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
 * A PendingInterestTable is an internal class to hold a list of pending
 * interests with their callbacks.
 */
class PendingInterestTable {
  table_ = null;          // Array of PendingInterestTableEntry
  removeRequests_ = null; // Array of integer

  constructor()
  {
    table_ = [];
    removeRequests_ = [];
  }

  /**
   * Add a new entry to the pending interest table. However, if 
   * removePendingInterest was already called with the pendingInterestId, don't
   * add an entry and return null.
   * @param {integer} pendingInterestId
   * @param {Interest} interestCopy
   * @param {function} onData
   * @param {function} onTimeout
   * @param {function} onNetworkNack
   * @return {PendingInterestTableEntry} The new PendingInterestTableEntry, or
   * null if removePendingInterest was already called with the pendingInterestId.
   */
  function add(pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack)
  {
    local removeRequestIndex = removeRequests_.find(pendingInterestId);
    if (removeRequestIndex != null) {
      // removePendingInterest was called with the pendingInterestId returned by
      //   expressInterest before we got here, so don't add a PIT entry.
      removeRequests_.remove(removeRequestIndex);
      return null;
    }

    local entry = PendingInterestTableEntry
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack);
    table_.append(entry);
    return entry;
  }

  /**
   * Find all entries from the pending interest table where data conforms to
   * the entry's interest selectors, remove the entries from the table, set each
   * entry's isRemoved flag, and add to the entries list.
   * @param {Data} data The incoming Data packet to find the interest for.
   * @param {Array<PendingInterestTableEntry>} entries Add matching
   * PendingInterestTableEntry from the pending interest table. The caller
   * should pass in an empty array.
   */
  function extractEntriesForExpressedInterest(data, entries)
  {
    // Go backwards through the list so we can erase entries.
    for (local i = table_.len() - 1; i >= 0; --i) {
      local pendingInterest = table_[i];

      if (pendingInterest.getInterest().matchesData(data)) {
        entries.append(pendingInterest);
        table_.remove(i);
        // We let the callback from callLater call _processInterestTimeout,
        // but for efficiency, mark this as removed so that it returns
        // right away.
        pendingInterest.setIsRemoved();
      }
    }
  }

  // TODO: extractEntriesForNackInterest
  // TODO: removePendingInterest

  /**
   * Remove the specific pendingInterest entry from the table and set its
   * isRemoved flag. However, if the pendingInterest isRemoved flag is already
   * true or the entry is not in the pending interest table then do nothing.
   * @param {PendingInterestTableEntry} pendingInterest The Entry from the
   * pending interest table.
   * @return {bool} True if the entry was removed, false if not.
   */
  function removeEntry(pendingInterest)
  {
    if (pendingInterest.getIsRemoved())
      // extractEntriesForExpressedInterest or removePendingInterest has removed
      // pendingInterest from the table, so we don't need to look for it. Do
      // nothing.
      return false;

    local index = table_.find(pendingInterest);
    if (index == null)
      // The pending interest has been removed. Do nothing.
      return false;

    pendingInterest.setIsRemoved();
    table_.remove(index);
    return true;
  }
}

/**
 * PendingInterestTableEntry holds the callbacks and other fields for an entry
 * in the pending interest table.
 */
class PendingInterestTableEntry {
  pendingInterestId_ = 0;
  interest_ = null;
  onData_ = null;
  onTimeout_ = null;
  onNetworkNack_ = null;
  isRemoved_ = false;

  /*
   * Create a new Entry with the given fields. Note: You should not call this
   * directly but call PendingInterestTable.add.
   */
  constructor(pendingInterestId, interest, onData, onTimeout, onNetworkNack)
  {
    pendingInterestId_ = pendingInterestId;
    interest_ = interest;
    onData_ = onData;
    onTimeout_ = onTimeout;
    onNetworkNack_ = onNetworkNack;
  }

  /**
   * Get the pendingInterestId given to the constructor.
   * @return {integer} The pendingInterestId.
   */
  function getPendingInterestId() { return this.pendingInterestId_; }

  /**
   * Get the interest given to the constructor (from Face.expressInterest).
   * @return {Interest} The interest. NOTE: You must not change the interest
   * object - if you need to change it then make a copy.
   */
  function getInterest() { return this.interest_; }

  /**
   * Get the OnData callback given to the constructor.
   * @return {function} The OnData callback.
   */
  function getOnData() { return this.onData_; }

  /**
   * Get the OnNetworkNack callback given to the constructor.
   * @return {function} The OnNetworkNack callback.
   */
  function getOnNetworkNack() { return this.onNetworkNack_; }

  /**
   * Call onTimeout_ (if defined).  This ignores exceptions from onTimeout_.
   */
  function callTimeout()
  {
    if (onTimeout_ != null) {
      try {
        onTimeout_(interest_);
      } catch (ex) {
        consoleLog("Error in onTimeout: " + ex);
      }
    }
  }

  /**
   * Set the isRemoved flag which is returned by getIsRemoved().
   */
  function setIsRemoved() { isRemoved_ = true; }

  /**
   * Check if setIsRemoved() was called.
   * @return {bool} True if setIsRemoved() was called.
   */
  function getIsRemoved() { return isRemoved_; }
}
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
 * Transport is a base class for specific transport classes such as 
 * AgentDeviceTransport.
 */
class Transport {
}

/**
 * TransportConnectionInfo is a base class for connection information used by
 * subclasses of Transport.
 */
class TransportConnectionInfo {
}
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
 * A SquirrelObjectTransport extends Transport to communicate with a connection
 * object which supports "on" and "send" methods, such as an Imp agent or device
 * object. This can send a blob as well as another type of Squirrel object.
 */
class SquirrelObjectTransport extends Transport {
  elementReader_ = null;
  onReceivedObject_ = null;
  connection_ = null;

  /**
   * Set the onReceivedObject callback, replacing any previous callback.
   * @param {function} onReceivedObject If the received object is not a blob
   * then just call onReceivedObject(obj). If this is null, then don't call it.
   */
  function setOnReceivedObject(onReceivedObject)
  {
    onReceivedObject_ = onReceivedObject;
  }

  /**
   * Connect to the connection object given by connectionInfo.getConnnection(),
   * communicating with connection.on and connection.send using the message name
   * "NDN". If a received object is a Squirrel blob, make a Buffer from it and
   * use it to read an entire packet element and call
   * elementListener.onReceivedElement(element). Otherwise just call
   * onReceivedObject(obj) using the callback given to the constructor.
   * @param {SquirrelObjectTransportConnectionInfo} connectionInfo The
   * ConnectionInfo with the connection object.
   * @param {instance} elementListener The elementListener with function
   * onReceivedElement which must remain valid during the life of this object.
   * @param {function} onOpenCallback Once connected, call onOpenCallback().
   * @param {function} onClosedCallback (optional) If the connection is closed 
   * by the remote host, call onClosedCallback(). If omitted or null, don't call
   * it.
   */
  function connect
    (connectionInfo, elementListener, onOpenCallback, onClosedCallback = null)
  {
    elementReader_ = ElementReader(elementListener);
    connection_ = connectionInfo.getConnnection();

    // Add a listener to wait for a message object.
    local thisTransport = this;
    connection_.on("NDN", function(obj) {
      if (typeof obj == "blob") {
        try {
          thisTransport.elementReader_.onReceivedData(Buffer.from(obj));
        } catch (ex) {
          consoleLog("Error in onReceivedData: " + ex);
        }
      }
      else {
        if (thisTransport.onReceivedObject_ != null) {
          try {
            thisTransport.onReceivedObject_(obj);
          } catch (ex) {
            consoleLog("Error in onReceivedObject: " + ex);
          }
        }
      }
    });

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Send the object over the connection created by connect, using the message
   * name "NDN".
   * @param {blob|table} obj The object to send. If it is a blob then it is
   * processed like an NDN packet.
   */
  function sendObject(obj) 
  {
    if (connection_ == null)
      throw "not connected";
    connection_.send("NDN", obj);
  }

  /**
   * Convert the buffer to a Squirrel blob and send it over the connection
   * created by connect.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    sendObject(buffer.toBlob());
  }
}

/**
 * An SquirrelObjectTransportConnectionInfo extends TransportConnectionInfo to
 * hold the connection object.
 */
class SquirrelObjectTransportConnectionInfo extends TransportConnectionInfo {
  connection_ = null;

  /**
   * Create a new SquirrelObjectTransportConnectionInfo with the connection
   * object.
   * @param {instance} connection The connection object which supports "on" and
   * "send" methods, such as an Imp agent or device object.
   */
  constructor(connection)
  {
    connection_ = connection;
  }

  /**
   * Get the connection object given to the constructor.
   * @return {instance} The connection object.
   */
  function getConnnection() { return connection_; }
}
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
 * A MicroForwarderTransport extends Transport to communicate with a
 * MicroForwarder object. This also supports "on" and "send" methods so that
 * this can be used by SquirrelObjectTransport as the connection object (see
 * connect).
 */
class MicroForwarderTransport extends Transport {
  elementReader_ = null;
  onReceivedObject_ = null;
  onCallbacks_ = null; // array of function which takes a Squirrel object.

  /**
   * Create a MicroForwarderTransport.
   * @param {function} onReceivedObject (optional) If supplied and the received
   * object is not a blob then just call onReceivedObject(obj).
   */
  constructor(onReceivedObject = null) {
    onReceivedObject_ = onReceivedObject;
    onCallbacks_ = [];
  }

  /**
   * Connect to connectionInfo.getForwarder() by calling its addFace and using
   * this as the connection object. If a received object is a Squirrel blob,
   * make a Buffer from it and use it to read an entire packet element and call
   * elementListener.onReceivedElement(element). Otherwise just call
   * onReceivedObject(obj) using the callback given to the constructor.
   * @param {MicroForwarderTransportConnectionInfo} connectionInfo The
   * ConnectionInfo with the MicroForwarder object.
   * @param {instance} elementListener The elementListener with function
   * onReceivedElement which must remain valid during the life of this object.
   * @param {function} onOpenCallback Once connected, call onOpenCallback().
   * @param {function} onClosedCallback (optional) If the connection is closed 
   * by the remote host, call onClosedCallback(). If omitted or null, don't call
   * it.
   */
  function connect
    (connectionInfo, elementListener, onOpenCallback, onClosedCallback = null)
  {
    elementReader_ = ElementReader(elementListener);
    connectionInfo.getForwarder().addFace
      ("internal://app", SquirrelObjectTransport(),
       SquirrelObjectTransportConnectionInfo(this));

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Send the object to the MicroForwarder over the connection created by
   * connect (and to anyone else who called on("NDN", callback)).
   * @param {blob|table} obj The object to send. If it is a blob then it is
   * processed by the MicroForwarder like an NDN packet.
   */
  function sendObject(obj) 
  {
    if (onCallbacks_.len() == null)
      // There should have been at least one callback added during connect.
      throw "not connected";

    foreach (callback in onCallbacks_)
      callback(obj);
  }

  /**
   * This is overloaded with the following two forms:
   * send(buffer) - Convert the buffer to a Squirrel blob and send it to the
   * MicroForwarder over the connection created by connect (and to anyone else
   * who called on("NDN", callback)).
   * send(messageName, obj) - When the MicroForwarder calls send, if it is a
   * Squirrel blob then make a Buffer from it and use it to read an entire
   * packet element and call elementListener_.onReceivedElement(element),
   * otherwise just call onReceivedObject(obj) using the callback given to the
   * constructor.
   * @param {Buffer} buffer The bytes to send.
   * @param {string} messageName The name of the message if calling
   * send(messageName, obj). If messageName is not "NDN", do nothing.
   * @param {blob|table} obj The object if calling send(messageName, obj).
   */
  function send(arg1, obj = null)
  {
    if (arg1 instanceof Buffer)
      sendObject(arg1.toBlob());
    else {
      if (arg1 != "NDN")
        // The messageName is not "NDN". Ignore.
        return;

      if (typeof obj == "blob") {
        try {
          elementReader_.onReceivedData(Buffer.from(obj));
        } catch (ex) {
          consoleLog("Error in onReceivedData: " + ex);
        }
      }
      else {
        if (onReceivedObject_ != null) {
          try {
            onReceivedObject_(obj);
          } catch (ex) {
            consoleLog("Error in onReceivedObject: " + ex);
          }
        }
      }
    }
  }

  function on(messageName, callback)
  {
    if (messageName != "NDN")
      return;
    onCallbacks_.append(callback);
  }
}

/**
 * A MicroForwarderTransportConnectionInfo extends TransportConnectionInfo to
 * hold the MicroForwarder object to connect to.
 */
class MicroForwarderTransportConnectionInfo extends TransportConnectionInfo {
  forwarder_ = null;

  /**
   * Create a new MicroForwarderTransportConnectionInfo with the forwarder
   * object.
   * @param {MicroForwarder} forwarder (optional) The MicroForwarder to
   * communicate with. If omitted or null, use the static MicroForwarder.get().
   */
  constructor(forwarder = null)
  {
    forwarder_ = forwarder != null ? forwarder : MicroForwarder.get();
  }

  /**
   * Get the MicroForwarder object given to the constructor.
   * @return {MicroForwarder} The MicroForwarder object.
   */
  function getForwarder() { return forwarder_; }
}
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
 * A UartTransport extends Transport to communicate with a connection
 * object which supports "write" and "readblob" methods, such as an Imp uart
 * object.
 */
class UartTransport extends Transport {
  elementReader_ = null;
  uart_ = null;
  readInterval_ = 0

  /**
   * Create a UartTransport in the unconnected state.
   * @param {float} (optional) The interval in seconds for polling the UART to
   * read. If omitted, use a default value.
   */
  constructor(readInterval = 0.5)
  {
    readInterval_ = readInterval;
  }

  /**
   * Connect to the connection object given by connectionInfo.getUart(),
   * communicating with getUart().write() and getUart().readblob(). Read an
   * entire packet element and call elementListener.onReceivedElement(element).
   * This starts a timer using imp.wakeup to repeatedly read the input according
   * to the readInterval given to the constructor.
   * @param {UartTransportConnectionInfo} connectionInfo The ConnectionInfo with 
   * the uart object. This assumes you have already called configure() as needed.
   * @param {instance} elementListener The elementListener with function
   * onReceivedElement which must remain valid during the life of this object.
   * @param {function} onOpenCallback Once connected, call onOpenCallback().
   * @param {function} onClosedCallback (optional) If the connection is closed 
   * by the remote host, call onClosedCallback(). If omitted or null, don't call
   * it.
   */
  function connect
    (connectionInfo, elementListener, onOpenCallback, onClosedCallback = null)
  {
    elementReader_ = ElementReader(elementListener);
    uart_ = connectionInfo.getUart();

    // This will start the read timer.
    read();

    if (onOpenCallback != null)
      onOpenCallback();
  }

  /**
   * Write the bytes to the UART.
   * @param {Buffer} buffer The bytes to send.
   */
  function send(buffer)
  {
    uart_.write(buffer.toBlob());
  }

  /**
   * Read bytes from the uart_ and pass to the elementReader_, then use
   * imp.wakeup to call this again after readInterval_ seconds.
   */
  function read()
  {
    // Loop until there is no more data in the receive buffer.
    while (true) {
      local input = uart_.readblob();
      if (input.len() <= 0)
        break;

      elementReader_.onReceivedData(Buffer.from(input));
    }

    // Restart the read timer.
    // TODO: How to close the connection?
    local thisTransport = this;
    imp.wakeup(readInterval_, function() { thisTransport.read(); });
  }
}

/**
 * An UartTransportConnectionInfo extends TransportConnectionInfo to hold the
 * uart object.
 */
class UartTransportConnectionInfo extends TransportConnectionInfo {
  uart_ = null;

  /**
   * Create a new UartTransportConnectionInfo with the uart object.
   * @param {instance} uart The uart object which supports "write" and
   * "readblob" methods, such as hardware.uart0.
   */
  constructor(uart)
  {
    uart_ = uart;
  }

  /**
   * Get the uart object given to the constructor.
   * @return {instance} The uart object.
   */
  function getUart() { return uart_; }
}
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

enum FaceConnectStatus_ { UNCONNECTED, CONNECT_REQUESTED, CONNECT_COMPLETE }

/**
 * A Face provides the top-level interface to the library. It holds a connection
 * to a forwarder and supports interest / data exchange.
 */
class Face {
  transport_ = null;
  connectionInfo_ = null;
  pendingInterestTable_ = null;
  interestFilterTable_ = null;
  registeredPrefixTable_ = null;
  delayedCallTable_ = null;
  connectStatus_ = FaceConnectStatus_.UNCONNECTED;
  lastEntryId_ = 0;
  doingProcessEvents_ = false;
  timeoutPrefix_ = Name("/local/timeout");
  nonceTemplate_ = Blob(Buffer(4), false);

  /**
   * Create a new Face. The constructor has the forms Face() or
   * Face(transport, connectionInfo). If the default Face() constructor is
   * used, create a MicroForwarderTransport connection to the static instance
   * MicroForwarder.get(). Otherwise connect using the given transport and
   * connectionInfo.
   * @param {Transport} transport (optional) An object of a subclass of
   * Transport to use for communication. If supplied, you must also supply a
   * connectionInfo.
   * @param {TransportConnectionInfo} connectionInfo (optional) This must be a
   * ConnectionInfo from the same subclass of Transport as transport.
   */
  constructor(transport = null, connectionInfo = null)
  {
    if (transport == null) {
      transport_ = MicroForwarderTransport();
      connectionInfo_ = MicroForwarderTransportConnectionInfo();
    }
    else {
      transport_ = transport;
      connectionInfo_ = connectionInfo;
    }

    pendingInterestTable_ = PendingInterestTable();
    interestFilterTable_ = InterestFilterTable();
// TODO    registeredPrefixTable_ = RegisteredPrefixTable(interestFilterTable_);
    delayedCallTable_ = DelayedCallTable()
  }

  /**
   * Send the interest through the transport, read the entire response and call
   * onData, onTimeout or onNetworkNack as described below.
   * There are two forms of expressInterest. The first form takes the exact
   * interest (including lifetime):
   * expressInterest(interest, onData [, onTimeout] [, onNetworkNack] [, wireFormat]).
   * The second form creates the interest from a name and optional interest template:
   * expressInterest(name [, template], onData [, onTimeout] [, onNetworkNack] [, wireFormat]).
   * @param {Interest} interest The Interest to send which includes the interest
   * lifetime for the timeout.
   * @param {function} onData When a matching data packet is received, this
   * calls onData(interest, data) where interest is the interest given to
   * expressInterest and data is the received Data object. NOTE: You must not
   * change the interest object - if you need to change it then make a copy.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {function} onTimeout (optional) If the interest times out according
   * to the interest lifetime, this calls onTimeout(interest) where interest is
   * the interest given to expressInterest.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {function} onNetworkNack (optional) When a network Nack packet for
   * the interest is received and onNetworkNack is not null, this calls
   * onNetworkNack(interest, networkNack) and does not call onTimeout. interest
   * is the sent Interest and networkNack is the received NetworkNack. If
   * onNetworkNack is supplied, then onTimeout must be supplied too. However, if 
   * a network Nack is received and onNetworkNack is null, do nothing and wait
   * for the interest to time out. (Therefore, an application which does not yet
   * process a network Nack reason treats a Nack the same as a timeout.)
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   * @param {Name} name The Name for the interest. (only used for the second
   * form of expressInterest).
   * @param {Interest} template (optional) If not omitted, copy the interest 
   * selectors from this Interest. If omitted, use a default interest lifetime.
   * (only used for the second form of expressInterest).
   * @param {WireFormat} (optional) A WireFormat object used to encode the
   * message. If omitted, use WireFormat.getDefaultWireFormat().
   * @return {integer} The pending interest ID which can be used with
   * removePendingInterest.
   * @throws string If the encoded interest size exceeds
   * Face.getMaxNdnPacketSize().
   */
  function expressInterest
    (interestOrName, arg2 = null, arg3 = null, arg4 = null, arg5 = null,
     arg6 = null)
  {
    local interestCopy;
    if (interestOrName instanceof Interest)
      // Just use a copy of the interest.
      interestCopy = Interest(interestOrName);
    else {
      // The first argument is a name. Make the interest from the name and
      // possible template.
      if (arg2 instanceof Interest) {
        local template = arg2;
        // Copy the template.
        interestCopy = Interest(template);
        interestCopy.setName(interestOrName);

        // Shift the remaining args to be processed below.
        arg2 = arg3;
        arg3 = arg4;
        arg4 = arg5;
        arg5 = arg6;
      }
      else {
        // No template.
        interestCopy = Interest(interestOrName);
        // Use a default timeout.
        interestCopy.setInterestLifetimeMilliseconds(4000.0);
      }
    }

    local onData = arg2;
    local onTimeout;
    local onNetworkNack;
    local wireFormat;
    // arg3,       arg4,          arg5 may be:
    // OnTimeout,  OnNetworkNack, WireFormat
    // OnTimeout,  OnNetworkNack, null
    // OnTimeout,  WireFormat,    null
    // OnTimeout,  null,          null
    // WireFormat, null,          null
    // null,       null,          null
    if (typeof arg3 == "function")
      onTimeout = arg3;
    else
      onTimeout = function() {};

    if (typeof arg4 == "function")
      onNetworkNack = arg4;
    else
      onNetworkNack = null;

    if (arg3 instanceof WireFormat)
      wireFormat = arg3;
    else if (arg4 instanceof WireFormat)
      wireFormat = arg4;
    else if (arg5 instanceof WireFormat)
      wireFormat = arg5;
    else
      wireFormat = WireFormat.getDefaultWireFormat();

    local pendingInterestId = getNextEntryId();

    // Set the nonce in our copy of the Interest so it is saved in the PIT.
    interestCopy.setNonce(Face.nonceTemplate_);
    interestCopy.refreshNonce();

    // TODO: Handle async connect.
    connectSync();
    expressInterestHelper_
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack,
       wireFormat);

    return pendingInterestId;
  }

  /**
   * Do the work of reconnectAndExpressInterest once we know we are connected.
   * Add to the pendingInterestTable_ and call transport_.send to send the
   * interest.
   * @param {integer} pendingInterestId The getNextEntryId() for the pending
   * interest ID which expressInterest got so it could return it to the caller.
   * @param {Interest} interestCopy The Interest to send, which has already
   * been copied.
   * @param {function} onData A function object to call when a matching data
   * packet is received.
   * @param {function} onTimeout A function to call if the interest times out.
   * If onTimeout is null, this does not use it.
   * @param {function} onNetworkNack A function to call when a network Nack
   * packet is received. If onNetworkNack is null, this does not use it.
   * @param {WireFormat} wireFormat A WireFormat object used to encode the
   * message.
   */
  function expressInterestHelper_
    (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack,
     wireFormat)
  {
    local pendingInterest = pendingInterestTable_.add
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack);
    if (pendingInterest == null)
      // removePendingInterest was already called with the pendingInterestId.
      return;

    if (onTimeout != null ||
        interestCopy.getInterestLifetimeMilliseconds() != null &&
        interestCopy.getInterestLifetimeMilliseconds() >= 0.0) {
      // Set up the timeout.
      local delayMilliseconds = interestCopy.getInterestLifetimeMilliseconds()
      if (delayMilliseconds == null || delayMilliseconds < 0.0)
        // Use a default timeout delay.
        delayMilliseconds = 4000.0;

      local thisFace = this;
      callLater
        (delayMilliseconds,
         function() { thisFace.processInterestTimeout_(pendingInterest); });
   }

    // Special case: For timeoutPrefix we don't actually send the interest.
    if (!Face.timeoutPrefix_.match(interestCopy.getName())) {
      local encoding = interestCopy.wireEncode(wireFormat);
      if (encoding.size() > Face.getMaxNdnPacketSize())
        throw
          "The encoded interest size exceeds the maximum limit getMaxNdnPacketSize()";

      transport_.send(encoding.buf());
    }
  }

  // TODO: setCommandSigningInfo
  // TODO: setCommandCertificateName
  // TODO: makeCommandInterest

  /**
   * Add an entry to the local interest filter table to call the onInterest
   * callback for a matching incoming Interest. This method only modifies the
   * library's local callback table and does not register the prefix with the
   * forwarder. It will always succeed. To register a prefix with the forwarder,
   * use registerPrefix. There are two forms of setInterestFilter.
   * The first form uses the exact given InterestFilter:
   * setInterestFilter(filter, onInterest).
   * The second form creates an InterestFilter from the given prefix Name:
   * setInterestFilter(prefix, onInterest).
   * @param {InterestFilter} filter The InterestFilter with a prefix and 
   * optional regex filter used to match the name of an incoming Interest. This
   * makes a copy of filter.
   * @param {Name} prefix The Name prefix used to match the name of an incoming
   * Interest.
   * @param {function} onInterest When an Interest is received which matches the
   * filter, this calls
   * onInterest(prefix, interest, face, interestFilterId, filter).
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   */
  function setInterestFilter(filterOrPrefix, onInterest)
  {
    local interestFilterId = getNextEntryId();
    interestFilterTable_.setInterestFilter
      (interestFilterId, InterestFilter(filterOrPrefix), onInterest, this);
    return interestFilterId;
  }

  /**
   * The OnInterest callback calls this to put a Data packet which satisfies an
   * Interest.
   * @param {Data} data The Data packet which satisfies the interest.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode the Data packet. If omitted, use WireFormat.getDefaultWireFormat().
   * @throws Error If the encoded Data packet size exceeds getMaxNdnPacketSize().
   */
  function putData(data, wireFormat = null)
  {
    local encoding = data.wireEncode(wireFormat);
    if (encoding.size() > Face.getMaxNdnPacketSize())
      throw
        "The encoded Data packet size exceeds the maximum limit getMaxNdnPacketSize()";

    transport_.send(encoding.buf());
  }

  /**
   * Call callbacks such as onTimeout. This returns immediately if there is
   * nothing to process. This blocks while calling the callbacks. You should
   * repeatedly call this from an event loop, with calls to sleep as needed so
   * that the loop doesn't use 100% of the CPU. Since processEvents modifies the
   * pending interest table, your application should make sure that it calls
   * processEvents in the same thread as expressInterest (which also modifies
   * the pending interest table).
   * If you call this from an main event loop, you may want to catch and
   * log/disregard all exceptions.
   */
  function processEvents()
  {
    if (doingProcessEvents_)
      // Avoid loops where a callback eventually calls processEvents again.
      return;

    doingProcessEvents_ = true;
    try {
      delayedCallTable_.callTimedOut();
      doingProcessEvents_ = false;
    } catch (ex) {
      doingProcessEvents_ = false;
      throw ex;
    }
  }

  /**
   * This is a simple form of registerPrefix to register with a local forwarder
   * where the transport (such as MicroForwarderTransport) supports "sendObject"
   * to communicate using Squirrel objects, avoiding the time and code space
   * to encode/decode control packets. Register the prefix with the forwarder
   * and call onInterest when a matching interest is received.
   * @param {Name} prefix The Name prefix.
   * @param {function} onInterest (optional) If not null, this creates an
   * interest filter from prefix so that when an Interest is received which
   * matches the filter, this calls
   * onInterest(prefix, interest, face, interestFilterId, filter).
   * NOTE: You must not change the prefix object - if you need to change it then
   * make a copy. If onInterest is null, it is ignored and you must call
   * setInterestFilter.
   * NOTE: The library will log any exceptions thrown by this callback, but for
   * better error handling the callback should catch and properly handle any
   * exceptions.
   */
  function registerPrefixUsingObject(prefix, onInterest = null)
  {
    // TODO: Handle async connect.
    connectSync();

    // TODO: Handle async register.
    transport_.sendObject({
      type = "rib/register",
      nameUri = prefix.toUri()
    });

    if (onInterest != null)
      setInterestFilter(InterestFilter(prefix), onInterest);
  }

  /**
   * Get the practical limit of the size of a network-layer packet. If a packet
   * is larger than this, the library or application MAY drop it.
   * @return {integer} The maximum NDN packet size.
   */
  static function getMaxNdnPacketSize() { return NdnCommon.MAX_NDN_PACKET_SIZE; }

  /**
   * Call callback() after the given delay. This is not part of the public API 
   * of Face.
   * @param {float} delayMilliseconds The delay in milliseconds.
   * @param {float} callback This calls callback() after the delay.
   */
  function callLater(delayMilliseconds, callback)
  {
    delayedCallTable_.callLater(delayMilliseconds, callback);
  }

  /**
   * This is used in callLater for when the pending interest expires. If the
   * pendingInterest is still in the pendingInterestTable_, remove it and call
   * its onTimeout callback.
   */
  function processInterestTimeout_(pendingInterest)
  {
    if (pendingInterestTable_.removeEntry(pendingInterest))
      pendingInterest.callTimeout();
  }

  /**
   * An internal method to get the next unique entry ID for the pending interest
   * table, interest filter table, etc. Most entry IDs are for the pending
   * interest table (there usually are not many interest filter table entries)
   * so we use a common pool to only have to have one method which is called by
   * Face.
   *
   * @return {integer} The next entry ID.
   */
  function getNextEntryId() { return ++lastEntryId_; }

  /**
   * If connectionStatus_ is not already CONNECT_COMPLETE, do a synchronous
   * transport_connect and set the status to CONNECT_COMPLETE.
   */
  function connectSync()
  {
    if (connectStatus_ != FaceConnectStatus_.CONNECT_COMPLETE) {
      transport_.connect(connectionInfo_, this, null);
      connectStatus_ = FaceConnectStatus_.CONNECT_COMPLETE;
    }
  }

  /**
   * This is called by the transport's ElementReader to process an entire
   * received element such as a Data or Interest packet.
   * @param {Buffer} element The bytes of the incoming element.
   */
  function onReceivedElement(element)
  {
    // Clear timed-out Interests in case the application doesn't call processEvents.
    processEvents();

    local lpPacket = null;
    // Use Buffer.get to avoid using the metamethod.
    if (element.get(0) == Tlv.LpPacket_LpPacket)
      // TODO: Support LpPacket.
      throw "not supported";

    // First, decode as Interest or Data.
    local interest = null;
    local data = null;
    if (element.get(0) == Tlv.Interest || element.get(0) == Tlv.Data) {
      local decoder = TlvDecoder (element);
      if (decoder.peekType(Tlv.Interest, element.len())) {
        interest = Interest();
        interest.wireDecode(element, TlvWireFormat.get());

        if (lpPacket != null)
          interest.setLpPacket(lpPacket);
      }
      else if (decoder.peekType(Tlv.Data, element.len())) {
        data = Data();
        data.wireDecode(element, TlvWireFormat.get());

        if (lpPacket != null)
          data.setLpPacket(lpPacket);
      }
    }

    if (lpPacket != null) {
      // We have decoded the fragment, so remove the wire encoding to save memory.
      lpPacket.setFragmentWireEncoding(Blob());

      // TODO: Check for NetworkNack.
    }

    // Now process as Interest or Data.
    if (interest != null) {
      // Call all interest filter callbacks which match.
      local matchedFilters = [];
      interestFilterTable_.getMatchedFilters(interest, matchedFilters);
      foreach (entry in matchedFilters) {
        try {
          entry.getOnInterest()
            (entry.getFilter().getPrefix(), interest, this,
             entry.getInterestFilterId(), entry.getFilter());
        } catch (ex) {
          consoleLog("Error in onInterest: " + ex);
        }
      }
    }
    else if (data != null) {
      local pendingInterests = [];
      pendingInterestTable_.extractEntriesForExpressedInterest
        (data, pendingInterests);
      // Process each matching PIT entry (if any).
      foreach (pendingInterest in pendingInterests) {
        try {
          pendingInterest.getOnData()(pendingInterest.getInterest(), data);
        } catch (ex) {
          consoleLog("Error in onData: " + ex);
        }
      }
    }
  }
}
