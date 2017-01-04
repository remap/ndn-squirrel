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
