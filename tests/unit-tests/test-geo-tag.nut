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

describe("TestGeoTag", function() {
  it("Distance", function() {
    Assert.equal(typeof GeoTag.distance(0, 0), "float");

    // Test zero distance.
    Assert.equal(GeoTag.distance(    9999,     9999), 0.0);
    Assert.equal(GeoTag.distance(99990000, 99990000), 0.0);
    Assert.equal(GeoTag.distance(12345678, 12345678), 0.0);

    // Test simple straight distance.
    Assert.equal(GeoTag.distance(    9999,        0), 99990.0);
    Assert.equal(GeoTag.distance(       0,     9999), 99990.0);
    Assert.equal(GeoTag.distance(99990000,        0), 99990.0);
    Assert.equal(GeoTag.distance(       0, 99990000), 99990.0);

    // Test diagonal distance with whole numbers.
    Assert.equal(GeoTag.distance(30004000,        0), 50000.0);
    Assert.equal(GeoTag.distance(40003000,        0), 50000.0);
    Assert.equal(GeoTag.distance(       0, 30004000), 50000.0);
    Assert.equal(GeoTag.distance(       0, 40003000), 50000.0);
    Assert.equal(GeoTag.distance(30000000,     4000), 50000.0);
    Assert.equal(GeoTag.distance(    3000, 40000000), 50000.0);

    local actual, expected;
    // Test diagonal distance with a fractional component.
    actual =   GeoTag.distance(   10001,        0);
    expected = 14.1421;
    Assert.ok((actual - expected) / expected < 0.0001);
    actual =   GeoTag.distance(       0,    10001);
    expected = 14.1421;
    Assert.ok((actual - expected) / expected < 0.0001);
    actual =   GeoTag.distance(       1,    10000);
    expected = 14.1421;
    Assert.ok((actual - expected) / expected < 0.0001);
    actual =   GeoTag.distance(99999999,        0);
    expected = 141407.0;
    Assert.ok((actual - expected) / expected < 0.0001);
    actual =   GeoTag.distance(       0, 99999999);
    expected = 141407.0;
    Assert.ok((actual - expected) / expected < 0.0001);
    actual =   GeoTag.distance(    9999, 99990000);
    expected = 141407.0;
    Assert.ok((actual - expected) / expected < 0.0001);
  });

  it("FigureOfMerit", function() {
    // Case A.
    // Self, Source and Dest are on a line.
    Assert.equal(GeoTag.figureOfMerit(1,   0, 100), 0.99)
    Assert.equal(GeoTag.figureOfMerit(50,  0, 100), 0.5)
    Assert.equal(GeoTag.figureOfMerit(100, 0, 100), 0.0)
    Assert.equal(GeoTag.figureOfMerit(150, 0, 100), -0.5)
    // The projection of Self is half way from Source to Dest.
    Assert.equal(GeoTag.figureOfMerit(0, 1000000, 100), 0.5)

    // Case B.
    Assert.equal(GeoTag.figureOfMerit(0,   0, 100), -1.0)
    Assert.equal(GeoTag.figureOfMerit(200, 0, 100), -1.0)
    Assert.equal(GeoTag.figureOfMerit(0,  50, 100), -1.0)
  });
});
