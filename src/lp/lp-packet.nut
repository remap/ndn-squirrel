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
 * An LpPacket represents an NDNLPv2 packet including header fields an an
 * optional fragment. This is an internal class which the application normally
 * would not use.
 * http://redmine.named-data.net/projects/nfd/wiki/NDNLPv2
 */
class LpPacket {
  headerFields_ = null;
  fragmentWireEncoding_ = null;

  constructor() {
    headerFields_ = [];
    fragmentWireEncoding_ = Blob();
  }

  /**
   * Get the fragment wire encoding.
   * @return {Blob} The wire encoding, or an isNull Blob if not specified.
   */
  function getFragmentWireEncoding() { return fragmentWireEncoding_; }

  /**
   * Get the number of header fields. This does not include the fragment.
   * @return {integer} The number of header fields.
   */
  function countHeaderFields() { return headerFields_.len(); }

  /**
   * Get the header field at the given index.
   * @param {integer} index The index, starting from 0. It is an error if index
   * is greater to or equal to countHeaderFields().
   * @return {object} The header field at the index.
   */
  function getHeaderField(index) { return headerFields_[index]; }

  /**
   * Remove all header fields and set the fragment to an isNull Blob.
   */
  function clear()
  {
    headerFields_ = [];
    fragmentWireEncoding_ = Blob();
  }

  /**
   * Set the fragment wire encoding.
   * @param {Blob} fragmentWireEncoding The fragment wire encoding or an isNull
   * Blob if not specified.
   */
  function setFragmentWireEncoding(fragmentWireEncoding)
  {
    fragmentWireEncoding_ = fragmentWireEncoding instanceof Blob ?
      fragmentWireEncoding : Blob(fragmentWireEncoding);
  }

  /**
   * Add a header field. To add the fragment, use setFragmentWireEncoding().
   * @param {object} headerField The header field to add.
   */
  function addHeaderField(headerField) { headerFields_.append(headerField); }
}
