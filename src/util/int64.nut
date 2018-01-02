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
 * An Int64 represents a signed 64-bit integer, internally implemented by two
 * 32-bit integers. An Int64 object is immutable. This class is needed since the
 * Imp does not have 64-bit integers, and the float is only single-precision.
 * Note: This class assumes an integer is 32 bits; it will not work in standard
 * Squirrel where an integer is 64 bits (nor is it needed).
 */
class Int64 {
  // The high byte, interpreted as a signed 32-bit integer.
  hi_ = 0;
  // The low byte, interpreted as an unsigned 32-bit integer.
  lo_ = 0;

  /**
   * Create a new Int64. There are two forms of the constructor.
   * Int64(x) where x is a signed 32-bit integer, placed in the low byte and
   * sign-exteneded into the high byte (which is 0xffffffff for negative).
   * Int64(hi, lo) where hi is a signed 32-bit integer for the high byte and lo
   * is treated like the unsigned 32-bit integer for the low byte.
   */
  constructor(arg1, arg2 = null)
  {
    if (typeof arg1 == "integer" && typeof arg2 == "integer") {
      hi_ = arg1;
      lo_ = arg2;
    }
    else if (typeof arg1 == "integer" && arg2 == null) {
      // A single signed 32-bit integer.
      lo_ = arg1;
      // If lo is negative, we sign-extend it.
      hi_ = arg1 >= 0 ? 0 : 0xffffffff;
    }
    else
      throw "Int64 constructor: Invalid arguments";
  }

  /**
   * Get the hex representation of this Int64.
   * @returns {string} The 16 hex characters for the 64-bit value.
   */
  function toHex() { return format("%08x%08x", hi_, lo_); }

  /**
   * Check if this equals the other Int64.
   * @param {Int64|integer} other The other integer to compare. If other is a
   * Squirrel integer, it is cast to an Int64.
   * @returns {boolean} True if equal, false otherwise.
   */
  function equals(other) 
  {
    if (typeof other == "integer")
      other = Int64(other);
    else if (!(other instanceof Int64))
      return false;

    return hi_ == other.hi_ && lo_ == other.lo_;
  }

  /**
   * The comparison operator used for this > other, this <= other, etc.
   * Note that Squirrel does NOT call _cmp for this == other which object checks
   * for identical objects, so you must use this.equals(other).
   * @param {Int64} other The other Int64 to compare.
   * @return {integer} 1 if this > other, -1 if this < other, 0 if this == other.
   */
  function _cmp(other)
  {
    if (hi_ > other.hi_)
      return 1;
    else if (hi_ < other.hi_)
      return -1;
    else
      // The hi bytes are the same. Check the lo bytes.
      return Int64.cmpUnsigned(lo_, other.lo_);
  }

  /**
   * The add operator for this + other.
   * @param {Int64} other The Int64 integer to add.
   * @returns {Int64} A new Int64 as the sum.
   */
  function _add(other)
  {
    // Add the lo and hi bytes.
    local loSum = lo_ + other.lo_;
    local hiSum = hi_ + other.hi_;

    // Do the carry.
    if (lo_ >= 0 && other.lo_ >= 0) {
      // Neither has the hi bit set, so there can't be a carry.
    }
    else if (lo_ < 0 && other.lo_ < 0)
      // Both have the hi bit set, so there must be a carry.
      hiSum += 1;
    else {
      // One of them has the hi bit set and the other doesn't.
      // If loSum doesn't have the hi bit set, there was a carry.
      if (loSum >= 0)
        hiSum += 1;
    }

    return Int64(hiSum, loSum);
  }

  /**
   * The negation (unary minus) operator for -this.
   * @returns {Int64} A new Int64 as the negation.
   */
  function _unm()
  {
    // Negate using two's complement.
    local lo = (lo_ ^ 0xffffffff) + 1;
    local hi = hi_ ^ 0xffffffff;

    if (lo == 0)
      // We had a carry when adding 1.
      hi += 1;

    return Int64(hi, lo);
  }

  /**
   * The subtract operator for this - other.
   * @param {Int64} other The other Int64 to subtract.
   * @returns {Int64} A new Int64 as the difference.
   */
  function _sub(other) { return this + (-other); }

  /**
   * Compare two 32-bit integers as if they were unsigned.
   * @param {integer} x The first 32-bit integer, treated as unsigned.
   * @param {integer} y The second 32-bit integer, treated as unsigned.
   * @return {integer} 1 if x > y, -1 if x < y, 0 if x == y.
   */
  static function cmpUnsigned(x, y)
  {
    if (x < 0 && y >= 0)
      // x has the hi bit set, y doesn't.
      return 1;
    else if (x >= 0 && y < 0)
      // x doesn't have the hi bit set, but y does.
      return -1;
    else {
      // Both are the same sign, so compare normally.
      if (x > y)
        return 1;
      else if (x < y)
        return -1;
      else
        return 0;
    }
  }
}
