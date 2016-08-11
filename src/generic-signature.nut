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
 * A GenericSignature extends Signature and holds the encoding bytes of the
 * SignatureInfo so that the application can process experimental signature
 * types. When decoding a packet, if the type of SignatureInfo is not
 * recognized, the library creates a GenericSignature.
 */
class GenericSignature {
  signature_ = null;
  signatureInfoEncoding_ = null;
  typeCode_ = null;
  changeCount_ = 0;

  /**
   * Create a new GenericSignature object, possibly copying values from another
   * object.
   * @param {GenericSignature} value (optional) If value is a GenericSignature,
   * copy its values.  If value is omitted, the signature is unspecified.
   */
  constructor(value = null)
  {
    if (value instanceof GenericSignature) {
      // The copy constructor.
      signature_ = value.signature_;
      signatureInfoEncoding_ = value.signatureInfoEncoding_;
      typeCode_ = value.typeCode_;
    }
    else {
      signature_ = Blob();
      signatureInfoEncoding_ = Blob();
      typeCode_ = null;
    }
  }

  /**
   * Get the data packet's signature bytes.
   * @return {Blob} The signature bytes. If not specified, the value isNull().
   */
  function getSignature() { return signature_; }

  /**
   * Get the bytes of the entire signature info encoding (including the type
   * code).
   * @return {Blob} The encoding bytes. If not specified, the value isNull().
   */
  function getSignatureInfoEncoding() { return signatureInfoEncoding_; }

  /**
   * Get the type code of the signature type. When wire decode calls
   * setSignatureInfoEncoding, it sets the type code. Note that the type code
   * is ignored during wire encode, which simply uses getSignatureInfoEncoding()
   * where the encoding already has the type code.
   * @return {integer} The type code, or null if not known.
   */
  function getTypeCode () { return typeCode_; }

  /**
   * Set the data packet's signature bytes.
   * @param {Blob} signature
   */
  function setSignature(signature)
  {
    signature_ = signature instanceof Blob ? signature : Blob(signature);
    ++changeCount_;
  }

  /**
   * Set the bytes of the entire signature info encoding (including the type
   * code).
   * @param {Blob} signatureInfoEncoding A Blob with the encoding bytes.
   * @param {integer} (optional) The type code of the signature type, or null if
   * not known. (When a GenericSignature is created by wire decoding, it sets
   * the typeCode.)
   */
  function setSignatureInfoEncoding(signatureInfoEncoding, typeCode = null)
  {
    signatureInfoEncoding_ = signatureInfoEncoding instanceof Blob ?
      signatureInfoEncoding : Blob(signatureInfoEncoding);
    typeCode_ = typeCode;
    ++changeCount_;
  }

  /**
   * Get the change count, which is incremented each time this object (or a
   * child object) is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
