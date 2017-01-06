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
 * A PendingInterestTable is an internal class to hold a list of pending
 * interests with their callbacks.
 */
class PendingInterestTable {
  table_ = null;          // Array of PendingInterestTableEntry
  removeRequests_ = null; // Array of integer

  constructor()
  {
    table_ = [];
    removeRequests_ = [];
  }

  /**
   * Add a new entry to the pending interest table. However, if 
   * removePendingInterest was already called with the pendingInterestId, don't
   * add an entry and return null.
   * @param {integer} pendingInterestId
   * @param {Interest} interestCopy
   * @param {function} onData
   * @param {function} onTimeout
   * @param {function} onNetworkNack
   * @return {PendingInterestTableEntry} The new PendingInterestTableEntry, or
   * null if removePendingInterest was already called with the pendingInterestId.
   */
  function add(pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack)
  {
    local removeRequestIndex = removeRequests_.find(pendingInterestId);
    if (removeRequestIndex != null) {
      // removePendingInterest was called with the pendingInterestId returned by
      //   expressInterest before we got here, so don't add a PIT entry.
      removeRequests_.remove(removeRequestIndex);
      return null;
    }

    local entry = PendingInterestTableEntry
      (pendingInterestId, interestCopy, onData, onTimeout, onNetworkNack);
    table_.append(entry);
    return entry;
  }

  /**
   * Find all entries from the pending interest table where data conforms to
   * the entry's interest selectors, remove the entries from the table, set each
   * entry's isRemoved flag, and add to the entries list.
   * @param {Data} data The incoming Data packet to find the interest for.
   * @param {Array<PendingInterestTableEntry>} entries Add matching
   * PendingInterestTableEntry from the pending interest table. The caller
   * should pass in an empty array.
   */
  function extractEntriesForExpressedInterest(data, entries)
  {
    // Go backwards through the list so we can erase entries.
    for (local i = table_.len() - 1; i >= 0; --i) {
      local pendingInterest = table_[i];

      if (pendingInterest.getInterest().matchesData(data)) {
        entries.append(pendingInterest);
        table_.remove(i);
        // We let the callback from callLater call _processInterestTimeout,
        // but for efficiency, mark this as removed so that it returns
        // right away.
        pendingInterest.setIsRemoved();
      }
    }
  }

  // TODO: extractEntriesForNackInterest
  // TODO: removePendingInterest

  /**
   * Remove the specific pendingInterest entry from the table and set its
   * isRemoved flag. However, if the pendingInterest isRemoved flag is already
   * true or the entry is not in the pending interest table then do nothing.
   * @param {PendingInterestTableEntry} pendingInterest The Entry from the
   * pending interest table.
   * @return {bool} True if the entry was removed, false if not.
   */
  function removeEntry(pendingInterest)
  {
    if (pendingInterest.getIsRemoved())
      // extractEntriesForExpressedInterest or removePendingInterest has removed
      // pendingInterest from the table, so we don't need to look for it. Do
      // nothing.
      return false;

    local index = table_.find(pendingInterest);
    if (index == null)
      // The pending interest has been removed. Do nothing.
      return false;

    pendingInterest.setIsRemoved();
    table_.remove(index);
    return true;
  }
}

/**
 * PendingInterestTableEntry holds the callbacks and other fields for an entry
 * in the pending interest table.
 */
class PendingInterestTableEntry {
  pendingInterestId_ = 0;
  interest_ = null;
  onData_ = null;
  onTimeout_ = null;
  onNetworkNack_ = null;
  isRemoved_ = false;

  /*
   * Create a new Entry with the given fields. Note: You should not call this
   * directly but call PendingInterestTable.add.
   */
  constructor(pendingInterestId, interest, onData, onTimeout, onNetworkNack)
  {
    pendingInterestId_ = pendingInterestId;
    interest_ = interest;
    onData_ = onData;
    onTimeout_ = onTimeout;
    onNetworkNack_ = onNetworkNack;
  }

  /**
   * Get the pendingInterestId given to the constructor.
   * @return {integer} The pendingInterestId.
   */
  function getPendingInterestId() { return this.pendingInterestId_; }

  /**
   * Get the interest given to the constructor (from Face.expressInterest).
   * @return {Interest} The interest. NOTE: You must not change the interest
   * object - if you need to change it then make a copy.
   */
  function getInterest() { return this.interest_; }

  /**
   * Get the OnData callback given to the constructor.
   * @return {function} The OnData callback.
   */
  function getOnData() { return this.onData_; }

  /**
   * Get the OnNetworkNack callback given to the constructor.
   * @return {function} The OnNetworkNack callback.
   */
  function getOnNetworkNack() { return this.onNetworkNack_; }

  /**
   * Call onTimeout_ (if defined).  This ignores exceptions from onTimeout_.
   */
  function callTimeout()
  {
    if (onTimeout_ != null) {
      try {
        onTimeout_(interest_);
      } catch (ex) {
        consoleLog("Error in onTimeout: " + ex);
      }
    }
  }

  /**
   * Set the isRemoved flag which is returned by getIsRemoved().
   */
  function setIsRemoved() { isRemoved_ = true; }

  /**
   * Check if setIsRemoved() was called.
   * @return {bool} True if setIsRemoved() was called.
   */
  function getIsRemoved() { return isRemoved_; }
}
