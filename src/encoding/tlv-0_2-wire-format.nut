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
 * A Tlv0_2WireFormat has methods for encoding and decoding with the NDN-TLV
 * wire format, version 0.2.
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

  // TODO encodeInterest
  // TODO decodeInterest

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

    local result = encoder.writeNestedTlv
      (Tlv.Data, encodeDataValue_, data, false);

    result.encoding <- encoder.finish();
    return result;
  }

  /**
   * This is called by writeNestedTlv to write the TLVs in the body of the Data
   * value.
   * @param {Data} data The Data object which was passed to writeTlv.
   * @param {TlvEncoder} encoder The TlvEncoder which is calling this.
   * @return {table} A table with fields (signedPortionBeginOffset,
   * signedPortionEndOffset) where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion.
   */
  static function encodeDataValue_(data, encoder)
  {
    local result = {};
    result.signedPortionBeginOffset <- encoder.offset_;

    Tlv0_2WireFormat.encodeName_(data.getName(), encoder);
    encoder.writeNestedTlv
      (Tlv.MetaInfo, Tlv0_2WireFormat.encodeMetaInfoValue_, data.getMetaInfo(),
       false);
    encoder.writeBlobTlv(Tlv.Content, data.getContent().buf());
    Tlv0_2WireFormat.encodeSignatureInfo_(data.getSignature(), encoder);

    result.signedPortionEndOffset <- encoder.offset_;

    encoder.writeBlobTlv
      (Tlv.SignatureValue, data.getSignature().getSignature().buf());

    return result;
  }

  /**
   * Decode input as an NDN-TLV data packet, set the fields in the data object,
   * and return the signed offsets.
   * @param {Data} data The Data object whose fields are updated.
   * @param {blob} input The Squirrel blob with the bytes to decode.  This
   * decodes starting from input[0], ignoring the location of the blob pointer
   * given by input.tell(). This does not update the blob pointer.
   * @return {table} A table with fields (signedPortionBeginOffset,
   * signedPortionEndOffset) where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion.
   */
  function decodeData(data, input)
  {
    local decoder = TlvDecoder(input);

    local endOffset = decoder.readNestedTlvsStart(Tlv.Data);
    local signedPortionBeginOffset = decoder.getOffset();

    decodeName_(data.getName(), decoder);
    decodeMetaInfo_(data.getMetaInfo(), decoder);
    data.setContent(Blob(decoder.readBlobTlv(Tlv.Content), true));
    decodeSignatureInfo_(data, decoder);

    local signedPortionEndOffset = decoder.getOffset();
    data.getSignature().setSignature
      (Blob(decoder.readBlobTlv(Tlv.SignatureValue), true));

    decoder.finishNestedTlvs(endOffset);
    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
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
   * @return {table} A table with fields signedPortionBeginOffset and
   * signedPortionEndOffset where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion. The signed
   * portion starts from the first name component and ends just before the final
   * name component (which is assumed to be a signature for a signed interest).
   */
  static function encodeName_(name, encoder)
  {
    local nameValueLength = 0;

    for (local i = 0; i < name.size(); ++i)
      nameValueLength += TlvEncoder.sizeOfBlobTlv
        (name.get(i).type_, name.get(i).getValue().size());

    encoder.writeTypeAndLength(Tlv.Name, nameValueLength);
    local signedPortionBeginOffset = encoder.offset_;
    local signedPortionEndOffset;

    if (name.size() == 0)
      // There is no "final component", so set signedPortionEndOffset arbitrarily.
      signedPortionEndOffset = signedPortionBeginOffset;
    else {
      for (local i = 0; i < name.size(); ++i) {
        if (i == name.size() - 1)
          // We will begin the final component.
          signedPortionEndOffset = encoder.offset_;

        encodeNameComponent_(name.get(i), encoder);
      }
    }

    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * Clear the name, decode a Name from the decoder and set the fields of the
   * name object.
   * @param {Name} name The name object whose fields are updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   * @return {table} A table with fields signedPortionBeginOffset and
   * signedPortionEndOffset where signedPortionBeginOffset is the offset in the
   * encoding of the beginning of the signed portion, and signedPortionEndOffset
   * is the offset in the encoding of the end of the signed portion. The signed
   * portion starts from the first name component and ends just before the final
   * name component (which is assumed to be a signature for a signed interest).
   */
  static function decodeName_(name, decoder)
  {
    name.clear();

    local endOffset = decoder.readNestedTlvsStart(Tlv.Name);
    local signedPortionBeginOffset = decoder.getOffset();
    // In case there are no components, set signedPortionEndOffset arbitrarily.
    local signedPortionEndOffset = signedPortionBeginOffset;

    while (decoder.getOffset() < endOffset) {
      signedPortionEndOffset = decoder.getOffset();
      name.append(decodeNameComponent_(decoder));
    }

    decoder.finishNestedTlvs(endOffset);

    return { signedPortionBeginOffset = signedPortionBeginOffset,
             signedPortionEndOffset = signedPortionEndOffset };
  }

  /**
   * This is called by writeNestedTlv to write the TLVs in the body of the
   * KeyLocator value.
   * @param {KeyLocator} keyLocator The KeyLocator which was passed to writeTlv.
   * @param {TlvEncoder} encoder The TlvEncoder which is calling this.
   */
  static function encodeKeyLocatorValue_(keyLocator, encoder)
  {
    if (keyLocator.getType() == null || keyLocator.getType() < 0)
      return;

    if (keyLocator.getType() == KeyLocatorType.KEYNAME)
      Tlv0_2WireFormat.encodeName_(keyLocator.getKeyName(), encoder);
    else if (keyLocator.getType() == KeyLocatorType.KEY_LOCATOR_DIGEST &&
             keyLocator.getKeyData().size() > 0)
      encoder.writeBlobTlv(Tlv.KeyLocatorDigest, keyLocator.getKeyData().buf());
    else
      return NDN_ERROR_unrecognized_ndn_KeyLocatorType;
  }

  /**
   * This is called by writeNestedTlv to write the TLVs in the body of the
   * SignatureInfo value, where the Signature has a KeyLocator, e.g.
   * SignatureSha256WithRsa.
   * @param {Signature} signature The Signature object which was passed to
   * writeTlv.
   * @param {TlvEncoder} encoder The TlvEncoder which is calling this.
   */
  static function encodeSignatureWithKeyLocatorValue_(signature, encoder)
  {
    local signatureType;
    if (signature instanceof Sha256WithRsaSignature)
      signatureType = Tlv.SignatureType_SignatureSha256WithRsa;
    // TODO: Sha256WithEcdsaSignature.
    // TODO: HmacWithSha256Signature.
    else
      throw "encodeSignatureInfo: Unrecognized Signature object type";

    encoder.writeNonNegativeIntegerTlv(Tlv.SignatureType, signatureType);
    encoder.writeNestedTlv
      (Tlv.KeyLocator, Tlv0_2WireFormat.encodeKeyLocatorValue_,
       signature.getKeyLocator(), false);
  }

  /**
   * Clear the name, decode a KeyLocator from the decoder and set the fields of
   * the keyLocator object.
   * @param {integer} expectedType The expected type of the TLV.
   * @param {KeyLocator} keyLocator The KeyLocator object whose fields are
   * updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   */
  static function decodeKeyLocator_(expectedType, keyLocator, decoder)
  {
    local endOffset = decoder.readNestedTlvsStart(expectedType);

    keyLocator.clear();

    if (decoder.getOffset() == endOffset)
      // The KeyLocator is omitted, so leave the fields as none.
      return;

    if (decoder.peekType(Tlv.Name, endOffset)) {
      // KeyLocator is a Name.
      keyLocator.setType(KeyLocatorType.KEYNAME);
      decodeName_(keyLocator.getKeyName(), decoder);
    }
    else if (decoder.peekType(Tlv.KeyLocatorDigest, endOffset)) {
      // KeyLocator is a KeyLocatorDigest.
      keyLocator.setType(KeyLocatorType.KEY_LOCATOR_DIGEST);
      keyLocator.setKeyData(decoder.readBlobTlv(Tlv.KeyLocatorDigest));
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

      encoder.writeArray(encoding.buf(), 0, encoding.size());
      return;
    }

    if (signature instanceof Sha256WithRsaSignature)
      encoder.writeNestedTlv
        (Tlv.SignatureInfo, encodeSignatureWithKeyLocatorValue_, signature,
         false);
    // TODO: Sha256WithEcdsaSignature.
    // TODO: HmacWithSha256Signature.
    // TODO: DigestSha256Signature.
    else
      throw "encodeSignatureInfo: Unrecognized Signature object type";
  }

  /**
   * Decode an NDN-TLV SignatureInfo from the decoder and set the Data object
   * with a new Signature object.
   * @param {Data} data This calls data.setSignature with a new Signature object.
   * @param {TlvDecoder} decoder The decoder with the input.
   */
  static function decodeSignatureInfo_(data, decoder)
  {
    local beginOffset = decoder.getOffset();
    local endOffset = decoder.readNestedTlvsStart(Tlv.SignatureInfo);

    local signatureType = decoder.readNonNegativeIntegerTlv(Tlv.SignatureType);
    if (signatureType == Tlv.SignatureType_SignatureSha256WithRsa) {
      data.setSignature(Sha256WithRsaSignature());
      // Modify data's signature object because if we create an object
      //   and set it, then data will have to copy all the fields.
      local signatureInfo = data.getSignature();
      decodeKeyLocator_(Tlv.KeyLocator, signatureInfo.getKeyLocator(), decoder);
    }
    else if (signatureType == Tlv.SignatureType_SignatureHmacWithSha256) {
      data.setSignature(HmacWithSha256Signature());
      local signatureInfo = data.getSignature();
      decodeKeyLocator_(Tlv.KeyLocator, signatureInfo.getKeyLocator(), decoder);
    }
    else if (signatureType == Tlv.SignatureType_DigestSha256)
      data.setSignature(DigestSha256Signature());
    else {
      data.setSignature(GenericSignature());
      local signatureInfo = data.getSignature();

      // Get the bytes of the SignatureInfo TLV.
      signatureInfo.setSignatureInfoEncoding
        (Blob(decoder.getSlice(beginOffset, endOffset), true), signatureType);
    }

    decoder.finishNestedTlvs(endOffset);
  }

  /**
   * This is called by writeNestedTlv to write the TLVs in the body of the
   * MetaInfo value.
   * @param {MetaInfo} metaInfo The MetaInfo which was passed to writeTlv.
   * @param {TlvEncoder} encoder The TlvEncoder which is calling this.
   */
  static function encodeMetaInfoValue_(metaInfo, encoder)
  {
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

    encoder.writeOptionalNonNegativeIntegerTlvFromFloat
      (Tlv.FreshnessPeriod, metaInfo.getFreshnessPeriod());
    local finalBlockIdBuf = metaInfo.getFinalBlockId().getValue().buf();
    if (finalBlockIdBuf != null && finalBlockIdBuf.len() > 0) {
      // The FinalBlockId has an inner NameComponent.
      encoder.writeTypeAndLength
        (Tlv.FinalBlockId, TlvEncoder.sizeOfBlobTlv
         (metaInfo.getFinalBlockId().type_, finalBlockIdBuf.len()));
      Tlv0_2WireFormat.encodeNameComponent_(metaInfo.getFinalBlockId(), encoder);
    }
  }

  /**
   * Clear the name, decode a MetaInfo from the decoder and set the fields of
   * the metaInfo object.
   * @param {MetaInfo} metaInfo The MetaInfo object whose fields are updated.
   * @param {TlvDecoder} decoder The decoder with the input.
   */
  static function decodeMetaInfo_(metaInfo, decoder)
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
      metaInfo.setFinalBlockId(decodeNameComponent_(decoder));
      decoder.finishNestedTlvs(finalBlockIdEndOffset);
    }
    else
      metaInfo.setFinalBlockId(null);

    decoder.finishNestedTlvs(endOffset);
  }
}
