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
 * minimum capacity, resizing if necessary.
 */
class DynamicBlobArray {
  array_ = null;        // blob
  wrappedArray_ = null; // Buffer

  /**
   * Create a new DynamicBlobArray with an initial size.
   * @param initialSize The initial size of the allocated array.
   */
  constructor(initialSize)
  {
    array_ = blob(initialSize);
  }

  /**
   * Ensure that the array has the minimal size, resizing it if necessary.
   * The new size of the array may be greater than the given size. 
   * @param {integer} length The minimum length for the array.
   */
  function ensureSize(size)
  {
    // array_.len() is always the full size of the array.
    if (array_.len() >= size)
      return;

    // See if double is enough.
    local newSize = array_.len() * 2;
    if (size > newSize)
      // The needed size is much greater, so use it.
      newSize = size;

    // Instead of using resize, we manually copy to a new blob so that
    // array_.len() will be the full size.
    local newArray = blob(newSize);
    newArray.writeblob(array_);
    array_ = newArray;
    wrappedArray_ = null;
  }

  /**
   * Copy the given array into this object's array, using ensureSize to make
   * sure there is enough room.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   * @param {offset} The offset in this object's array to copy to.
   */
  function copy(buffer, offset)
  {
    ensureSize(offset + buffer.len());

    // We want to use Buffer.copy, so we need array_ as a Buffer.
    if (wrappedArray_ == null)
      wrappedArray_ = Buffer.from(array_);
    buffer.copy(wrappedArray_, offset);
  }

  /**
   * Resize this object's array to the given size, transfer the bytes to a Blob
   * and return the Blob. Finally, set this object's array to null to prevent
   * further use.
   * @param {integer} size The final size of the allocated array.
   * @return {Blob} A new NDN Blob with the bytes from the array.
   */
  function finish(size)
  {
    array_.resize(size);
    local result = Blob(array_, false);
    array_ = null;
    return result;
  }
}
