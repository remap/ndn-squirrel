/**
 * Copyright (C) 2017-2018 Regents of the University of California.
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
 * A DelayedCallTable which is an internal class used by the Face implementation
 * of callLater to store callbacks and call them when they time out.
 */
class DelayedCallTable {
  table_ = null;          // Array of DelayedCallTableEntry

  constructor()
  {
    table_ = [];
  }

  /*
   * Call callback() after the given delay. This adds to the delayed call table
   * which is used by callTimedOut().
   * @param {float} delayMilliseconds: The delay in milliseconds.
   * @param {function} callback This calls callback() after the delay.
   */
  function callLater(delayMilliseconds, callback)
  {
    local entry = DelayedCallTableEntry(delayMilliseconds, callback);
    // Insert into table_, sorted on getCallTimeSeconds().
    // Search from the back since we expect it to go there.
    local i = table_.len() - 1;
    while (i >= 0) {
      if (table_[i].getCallTimeSeconds() <= entry.getCallTimeSeconds())
        break;
      --i;
    }

    // Element i is the greatest less than or equal to entry.getCallTimeSeconds(), so
    // insert after it.
    table_.insert(i + 1, entry);
  }

  /**
   * Call and remove timed-out callback entries. Since callLater does a sorted
   * insert into the delayed call table, the check for timed-out entries is
   * quick and does not require searching the entire table.
   */
  function callTimedOut()
  {
    local nowSeconds = NdnCommon.getNowSeconds();
    // table_ is sorted on _callTime, so we only need to process the timed-out
    // entries at the front, then quit.
    while (table_.len() > 0 && table_[0].getCallTimeSeconds() <= nowSeconds) {
      local entry = table_[0];
      table_.remove(0);
      entry.callCallback();
    }
  }
}

/**
 * DelayedCallTableEntry holds the callback and other fields for an entry in the
 * delayed call table.
 */
class DelayedCallTableEntry {
  callback_ = null;
  callTimeSeconds_ = 0.0;

  /*
   * Create a new DelayedCallTableEntry and set the call time based on the
   * current time and the delayMilliseconds.
   * @param {float} delayMilliseconds: The delay in milliseconds.
   * @param {function} callback This calls callback() after the delay.
   */
  constructor(delayMilliseconds, callback)
  {
    callback_ = callback;
    local nowSeconds = NdnCommon.getNowSeconds();
    callTimeSeconds_ = nowSeconds + (delayMilliseconds / 1000.0).tointeger();
  }

  /**
   * Get the time at which the callback should be called.
   * @return {float} The call time in seconds, based on NdnCommon.getNowSeconds().
   */
  function getCallTimeSeconds() { return callTimeSeconds_; }

  /**
   * Call the callback given to the constructor. This does not catch exceptions.
   */
  function callCallback() { callback_(); }
}
