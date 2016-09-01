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

// This file is loaded for testing if not on the Imp to create simple stubs for
// the global agent and device objects.

agentOnCallbacks <- {}; // Key: the messageName. Value: An array of callbacks.
agent <- {
  on = function(messageName, callback) {
    if (!(messageName in agentOnCallbacks))
      agentOnCallbacks[messageName] <- [];
    agentOnCallbacks[messageName].append(callback);
  },
  send = function(messageName, obj) {
    if (messageName in deviceOnCallbacks)
      foreach (callback in deviceOnCallbacks[messageName])
        callback(obj);
  }
}

deviceOnCallbacks <- {};
device <- {
  on = function(messageName, callback) { 
    if (!(messageName in deviceOnCallbacks))
      deviceOnCallbacks[messageName] <- [];
    deviceOnCallbacks[messageName].append(callback);
  },
  send = function(messageName, obj) {
    if (messageName in agentOnCallbacks)
      foreach (callback in agentOnCallbacks[messageName])
        callback(obj);
  }
}
