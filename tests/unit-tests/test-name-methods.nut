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

describe("TestNameComponentMethods", function() {
  it("Compare", function() {
    local c7f = Name("/%7F").get(0);
    local c80 = Name("/%80").get(0);
    local c81 = Name("/%81").get(0);

    Assert.ok(c81.compare(c80) > 0, "%81 should be greater than %80");
    Assert.ok(c80.compare(c7f) > 0, "%80 should be greater than %7f");
  });
});

describe("TestNameMethods", function() {
  local expectedURI = null;
  local comp2 = null;

  local TEST_NAME = Buffer([
    0x7,  0x14, // Name
      0x8,  0x5, // NameComponent
          0x6c,  0x6f,  0x63,  0x61,  0x6c,
      0x8,  0x3, // NameComponent
          0x6e,  0x64,  0x6e,
      0x8,  0x6, // NameComponent
          0x70,  0x72,  0x65,  0x66,  0x69,  0x78
  ]);

  local TEST_NAME_IMPLICIT_DIGEST = Buffer([
    0x7,  0x36, // Name
      0x8,  0x5, // NameComponent
          0x6c,  0x6f,  0x63,  0x61,  0x6c,
      0x8,  0x3, // NameComponent
          0x6e,  0x64,  0x6e,
      0x8,  0x6, // NameComponent
          0x70,  0x72,  0x65,  0x66,  0x69,  0x78,
      0x01, 0x20, // ImplicitSha256DigestComponent
        0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f,
        0x10, 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f
  ]);

  beforeEach(function() {
    expectedURI = "/entr%C3%A9e/..../%00%01%02%03";
    comp2 = NameComponent([0x00, 0x01, 0x02, 0x03]);
  });

  it("UriConstructor", function() {
    local name = Name(expectedURI);
    Assert.equal(name.size(), 3,
      "Constructed name has " + name.size() + " components instead of 3");
    Assert.equal(name.toUri(), expectedURI, "URI is incorrect");
  });

  it("CopyConstructor", function() {
    local name = Name(expectedURI);
    local name2 = Name(name);
    Assert.ok(name.equals(name2), "Name from copy constructor does not match original");
  });

  it("GetComponent", function() {
    local name = Name(expectedURI);
    local component2 = name.get(2);
    Assert.ok(comp2.equals(component2), "Component at index 2 is incorrect");
  });

  it("Append", function() {
    // We could possibly split this into different tests.
    local uri = "/localhost/user/folders/files/%00%0F";
    local name = Name(uri);
    local name2 = Name("/localhost").append(Name("/user/folders/"));
    Assert.equal(name2.size(), 3,
      "Name constructed by appending names has " + name2.size() + " components instead of 3");
    Assert.ok(name2.get(2).getValue().equals(Blob("folders")),
      "Name constructed with append has wrong suffix");
    name2.append("files");
    Assert.equal(name2.size(), 4,
      "Name constructed by appending string has " + name2.size() + " components instead of 4");
/*  TODO: Implement appendSegment.
    name2.appendSegment(15);
    Assert.ok(name2.get(4).getValue().equals(Blob([0x00, 0x0F])),
      "Name constructed by appending segment has wrong segment value");

    Assert.ok(name2.equals(name),
      "Name constructed with append is not equal to URI constructed name");
    Assert.equal(name2.toUri(), name.toUri(),
      "Name constructed with append has wrong URI");
*/
  });

  it("Prefix", function() {
    local name = Name("/edu/cmu/andrew/user/3498478");
    local name2 = name.getPrefix(2);
    Assert.equal(name2.size(), 2,
      "Name prefix has " + name2.size() + " components instead of 2");
    for (local i = 0; i < 2; ++i)
      Assert.ok(name.get(i).getValue().equals(name2.get(i).getValue()));

    local prefix2 = name.getPrefix(100);
    Assert.ok(prefix2.equals(name),
      "Prefix with more components than original should stop at end of original name");
  });

  it("Subname", function() {
    local name = Name("/edu/cmu/andrew/user/3498478");
    local subName1 = name.getSubName(0);
    Assert.ok(subName1.equals(name),
      "Subname from first component does not match original name");
    local subName2 = name.getSubName(3);
    Assert.equal(subName2.toUri(), "/user/3498478");

    local subName3 = name.getSubName(1, 3);
    Assert.equal(subName3.toUri(), "/cmu/andrew/user");

    local subName4 = name.getSubName(0, 100);
    Assert.ok(name.equals(subName4),
      "Subname with more components than original should stop at end of original name");

    local subName5 = name.getSubName(7, 2);
    Assert.ok(Name().equals(subName5),
      "Subname beginning after end of name should be empty");

    local subName6 = name.getSubName(-1,7);
    Assert.ok(subName6.equals(Name("/3498478")),
      "Negative subname with more components than original should stop at end of original name");

    local subName7 = name.getSubName(-5,5);
    Assert.ok(subName7.equals(name),
      "Subname from (-length) should match original name");
  });

  it("Clear", function() {
    local name = Name(expectedURI);
    name.clear();
    Assert.ok(Name().equals(name), "Cleared name is not empty");
  });

  it("Compare", function() {
    local names = [ Name("/a/b/d"), Name("/c"), Name("/c/a"), Name("/bb"), Name("/a/b/cc")];
    local expectedOrder = ["/a/b/d", "/a/b/cc", "/c", "/c/a", "/bb"];
    names.sort(function(a, b) { return a.compare(b); });

    local sortedURIs = [];
    for (local i = 0; i < names.len(); ++i)
      sortedURIs.push(names[i].toUri());
    Assert.deepEqual(sortedURIs, expectedOrder,
      "Name comparison gave incorrect order");

    // Tests from ndn-cxx name.t.cpp Compare.
    Assert.equal(Name("/A")  .compare(Name("/A")),    0);
    Assert.equal(Name("/A")  .compare(Name("/A")),    0);
    Assert.ok   (Name("/A")  .compare(Name("/B"))   < 0);
    Assert.ok   (Name("/B")  .compare(Name("/A"))   > 0);
    Assert.ok   (Name("/A")  .compare(Name("/AA"))  < 0);
    Assert.ok   (Name("/AA") .compare(Name("/A"))   > 0);
    Assert.ok   (Name("/A")  .compare(Name("/A/C")) < 0);
    Assert.ok   (Name("/A/C").compare(Name("/A"))   > 0);

    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/A")),    0);
    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/A")),    0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/B"))   < 0);
    Assert.ok   (Name("/Z/B/Y")  .compare(1, 1, Name("/A"))   > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/AA"))  < 0);
    Assert.ok   (Name("/Z/AA/Y") .compare(1, 1, Name("/A"))   > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/A/C")) < 0);
    Assert.ok   (Name("/Z/A/C/Y").compare(1, 2, Name("/A"))   > 0);

    Assert.equal(Name("/Z/A")  .compare(1, 9, Name("/A")),    0);
    Assert.equal(Name("/Z/A")  .compare(1, 9, Name("/A")),    0);
    Assert.ok   (Name("/Z/A")  .compare(1, 9, Name("/B"))   < 0);
    Assert.ok   (Name("/Z/B")  .compare(1, 9, Name("/A"))   > 0);
    Assert.ok   (Name("/Z/A")  .compare(1, 9, Name("/AA"))  < 0);
    Assert.ok   (Name("/Z/AA") .compare(1, 9, Name("/A"))   > 0);
    Assert.ok   (Name("/Z/A")  .compare(1, 9, Name("/A/C")) < 0);
    Assert.ok   (Name("/Z/A/C").compare(1, 9, Name("/A"))   > 0);

    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/X/A/W"),   1, 1),  0);
    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/X/A/W"),   1, 1),  0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/B/W"),   1, 1) < 0);
    Assert.ok   (Name("/Z/B/Y")  .compare(1, 1, Name("/X/A/W"),   1, 1) > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/AA/W"),  1, 1) < 0);
    Assert.ok   (Name("/Z/AA/Y") .compare(1, 1, Name("/X/A/W"),   1, 1) > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/A/C/W"), 1, 2) < 0);
    Assert.ok   (Name("/Z/A/C/Y").compare(1, 2, Name("/X/A/W"),   1, 1) > 0);

    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/X/A"),   1),  0);
    Assert.equal(Name("/Z/A/Y")  .compare(1, 1, Name("/X/A"),   1),  0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/B"),   1) < 0);
    Assert.ok   (Name("/Z/B/Y")  .compare(1, 1, Name("/X/A"),   1) > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/AA"),  1) < 0);
    Assert.ok   (Name("/Z/AA/Y") .compare(1, 1, Name("/X/A"),   1) > 0);
    Assert.ok   (Name("/Z/A/Y")  .compare(1, 1, Name("/X/A/C"), 1) < 0);
    Assert.ok   (Name("/Z/A/C/Y").compare(1, 2, Name("/X/A"),   1) > 0);
  });

  it("Match", function() {
    local name = Name("/edu/cmu/andrew/user/3498478");
    local name1 = Name(name);
    Assert.ok(name.match(name1), "Name does not match deep copy of itself");

    local name2 = name.getPrefix(2);
    Assert.ok(name2.match(name), "Name did not match prefix");
    Assert.ok(!name.match(name2), "Name should not match shorter name");
    Assert.ok(Name().match(name), "Empty name should always match another");
  });

  // TODO: GetSuccessor

  it("EncodeDecode", function() {
    local name = Name("/local/ndn/prefix");

    local encoding = name.wireEncode(TlvWireFormat.get());
    Assert.ok(encoding.equals(Blob(TEST_NAME)));

    local decodedName = Name();
    decodedName.wireDecode(Blob(TEST_NAME), TlvWireFormat.get());
    Assert.ok(decodedName.equals(name));

    // Test ImplicitSha256Digest.
    local name2 = Name
      ("/local/ndn/prefix/sha256digest=" +
       "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f");

    local encoding2 = name2.wireEncode(TlvWireFormat.get());
    Assert.ok(encoding2.equals(Blob(TEST_NAME_IMPLICIT_DIGEST)));

    local decodedName2 = Name();
    decodedName2.wireDecode(Blob(TEST_NAME_IMPLICIT_DIGEST), TlvWireFormat.get());
    Assert.ok(decodedName2.equals(name2));
  });

  it("ImplicitSha256Digest", function() {
    local name = Name();

    local digest = Buffer([
      0x28, 0xba, 0xd4, 0xb5, 0x27, 0x5b, 0xd3, 0x92,
      0xdb, 0xb6, 0x70, 0xc7, 0x5c, 0xf0, 0xb6, 0x6f,
      0x13, 0xf7, 0x94, 0x2b, 0x21, 0xe8, 0x0f, 0x55,
      0xc0, 0xe8, 0x6b, 0x37, 0x47, 0x53, 0xa5, 0x48,
      0x00, 0x00
    ]);

    name.appendImplicitSha256Digest(digest.slice(0, 32));
    name.appendImplicitSha256Digest(digest.slice(0, 32));
    Assert.ok(name.get(0).equals(name.get(1)));

    local gotError = true;
    try {
      name.appendImplicitSha256Digest(digest.slice(0, 34));
      gotError = false;
    } catch (ex) {}
    if (!gotError)
      Assert.fail("Expected error in appendImplicitSha256Digest");

    local gotError = true;
    try {
      name.appendImplicitSha256Digest(digest.slice(0, 30));
      gotError = false;
    } catch (ex) {}
    if (!gotError)
      Assert.fail("Expected error in appendImplicitSha256Digest");

    // Add name.get(2) as a generic component.
    name.append(digest.slice(0, 32));
    Assert.ok(name.get(0).compare(name.get(2)) < 0);
    Assert.ok(name.get(0).getValue().equals(name.get(2).getValue()));

    // Add name.get(3) as a generic component whose first byte is greater.
    name.append(digest.slice(1, 32));
    Assert.ok(name.get(0).compare(name.get(3)) < 0);

    Assert.equal
      (name.get(0).toEscapedString(),
       "sha256digest=" +
       "28bad4b5275bd392dbb670c75cf0b66f13f7942b21e80f55c0e86b374753a548");

    Assert.equal(name.get(0).isImplicitSha256Digest(), true);
    Assert.equal(name.get(2).isImplicitSha256Digest(), false);

    gotError = true;
    try {
      Name("/hello/sha256digest=hmm");
      gotError = false;
    } catch (ex) {}
    if (!gotError)
      Assert.fail("Expected error in new Name from URI");

    // Check canonical URI encoding (lower case).
    local name2 = Name
      ("/hello/sha256digest=" +
       "28bad4b5275bd392dbb670c75cf0b66f13f7942b21e80f55c0e86b374753a548");
    Assert.ok(name.get(0).equals(name2.get(1)));

    // Check that it will accept a hex value in upper case too.
    name2 = Name
      ("/hello/sha256digest=" +
       "28BAD4B5275BD392DBB670C75CF0B66F13F7942B21E80F55C0E86B374753A548");
    Assert.ok(name.get(0).equals(name2.get(1)));

    // This is not a valid sha256digest component. It should be treated as generic.
    name2 = Name
      ("/hello/SHA256DIGEST=" +
       "28BAD4B5275BD392DBB670C75CF0B66F13F7942B21E80F55C0E86B374753A548");
    Assert.ok(!name.get(0).equals(name2.get(1)));
    Assert.ok(name2.get(1).isGeneric());
  });
});
