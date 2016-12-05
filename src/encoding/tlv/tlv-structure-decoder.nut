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
