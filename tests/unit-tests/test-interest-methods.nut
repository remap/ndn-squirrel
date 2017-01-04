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

local codedInterest = Buffer([
0x05, 0x50, // Interest
  0x07, 0x0A, 0x08, 0x03, 0x6E, 0x64, 0x6E, 0x08, 0x03, 0x61, 0x62, 0x63, // Name
  0x09, 0x38, // Selectors
    0x0D, 0x01, 0x04, // MinSuffixComponents
    0x0E, 0x01, 0x06, // MaxSuffixComponents
    0x0F, 0x22, // KeyLocator
      0x1D, 0x20, // KeyLocatorDigest
                  0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
                  0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F,
    0x10, 0x07, // Exclude
      0x08, 0x03, 0x61, 0x62, 0x63, // NameComponent
      0x13, 0x00, // Any
    0x11, 0x01, 0x01, // ChildSelector
    0x12, 0x00, // MustBeFesh
  0x0A, 0x04, 0x61, 0x62, 0x61, 0x62,   // Nonce
  0x0C, 0x02, 0x75, 0x30, // InterestLifetime
1
]);

function dumpInterest(interest)
{
  function dump(s1, s2 = null)
  {
    local result = s1;
    if (s2)
      result += " " + s2;

    return result;
  }

  local result = [];
  result.append(dump("name:", interest.getName().toUri()));
  result.append(dump("minSuffixComponents:",
    interest.getMinSuffixComponents() != null ?
      interest.getMinSuffixComponents() : "<none>"));
  result.append(dump("maxSuffixComponents:",
    interest.getMaxSuffixComponents() != null ?
      interest.getMaxSuffixComponents() : "<none>"));
  if (interest.getKeyLocator().getType() != null) {
    if (interest.getKeyLocator().getType() == KeyLocatorType.KEY_LOCATOR_DIGEST)
      result.append(dump("keyLocator: KeyLocatorDigest:",
        interest.getKeyLocator().getKeyData().toHex()));
    else if (interest.getKeyLocator().getType() == KeyLocatorType.KEYNAME)
      result.append(dump("keyLocator: KeyName:",
        interest.getKeyLocator().getKeyName().toUri()));
    else
      result.append(dump("keyLocator: <unrecognized KeyLocatorType"));
  }
  else
    result.append(dump("keyLocator: <none>"));
  result.append(dump("exclude:",
    interest.getExclude().size() > 0 ? interest.getExclude().toUri() :"<none>"));
  result.append(dump("childSelector:",
    interest.getChildSelector() != null ? interest.getChildSelector() : "<none>"));
  result.append(dump("mustBeFresh:", interest.getMustBeFresh()));
  result.append(dump("nonce:", interest.getNonce().size() == 0 ?
    "<none>" : interest.getNonce().toHex()));
  result.append(dump("lifetimeMilliseconds:",
    interest.getInterestLifetimeMilliseconds() == null ?
      "<none>" : interest.getInterestLifetimeMilliseconds()));
  return result;
}

// ignoring nonce, check that the dumped interests are equal
function interestDumpsEqual(dump1, dump2)
{
  /**
   * Return a copy of the strings array, removing any string that start with prefix.
   */
  function removeStartingWith(strings, prefix)
  {
    local result = [];
    for (local i = 0; i < strings.len(); ++i) {
      if (strings[i].len() < prefix.len() ||
          strings[i].slice(0, prefix.len()) != prefix)
        result.append(strings[i]);
    }

    return result;
  }

  local prefix = "nonce:";
  dump1 = removeStartingWith(dump1, prefix);
  dump2 = removeStartingWith(dump2, prefix);

  if (dump1.len() != dump2.len())
    return false;
  for (local i = 0; i < dump1.len(); ++i) {
    if (dump1[i] != dump2[i])
      return false;
  }
  return true;
}

function createFreshInterest()
{
  local freshInterest = Interest(Name("/ndn/abc"))
    .setMustBeFresh(false)
    .setMinSuffixComponents(4)
    .setMaxSuffixComponents(6)
    .setInterestLifetimeMilliseconds(30000)
    .setChildSelector(1)
    .setMustBeFresh(true);
  freshInterest.getKeyLocator().setType(KeyLocatorType.KEY_LOCATOR_DIGEST);
  freshInterest.getKeyLocator().setKeyData(Blob(
    [0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F,
     0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F], false));
  freshInterest.getExclude().appendComponent(Name("abc").get(0)).appendAny();

  return freshInterest;
}


describe("TestInterestDump", function() {
  local referenceInterest = null;

  local initialDump = ["name: /ndn/abc",
    "minSuffixComponents: 4",
    "maxSuffixComponents: 6",
    "keyLocator: KeyLocatorDigest: 000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f",
    "exclude: abc,*",
    "childSelector: 1",
    "mustBeFresh: true",
    "nonce: 61626162",
    "lifetimeMilliseconds: 30000"];

  beforeEach(function() {
    referenceInterest = Interest();
    referenceInterest.wireDecode(codedInterest);
  });

  it("Dump", function() {
    // See if the dump format is the same as we expect.
    local decodedDump = dumpInterest(referenceInterest);
    Assert.deepEqual(initialDump, decodedDump,
      "Initial dump does not have expected format");
  });

  it("Redecode", function() {
    // check that we encode and decode correctly
    local encoding = referenceInterest.wireEncode();
    local reDecodedInterest = Interest();
    reDecodedInterest.wireDecode(encoding);
    local redecodedDump = dumpInterest(reDecodedInterest);
    Assert.deepEqual(initialDump, redecodedDump, "Re-decoded interest does not match original");
  });

  it("RedecodeImplicitDigestExclude", function() {
    // Check that we encode and decode correctly with an implicit digest exclude.
    local interest = Interest(Name("/A"));
    interest.getExclude().appendComponent(Name("/sha256digest=" +
      "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f").get(0));
    local dump = dumpInterest(interest);

    local encoding = interest.wireEncode();
    local reDecodedInterest = Interest();
    reDecodedInterest.wireDecode(encoding);
    local redecodedDump = dumpInterest(reDecodedInterest);
    Assert.ok(interestDumpsEqual(dump, redecodedDump),
      "Re-decoded interest does not match original");
  });

  it("CreateFresh", function() {
    local freshInterest = createFreshInterest();
    local freshDump = dumpInterest(freshInterest);
    Assert.ok(interestDumpsEqual(initialDump, freshDump),
      "Fresh interest does not match original");

    local reDecodedFreshInterest = Interest();
    reDecodedFreshInterest.wireDecode(freshInterest.wireEncode());
    local reDecodedFreshDump = dumpInterest(reDecodedFreshInterest);

    Assert.ok(interestDumpsEqual(freshDump, reDecodedFreshDump),
      "Redecoded fresh interest does not match original");
  });
});

describe("TestInterestMethods", function() {
  local referenceInterest = null;

  beforeEach(function() {
    referenceInterest = Interest();
    referenceInterest.wireDecode(codedInterest);
  });

  it("CopyConstructor", function() {
    local interest = Interest(referenceInterest);
    Assert.ok(interestDumpsEqual(dumpInterest(interest), dumpInterest(referenceInterest)),
      "Interest constructed as deep copy does not match original");
  });

  it("EmptyNonce", function() {
    // Make sure a freshly created interest has no nonce.
    local freshInterest = createFreshInterest();
    Assert.ok(freshInterest.getNonce().isNull(),
      "Freshly created interest should not have a nonce");
  });

  it("SetRemovesNonce", function() {
    // Ensure that changing a value on an interest clears the nonce.
    Assert.ok(!referenceInterest.getNonce().isNull());
    local interest = Interest(referenceInterest);
    // Change a child object.
    interest.getExclude().clear();
    Assert.ok(interest.getNonce().isNull(),
      "Interest should not have a nonce after changing fields");
  });

  it("RefreshNonce", function() {
    local interest = Interest(referenceInterest);
    local oldNonce = interest.getNonce();
    Assert.equal(oldNonce.size(), 4);

    interest.refreshNonce();
    Assert.equal(interest.getNonce().size(), oldNonce.size(),
                 "The refreshed nonce should be the same size");
    Assert.equal(interest.getNonce().equals(oldNonce), false,
                 "The refreshed nonce should be different");
  });

/* TODO: Exclude.matches.
  it("ExcludeMatches", function() {
    local exclude = Exclude();
    exclude.appendComponent(Name("%00%02").get(0));
    exclude.appendAny();
    exclude.appendComponent(Name("%00%20").get(0));

    local component;
    component = Name("%00%01").get(0);
    Assert.ok(!exclude.matches(component),
      component.toEscapedString() + " should not match " + exclude.toUri());
    component = Name("%00%0F").get(0);
    Assert.ok(exclude.matches(component),
      component.toEscapedString() + " should match " + exclude.toUri());
    component = Name("%00%21").get(0);
    Assert.ok(!exclude.matches(component),
      component.toEscapedString() + " should not match " + exclude.toUri());
  });
*/

  // TODO: VerifyDigestSha256

  it("MatchesData", function() {
    local interest = Interest(Name("/A"));
    interest.setMinSuffixComponents(2);
    interest.setMaxSuffixComponents(2);
    interest.getKeyLocator().setType(KeyLocatorType.KEYNAME);
    interest.getKeyLocator().setKeyName(Name("/B"));
    interest.getExclude().appendComponent(NameComponent("J"));
    interest.getExclude().appendAny();

    local data = Data(Name("/A/D"));
    local signature = Sha256WithRsaSignature();
    signature.getKeyLocator().setType(KeyLocatorType.KEYNAME);
    signature.getKeyLocator().setKeyName(Name("/B"));
    data.setSignature(signature);
/*  TODO: Implement Exclude.matches
    Assert.equal(interest.matchesData(data), true);
*/

    // Check violating MinSuffixComponents.
    local data1 = Data(data);
    data1.setName(Name("/A"));
    Assert.equal(interest.matchesData(data1), false);

    local interest1 = Interest(interest);
    interest1.setMinSuffixComponents(1);
/*  TODO: Implement Exclude.matches
    Assert.equal(interest1.matchesData(data1), true);

    // Check violating MaxSuffixComponents.
    local data2 = Data(data);
    data2.setName(Name("/A/E/F"));
    Assert.equal(interest.matchesData(data2), false);

    local interest2 = Interest(interest);
    interest2.setMaxSuffixComponents(3);
    Assert.equal(interest2.matchesData(data2), true);

    // Check violating PublisherPublicKeyLocator.
    local data3 = Data(data);
    local signature3 = Sha256WithRsaSignature();
    signature3.getKeyLocator().setType(KeyLocatorType.KEYNAME);
    signature3.getKeyLocator().setKeyName(Name("/G"));
    data3.setSignature(signature3);
    Assert.equal(interest.matchesData(data3), false);

    local interest3 = Interest(interest);
    interest3.getKeyLocator().setType(KeyLocatorType.KEYNAME);
    interest3.getKeyLocator().setKeyName(Name("/G"));
    Assert.equal(interest3.matchesData(data3), true);

    local data4 = Data(data);
    data4.setSignature(DigestSha256Signature());
    Assert.equal(interest.matchesData(data4), false);

    local interest4 = Interest(interest);
    interest4.setKeyLocator(KeyLocator());
    Assert.equal(interest4.matchesData(data4), true);

    // Check violating Exclude.
    local data5 = Data(data);
    data5.setName(Name("/A/J"));
    Assert.equal(interest.matchesData(data5), false);

    local interest5 = Interest(interest);
    interest5.getExclude().clear();
    interest5.getExclude().appendComponent(NameComponent("K"));
    interest5.getExclude().appendAny();
    Assert.equal(interest5.matchesData(data5), true);

    // Check violating Name.
    local data6 = Data(data);
    data6.setName(Name("/H/I"));
    Assert.equal(interest.matchesData(data6), false);

    local data7 = Data(data);
    data7.setName(Name("/A/B"));

    local interest7 = Interest
      (Name("/A/B/sha256digest=" +
                "54008e240a7eea2714a161dfddf0dd6ced223b3856e9da96792151e180f3b128"));
    Assert.equal(interest7.matchesData(data7), true);

    // Check violating the implicit digest.
    local interest7b = Interest
      (Name("/A/B/%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00" +
                     "%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00%00"));
    Assert.equal(interest7b.matchesData(data7), false);

    // Check excluding the implicit digest.
    local interest8 = Interest(Name("/A/B"));
    interest8.getExclude().appendComponent(interest7.getName().get(2));
    Assert.equal(interest8.matchesData(data7), false);
*/
  });

  it("InterestFilterMatching", function() {
    // From ndn-cxx interest.t.cpp.
    Assert.equal(true,  InterestFilter("/a").doesMatch(Name("/a/b")));
    Assert.equal(true,  InterestFilter("/a/b").doesMatch(Name("/a/b")));
    Assert.equal(false, InterestFilter("/a/b/c").doesMatch(Name("/a/b")));

/* TODO: Support InterestFilter regex.
    Assert.equal(true,  InterestFilter("/a", "<b>").doesMatch(Name("/a/b")));
    Assert.equal(false, InterestFilter("/a/b", "<b>").doesMatch(Name("/a/b")));

    Assert.equal(false, InterestFilter("/a/b", "<c>").doesMatch(Name("/a/b/c/d")));
    Assert.equal(false, InterestFilter("/a/b", "<b>").doesMatch(Name("/a/b/c/b")));
    Assert.equal(true,  InterestFilter("/a/b", "<>*<b>").doesMatch(Name("/a/b/c/b")));

    Assert.equal(false, InterestFilter("/a", "<b>").doesMatch(Name("/a/b/c/d")));
    Assert.equal(true,  InterestFilter("/a", "<b><>*").doesMatch(Name("/a/b/c/d")));
    Assert.equal(true,  InterestFilter("/a", "<b><>*").doesMatch(Name("/a/b")));
    Assert.equal(false, InterestFilter("/a", "<b><>+").doesMatch(Name("/a/b")));
    Assert.equal(true,  InterestFilter("/a", "<b><>+").doesMatch(Name("/a/b/c")));
*/
  });
});
