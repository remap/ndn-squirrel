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
 * Imitate the JavaScript Mocha unit test framework. This defines "assert" and
 * the "describe" function, and must be included before the unit test files.
 * Note, because Squirrel already defines a global "assert" function, you must
 * use "Assert" instead. (Or you can put "local assert = Assert;" at the start
 * of each test function.) Otherwise if you call "assert.ok" you will get an
 * error like "the index 'ok' does not exist".
 */

Assert <- null;
it <- null;

function describe(testName, test)
{
  // Define the global it function called by test() to get the local context.
  ::it = function(subTestName, subTest)
  {
    // Define the global Assert functions called by subTest() to get the local context.
    ::Assert = {
      function equal(value1, value2) {
        if (value1 != value2)
          throw(testName + " " + subTestName + ": Assertion values are not equal");
      }

      function ok(value) {
        if (!value)
          throw(testName + " " + subTestName + ": Assertion is not true");
      }
    }

    subTest();
    consoleLog("PASSED: " + testName + " " + subTestName);
  }

  test();
}

