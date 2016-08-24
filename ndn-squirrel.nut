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
   */
  constructor(value)
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
      // Just copy the string. Don't UTF-8 decode.
      blob_ = ::blob(value.len());
      // Don't use writestring since Standard Squirrel doesn't have it.
      foreach (x in value)
        blob_.writen(x, 'b');

      len_ = value.len();
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
   * @param {Buffer|blob} target The Buffer or Squirrel blob to copy to.
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

    // TODO: Do a bounds check?
    local result = ::Buffer.from(blob_);
    // Fix offset_ and len_.
    result.offset_ = offset_ + start;
    result.len_ = end - start;
    return result;
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
      foreach (x in this)
        result += ::format("%02x", x);

      return result;
    }
    else if (encoding == "raw") {
      // Don't use readstring since Standard Squirrel doesn't have it.
      local result = "";
      // TODO: Does Squirrel have a StringBuffer?
      // TODO: Is there a better way to convert an integer to a string character?
      const CHARS = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";
      foreach (x in this)
        result += CHARS.slice(x, x + 1);

      return result;
    }
    else
      throw "Unrecognized type";
  }

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
        if (buffer_[i] != other.buffer_[i])
          return false;
      }

      return true;
    }
  }
}
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

    for (local i = startIndex; i < endIndex; ++i)
      value[i] = (1.0 * math.rand() / RAND_MAX) * 256;
  }
}
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
   */
  function copy(buffer, offset)
  {
    ensureLength(offset + buffer.len());
    buffer.copy(array_, offset);
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
  // TODO fromNumber.
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

  // TODO: set(uri).

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

  // TODO: getPrefix.

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

  // TODO: fromEscapedString
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

  // TODO: toUri.
  // TODO: matches.

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
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
    local firstOctet = input_[offset_];
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
      result = ((input_[offset_] << 8) +
                 input_[offset_ + 1]);
      offset_ += 2;
    }
    else if (firstOctet == 254) {
      // Use abs because << 24 can set the high bit of the 32-bit int making it negative.
      result = (math.abs(input_[offset_] << 24) +
                        (input_[offset_ + 1] << 16) +
                        (input_[offset_ + 2] << 8) +
                         input_[offset_ + 3]);
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
      result = input_[offset_];
    else if (length == 2)
      result = ((input_[offset_] << 8) +
                 input_[offset_ + 1]);
    else if (length == 4)
      // Use abs because << 24 can set the high bit of the 32-bit int making it negative.
      result = (math.abs(input_[offset_] << 24) +
                        (input_[offset_ + 1] << 16) +
                        (input_[offset_ + 2] << 8) +
                         input_[offset_ + 3]);
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
    var linkWireEncoding = interest.getLinkWireEncoding(this);
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
   * Get a singleton instance of a Tlv0_2WireFormat.  To always use the
   * preferred version NDN-TLV, you should use TlvWireFormat.get().
   * @return {Tlv0_2WireFormat} The singleton instance.
   */
  static function get() { return Tlv0_2WireFormat_instance; }

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
    // TODO: HmacWithSha256Signature.
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
Tlv0_2WireFormat_instance <- Tlv0_2WireFormat();
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
  static function get() { return TlvWireFormat_instance; }
}

// We use a global variable because static member variables are immutable.
TlvWireFormat_instance <- TlvWireFormat();

// On loading this code, make this the default wire format.
WireFormat.setDefaultWireFormat(TlvWireFormat.get());
