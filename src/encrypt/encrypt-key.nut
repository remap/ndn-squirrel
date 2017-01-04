/**
 * Copyright (C) 2016-2017 Regents of the University of California.
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
 * An EncryptKey supplies the key for encrypt.
 * @note This class is an experimental feature. The API may change.
 */
class EncryptKey {
  keyBits_ = null;

  /**
   * Create an EncryptKey with the given key value.
   * @param {Blob|EncryptKey} value If value is another EncryptKey then copy it.
   * Otherwise, value is the key value.
   */
  constructor(value)
  {
    if (value instanceof EncryptKey)
      // The copy constructor.
      keyBits_ = value.keyBits_;
    else {
      local keyBits = value;
      keyBits_ = keyBits instanceof Blob ? keyBits : Blob(keyBits, true);
    }
  }

  /**
   * Get the key value.
   * @return {Blob} The key value.
   */
  function getKeyBits() { return keyBits_; }
}
