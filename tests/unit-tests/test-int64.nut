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

describe("TestInt64", function() {
  it("Construction", function() {
    local x = Int64(0);
    Assert.equal(x.hi_, 0);
    Assert.equal(x.lo_, 0);

    x = Int64(1);
    Assert.equal(x.hi_, 0);
    Assert.equal(x.lo_, 1);

    x = Int64(-1);
    Assert.equal(x.hi_, 0xffffffff);
    Assert.equal(x.lo_, 0xffffffff);

    local x = Int64(0, 0);
    Assert.equal(x.hi_, 0);
    Assert.equal(x.lo_, 0);

    local x = Int64(1, 0xffffffff);
    Assert.equal(x.hi_, 1);
    Assert.equal(x.lo_, 0xffffffff);

    local x = Int64(-1, 0xffffffff);
    Assert.equal(x.hi_, 0xffffffff);
    Assert.equal(x.lo_, 0xffffffff);
  });

  it("Compare", function() {
    local x = Int64(10)
    local y = Int64(10)
    Assert.equal(true, x.equals(y));

    x = Int64(-10)
    y = Int64(-10)
    Assert.equal(true, x.equals(y));

    // Test changes in lo, with hi extended.
    x = Int64(1)
    y = Int64(0)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(1)
    y = Int64(-1)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(-1)
    y = Int64(-2)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    // Test changes in lo, with hi positive.
    x = Int64(0, 1)
    y = Int64(0, 0)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(0, 1)
    y = Int64(0, 0xffffffff)
    Assert.equal(false, x > y);
    Assert.equal(true, x < y);

    x = Int64(0, 0xffffffff)
    y = Int64(0, 0xfffffffe)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    // Test changes in lo, with hi negative.
    x = Int64(-1, 0xffffffff) // = -1
    y = Int64(-1, 0)          // = -4000000000 (approx.)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(-1, 1)          // = -4000000000 (approx.)
    y = Int64(-1, 0xffffffff) // = -1
    Assert.equal(false, x > y);
    Assert.equal(true, x < y);

    x = Int64(-1, 0xffffffff) // = -1
    y = Int64(-1, 0xfffffffe) // = -2
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    // Test changes in hi.
    x = Int64(1, 0)
    y = Int64(0, 0)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(1, 0)
    y = Int64(-1, 0)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);

    x = Int64(-1, 0)
    y = Int64(-2, 0)
    Assert.equal(true, x > y);
    Assert.equal(false, x < y);
  });

  it("Add", function() {
    Assert.equal("00000000"+"e0000000", (Int64(0, 0x70000000) +
                                         Int64(0, 0x70000000)).toHex());
    Assert.equal("00000001"+"00000000", (Int64(0, 0x80000000) +
                                         Int64(0, 0x80000000)).toHex());
    Assert.equal("00000001"+"e0000000", (Int64(0, 0xf0000000) +
                                         Int64(0, 0xf0000000)).toHex());
    Assert.equal("00000000"+"f0000000", (Int64(0, 0xe0000000) +
                                         Int64(0, 0x10000000)).toHex());
    Assert.equal("00000001"+"00000000", (Int64(0, 0xe0000000) +
                                         Int64(0, 0x20000000)).toHex());
    Assert.equal("00000001"+"60000000", (Int64(0, 0xf0000000) +
                                         Int64(0, 0x70000000)).toHex());
    Assert.equal("00000004"+"e0000000", (Int64(1, 0xf0000000) +
                                         Int64(2, 0xf0000000)).toHex());

    Assert.equal("80000000"+"e0000000", (Int64(0x00000000, 0x70000000) +
                                         Int64(0x80000000, 0x70000000)).toHex());
    Assert.equal("80000001"+"e0000000", (Int64(0x00000000, 0xf0000000) +
                                         Int64(0x80000000, 0xf0000000)).toHex());
    Assert.equal("e0000001"+"e0000000", (Int64(0xf0000000, 0xf0000000) +
                                         Int64(0xf0000000, 0xf0000000)).toHex());
    Assert.equal("ffffffff"+"fffffffe", (Int64(0xffffffff, 0xffffffff) +
                                         Int64(0xffffffff, 0xffffffff)).toHex());
  });

  it("Negate", function() {
    Assert.equal("00000000"+"00000000", (-Int64(0)).toHex());
    Assert.equal("ffffffff"+"ffffffff", (-Int64(1)).toHex());
    Assert.equal("00000000"+"00000001", (-Int64(-1)).toHex());
    Assert.equal("80000000"+"00000001", (-Int64(0x7fffffff, 0xffffffff)).toHex());
    Assert.equal("80000000"+"00000000", (-Int64(0x80000000, 0x00000000)).toHex());
  });

  it("Subtract", function() {
    Assert.equal("00000000"+"00000000", (Int64(1) - Int64(1)).toHex());
    Assert.equal("00000000"+"00000000", (Int64(-1) - Int64(-1)).toHex());
    Assert.equal("00000000"+"00000002", (Int64(1) - Int64(-1)).toHex());
    Assert.equal("ffffffff"+"87654321", (Int64(0x87654321) - Int64(0)).toHex());

    Assert.equal("00000000"+"00000000", (Int64(0x00000000, 0xffffffff) -
                                         Int64(0x00000000, 0xffffffff)).toHex());
    Assert.equal("00000000"+"ffffffff", (Int64(0x00000001, 0x00000000) -
                                         Int64(0x00000000, 0x00000001)).toHex());
  });
});
