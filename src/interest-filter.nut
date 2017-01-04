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

/**
 * An InterestFilter holds a Name prefix and optional regex match expression for
 * use in Face.setInterestFilter.
 */
class InterestFilter {
  prefix_ = null;
  regexFilter_ = null;
  regexFilterPattern_ = null;

  /**
   * Create an InterestFilter to match any Interest whose name starts with the
   * given prefix. If the optional regexFilter is provided then the remaining
   * components match the regexFilter regular expression as described in
   * doesMatch.
   * @param {InterestFilter|Name|string} prefix If prefix is another
   * InterestFilter copy its values. If prefix is a Name then this makes a copy
   * of the Name. Otherwise this creates a Name from the URI string.
   * @param {string} regexFilter (optional) The regular expression for matching
   * the remaining name components.
   */
  constructor(prefix, regexFilter = null)
  {
    if (prefix instanceof InterestFilter) {
      // The copy constructor.
      local interestFilter = prefix;
      prefix_ = Name(interestFilter.prefix_);
      regexFilter_ = interestFilter.regexFilter_;
      regexFilterPattern_ = interestFilter.regexFilterPattern_;
    }
    else {
      prefix_ = Name(prefix);
      if (regexFilter != null) {
/*      TODO: Support regex.
        regexFilter_ = regexFilter;
        regexFilterPattern_ = InterestFilter.makePattern(regexFilter);
*/
        throw "not supported";
      }
    }
  }
  
  /**
   * Check if the given name matches this filter. Match if name starts with this
   * filter's prefix. If this filter has the optional regexFilter then the
   * remaining components match the regexFilter regular expression.
   * For example, the following InterestFilter:
   *
   *    InterestFilter("/hello", "<world><>+")
   *
   * will match all Interests, whose name has the prefix `/hello` which is
   * followed by a component `world` and has at least one more component after it.
   * Examples:
   *
   *    /hello/world/!
   *    /hello/world/x/y/z
   *
   * Note that the regular expression will need to match all remaining components
   * (e.g., there are implicit heading `^` and trailing `$` symbols in the
   * regular expression).
   * @param {Name} name The name to check against this filter.
   * @return {bool} True if name matches this filter, otherwise false.
   */
  function doesMatch(name)
  {
    if (name.size() < prefix_.size())
      return false;

/*  TODO: Support regex. The constructor already rejected a regexFilter.
    if (hasRegexFilter()) {
      // Perform a prefix match and regular expression match for the remaining
      // components.
      if (!prefix_.match(name))
        return false;

      return null != NdnRegexMatcher.match
        (this.regexFilterPattern, name.getSubName(this.prefix.size()));
    }
    else
*/
      // Just perform a prefix match.
      return prefix_.match(name);
  }

  /**
   * Get the prefix given to the constructor.
   * @return {Name} The prefix Name which you should not modify.
   */
  function getPrefix() { return prefix_; }

  // TODO: hasRegexFilter
  // TODO: getRegexFilter
}
