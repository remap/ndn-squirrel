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
 * A Consumer manages fetched group keys used to decrypt a data packet in the
 * group-based encryption protocol.
 * @note This class is an experimental feature. The API may change.
 */
class Consumer {
  // The map key is the C-KEY name URI string. The value is the encoded key Blob.
  // (Use a string because we can't use the Name object as the key in Squirrel.)
  cKeyMap_ = null;

  constructor()
  {
    cKeyMap_ = {};
  }

  /**
   * Decrypt encryptedContent using keyBits.
   * @param {Blob|EncryptedContent} encryptedContent The EncryptedContent to
   * decrypt, or a Blob which is first decoded as an EncryptedContent.
   * @param {Blob} keyBits The key value.
   * @param {function} onPlainText When encryptedBlob is decrypted, this calls
   * onPlainText(decryptedBlob) with the decrypted blob.
   * @param {function} onError This calls onError(errorCode, message) for an
   * error.
   */
  static function decrypt_(encryptedContent, keyBits, onPlainText, onError)
  {
    if (encryptedContent instanceof Blob) {
      // Decode as EncryptedContent.
      local encryptedBlob = encryptedContent;
      encryptedContent = EncryptedContent();
      encryptedContent.wireDecode(encryptedBlob);
    }

    local payload = encryptedContent.getPayload();

    if (encryptedContent.getAlgorithmType() == EncryptAlgorithmType.AesCbc) {
      // Prepare the parameters.
      local decryptParams = EncryptParams(EncryptAlgorithmType.AesCbc);
      decryptParams.setInitialVector(encryptedContent.getInitialVector());

      // Decrypt the content.
      local content = AesAlgorithm.decrypt(keyBits, payload, decryptParams);
      try {
        onPlainText(content);
      } catch (ex) {
        consoleLog("Error in onPlainText: " + ex);
      }
    }
    // TODO: Support RsaOaep.
    else {
      try {
        onError(EncryptError.ErrorCode.UnsupportedEncryptionScheme,
                "" + encryptedContent.getAlgorithmType());
      } catch (ex) {
        consoleLog("Error in onError: " + ex);
      }
    }
  }

  /**
   * Decrypt the data packet.
   * @param {Data} data The data packet. This does not verify the packet.
   * @param {function} onPlainText When the data packet is decrypted, this calls
   * onPlainText(decryptedBlob) with the decrypted Blob.
   * @param {function} onError This calls onError(errorCode, message) for an
   * error, where errorCode is an error code from EncryptError.ErrorCode.
   */
  function decryptContent_(data, onPlainText, onError)
  {
    // Get the encrypted content.
    local dataEncryptedContent = EncryptedContent();
    try {
      dataEncryptedContent.wireDecode(data.getContent());
    } catch (ex) {
      try {
        onError(EncryptError.ErrorCode.InvalidEncryptedFormat,
                "Error decoding EncryptedContent: " + ex);
      } catch (ex) {
        consoleLog("Error in onError: " + ex);
      }
      return;
    }
    local cKeyName = dataEncryptedContent.getKeyLocator().getKeyName();

    // Check if the content key is already in the store.
    if (cKeyName.toUri() in cKeyMap_)
      Consumer.decrypt_
        (dataEncryptedContent, cKeyMap_[cKeyName.toUri()], onPlainText, onError);
    else {
      Consumer.Error.callOnError
        (onError, "Can't find the C-KEY named cKeyName.toUri()", "");
/* TODO: Implment retrieving the C-KEY.
      // Retrieve the C-KEY Data from the network.
      var interestName = new Name(cKeyName);
      interestName.append(Encryptor.NAME_COMPONENT_FOR).append(this.groupName_);
      var interest = new Interest(interestName);

      // Prepare the callback functions.
      var thisConsumer = this;
      var onData = function(cKeyInterest, cKeyData) {
        // The Interest has no selectors, so assume the library correctly
        // matched with the Data name before calling onData.

        try {
          thisConsumer.keyChain_.verifyData(cKeyData, function(validCKeyData) {
            thisConsumer.decryptCKey_(validCKeyData, function(cKeyBits) {
              thisConsumer.cKeyMap_[cKeyName.toUri()] = cKeyBits;
              Consumer.decrypt_
                (dataEncryptedContent, cKeyBits, onPlainText, onError);
            }, onError);
          }, function(d) {
            onError(EncryptError.ErrorCode.Validation, "verifyData failed");
          });
        } catch (ex) {
          Consumer.Error.callOnError(onError, ex, "verifyData error: ");
        }
      };

      var onTimeout = function(dKeyInterest) {
        // We should re-try at least once.
        try {
          thisConsumer.face_.expressInterest
            (interest, onData, function(contentInterest) {
            onError(EncryptError.ErrorCode.Timeout, interest.getName().toUri());
           });
        } catch (ex) {
          Consumer.Error.callOnError(onError, ex, "expressInterest error: ");
        }
      };

      // Express the Interest.
      try {
        thisConsumer.face_.expressInterest(interest, onData, onTimeout);
      } catch (ex) {
        Consumer.Error.callOnError(onError, ex, "expressInterest error: ");
      }
*/
    }
  }
}
