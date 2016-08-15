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
 * An ExcludeType specifies the type of an ExcludeEntry.
 */
enum ExcludeType {
  COMPONENT, ANY
}

/**
 * An ExcludeEntry holds an ExcludeType, and if it is a COMPONENT, it holds
 * the component value.
 */
class ExcludeEntry {
  type_ = 0;
  component_ = null;

  /**
   * Create a new Exclude.Entry.
   * @param {NameComponent|Blob|blob|Array<integer>|string} (optional) If value
   * is omitted or null, create an ExcludeEntry of type ExcludeType.ANY.
   * Otherwise creat an ExcludeEntry of type ExcludeType.COMPONENT with the value.
   * If the value is a NameComponent or Blob, use its value directly, otherwise
   * use the value according to the Blob constructor.
   */
  constructor(value = null)
  {
    if (value == null)
      type_ = ExcludeType.ANY;
    else {
      type_ = ExcludeType.COMPONENT;
      component_ = value instanceof NameComponent ? value : NameComponent(value);
    }
  }

  /**
   * Get the type of this entry.
   * @return {integer} The Exclude type as an ExcludeType enum value.
   */
  function getType() { return type_; }

  /**
   * Get the component value for this entry (if it is of type ExcludeType.COMPONENT).
   * @return {NameComponent} The component value, or null if this entry is not
   * of type ExcludeType.COMPONENT.
   */
  function getComponent() { return component_; }
}

/**
 * The Exclude class is used by Interest and holds an array of ExcludeEntry to
 * represent the fields of an NDN Exclude selector.
 */
class Exclude {
  entries_ = null;
  changeCount_ = 0;

  /**
   * Create a new Exclude.
   * @param {Exclude} exclude (optional) If exclude is another Exclude
   * object, copy its values. Otherwise, set all fields to defaut values.
   */
  constructor(exclude = null)
  {
    if (exclude instanceof Exclude)
      // The copy constructor.
      entries_ = exclude.entries_.slice(0);
    else
      entries_ = [];
  }

  /**
   * Get the number of entries.
   * @return {integer} The number of entries.
   */
  function size() { return entries_.len(); }

  /**
   * Get the entry at the given index.
   * @param {integer} i The index of the entry, starting from 0.
   * @return {ExcludeEntry} The entry at the index.
   */
  function get(i) { return entries_[i]; }

  /**
   * Append a new entry of type Exclude.Type.ANY.
   * @return This Exclude so that you can chain calls to append.
   */
  function appendAny()
  {
    entries_.append(ExcludeEntry());
    ++changeCount_;
    return this;
  }

  /**
   * Append a new entry of type ExcludeType.COMPONENT with the give component.
   * @param component {NameComponent|Blob|blob|Array<integer>|string} The
   * component value for the entry. If component is a NameComponent or Blob, use
   * its value directly, otherwise use the value according to the Blob
   * constructor.
   * @return This Exclude so that you can chain calls to append.
   */
  function appendComponent(component)
  {
    entries_.append(ExcludeEntry(component));
    ++changeCount_;
    return this;
  }

  /**
   * Clear all the entries.
   */
  function clear()
  {
    ++changeCount_;
    entries_ = [];
  }

  // TODO: toUri.
  // TODO: matches.

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
