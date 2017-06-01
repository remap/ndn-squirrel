/**
 * Copyright (C) 2017 Regents of the University of California.
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
 * WakeupDelayedCallTable extends DelayedCallTable and overrides the callLater
 * method to automatically schedule the delayed call to callback() using
 * imp.wakeup. The application does not need to call callTimedOut(). This only
 * keeps one active wakeup timer, but since the Imp has limited timers you
 * should use this sparingly.
 */
class WakeupDelayedCallTable extends DelayedCallTable {
  timer_ = null;  // The active timer object, or null.

  /*
   * Call callback() after the given delay. This calls the base class method to
   * add to the delayed call table and uses imp.wakeup to schedule the delayed
   * call to callback(). The application does not need to call callTimedOut().
   * @param {float} delayMilliseconds: The delay in milliseconds.
   * @param {function} callback This calls callback() after the delay.
   */
  function callLater(delayMilliseconds, callback)
  {
    local earliestCallTime = 
      (table_.len() > 0 ? table_[0].getCallTimeSeconds() : null);
    base.callLater(delayMilliseconds, callback);

    if (earliestCallTime == null ||
        table_[0].getCallTimeSeconds() < earliestCallTime) {
      // The new call time is earlier than the previously scheduled call time.
      if (timer_ != null) {
        // Clear the old timer so we can make a new one.
        imp.cancelwakeup(timer_);
        timer_ = null;
      }

      scheduleWakeup_();
    }
  }

  /**
   * Based on the next call time (if any), use imp.wakeup() to call onWakeup_()
   * after the appropriate delay. This sets timer_ to the created timer object.
   */
  function scheduleWakeup_()
  {
    if (table_.len() <= 0)
      // No more scheduled callbacks.
      return;

    // Add a fraction of a second to make sure it's later than the next call time.
    local delaySeconds =
      (table_[0].getCallTimeSeconds() - NdnCommon.getNowSeconds()) + 0.1;

    local thisTable = this;
    timer_ = imp.wakeup(delaySeconds, function() { thisTable.onWakeup_(); });
  }

  /**
   * This is the callback from imp.wakeup(). Call callTimedOut() then
   * scheduleWakeup_().
   */
  function onWakeup_()
  {
    // TODO: What if a callback calls callLater (which calls this)?
    timer_ = null;
    try {
      callTimedOut();
    } catch (ex) {
      // Log and ignore exceptions from callbacks.
      consoleLog("Error in callTimedOut: " + ex);
    }

    scheduleWakeup_();
  }
}
