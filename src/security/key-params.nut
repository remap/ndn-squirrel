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
 * KeyParams is a base class for key parameters. Its subclasses are used to
 * store parameters for key generation. You should create one of the subclasses,
 * for example RsaKeyParams.
 */
class KeyParams {
  keyType_ = 0;

  constructor(keyType)
  {
    keyType_ = keyType;
  }

  function getKeyType() { return keyType_; }
}

class AesKeyParams extends KeyParams {
  size_ = 0;

  constructor(size = null)
  {
    base.constructor(AesKeyParams.getType());

    if (size == null)
      size = AesKeyParams.getDefaultSize();
    size_ = size;
  }

  function getKeySize() { return size_; }

  static function getDefaultSize() { return 64; }

  static function getType() { return KeyType.AES; }
}
