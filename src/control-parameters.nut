/**
 * Copyright (C) 2018 Regents of the University of California.
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
 * A ControlParameters holds a Name and other fields for a ControlParameters
 * which is used, for example, in the command interest to register a prefix with
 * a forwarder. See
 * http://redmine.named-data.net/projects/nfd/wiki/ControlCommand#ControlParameters
 */
class ControlParameters {
  name_ = null;
  faceId_ = null;
  uri_ = null;
  localControlFeature_ = null;
  origin_ = null;
  cost_ = null;
  // TODO: forwardingFlags_
  strategy_ = null;
  expirationPeriod_ = null;

  /**
   * Create a new ControlParameters.
   * @param {ControlParameters} controlParameters (optional) If
   * controlParameters is another ControlParameters object, copy its values.
   * Otherwise, set all fields to defaut values.
   */
  constructor(controlParameters = null)
  {
    if (controlParameters instanceof ControlParameters) {
      // The copy constructor.
      name_ = ControlParameters.name_ == null ? null : Name(controlParameters.name_);
      faceId_ = controlParameters.faceId_;
      uri_ = controlParameters.uri_;
      localControlFeature_ = controlParameters.localControlFeature_;
      origin_ = controlParameters.origin_;
      cost_ = controlParameters.cost_;
      // TODO: forwardingFlags_
      strategy_ = Name(controlParameters.strategy_);
      expirationPeriod_ = controlParameters.expirationPeriod_;
    }
    else
      clear();
  }

  function clear()
  {
    name_ = null;
    faceId_ = null;
    uri_ = "";
    localControlFeature_ = null;
    origin_ = null;
    cost_ = null;
    // TODO: forwardingFlags_
    strategy_ = Name();
    expirationPeriod_ = null;
  }

  /**
   * Encode this ControlParameters for a particular wire format.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * encode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   * @return {Blob} The encoded buffer in a Blob object.
   */
  function wireEncode(wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    return wireFormat.encodeControlParameters(this);
  }

  /**
   * Decode the input using a particular wire format and update this
   * ControlParameters.
   * @param {Blob|Buffer} input The buffer with the bytes to decode.
   * @param {WireFormat} wireFormat (optional) A WireFormat object used to
   * decode this object. If null or omitted, use WireFormat.getDefaultWireFormat().
   */
  function wireDecode(input, wireFormat = null)
  {
    if (wireFormat == null)
        // Don't use a default argument since getDefaultWireFormat can change.
        wireFormat = WireFormat.getDefaultWireFormat();

    if (input instanceof Blob)
      wireFormat.decodeControlParameters(this, input.buf(), false);
    else
      wireFormat.decodeControlParameters(this, input, true);
  }

  /**
   * Get the name.
   * @return {Name} The name. If not specified, return null.
   */
  function getName() { return name_; }

  /**
   * Get the face ID.
   * @return {integer} The face ID, or null if not specified.
   */
  function getFaceId() { return faceId_; }

  /**
   * Get the URI.
   * @return {string} The face URI, or an empty string if not specified.
   */
  function getUri() { return uri_; }

  /**
   * Get the local control feature value.
   * @return {integer} The local control feature value, or null if not specified.
   */
  function getLocalControlFeature() { return localControlFeature_; }

  /**
   * Get the origin value.
   * @return {integer} The origin value, or null if not specified.
   */
  function getOrigin() { return origin_; }

  /**
   * Get the cost value.
   * @return {integer} The cost value, or null if not specified.
   */
  function getCost() { return cost_; }

  /**
   * Get the strategy.
   * @return {Name} The strategy or an empty Name.
   */
  function getStrategy() { return strategy_; }

  /**
   * Get the expiration period.
   * @return {float} The expiration period in milliseconds, or null if not specified.
   */
  function getExpirationPeriod() { return expirationPeriod_; }

  /**
   * Set the name.
   * @param {Name} name The name. If not specified, set to null. If specified,
   * this makes a copy of the name.
   */
  function setName(name)
  {
    name_ = name instanceof Name ? Name(name) : null;
  }

  /**
   * Set the Face ID.
   * @param {integer} faceId The new face ID, or null for not specified.
   */
  function setFaceId(faceId) { faceId_ = faceId; }

  /**
   * Set the URI.
   * @param {string} uri The new uri, or an empty string for not specified.
   */
  function setUri(uri) { uri_ = uri != null ? uri : ""; }

  /**
   * Set the local control feature value.
   * @param {integer} localControlFeature The new local control feature value, or
   * null for not specified.
   */
  function setLocalControlFeature(localControlFeature)
  {
    localControlFeature_ = localControlFeature;
  }

  /**
   * Set the origin value.
   * @param {integer} origin The new origin value, or null for not specified.
   */
  function setOrigin(origin) { origin_ = origin; }

  /**
   * Set the cost value.
   * @param {integer} cost The new cost value, or null for not specified.
   */
  function setCost(cost) { cost_ = cost; }

  /**
   * Set the strategy to a copy of the given Name.
   * @param {Name} strategy The Name to copy, or an empty Name if not specified.
   */
  function setStrategy(strategy)
  {
    strategy_ = strategy instanceof Name ? Name(strategy) : Name();
  }

  /**
   * Set the expiration period.
   * @param {float} expirationPeriod The expiration period in milliseconds, or
   * null for not specified.
   */
  function setExpirationPeriod(expirationPeriod)
  {
    if (expirationPeriod == null || expirationPeriod < 0)
      expirationPeriod_ = null;
    else
      expirationPeriod_ = (typeof expirationPeriod == "float") ?
        expirationPeriod : expirationPeriod.tofloat();
  }
}
