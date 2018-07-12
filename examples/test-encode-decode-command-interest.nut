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
 * Make a signed command interest to register a route for the prefix.
 * @param {Name} prefix The prefix to copy. This makes a copy of the Name.
 * @param {string} uri The uri for the face.
 * @param {integer} cost The new cost value, or null for not specified.
 * @return {Interest} The new command Interest.
 */
function makeRegisterRouteCommandInterest(prefix, uri, cost)
{
  local controlParameters = ControlParameters();
  controlParameters.setName(prefix);
  controlParameters.setUri(uri);
  controlParameters.setCost(cost);

  local interest = Interest(Name("/localhop/mf/rib/register"));
  interest.getName().append(controlParameters.wireEncode());

  // Note: Normally, an application creates a CommandInterestPreparer once and
  // keeps calling its prepareCommandInterestName. But we use it just once here.
  CommandInterestPreparer().prepareCommandInterestName(interest);

  // Create a dummy Signature.
  local keyLocator = KeyLocator();
  keyLocator.setType(KeyLocatorType.KEYNAME);
  keyLocator.setKeyName(Name("/key/locator"));
  local signature = Sha256WithRsaSignature();
  signature.setKeyLocator(keyLocator);
  signature.setSignature(Blob(blob(256)));
  // Add the signature name components.
  interest.getName().append(TlvWireFormat.get().encodeSignatureInfo(signature));
  interest.getName().append(TlvWireFormat.get().encodeSignatureValue(signature));

  return interest;
}

/**
 * Decode and return the ControlParameters in the command interest.
 * @param {Interest} interest The command interest.
 * @return {ControlParameters} The decoded ControlParameters.
 */
function getCommandInterestControlParameters(interest)
{
  local controlParameters = ControlParameters();
  controlParameters.wireDecode(interest.getName().get(4).getValue());

  return controlParameters;
}

function main()
{
  local interest = makeRegisterRouteCommandInterest
    (Name("/my/prefix"), "http://otherhost", 10);
  local encoding = interest.wireEncode();

  local decodedInterest = Interest();
  decodedInterest.wireDecode(encoding);

  local controlParameters = getCommandInterestControlParameters(decodedInterest);
  consoleLog("Prefix: " + controlParameters.getName().toUri());
  consoleLog("URI: " + controlParameters.getUri());
  consoleLog("Cost: " + controlParameters.getCost());
  local debug = "entr\u00E9e";
  consoleLog("Debug size " + debug.len() + " " + debug);
  consoleLog("Buffer size " + Buffer(debug).len());
}

main();
