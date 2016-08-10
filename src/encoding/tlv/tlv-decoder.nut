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
   * @param {blob} input The Squirrel blob with the bytes to decode. This
   * decodes starting from input[0], ignoring the location of the blob pointer
   * given by input.tell(). This does not update the blob pointer.
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
   * @return {blob} The bytes in the value as a Squirrel blob.  This is a copy
   * of the bytes in the input buffer.
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
   * @return {Buffer} The bytes in the value as a Squirrel blob or null if the
   * next TLV doesn't have the expected type. This is a copy of the bytes in the
   * input buffer.
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
   * Return an array of a slice of the input for the given offset range.
   * @param {integer} beginOffset The offset in the input of the beginning of the
   * slice.
   * @param {integer} endOffset The offset in the input of the end of the slice.
   * @return {blob} The bytes in the value as a Squirrel blob.  This is a copy
   * of the bytes in the input buffer.
   */
  function getSlice(beginOffset, endOffset)
  {
    // TODO: Can Squirrel do slice without copy?
    // Set and restore the read/write pointer.
    local savePointer = input_.tell();
    input_.seek(beginOffset);
    local result = input_.readblob(endOffset - beginOffset);

    input_.seek(savePointer);
    return result;
  };
}
