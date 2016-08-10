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

class Tlv0_2WireFormat {
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
   * @param {blob} input The Squirrel blob with the bytes to decode.  This
   * decodes starting from input[0], ignoring the location of the blob pointer
   * given by input.tell(). This does not update the blob pointer.
   */
  function decodeName(name, input)
  {
    local decoder = TlvDecoder(input);
    decodeName_(name, decoder);
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
   * @return {NameComponent} A new NameComponent.
   */
  static function decodeNameComponent_(decoder)
  {
    local savePosition = decoder.getOffset();
    local type = decoder.readVarNumber();
    // Restore the position.
    decoder.seek(savePosition);

    local value = Blob(decoder.readBlobTlv(type), true);
    if (type == Tlv.ImplicitSha256DigestComponent)
      return NameComponent.fromImplicitSha256Digest(value);
    else
      return NameComponent(value);
  }

  /**
   * Encode the name to the encoder.
   * @param {Name} name The name to encode.
   * @param {TlvEncoder} encoder The encoder to receive the encoding.
   * @return {array<integer>} An array with
   * [signedPortionBeginOffset, signedPortionEndOffset] where
   * signedPortionBeginOffset is the offset in the encoding of the beginning of
   * the signed portion, and signedPortionEndOffset is the offset in the encoding
   * of the end of the signed portion. The signed portion starts from the first
   * name component and ends just before the final name component (which is
   * assumed to be a signature for a signed interest).
   */
  static function encodeName_(name, encoder)
  {
    local resultOffsets = [0, 0];
    local nameValueLength = 0;

    for (local i = 0; i < name.size(); ++i)
      nameValueLength += TlvEncoder.sizeOfBlobTlv
        (name.get(i).type_, name.get(i).getValue().size());

    encoder.writeTypeAndLength(Tlv.Name, nameValueLength);
    resultOffsets[0] = encoder.offset_;

    if (name.size() == 0)
      // There is no "final component", so set signedPortionEndOffset arbitrarily.
      resultOffsets[1] = resultOffsets[0];
    else {
      for (local i = 0; i < name.size(); ++i) {
        if (i == name.size() - 1)
          // We will begin the final component.
          resultOffsets[1] = encoder.offset_;

        encodeNameComponent_(name.get(i), encoder);
      }
    }

    return resultOffsets;
  }

  /**
   * Clear the name, decode a Name from the decoder and set the fields of the
   * name object.
   * @param {Name} name The name object whose fields are updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @return {array<integer>} An array with
   * [signedPortionBeginOffset, signedPortionEndOffset] where
   * signedPortionBeginOffset is the offset in the encoding of the beginning of
   * the signed portion, and signedPortionEndOffset is the offset in the encoding
   * of the end of the signed portion. The signed portion starts from the first
   * name component and ends just before the final name component (which is
   * assumed to be a signature for a signed interest).
   */
  static function decodeName_(name, decoder)
  {
    name.clear();
    local resultOffsets = [0, 0];

    local endOffset = decoder.readNestedTlvsStart(Tlv.Name);
    resultOffsets[0] = decoder.getOffset();
    // In case there are no components, set signedPortionEndOffset arbitrarily.
    resultOffsets[1] = resultOffsets[0];

    while (decoder.getOffset() < endOffset) {
      resultOffsets[1] = decoder.getOffset();
      name.append(decodeNameComponent_(decoder));
    }

    decoder.finishNestedTlvs(endOffset);
    return resultOffsets;
  }
}
