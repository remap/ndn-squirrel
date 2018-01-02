/**
 * Copyright (C) 2016-2018 Regents of the University of California.
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
