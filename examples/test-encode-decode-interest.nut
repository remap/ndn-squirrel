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

local TlvInterest = Blob([
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
  0x0A, 0x04, 0x61, 0x62, 0x61, 0x62, // Nonce
  0x0C, 0x02, 0x75, 0x30, // InterestLifetime
1
]);

function excludeToRawUri(exclude) {
  if (exclude.size() == 0)
    return "";

  local result = "";
  for (local i = 0; i < exclude.size(); ++i) {
    if (i > 0)
      result += ",";

    if (exclude.get(i).getType() == ExcludeType.ANY)
      result += "*";
    else
      result += exclude.get(i).getComponent().getValue().toRawStr();
  }

  return result;
}

function dumpInterest(interest)
{
  consoleLog("name: " + interest.getName().toUri());
  consoleLog("minSuffixComponents: " + (interest.getMinSuffixComponents() != null ?
    interest.getMinSuffixComponents() : "<none>"));
  consoleLog("maxSuffixComponents: " + (interest.getMaxSuffixComponents() != null ?
    interest.getMaxSuffixComponents() : "<none>"));
  if (interest.getKeyLocator().getType() != null) {
    if (interest.getKeyLocator().getType() == KeyLocatorType.KEY_LOCATOR_DIGEST)
      consoleLog("keyLocator: KeyLocatorDigest: " +
                 interest.getKeyLocator().getKeyData().toHex());
    else if (interest.getKeyLocator().getType() == KeyLocatorType.KEYNAME)
      consoleLog("keyLocator: KeyName: " +
                 interest.getKeyLocator().getKeyName().toUri());
    else
      consoleLog("keyLocator: <unrecognized ndn_KeyLocatorType " +
                 interest.getKeyLocator().getType() + ">");
  }
  else
    consoleLog("keyLocator: <none>");

  consoleLog("exclude: " + (interest.getExclude().size() > 0 ?
                      excludeToRawUri(interest.getExclude()) : "<none>"));
  consoleLog("lifetimeMilliseconds: " +
    (interest.getInterestLifetimeMilliseconds() != null ?
    interest.getInterestLifetimeMilliseconds() : "<none>"));
  consoleLog("childSelector: " +
    (interest.getChildSelector() != null ?interest.getChildSelector() : "<none>"));
  consoleLog("mustBeFresh: " + (interest.getMustBeFresh() ? "true" : "false"));
  consoleLog("nonce: " +
    (interest.getNonce().size() > 0 ? interest.getNonce().toHex() : "<none>"));
}

function main()
{
  local interest = Interest();
  interest.wireDecode(TlvInterest);
  consoleLog("Interest:");
  dumpInterest(interest);

  // Set the name again to clear the cached encoding so we encode again.
  interest.setName(interest.getName());
  local encoding = interest.wireEncode();
  consoleLog("");
  consoleLog("Re-encoded interest " + encoding.toHex());

  local reDecodedInterest = Interest();
  reDecodedInterest.wireDecode(encoding);
  consoleLog("Re-decoded Interest:");
  dumpInterest(reDecodedInterest);
}

main();
