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

// These correspond to the TLV codes.
enum EncryptAlgorithmType {
  AesEcb = 0,
  AesCbc = 1,
  RsaPkcs = 2,
  RsaOaep = 3
}

/**
 * An EncryptParams holds an algorithm type and other parameters used to encrypt
 * and decrypt.
 */
class EncryptParams {
  algorithmType_ = 0;
  initialVector_ = null;

  /**
   * Create an EncryptParams with the given parameters.
   * @param {integer} algorithmType The algorithm type from the
   * EncryptAlgorithmType enum, or null if not specified.
   * @param {integer} initialVectorLength (optional) The initial vector length,
   * or 0 if the initial vector is not specified. If omitted, the initial
   * vector is not specified.
   * @note This class is an experimental feature. The API may change.
   */
  constructor(algorithmType, initialVectorLength = null)
  {
    algorithmType_ = algorithmType;

    if (initialVectorLength != null && initialVectorLength > 0) {
      local initialVector = Buffer(initialVectorLength);
      Crypto.generateRandomBytes(initialVector);
      initialVector_ = Blob(initialVector, false);
    }
    else
      initialVector_ = Blob();
  }

  /**
   * Get the algorithmType.
   * @return {integer} The algorithm type from the EncryptAlgorithmType enum,
   * or null if not specified.
   */
  function getAlgorithmType() { return algorithmType_; }

  /**
   * Get the initial vector.
   * @return {Blob} The initial vector. If not specified, isNull() is true.
   */
  function getInitialVector() { return initialVector_; }

  /**
   * Set the algorithm type.
   * @param {integer} algorithmType The algorithm type from the
   * EncryptAlgorithmType enum. If not specified, set to null.
   * @return {EncryptParams} This EncryptParams so that you can chain calls to
   * update values.
   */
  function setAlgorithmType(algorithmType)
  {
    algorithmType_ = algorithmType;
    return this;
  }

  /**
   * Set the initial vector.
   * @param {Blob} initialVector The initial vector. If not specified, set to
   * the default Blob() where isNull() is true.
   * @return {EncryptParams} This EncryptParams so that you can chain calls to
   * update values.
   */
  function setInitialVector(initialVector)
  {
    this.initialVector_ =
      initialVector instanceof Blob ? initialVector : Blob(initialVector, true);
    return this;
  }
}
