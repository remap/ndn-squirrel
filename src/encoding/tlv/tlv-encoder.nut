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
  offset_ = 0;
  enableOutput_ = true;

  /**
   * Create a new TlvEncoder to use a DynamicBlobArray with the initialSize.
   * When done, you should call getOutput().
   * @param initialSize The initial size of output buffer.
   */
  constructor(initialSize)
  {
    output_ = DynamicBlobArray(initialSize);
  }

  /**
   * Return the number of bytes to encode varNumber as a VAR-NUMBER in NDN-TLV.
   * @param {integer} varNumber The number to encode.
   * @return {integer} The number of bytes to encode varNumber.
   */
  static function sizeOfVarNumber(varNumber)
  {
    if (varNumber < 0)
      throw "TlvEncoder: Can have a negative VAR-NUMBER";
   
    if (varNumber < 253)
      return 1;
    else if (varNumber <= 0xffff)
      return 3;
    else
      return 5;
/* TODO: Can Squirrel have a 64-bit integer?
    else if (varNumber <= 0xffffffff)
      return 5;
    else
      return 9;
*/
  }

  /**
   * A private function to do the work of writeVarNumber, assuming that
   * enableOutput_ is true.
   * @param {integer} varNumber The number to encode.
   */
  function writeVarNumberEnabled_(varNumber)
  {
    if (varNumber < 0)
      throw "TlvEncoder: Can have a negative VAR-NUMBER";

    if (varNumber < 253) {
      output_.ensureSize(offset_ + 1);
      output_.array_[offset_++] = varNumber;
    }
    else if (varNumber <= 0xffff) {
      output_.ensureSize(offset_ + 3);
      output_.array_[offset_++] = 253;
      output_.array_[offset_++] = (varNumber >> 8) & 0xff;
      output_.array_[offset_++] =  varNumber & 0xff;
    }
    else {
      output_.ensureSize(offset_ + 5);
      output_.array_[offset_++] = 254;
      output_.array_[offset_++] = (varNumber >> 24) & 0xff;
      output_.array_[offset_++] = (varNumber >> 16) & 0xff;
      output_.array_[offset_++] = (varNumber >> 8)  & 0xff;
      output_.array_[offset_++] =  varNumber & 0xff;
    }
    // TODO: Can Squirrel have a 64-bit integer?
  }

  /**
   * Encode varNumber as a VAR-NUMBER in NDN-TLV and write it to the output. If
   * enableOutput_ is false, just advance offset_ without writing to the output.
   * @param {integer} varNumber The number to encode.
   */
  function writeVarNumber(varNumber)
  {
    if (enableOutput_)
      writeVarNumberEnabled_(varNumber);
    else
      // Just advance offset_.
      offset_ + sizeOfVarNumber(varNumber);
  }

  /**
   * Write the type and length to the output. If enableOutput_ is false, just
   * advance offset_ without writing to the output.
   * @param {integer} type the type of the TLV.
   * @param {integer} length The length of the TLV.
   */
  function writeTypeAndLength(type, length)
  {
    if (enableOutput_) {
      writeVarNumberEnabled_(type);
      writeVarNumberEnabled_(length);
    }
    else
      // Just advance offset_.
      offset_ += sizeOfVarNumber(type) + sizeOfVarNumber(length);
  }

  /**
   * Return the number of bytes to encode value as a non-negative integer.
   * @param (integer) value The integer to encode.
   * @return (integer) The number of bytes to encode value.
   */
  static function sizeOfNonNegativeInteger(value)
  {
    if (value < 0)
      throw "TlvEncoder: Non-negative integer cannot be negative";

    if (value <= 0xff)
      return 1;
    else if (value <= 0xffff)
      return 2;
    else
      return 4;
/* TODO: Can Squirrel have a 64-bit integer?
    else if (value <= 0xffffffff)
      return 4;
    else
      return 8;
*/
  }

  /**
   * A private function to do the work of writeNonNegativeInteger, assuming that
   * enableOutput_ is true.
   * @param (integer) value The integer to encode.
   */
  function writeNonNegativeIntegerEnabled_(value)
  {
    if (value < 0)
      throw "TlvEncoder: Non-negative integer cannot be negative";

    if (value <= 0xff) {
      output_.ensureSize(offset_ + 1);
      output_.array_[offset_++] = value;
    }
    else if (value <= 0xffff) {
      output_.ensureSize(offset_ + 2);
      output_.array_[offset_++] = (value >> 8) & 0xff;
      output_.array_[offset_++] =  value & 0xff;
    }
    else {
      output_.ensureSize(offset_ + 4);
      output_.array_[offset_++] = (value >> 24) & 0xff;
      output_.array_[offset_++] = (value >> 16) & 0xff;
      output_.array_[offset_++] = (value >> 8)  & 0xff;
      output_.array_[offset_++] =  value & 0xff;
    }
    // TODO: Can Squirrel have a 64-bit integer?
  }

  /**
   * Encode value as a non-negative integer in NDN-TLV and write it to the 
   * output. If enableOutput_ is false, just advance offset_ without writing to
   * the output. This does not write a type or length for the value.
   * @param {integer} value The integer to encode.
   */
  function writeNonNegativeInteger(value)
  {
    if (enableOutput_)
      writeNonNegativeIntegerEnabled_(value);
    else
      // Just advance offset_.
      offset_ += sizeOfNonNegativeInteger(value);
  }

  /**
   * Return the number of bytes to encode the type, length and blob value.
   * @param {integer} type the type of the TLV.
   * @param {integer} blobLength The length of the blob value.
   * @return {number} The number of bytes to encode the TLV.
   */
  static function sizeOfBlobTlv(type, blobLength)
  {
    return sizeOfVarNumber(type) + sizeOfVarNumber(blobLength) + blobLength;
  }

  /**
   * Do the work of writeBuffer, assuming that enableOutput_ is true. This
   * updates offset_.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   */
  function writeBufferEnabled(buffer)
  {
    if (buffer != null) {
      output_.copy(buffer, offset_);
      offset_ += buffer.len();
    }
  }

  /**
   * Copy the bytes of the buffer to the output. Note that this does not encode 
   * a type and length; for that see writeBlobTlv. If enableOutput_ is false,
   * just advance offset_ without writing to the output.
   * @param {Buffer} buffer A Buffer with the bytes to copy.
   */
  function writeBuffer(buffer)
  {
    if (enableOutput_)
      writeBufferEnabled(buffer);
    else
      // Just advance offset_.
      offset_ += buffer.len();
  }

  /**
   * A private function to do the work of writeBlobTlv, assuming that
   * enableOutput_ is true.
   * @param {integer} type the type of the TLV.
   * @param {Buffer} value A Buffer with the bytes to copy.
   */
  function writeBlobTlvEnabled_(type, value)
  {
    writeTypeAndLength(type, value.len());
    writeBufferEnabled(value);
  }

  /**
   * Write the type, then the length of the blob then the blob value to the 
   * output. If enableOutput_ is false, just advance offset_ without writing to
   * the output.
   * @param {integer} type the type of the TLV.
   * @param {Buffer} value A Buffer with the bytes to copy.
   */
  function writeBlobTlv(type, value)
  {
    if (enableOutput_)
      writeBlobTlvEnabled_(type, value);
    else
      // Just advance offset_.
      offset_ += sizeOfBlobTlv(type, value.len());
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
   * Write the type, then the length of the encoded value then encode value as a
   * non-negative integer and write it to the output. If enableOutput_ is false,
   * then just advance offset_ without writing to the output. (If you want to
   * just write the non-negative integer, use writeNonNegativeInteger.)
   * @param {integer} type the type of the TLV.
   * @param {integer} value The integer to encode.
   */
  function writeNonNegativeIntegerTlv(type, value)
  {
    local sizeOfInteger = sizeOfNonNegativeInteger(value);
    if (enableOutput_) {
      writeTypeAndLength(type, sizeOfInteger);
      writeNonNegativeIntegerEnabled_(value);
    }
    else
      // Just advance offset_.
      offset_ += sizeOfVarNumber(type) + sizeOfVarNumber(sizeOfInteger) +
        sizeOfInteger;
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
   * Make a first pass to call writeValue with enableOutput_ = false to
   * determine the length of the TLV. Then set enableOutput_ = true and write
   * the type and length to the output and call writeValue again to write the
   * TLVs in the body of the value. This is to solve the problem of finding the
   * length when the value of a TLV has nested TLVs. However, if enableOutput_
   * is already false when this is called, then just advance offset_ without
   * writing to the output.
   * @param {integer} type the type of the TLV.
   * @param {function} writeValue A function that writes the TLVs in the body of
   * the value. This calls writeValue(context, this) and returns its result.
   * @param {instance} context An object which is passed to writeValue.
   * @param {bool} omitZeroLength (optional) If true and the TLV length is zero,
   * then don't write anything. If omitted or false, and the TLV length is zero,
   * write the type and length.
   * @return The result of calling  writeValue(context, this), or null if
   * enableOutput_ is already false when this is called.
   */
  function writeNestedTlv(type, writeValue, context, omitZeroLength = false)
  {
    local originalEnableOutput = enableOutput_;

    // Make a first pass to get the value length by setting enableOutput_ false.
    local saveOffset = offset_;
    enableOutput_ = false;
    writeValue(context, this);
    local valueLength = offset_ - saveOffset;

    if (omitZeroLength && valueLength == 0) {
      // Omit the optional TLV.
      enableOutput_ = originalEnableOutput;
      return null;
    }

    if (originalEnableOutput) {
      // Restore the offset and enableOutput.
      offset_ = saveOffset;
      enableOutput_ = true;

      // Now, write the output.
      writeTypeAndLength(type, valueLength);
      return writeValue(context, this);
    }
    else {
      // The output was originally disabled. Just advance offset further by the
      // type and length.
      writeTypeAndLength(type, valueLength);
      return null;
    }
  }

  /**
   * Resize the output array to offset_, transfer the bytes to a Blob
   * and return the Blob. Finally, set this object's output array to null to
   * prevent further use.
   * @return {Blob} A new NDN Blob with the output.
   */
  function finish()
  {
    return output_.finish(offset_);
  }
}
