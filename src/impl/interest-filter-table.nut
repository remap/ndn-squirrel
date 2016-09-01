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
 * An InterestFilterTable is an internal class to hold a list of entries with
 * an interest Filter and its OnInterestCallback.
 */
class InterestFilterTable {
  table_ = null; // Array of InterestFilterTableEntry

  constructor()
  {
    table_ = [];
  }

  /**
   * Add a new entry to the table.
   * @param {integer} interestFilterId The ID from Node.getNextEntryId().
   * @param {InterestFilter} filter The InterestFilter for this entry.
   * @param {function} onInterest The callback to call.
   * @param {Face} face The face on which was called registerPrefix or
   * setInterestFilter which is passed to the onInterest callback.
   */
  function setInterestFilter(interestFilterId, filter, onInterest, face)
  {
    table_.append(InterestFilterTableEntry
      (interestFilterId, filter, onInterest, face));
  }

  /**
   * Find all entries from the interest filter table where the interest conforms
   * to the entry's filter, and add to the matchedFilters list.
   * @param {Interest} interest The interest which may match the filter in
   * multiple entries.
   * @param {Array<InterestFilterTableEntry>} matchedFilters Add each matching
   * InterestFilterTableEntry from the interest filter table.  The caller
   * should pass in an empty array.
   */
  function getMatchedFilters(interest, matchedFilters)
  {
    foreach (entry in table_) {
      if (entry.getFilter().doesMatch(interest.getName()))
        matchedFilters.append(entry);
    }
  }

  // TODO: unsetInterestFilter
}

/**
 * InterestFilterTable.Entry holds an interestFilterId, an InterestFilter and
 * the OnInterestCallback with its related Face.
 */
class InterestFilterTableEntry {
  interestFilterId_ = 0;
  filter_ = null;
  onInterest_ = null;
  face_ = null;

  /**
   * Create a new InterestFilterTableEntry with the given values.
   * @param {integer} interestFilterId The ID from getNextEntryId().
   * @param {InterestFilter} filter The InterestFilter for this entry.
   * @param {function} onInterest The callback to call.
   * @param {Face} face The face on which was called registerPrefix or
   * setInterestFilter which is passed to the onInterest callback.
   */
  constructor(interestFilterId, filter, onInterest, face)
  {
    interestFilterId_ = interestFilterId;
    filter_ = filter;
    onInterest_ = onInterest;
    face_ = face;
  }

  /**
   * Get the interestFilterId given to the constructor.
   * @return {integer} The interestFilterId.
   */
  function getInterestFilterId () { return interestFilterId_; }

  /**
   * Get the InterestFilter given to the constructor.
   * @return {InterestFilter} The InterestFilter.
   */
  function getFilter() { return filter_; }

  /**
   * Get the onInterest callback given to the constructor.
   * @return {function} The onInterest callback.
   */
  function getOnInterest() { return onInterest_; }

  /**
   * Get the Face given to the constructor.
   * @return {Face} The Face.
   */
  function getFace() { return face_; }
}
