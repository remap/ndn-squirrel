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
 * Encryptor has static constants and utility methods for encryption, such as
 * encryptData.
 */
class Encryptor {
  NAME_COMPONENT_FOR = NameComponent("FOR");
  NAME_COMPONENT_READ = NameComponent("READ");
  NAME_COMPONENT_SAMPLE = NameComponent("SAMPLE");
  NAME_COMPONENT_ACCESS = NameComponent("ACCESS");
  NAME_COMPONENT_E_KEY = NameComponent("E-KEY");
  NAME_COMPONENT_D_KEY = NameComponent("D-KEY");
  NAME_COMPONENT_C_KEY = NameComponent("C-KEY");

  /**
   * Prepare an encrypted data packet by encrypting the payload using the key
   * according to the params. In addition, this prepares the encoded
   * EncryptedContent with the encryption result using keyName and params. The
   * encoding is set as the content of the data packet. If params defines an
   * asymmetric encryption algorithm and the payload is larger than the maximum
   * plaintext size, this encrypts the payload with a symmetric key that is
   * asymmetrically encrypted and provided as a nonce in the content of the data
   * packet. The packet's /<dataName>/ is updated to be <dataName>/FOR/<keyName>.
   * @param {Data} data The data packet which is updated.
   * @param {Blob} payload The payload to encrypt.
   * @param {Name} keyName The key name for the EncryptedContent.
   * @param {Blob} key The encryption key value.
   * @param {EncryptParams} params The parameters for encryption.
   */
  static function encryptData(data, payload, keyName, key, params)
  {
    data.getName().append(Encryptor.NAME_COMPONENT_FOR).append(keyName);

    local algorithmType = params.getAlgorithmType();

    if (algorithmType == EncryptAlgorithmType.AesCbc ||
        algorithmType == EncryptAlgorithmType.AesEcb) {
      local content = Encryptor.encryptSymmetric_(payload, key, keyName, params);
      data.setContent(content.wireEncode(TlvWireFormat.get()));
    }
    // TODO: Support RsaPkcs and RsaOaep.
    else
      throw "Unsupported encryption method";
  }

  /**
   * Encrypt the payload using the symmetric key according to params, and return
   * an EncryptedContent.
   * @param {Blob} payload The data to encrypt.
   * @param {Blob} key The key value.
   * @param {Name} keyName The key name for the EncryptedContent key locator.
   * @param {EncryptParams} params The parameters for encryption.
   * @return {EncryptedContent} A new EncryptedContent.
   */
  static function encryptSymmetric_(payload, key, keyName, params)
  {
    local algorithmType = params.getAlgorithmType();
    local initialVector = params.getInitialVector();
    local keyLocator = KeyLocator();
    keyLocator.setType(KeyLocatorType.KEYNAME);
    keyLocator.setKeyName(keyName);

    if (algorithmType == EncryptAlgorithmType.AesCbc ||
        algorithmType == EncryptAlgorithmType.AesEcb) {
      if (algorithmType == EncryptAlgorithmType.AesCbc) {
        if (initialVector.size() != AesAlgorithm.BLOCK_SIZE)
          throw "Incorrect initial vector size";
      }

      local encryptedPayload = AesAlgorithm.encrypt(key, payload, params);

      local result = EncryptedContent();
      result.setAlgorithmType(algorithmType);
      result.setKeyLocator(keyLocator);
      result.setPayload(encryptedPayload);
      result.setInitialVector(initialVector);
      return result;
    }
  }
}
