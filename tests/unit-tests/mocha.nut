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
 * use "Assert" instead. Otherwise if you call "assert.ok" you will get an
 * error like "the index 'ok' does not exist".
 */

Assert <- null;
it <- null;

beforeEachFunc <- null;
function beforeEach(func) { beforeEachFunc = func; }

afterEachFunc <- null;
function afterEach(func) { afterEachFunc = func; }

function describe(testName, test)
{
  // Define the global it function called by test() so we have the local context.
  ::it = function(subTestName, subTest)
  {
    // Define the global Assert functions called by subTest() so we have the local context.
    ::Assert = {
      function fail(unused1, unused2, message) {
        throw(testName + " " + subTestName + ": " + message);
      }

      function equal(value1, value2, message = null) {
        if (value1 != value2)
          throw(testName + " " + subTestName + ": " +
                (message != null ? message : "Assertion values are not equal"));
      }

      function deepEqual(array1, array2, message = null) {
        if (array1.len() != array2.len())
          throw(testName + " " + subTestName + ": " +
                (message != null ? message : "deepEqual arrays are not the same length"));
        for (local i = 0; i < array1.len(); ++i) {
          if (array1[i] != array2[i])
            throw(testName + " " + subTestName + ": deepEqual at index " + i + ": " +
                  (message != null ? message : "Assertion values are not equal"));
        }
      }

      function ok(value, message = null) {
        if (!value)
          throw(testName + " " + subTestName + ": " +
                (message != null ? message : "Assertion is not true"));
      }

      function throws(func, type = null, message = null) {
        try {
          func();
        } catch (ex) {
          if (type != null) {
            if (typeof ex == type)
              // An exception of the expected type was thrown.
              return;
            else
              throw(testName + " " + subTestName + ": " +
                    (message != null ?
                     message : "An exception of the expected type was not thrown"));
          }
          else
            // An exception was thrown as expected.
            return;
        }

        throw(testName + " " + subTestName + ": " +
              (message != null ? message : "An expected exception was not thrown"));
      }
    }

    if (beforeEachFunc != null)
      beforeEachFunc();
    subTest();
    if (afterEachFunc != null)
      afterEachFunc();

    consoleLog("PASSED: " + testName + " " + subTestName);
  }

  test();

  // Clear any beforeEach or afterEach function.
  beforeEachFunc = null;
  afterEachFunc = null;
}

