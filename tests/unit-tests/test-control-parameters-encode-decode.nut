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

describe("ControlParametersEncodeDecode", function() {
  it("should encode and decode", function() {
    local parameters = ControlParameters();
    parameters.setName(Name("/test/control/parameters"));
    parameters.setFaceId(1);
    // Encode.
    local encoded = parameters.wireEncode();
    // Decode.
    local decodedParameters = ControlParameters();
    decodedParameters.wireDecode(encoded);
    // Compare.
    Assert.equal(parameters.getName().toUri(),
      decodedParameters.getName().toUri());
    Assert.equal(parameters.getFaceId(), decodedParameters.getFaceId());
    Assert.equal(parameters.getUri(), decodedParameters.getUri());
  });

  it("should encode and decode with no name", function() {
    local parameters = ControlParameters();
    parameters.setStrategy(Name("/localhost/nfd/strategy/broadcast"));
    parameters.setUri("null://");
    local encoded = parameters.wireEncode();
    local decodedParameters = ControlParameters();
    decodedParameters.wireDecode(encoded);
    // Compare.
    Assert.equal(decodedParameters.getName(), null);
    Assert.equal(parameters.getStrategy().toUri(),
      decodedParameters.getStrategy().toUri());
    Assert.equal(parameters.getUri(), decodedParameters.getUri());
  });
});
