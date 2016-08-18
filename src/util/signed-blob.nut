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
   * @param {Blob|SignedBlob|Buffer|blob|array<number>|string} value (optional)
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
