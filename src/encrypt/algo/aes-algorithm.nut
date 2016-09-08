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

// This requires contrib/aes-squirrel/aes.class.nut .

/**
 * The AesAlgorithm class provides static methods to manipulate keys, encrypt
 * and decrypt using the AES symmetric key cipher.
 * @note This class is an experimental feature. The API may change.
 */
class AesAlgorithm {
  /**
   * Generate a new random decrypt key for AES based on the given params.
   * @param {AesKeyParams} params The key params with the key size (in bits).
   * @return {DecryptKey} The new decrypt key.
   */
  static function generateKey(params)
  {
    // Convert the key bit size to bytes.
    local key = blob(params.getKeySize() / 8); 
    Crypto.generateRandomBytes(key);

    return DecryptKey(Blob(key, false));
  }

  /**
   * Derive a new encrypt key from the given decrypt key value.
   * @param {Blob} keyBits The key value of the decrypt key.
   * @return {EncryptKey} The new encrypt key.
   */
  static function deriveEncryptKey(keyBits) { return EncryptKey(keyBits); }

  /**
   * Decrypt the encryptedData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value.
   * @param {Blob} encryptedData The data to decrypt.
   * @param {EncryptParams} params This decrypts according to
   * params.getAlgorithmType() and other params as needed such as
   * params.getInitialVector().
   * @return {Blob} The decrypted data.
   */
  static function decrypt(keyBits, encryptedData, params)
  {
    local paddedData;
    if (params.getAlgorithmType() == EncryptAlgorithmType.AesEcb) {
      local cipher = AES(keyBits.buf().toBlob());
      // For the aes-squirrel package, we have to process each ECB block.
      local input = encryptedData.buf().toBlob();
      paddedData = blob(input.len());

      for (local i = 0; i < paddedData.len(); i += 16) {
        // TODO: Do we really have to copy once with readblob and again with writeblob?
        input.seek(i);
        paddedData.writeblob(cipher.decrypt(input.readblob(16)));
      }
    }
    else if (params.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      local cipher = AES_CBC
        (keyBits.buf().toBlob(), params.getInitialVector().buf().toBlob());
      paddedData = cipher.decrypt(encryptedData.buf().toBlob());
    }
    else
      throw "Unsupported encryption mode";

    // For the aes-squirrel package, we have to remove the padding.
    local padLength = paddedData[paddedData.len() - 1];
    return Blob
      (Buffer.from(paddedData).slice(0, paddedData.len() - padLength), false);
  }

  /**
   * Encrypt the plainData using the keyBits according the encrypt params.
   * @param {Blob} keyBits The key value.
   * @param {Blob} plainData The data to encrypt.
   * @param {EncryptParams} params This encrypts according to
   * params.getAlgorithmType() and other params as needed such as
   * params.getInitialVector().
   * @return {Blob} The encrypted data.
   */
  static function encrypt(keyBits, plainData, params)
  {
    // For the aes-squirrel package, we have to do the padding.
    local padLength = 16 - (plainData.size() % 16);
    local paddedData = blob(plainData.size() + padLength);
    plainData.buf().copy(paddedData);
    for (local i = 0; i < padLength; ++i)
      paddedData[plainData.size() + i] = padLength;

    local encrypted;
    if (params.getAlgorithmType() == EncryptAlgorithmType.AesEcb) {
      local cipher = AES(keyBits.buf().toBlob());
      // For the aes-squirrel package, we have to process each ECB block.
      encrypted = blob(paddedData.len());

      for (local i = 0; i < paddedData.len(); i += 16) {
        // TODO: Do we really have to copy once with readblob and again with writeblob?
        paddedData.seek(i);
        encrypted.writeblob(cipher.encrypt(paddedData.readblob(16)));
      }
    }
    else if (params.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      local cipher = AES_CBC
        (keyBits.buf().toBlob(), params.getInitialVector().buf().toBlob());
      encrypted = cipher.encrypt(paddedData);
    }
    else
      throw "Unsupported encryption mode";

    return Blob(Buffer.from(encrypted), false);
  }
}
