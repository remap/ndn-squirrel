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
 * A Blob holds an immutable byte array implemented as a Squirrel blob. This
 * should be treated like a string which is a pointer to an immutable string.
 * (It is OK to pass a pointer to the string because the new owner can’t change
 * the bytes of the string.)  Instead you must call buf() to get the byte array
 * which reminds you that you should not change the contents.  Also remember
 * that buf() can return null.
 */
class Blob {
  buffer_ = null;

  /**
   * Create a new Blob which holds an immutable array of bytes.
   * @param {Blob|blob|array<number>|string} value (optional) If value is a Blob,
   * take another pointer to its Squirrel blob without copying. If value is a
   * Squirrel blob or byte array, copy to create a new blob. If value is a
   * string, treat it as "raw" and copy to a blob without UTF-8 encoding.  If
   * omitted, buf() will return null.
   * @param {bool} copy (optional) If true, copy the contents of value into a 
   * new Squirrel blob. If value is a Squirrel blob, copy the entire array,
   * ignoring the location of its blob pointer given by value.tell().  If copy
   * is false, and value is a Squirrel blob, just it without copying. If omitted,
   * then copy the contents (unless value is already a Blob).
   * IMPORTANT: If copy is false, if you keep a pointer to the value then you
   * must treat the value as immutable and promise not to change it.
   */
  constructor(value = null, copy = true)
  {
    local valueType = typeof value;

    if (value == null)
      buffer_ = null;
    else if (Blob.isBlob(value))
      // Use the existing buffer.  Don't need to check for copy.
      buffer_ = value.buffer_;
    else if (valueType == "string") {
      // Just copy the string. Don't UTF-8 decode.
      buffer_ = blob(value.len());
      // Don't use writestring since Standard Squirrel doesn't have it.
      foreach (x in value)
        buffer_.writen(x, 'b');
      buffer_.seek(0);
    }
    else if (valueType == "array") {
      // Assume the array has integer values.
      buffer_ = blob(value.len());
      foreach (x in value)
        buffer_.writen(x, 'b');
      buffer_.seek(0);
    }
    else if (valueType == "blob") {
      if (copy) {
        // Copy the value blob. Set and restore its read/write pointer.
        local savePointer = value.tell();
        value.seek(0);
        buffer_ = value.readblob(value.len());

        value.seek(savePointer);
      }
      else
        buffer_ = value;
    }
    else
      throw "Blob constructor: Unrecognized value type " + valueType;
  }

  /**
   * Return the length of the immutable byte array.
   * @return {number} The length of the array.  If buf() is null, return 0.
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
   * @return {blob} The Squirrel blob holding the immutable byte array, or null.
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

    // TODO: Does Squirrel have a StringBuffer?
    local result = "";
    foreach (x in buffer_)
      result += format("%02x", x);

    return result;
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

    // Don't use readstring since Standard Squirrel doesn't have it.
    local result = "";
    // TODO: Does Squirrel have a StringBuffer?
    // TODO: Is there a better way to convert an integer to a string character?
    const CHARS = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2a\x2b\x2c\x2d\x2e\x2f\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3a\x3b\x3c\x3d\x3e\x3f\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4a\x4b\x4c\x4d\x4e\x4f\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5a\x5b\x5c\x5d\x5e\x5f\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6a\x6b\x6c\x6d\x6e\x6f\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7a\x7b\x7c\x7d\x7e\x7f\x80\x81\x82\x83\x84\x85\x86\x87\x88\x89\x8a\x8b\x8c\x8d\x8e\x8f\x90\x91\x92\x93\x94\x95\x96\x97\x98\x99\x9a\x9b\x9c\x9d\x9e\x9f\xa0\xa1\xa2\xa3\xa4\xa5\xa6\xa7\xa8\xa9\xaa\xab\xac\xad\xae\xaf\xb0\xb1\xb2\xb3\xb4\xb5\xb6\xb7\xb8\xb9\xba\xbb\xbc\xbd\xbe\xbf\xc0\xc1\xc2\xc3\xc4\xc5\xc6\xc7\xc8\xc9\xca\xcb\xcc\xcd\xce\xcf\xd0\xd1\xd2\xd3\xd4\xd5\xd6\xd7\xd8\xd9\xda\xdb\xdc\xdd\xde\xdf\xe0\xe1\xe2\xe3\xe4\xe5\xe6\xe7\xe8\xe9\xea\xeb\xec\xed\xee\xef\xf0\xf1\xf2\xf3\xf4\xf5\xf6\xf7\xf8\xf9\xfa\xfb\xfc\xfd\xfe\xff";
    foreach (x in buffer_)
      result += CHARS.slice(x, x + 1);
      
    return result;
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

  function _typeof() {
    return "Blob";
  }

  /**
   * Check if the object is an instance of Blob or a subclass of Blob.
   * TODO: Can Squirrel check instanceof Blob, including subclasses?
   * @param {instance} obj The object to check.
   * @return {bool} True if the object is an instance of Blob.
   */
  static function isBlob(obj)
  {
    local objType = typeof obj;
    return objType == "Blob" || objType == "SignedBlob";
  }
}
