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
 * A ContentType specifies the content type in a MetaInfo object. If the
 * content type in the packet is not a recognized enum value, then we use
 * ContentType.OTHER_CODE and you can call MetaInfo.getOtherTypeCode(). We do
 * this to keep the recognized content type values independent of packet
 * encoding formats.
 */
enum ContentType {
  BLOB = 0,
  LINK = 1,
  KEY =  2,
  NACK = 3,
  OTHER_CODE = 0x7fff
}

/**
 * The MetaInfo class is used by Data and represents the fields of an NDN
 * MetaInfo. The MetaInfo type specifies the type of the content in the Data
 * packet (usually BLOB).
 */
class MetaInfo {
  type_ = 0;
  otherTypeCode_ = 0;
  freshnessPeriod_ = null;
  finalBlockId_ = null;
  changeCount_ = 0;

  /**
   * Create a new MetaInfo.
   * @param {MetaInfo} metaInfo (optional) If metaInfo is another MetaInfo
   * object, copy its values. Otherwise, set all fields to defaut values.
   */
  constructor(metaInfo = null)
  {
    if (metaInfo instanceof MetaInfo) {
      // The copy constructor.
      type_ = metaInfo.type_;
      otherTypeCode_ = metaInfo.otherTypeCode_;
      freshnessPeriod_ = metaInfo.freshnessPeriod_;
      finalBlockId_ = metaInfo.finalBlockId_;
    }
    else {
      type_ = ContentType.BLOB;
      otherTypeCode_ = -1;
      freshnessPeriod_ = null;
      finalBlockId_ = NameComponent();
    }
  }

  /**
   * Get the content type.
   * @return {integer} The content type as a ContentType enum value. If
   * this is ContentType.OTHER_CODE, then call getOtherTypeCode() to get the
   * unrecognized content type code.
   */
  function getType() { return type_; }

  /**
   * Get the content type code from the packet which is other than a recognized
   * ContentType enum value. This is only meaningful if getType() is
   * ContentType.OTHER_CODE.
   * @return {integer} The type code.
   */
  function getOtherTypeCode() { return otherTypeCode_; }

  /**
   * Get the freshness period.
   * @return {float} The freshness period in milliseconds, or null if not
   * specified.
   */
  function getFreshnessPeriod() { return freshnessPeriod_; }

  /**
   * Get the final block ID.
   * @return {NameComponent} The final block ID as a NameComponent. If the
   * NameComponent getValue().size() is 0, then the final block ID is not
   * specified.
   */
  function getFinalBlockId() { return finalBlockId_; }

  /**
   * Set the content type.
   * @param {integer} type The content type as a ContentType enum value. If
   * null, this uses ContentType.BLOB. If the packet's content type is not a
   * recognized ContentType enum value, use ContentType.OTHER_CODE and call
   * setOtherTypeCode().
   */
  function setType(type)
  {
    type_ = (type == null || type < 0) ? ContentType.BLOB : type;
    ++changeCount_;
  }

  /**
   * Set the packet’s content type code to use when the content type enum is
   * ContentType.OTHER_CODE. If the packet’s content type code is a recognized
   * enum value, just call setType().
   * @param {integer} otherTypeCode The packet’s unrecognized content type code,
   * which must be non-negative.
   */
  function setOtherTypeCode(otherTypeCode)
  {
    if (otherTypeCode < 0)
      throw "MetaInfo other type code must be non-negative";

    otherTypeCode_ = otherTypeCode;
    ++changeCount_;
  }

  /**
   * Set the freshness period.
   * @param {float} freshnessPeriod The freshness period in milliseconds, or null
   * for not specified.
   */
  function setFreshnessPeriod(freshnessPeriod)
  {
    if (freshnessPeriod == null || freshnessPeriod < 0)
      freshnessPeriod_ = null;
    else
      freshnessPeriod_ = (typeof freshnessPeriod == "float") ?
        freshnessPeriod : freshnessPeriod.tofloat();
    
    ++changeCount_;
  }

  /**
   * Set the final block ID.
   * @param {NameComponent} finalBlockId The final block ID as a NameComponent.
   * If not specified, set to a new default NameComponent(), or to a
   * NameComponent where getValue().size() is 0.
   */
  function setFinalBlockId(finalBlockId)
  {
    finalBlockId_ = finalBlockId instanceof NameComponent ?
      finalBlockId : NameComponent(finalBlockId);
    ++changeCount_;
  }

  /**
   * Get the change count, which is incremented each time this object is changed.
   * @return {integer} The change count.
   */
  function getChangeCount() { return changeCount_; }
}
