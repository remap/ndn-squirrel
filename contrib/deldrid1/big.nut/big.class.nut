/*
  Based on big.js v3.1.3
  A small, fast, easy-to-use library for arbitrary-precision decimal arithmetic.
  https://github.com/MikeMcl/big.js/
  Copyright (c) 2014 Michael Mclaughlin <M8ch88l@gmail.com>
  MIT Expat Licence
*/
//TODO: BUG: The full suite of regression tests needs to be reran

//TODO: BUG: Implement metamethods...
// Available Squirrel Metamethods include the following:
//
// | Metamethod | Operator(s)      | Parameter(s)                                       | Notes                                                                                                                                      |
// |------------|------------------|----------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------|
// | _cmp       | <, >, <=, >=, == | Operand to the right of the operator               | Perform a comparison, eg. if (a > b) { ... } Function should return an integer: 1, if a > b 0, if a == b -1, if a < b                      |
// | _mul       | *                | Operand to the right of the operator               | Perform a multiplication, eg. local a = b * c Returns the result                                                                           |
// | _add       | +                | Operand to the right of the operator               | Perform an addition, eg. local a = b + c Returns the result                                                                                |
// | _sub       | -                | Operand to the right of the operator               | Perform a subtraction, eg, local a = b - c Returns the result                                                                              |
// | _div       | /                | Operand to the right of the operator               | Perform a division, eg. local a = b / c Returns the result                                                                                 |
// | _mod       | %                | Operand to the right of the operator               | Perform a modulo, eg. local a = b % c Returns the result                                                                                   |
// | _unm       | -                | Operand to the right of the operator               | Perform a unary minus, eg. local a = -b Returns the result                                                                                 |
// | _newslot   | <-               | Key and value                                      | Creates and adds a new slot to a table                                                                                                     |
// | _delete    | delete           | Key                                                | Removes a slot from a table                                                                                                                |
// | _set       | =                | Key and value                                      | Called when code attempts to set a non-existent slot’s key, eg. table.a = b                                                                |
// | _get       | =                | Key                                                | Called when code attempts to get the value of a non-existent slot, eg. local a = table.b                                                   |
// | _typeof    | typeof           | None                                               | Returns type of object or class instance as a string, eg. local a = typeof b                                                               |
// | _tostring  | .tostring()      | None                                               | Returns the value of the object or class instance as a string, eg. local a = b.tostring()                                                  |
// | _nexti     | foreach... in... | Previous iteration index                           | Called at each iteration of a foreach loop. Parameter value will be null at the first iteration. Function must return the next index value |
// | _cloned    | clone            | The original instance or table                     | Called when an instance or table is cloned                                                                                                 |
// | _inherited |                  | New class (as this) and its attributes             | A parent class method is overridden by a child class                                                                                       |
// | _newmember |                  | index, value, attributes, isstatic                 | Called when a new class member is declared. If implemented, members will not be added to the class                                         |
// | _call      |                  | this and the function's other (visible) parameters | A function in a table or class instance is called                                                                                          |
//
// See https://electricimp.com/docs/resources/metamethods/
// Also be aware of “halting stuck metamethod”. This arises because Squirrel agent code is time-sliced with all other Squirrel agent code. For technical reasons, Squirrel can’t be time-sliced while executing a metamethod. So each metamethod call is limited to a single time-slice (1,000 Squirrel compiled bytecode instructions) before it is aborted as a potential CPU hog, ie. potentially unfair to other agents running on the same system. There is no way around this other than to make the metamethod use fewer instructions (or don't use the metamethod at all)
class Big {

/* Don't use regexp2.
   static isValid = regexp2(@"^-?(\d+(\.\d*)?|\.\d+)(e[+-]?\d+)?$");
*/
   c = null;	//coefficient*	number[]	Blob (used as a low overhead Array) of single digits
   e = null;	//exponent	number	Integer, -1e+6 to 1e+6 inclusive
   s = null; 	//sign	number	-1 or 1

   minus = null;
   plus = null;
   times = null;
   valueOf = null;
   toJSON = null;

/***************************** EDITABLE DEFAULTS ******************************/

    // The default values below must be integers within the stated ranges.

    /*
     * The maximum number of decimal places of the results of operations
     * involving division: div and sqrt, and pow with negative exponents.
     */
    DP = 20;                           // 0 to MAX_DP

    /*
     * The rounding mode used when rounding to the above decimal places.
     *
     * 0 Towards zero (i.e. truncate, no rounding).       (ROUND_DOWN)
     * 1 To nearest neighbour. If equidistant, round up.  (ROUND_HALF_UP)
     * 2 To nearest neighbour. If equidistant, to even.   (ROUND_HALF_EVEN)
     * 3 Away from zero.                                  (ROUND_UP)
     */
     RM = 1;                            // 0, 1, 2 or 3

     // The maximum value of DP and Big.DP.
     MAX_DP = 1E6;                      // 0 to 1000000

     // The maximum magnitude of the exponent argument to the pow method.
     MAX_POWER = 1E6;                   // 1 to 1000000

    /*
     * The exponent value at and beneath which toString returns exponential
     * notation.
     * JavaScript's Number type: -7
     * -1000000 is the minimum recommended exponent value of a Big.
     */
     E_NEG = -7;                   // 0 to -1000000

    /*
     * The exponent value at and above which toString returns exponential
     * notation.
     * JavaScript's Number type: 21
     * 1000000 is the maximum recommended exponent value of a Big.
     * (This limit is not enforced or checked.)
     */
     E_POS = 21;                   // 0 to 1000000

/******************************************************************************/

        /*
         * The Big constructor and exported function.
         * Create and return a new instance of a Big number object.
         *
         * n {number|string|Big} A numeric value.
         */
      constructor(n) {
          // Duplicate.
          if (n instanceof Big) {
              this.s = n.s;
              this.e = n.e;
              this.c = clone(n.c);
          } else {
              parse(n.tostring().tolower());
          }

          this.minus = this.sub;
          this.plus = this.add;
          this.times = this.mul;
          this.valueOf = this.toString;
          this.toJSON = this.toString;
        }


    // // Private functions


    /*
     * Return a string representing the value of Big x in normal or exponential
     * notation to dp fixed decimal places or significant digits.
     *
     * dp {number} Integer, 0 to MAX_DP inclusive.
     * toE {number} 1 (toExponential), 2 (toPrecision) or undefined (toFixed).
     */
  function format(dp, toE=null) {
        local x = Big(this),
            // The index (normal notation) of the digit that may be rounded up.
            i = dp - x.e,
            c = x.c;

        // Round?
        if (c.len() > ++dp) {
            x.rnd(i, this.RM);
            c = x.c
        }

        if (!c[0]) {
            ++i;
        } else if (toE) {
            i = dp;

        // toFixed
        } else {
            c = x.c
            // Recalculate i as x.e may have changed if value rounded up.
            i = x.e + i + 1;
            x.E_NEG = x.e-1;
            x.E_POS = x.e+1;
        }

        // Append zeros?
        while(c.len() < i) {
          _resize(c, c.len()+1)
          //c[c.len()-1] = 0
        }
        i = x.e;

        /*
         * toPrecision returns exponential notation if the number of
         * significant digits specified is less than the number of digits
         * necessary to represent the integer part of the value in normal
         * notation.
         */
        return toE == 1 || toE && (dp <= i || i <= this.E_NEG) ?

          // Exponential notation.
        (x.s < 0 && c[0] ? "-" : "") + (c.len() > 1 ? c[0] + "." + _reduce(c).slice(1) : c[0]) + (i < 0 ? "e" : "e+") + i

          // Normal notation.
          : x.toString();
    }


    /*
     * Parse the number or string value passed to a Big constructor.
     *
     * x {Big} A Big number instance.
     * n {number|string} A numeric value.
     */
    function parse(n) {
        local e, i, nL;

        /*// Minus zero?
        if (n == 0 && 1 / n < 0) {
            n = "-0";
        } else if*/

        // Determine sign.
        if(n[0] == '-'){
          this.s = -1;
          n = n.slice(1)
        } else {
          this.s = 1;
          if(n[0] == '+')
            n = n.slice(1)
        }

/* Don't use regexp2.
        // Ensure n is string and check validity.
        if (!Big.isValid.match(n)) {
            throwErr("!Big.NaN!");
        }
*/

        // Decimal point?
        e = n.find(".") == null ? -1 : n.find(".");
        if (e != -1) {
            n = n.slice(0, e) + n.slice(e+1)
        }

        // Exponential form?
        i = n.find("e") == null ? -1 : n.find("e")
        if (i != -1) {

            // Determine exponent.
            if (e < 0) {
                e = i;
            }
            e += n.slice(i + 1).tointeger();
            n = n.slice(0, i);

        } else if (e < 0) {

            // Integer.
            e = n.len();
        }

        nL = n.len();

        // Determine leading zeros.
        for (i = 0; i < nL && n[i] == '0'; i++) {
        }


        if (i == nL) {

            // Zero.
            this.e = 0
            this.c = blob(1);
        } else {

            // Determine trailing zeros.
            for (; n[--nL] == '0';) {
            }

            this.e = e - i - 1;
            this.c = blob(nL-i + 1);

            // Convert string to array of digits without leading/trailing zeros.
            for (e = 0; i <= nL; this.c[e++] = n[i++].tochar().tointeger()) {
            }
        }

        return this;
    }


    /*
     * Round Big x to a maximum of dp decimal places using rounding mode rm.
     * Called by div, sqrt and round.
     *
     * dp {number} Integer, 0 to MAX_DP inclusive.
     * rm {number} 0, 1, 2 or 3 (DOWN, HALF_UP, HALF_EVEN, UP)
     * [more] {boolean} Whether the result of division was truncated.
     */
    function rnd(dp, rm, more = null) {
        local xc = clone(this.c),
              i = this.e + dp + 1;

        if (rm == 1) {
            // xc[i] is the digit after the digit that may be rounded up.
            more = i < 0 || i >= xc.len() ? false : xc[i] >= 5;
        } else if (rm == 2) {
            if(i < 0 || i >= xc.len())
                more = false
            else
                more = xc[i] > 5 || xc[i] == 5 && (more || i+1 < xc.len() || (i > 0 && xc[i - 1] & 1))
        } else if (rm == 3) {
            more = more || i < xc.len() || i < 0;
        } else {
            more = false;
            if (rm != 0) {
                throwErr("!Big.RM!");
            }
        }

        if (i < 1 || !xc[0]) {
            if (more) {

                // 1, 0.1, 0.01, 0.001, 0.0001 etc.
                this.e = -dp;
                xc = blob(1)
                xc[0] = 1;
            } else {

                // Zero.
                xc = blob(1);
                this.e = 0;
            }
        } else {

            // Remove any digits after the required decimal places.
            xc = i < xc.len() ? _slice(xc, 0, i) : xc;
            i--;

            // Round up?
            if (more) {



                // Rounding up may mean the previous digit has to be rounded up.
                for (; i >= 0 && ++xc[i] > 9;) {
                    xc[i] = 0;

                    if (!i--) {
                        ++this.e;
                        _insert(xc, 0,1);
                    }
                }
            }

            // Remove trailing zeros.
            for (i = xc.len(); --i >= 0 && !xc[i]; _resize(xc, xc.len()-1)) {
            }
        }

        this.c = xc;

        return this;
    }


    /*
     * Throw a BigError.
     *
     * message {string} The error message.
     */
    function throwErr(message) {
        throw "BigError" + message;
    }

    function _tostring() {
        return (this.s == 1 ? "+" : "-") + "[" + _reduce(this.c) + "]E"+this.e
    }



    // // Prototype/instance methods


    /*
     * Return a new Big whose value is the absolute value of this Big.
     */
    function abs() {
        local x = Big(this);
        x.s = 1;

        return x;
    };


    /*
     * Return
     * 1 if the value of this Big is greater than the value of Big y,
     * -1 if the value of this Big is less than the value of Big y, or
     * 0 if they have the same value.
    */
   function cmp (y) {
        local xNeg,
            x = this,
            xc = x.c,
            y = Big(y),
            yc = y.c,
            i = x.s,
            j = y.s,
            k = x.e,
            l = y.e;

        // Either zero?
        if (!xc[0] || !yc[0]) {
            return !xc[0] ? !yc[0] ? 0 : -j : i;
        }

        // Signs differ?
        if (i != j) {
            return i;
        }
        xNeg = (i < 0).tointeger();

        // Compare exponents.
        if (k != l) {
            return (k > l).tointeger() ^ xNeg ? 1 : -1;
        }

        i = -1;
        k = xc.len();
        l = yc.len();
        j = k < l ? k : l;

        // Compare digit by digit.
        for (; ++i < j;) {

            if (xc[i] != yc[i]) {
                return (xc[i] > yc[i]).tointeger() ^ xNeg ? 1 : -1;
            }
        }

        // Compare lengths.
        return k == l ? 0 : (k > l).tointeger() ^ xNeg ? 1 : -1;
    };


    /*
     * Return a new Big whose value is the value of this Big divided by the
     * value of Big y, rounded, if necessary, to a maximum of Big.DP decimal
     * places using rounding mode Big.RM.
     */
     function div(y) {
         y = Big(y)
         local x = this,
             // dividend
             dvd = x.c,
             //divisor
             dvs = y.c,
             s = x.s == y.s ? 1 : -1,
             dp = this.DP;

         if (dp != ~~dp || dp < 0 || dp > MAX_DP) {
             throwErr("!Big.DP!");
         }

         // Either 0?
         if (!dvd[0] || !dvs[0]) {

             // If both are 0, throw NaN
             if (dvd[0] == dvs[0]) {
                 throwErr("!Big.NaN!");
             }

             // If dvs is 0, throw +-Infinity.
             if (!dvs[0]) {
                 throwErr("!Big." + s < 0 ? "-" : "+" + "Infinity");
             }

             // dvd is 0, return +-0.
             return Big((s < 0 ? "-" : "+") + "0");
         }

         local dvsL, dvsT, next, cmp, remI,
             dvsZ = clone(dvs),
             dvdI = dvs.len(),
             dvsL = dvs.len(),
             dvdL = dvd.len(),
             // remainder
             rem = _slice(dvd, 0, dvsL < dvd.len() ? dvsL : dvd.len()),
             remL = rem.len(),
             // quotient
             q = y,
             qc =  blob(),
             qi = 0,
             digits = dp + (x.e - y.e) + 1;

         q.c = qc
         q.e = x.e - y.e
         q.s = s;
         s = digits < 0 ? 0 : digits;

         // Create version of divisor with leading zero.
         _insert(dvsZ, 0,0);

         // Add zeros to make remainder as long as divisor.
         while(remL++ < dvsL){
           _resize(rem, rem.len()+1)
           //rem[rem.len()-1] = 0
         }

         do {
             // 'next' is how many times the divisor goes into current remainder.
             for (next = 0; next < 10; next++) {

                 // Compare divisor and remainder.
                 remL = rem.len()
                 if (dvsL != remL) {
                     cmp = dvsL > remL ? 1 : -1;
                 } else {

                     for (remI = -1, cmp = 0; ++remI < dvsL;) {

                         if (dvs[remI] != rem[remI]) {
                             if(rem[remI] != 0xFF)
                                 cmp = dvs[remI] > rem[remI] ? 1 : -1;
                             else
                                 cmp = -1
                             break;
                         }
                     }
                 }

                 // If divisor < remainder, subtract divisor from remainder.
                 if (cmp < 0) {

                     // Remainder can't be more than 1 digit longer than divisor.
                     // Equalise lengths using divisor with extra leading zero
                     for (dvsT = remL == dvsL ? dvs : dvsZ; remL > 0;) {

                         if (remL == 0 || (rem[--remL] != 0xFF && rem[remL] < dvsT[remL])) {
                             remI = remL;

                             for (; remI && !rem[--remI] && rem[remI] != 0xFF; rem[remI] = 9) {
                             }
                             --rem[remI];
                             rem[remL] == 0xFF ? rem[remL] = 10 : rem[remL] += 10;
                         }
                         rem[remL] -= dvsT[remL];
                     }
                     for (; !rem[0] || rem[0] == 0xFF; rem = _slice(rem, 1)) {
                     }
                 } else {
                     break;
                 }
             }

             // Add the 'next' digit to the result array.
             _resize(qc, qc.len()+1)
             qc[qc.len()-1] = cmp ? next : ++next;
             qi++

             // Update the remainder.
             if (rem[0] && rem[0] != 0xFF && cmp) {
                 _resize(rem, rem.len()+1)
                 rem[rem.len()-1] = dvdI < dvd.len() ? dvd[dvdI] : 0; //TODO: BUG: There are probably a lot of if statements that we need to update
             } else {
                 rem = blob(1)
                 rem[0] = dvdI < dvd.len() ? dvd[dvdI] : 0xFF;
             }

         } while ((dvdI++ < dvdL || rem[0] != 0xFF) && s--);

         // Leading zero? Do not remove if result is simply zero (qi == 1).
         if (!qc[0] && qi != 1) {

             // There can't be more than one zero.
             _remove(qc, 0);
             q.e--;
         }

         // Round?
         if (qi > digits) {
             q.rnd(dp, this.RM, rem[0] != 0xFF);
         }

         return q;
     };



    /*
     * Return true if the value of this Big is equal to the value of Big y,
     * otherwise returns false.
     */
    function eq(y) {
        return !this.cmp(y);
    };


    /*
     * Return true if the value of this Big is greater than the value of Big y,
     * otherwise returns false.
     */
    function gt(y) {
        return this.cmp(y) > 0;
    };


    /*
     * Return true if the value of this Big is greater than or equal to the
     * value of Big y, otherwise returns false.
     */
    function gte(y) {
        return this.cmp(y) > -1;
    };


    /*
     * Return true if the value of this Big is less than the value of Big y,
     * otherwise returns false.
     */
    function lt(y) {
        return this.cmp(y) < 0;
    };


    /*
     * Return true if the value of this Big is less than or equal to the value
     * of Big y, otherwise returns false.
     */
    function lte(y) {
         return this.cmp(y) < 1;
    };


    /*
     * Return a new Big whose value is the value of this Big minus the value
     * of Big y.
     */
    function sub(y) {
        y = Big(y)
        local   i, j, t, xLTy,
                x = this,
                a = x.s,
                b = y.s;

        // Signs differ?
        if (a != b) {
            y.s = -b;
            return x.plus(y);
        }

        local   xc = clone(x.c),
                xe = x.e,
                yc = y.c,
                ye = y.e;

        // Either zero?
        if (!xc[0] || !yc[0]) {
            // y is non-zero? x is non-zero? Or both are zero.
            if(yc[0]) {
                y.s = -b
                return y
            } else {
                return Big(xc[0] ? x : 0)
            }
        }

        // Determine which is the bigger number.
        // Prepend zeros to equalise exponents.
        a = xe - ye
        if (a) {
            xLTy = a < 0

            if (xLTy) {
                a = -a;
                t = xc;
            } else {
                ye = xe;
                t = yc;
            }

            _reverse(t);
            for (b = a; b--;) {
              _resize(t, t.len()+1)
              //t[t.len()-1] = 0
            }
            _reverse(t);
        } else {

            // Exponents equal. Check digit by digit.
            xLTy = xc.len() < yc.len()
            j = xLTy ? xc.len() : yc.len();

            a = 0;
            for (b = 0; b < j; b++) {

                if (xc[b] != yc[b]) {
                    xLTy = xc[b] < yc[b];
                    break;
                }
            }
        }

        // x < y? Point xc to the array of the bigger number.
        if (xLTy) {
            t = xc;
            xc = yc;
            yc = t;
            y.s = -y.s;
        }

        /*
         * Append zeros to xc if shorter. No need to add zeros to yc if shorter
         * as subtraction only needs to start at yc.len().
         */
         j = yc.len()
         i = xc.len()
         b = j - i
        if (b > 0) {

            for (; b--; i++) {
                _resize(xc, xc.len()+1)
                //xc[xc.len()-1] = 0
            }
        }

        // Subtract yc from xc.
        for (b = i; j > a;){

            if (xc[--j] < yc[j]) {

                for (i = j; i && !xc[--i]; xc[i] = 9) {
                }
                --xc[i];
                xc[j] += 10;
            }
            xc[j] -= yc[j];
        }

        // Remove trailing zeros.
        for (; b > 0 && xc[--b] == 0; _resize(xc, xc.len()-1)) {
        }


        // Remove leading zeros and adjust exponent accordingly.
        for (; xc.len() > 0 && xc[0] == 0;) {
            xc = _slice(xc, 1)
            --ye;
        }

        if (xc.len() == 0 || !xc[0]) {

            // n - n = +0
            y.s = 1;

            // Result must be zero.
            ye = 0
            xc = blob(1);
        }

        y.c = xc;
        y.e = ye;

        return y;
    };


    /*
     * Return a new Big whose value is the value of this Big modulo the
     * value of Big y.
     */
    function mod(y) {
        y = Big(y)
        local yGTx,
            x = this,
            a = x.s,
            b = y.s;

        if (!y.c[0]) {
            throwErr("!Big.NaN!");
        }

        x.s = 1;
        y.s = 1;
        yGTx = y.cmp(x) == 1;
        x.s = a;
        y.s = b;

        if (yGTx) {
            return Big(x);
        }

        a = this.DP;
        b = this.RM;
        this.DP = 0
        this.RM = 0;
        x = x.div(y);
        this.DP = a;
        this.RM = b;

        return this.minus( x.times(y) );
    };


    /*
     * Return a new Big whose value is the value of this Big plus the value
     * of Big y.
     */
    function add (y) {
        y = Big(y)
        local   t,
                x = this,
                a = x.s,
                b = y.s;

        // Signs differ?
        if (a != b) {
            y.s = -b;
            return x.sub(y);
        }

        local   xe = x.e,
                xc = x.c,
                ye = y.e,
                yc = y.c;

        // Either zero?
        if (!xc[0] || !yc[0]) {
            // y is non-zero? x is non-zero? Or both are zero.
            return yc[0] ? y : Big(xc[0] ? x : a < 0 ? "-" : "+" + "0");
        }
        xc = clone(xc);

        // Prepend zeros to equalise exponents.
        // TODO: Is it Faster to use reverse then do unshifts?  (It is in JS)
        a = xe-ye
        if (a) {

            if (a > 0) {
                ye = xe;
                t = yc;
            } else {
                a = -a;
                t = xc;
            }

            _reverse(t);
            while(a--){
              _resize(t, t.len()+1)
              //t[t.len()-1] = 0
            }
            _reverse(t);
        }

        // Point xc to the longer array.
        if (xc.len() - yc.len() < 0) {
            t = yc;
            yc = xc;
            xc = t;
        }
        a = yc.len();

        /*
         * Only start adding at yc.len() - 1 as the further digits of xc can be
         * left as they are.
         */
        for (b = 0; a;) {
            xc[--a] = xc[a] + yc[a] + b
            b = (xc[a]) / 10 | 0;
            xc[a] %= 10;
        }

        // No need to check for zero, as +x + +y != 0 && -x + -y != 0

        if (b) {
             _insert(xc, 0,b);
            ++ye;
        }

         // Remove trailing zeros.
        for (a = xc.len(); a > 0 && xc[--a] == 0; _resize(xc, xc.len()-1)) {
        }

        y.c = xc;
        y.e = ye;

        return y;
    };



    /*
     * Return a Big whose value is the value of this Big raised to the power n.
     * If n is negative, round, if necessary, to a maximum of Big.DP decimal
     * places using rounding mode Big.RM.
     *
     * n {number} Integer, -MAX_POWER to MAX_POWER inclusive.
     */
    function pow(n) {
        local x = this,
            one = Big(1),
            y = one,
            isNeg = n < 0;

        if (n != ~~n || n < -MAX_POWER || n > MAX_POWER) {  //TODO: BUG: This test doesn't work correctly if n is a float.  There are several of these ~~ checks that need to be rewritten probably
            throwErr("!pow!");
        }

        n = isNeg ? -n : n;

        for (;;) {

            if (n & 1) {
                y = y.times(x);
            }
            n = n >> 1;

            if (!n) {
                break;
            }
            x = x.times(x);
        }

        one.DP = this.DP;
        one.RM = this.RM;


        return isNeg ? one.div(y) : y;
    };


    /*
     * Return a new Big whose value is the value of this Big rounded to a
     * maximum of dp decimal places using rounding mode rm.
     * If dp is not specified, round to 0 decimal places.
     * If rm is not specified, use Big.RM.
     *
     * [dp] {number} Integer, 0 to MAX_DP inclusive.
     * [rm] 0, 1, 2 or 3 (ROUND_DOWN, ROUND_HALF_UP, ROUND_HALF_EVEN, ROUND_UP)
     */
    function round(dp, rm) {
        if (dp == null) {
            dp = 0;
        } else if (dp != ~~dp || dp < 0 || dp > MAX_DP) {
            throwErr("!round!");
        }
        rnd(dp, rm == null ? this.RM : rm);

        return this;
    };


    /*
     * Return a new Big whose value is the square root of the value of this Big,
     * rounded, if necessary, to a maximum of Big.DP decimal places using
     * rounding mode Big.RM.
     */
//     function sqrt() {    //TODO: BUG: Implement properly...
//   // It's possible that we may need to change the .RM or .DP on our Big objects created in this function to get things to work properly...
//         local estimate, r, approx,
//             x = this,
//             xc = x.c,
//             i = x.s,
//             e = x.e,
//             half = Big("0.5");

//         // Zero?
//         if (!xc[0]) {
//             return Big(x);
//         }

//         // If negative, throw NaN.
//         if (i < 0) {
//             throwErr("!Big.NaN!");
//         }


//         // Estimate.
//         // i = math.sqrt(x.toString()); //TODO: BUG: this does some weird -nan thing that isn't recognized from what I can tell - file a ticket with imp

//         // // Math.sqrt underflow/overflow?
//         // // Pass x to Math.sqrt as integer, then adjust the result exponent.
//         // if (i == 0 || i.tointeger() == -2147483648 || i.tointeger() == 2147483648 ) {
//             estimate = _reduce(xc)

//             if (!(estimate.len() + e & 1)) {
//                 estimate += "0";
//             }

//             r = math.sqrt(estimate.tointeger()).tointeger()

//             if(r == -2147483648 || r == 2147483648 ){
//                 r = this.div(2)//TODO: This was added because math.sqrt was freaking
//             } else {
//                 r = Big(r);
//                 r.e = ((e + 1) / 2 | 0).tointeger() - (e < 0 || e & 1).tointeger();
//             }
//         // } else {
//         //     r = Big(i.toString());
//         // }

//         this.DP += 4
//         i = r.e + this.DP;

//         half.RM = this.RM;
//         half.DP = this.DP;

//         r.RM = this.RM;
//         r.DP = this.DP;

//         // Newton-Raphson iteration.
//         do {
//             approx = r;
//             r = half.times( approx.plus( x.div(approx) ) );

//             server.log(approx.toString())
//             server.log(r.toString())
//         } while (
//             _reduce(approx.c.slice(0,  i-1 >= approx.c.len() ? approx.c.len() : i-1))

//             !=

//             _reduce(r.c.slice(0, i-1 >= r.c.len() ? r.c.len() : i-1))
//         );

//         this.DP -= 4
//         r.rnd(this.DP, this.RM);

//         return r;
//     };


    /*
     * Return a new Big whose value is the value of this Big times the value of
     * Big y.
     */
    function mul(y) {
        y = Big(y)
        local c,
            x = this,
            xc = x.c,
            yc = y.c,
            a = xc.len(),
            b = yc.len(),
            i = x.e,
            j = y.e;

        // Determine sign of result.
        y.s = x.s == y.s ? 1 : -1;

        // Return signed 0 if either 0.
        if (!xc[0] || !yc[0]) {
            return Big((y.s < 0 ? "-" : "+") + "0");
        }

        // Initialise exponent of result as x.e + y.e.
        y.e = i + j;

        // If array xc has fewer digits than yc, swap xc and yc, and lengths.
        if (a < b) {
            c = xc;
            xc = yc;
            yc = c;
            j = a;
            a = b;
            b = j;
        }

        // Initialise coefficient array of result with zeros.
        c = blob(a + b);

        // Multiply.

        // i is initially xc.len().
        for (i = b; i--;) {
            b = 0;

            // a is yc.len().
            for (j = a + i; j > i;) {

                // Current sum of products at this digit position, plus carry.
                b = c[j] + yc[i] * xc[j - i - 1] + b;
                c[j--] = b % 10;

                // carry
                b = b / 10 | 0;
            }
            c[j] = (c[j] + b) % 10;
        }

        // Increment result exponent if there is a final carry.
        if (b) {
            ++y.e;
        }

        // Remove any leading zero.
        if (!c[0]) {
            c = _slice(c, 1)
        }

        // Remove trailing zeros.
        for (i = c.len(); !c[--i]; _resize(c, c.len()-1)) {
        }
        y.c = c;

        return y;
    };


    /*
        * Return a string representing the value of this Big.
        * Return exponential notation if this Big has a positive exponent equal to
        * or greater than Big.E_POS, or a negative exponent equal to or less than
        * Big.E_NEG.
        */
       //TODO: map .valueOf and .toJSON into this...
    function toString() {
           local e = this.e;
           local str = _reduce(this.c)
           local strL = str.len();

           // Exponential notation?
           if (e <= this.E_NEG || e >= this.E_POS) {
               str = str[0].tochar() + (strL > 1 ? "." + str.slice(1) : "") + (e < 0 ? "e" : "e+") + e;

           // Negative exponent?
           } else if (e < 0) {

               // Prepend zeros.
               for (; ++e; str = "0" + str) {
               }
               str = "0." + str;

           // Positive exponent?
           } else if (e > 0) {

               if (++e > strL) {

                   // Append zeros.
                   for (e -= strL; e-- ; str += "0") {
                   }
               } else if (e < strL) {
                   str = str.slice(0, e) + "." + str.slice(e);
               }

           // Exponent zero.
           } else if (strL > 1) {
               str = str[0].tochar() + "." + str.slice(1);
           }

           // Avoid "-0"
           return this.s < 0 && this.c[0] ? "-" + str : str;
       };

       function tointeger() {
         if (cmp(zeroBig_) < 0)
           throw "tointeger is negative: " + toString();
         else if (cmp(maxInt32Big_) > 0)
           throw "tointeger is not signed 32-bit: " + toString();

         // Get the floor of the value.
         local str = toString();
         local iDot = str.find(".");
         if (iDot != null)
           str = str.slice(0, iDot);
         return str.tointeger();
       }

    /*
     ***************************************************************************
     * If toExponential, toFixed, toPrecision and format are not required they
     * can safely be commented-out or deleted. No redundant code will be left.
     * format is used only by toExponential, toFixed and toPrecision.
     ***************************************************************************
     */


    /*
     * Return a string representing the value of this Big in exponential
     * notation to dp fixed decimal places and rounded, if necessary, using
     * Big.RM.
     *
     * [dp] {number} Integer, 0 to MAX_DP inclusive.
     */
    function toExponential(dp=null) {

        if (dp == null) {
            dp = this.c.len() - 1;
        } else if (dp != ~~dp || dp < 0 || dp > MAX_DP) {
            throwErr("!toExp!");
        }

        return this.format(dp, 1);
    };


    /*
     * Return a string representing the value of this Big in normal notation
     * to dp fixed decimal places and rounded, if necessary, using Big.RM.
     *
     * [dp] {number} Integer, 0 to MAX_DP inclusive.
     */
    function toFixed(dp=null) {
        local str,
            x = this,
            neg = this.E_NEG,
            pos = this.E_POS;

        // Prevent the possibility of exponential notation.
        x.E_NEG = -RAND_MAX;    //TODO: we are going into scientific notation unnecesarrily..
        x.E_POS = RAND_MAX;

        if (dp == null) {
            str = x.toString();
        } else if (dp == ~~dp && dp >= 0 && dp <= MAX_DP) {
            str = x.format(x.e + dp);

            // (-0).toFixed() is '0', but (-0.1).toFixed() is '-0'.
            // (-0).toFixed(1) is '0.0', but (-0.01).toFixed(1) is '-0.0'.
            if (x.s < 0 && x.c[0] && str.find("-") == null) {
                str = "-" + str;    //E.g. -0.5 if rounded to -0 will cause toString to omit the minus sign.
            }
        }
        x.E_NEG = neg;
        x.E_POS = pos;

        if (!str) {
            throwErr("!toFix!");
        }

        return str;
    };


    /*
     * Return a string representing the value of this Big rounded to sd
     * significant digits using Big.RM. Use exponential notation if sd is less
     * than the number of digits necessary to represent the integer part of the
     * value in normal notation.
     *
     * sd {number} Integer, 1 to MAX_DP inclusive.
     */
    function toPrecision(sd=null) {

        if (sd == null) {
            return this.toString();
        } else if (sd != ~~sd || sd < 1 || sd > MAX_DP) {
            throwErr("!toPre!");
        }

        return this.format(sd - 1, 2);
    };

    /**
     * Used with JSONEncoder.encode to allow for properly JSONizing big numbers
     * @method _serialize
     * @return {[type]}   [description]
     */
     function _serializeRaw(){
         return this.toString();
     }


      /**
       * reduce our coefficient blob into a string
       * @method _reduce
       * @param  {[type]} c [description]
       * @return {[type]}   [description]
       */
      function _reduce(bl){
        local str = ""
        for(local i=0; i<bl.len(); i++){
          str += bl[i].tostring()
        }
        return str;
      }

      // This will reverse the actual blob, not simply return a new one
      function _reverse(bl) {
        local tempbl = clone(bl)
        for(local i=0, j=bl.len()-1; i<bl.len(); i++, j--){
          tempbl[j] = bl[i]          //reverse the data
        }
        for(local i=0; i<bl.len(); i++)
          bl[i] = tempbl[i]

        return bl
      }

      // This will resize the actual blob, not simply return a new one
      function _resize(bl, len){ //The native squirrel resize doesn't actually change our length, just the blob's memory allocation so we get silly index out of range errors if we use it
        bl.resize(len)  //truncate the blob if necessary.  This possible fragments our memory more than needed but shouldn't be an issue in practice?
        bl.seek(bl.len())
        for(local i=bl.len(); i<len; i++)
          bl.writen(0, 'b')
        bl.seek(0)
        return bl
      }

      function _remove(bl, index){  //TODO: BUG: No protections in place for legal values of index...
        index++
        for(; index < bl.len(); index++)
            bl[index-1] = bl[index]
        bl.resize(bl.len()-1)
        return bl
      }


      function _insert(bl, index, item){
        _resize(bl, bl.len() + 1);

        //shift everything to the right by one index
        for(local i=bl.len()-2; i>=index; i--){
          bl[i+1] = bl[i]
        }

        //insert our item
        bl[index] = item
      }

      // This will return a new sliced blob
      function _slice(bl, startIndex, endIndex=null){
          endIndex = endIndex == null ? bl.len() : endIndex

          //TODO: I'm not sure that this is a one to one equivalent, but its a decent start

          if(math.abs(startIndex) > bl.len() || math.abs(endIndex) > bl.len()){
              throw("slice out of range")
          }

          if(startIndex < 0)
              startIndex = bl.len() + startIndex

          if(endIndex < 0)
              endIndex = bl.len() + endIndex

          if(startIndex > endIndex)
              throw("wrong indexes")


          local tempbl = blob(endIndex - startIndex);

          for(local i=startIndex; i < endIndex; i++)
              tempbl[i - startIndex] = bl[i]

          return tempbl
      }

}


function BigFromHexString(str){
    //Create an empty BigInt to hold our data
    local bi = Big(0)

    //Let's only deal with lower case letters
    str = str.tolower();

    //Remove leading "0x" if present
    if( str.len() >= 2 && str.slice(0, 2) == "0x" ){
        str = str.slice(2);
    }

    local exp = 0;
    // start scanning from the right
    for (local i = str.len() - 1; i >= 0; i -= 1) {
        local hex = str[i]
        local int = 0

        if( '0' <= hex && hex <= '9'){
            int = (hex - 0x30)
        } else if( 'a' <= hex && hex <= 'f' ){
            int = (hex - 0x57)
        } else{
            throw "Invalid Hex Character: " + hex;
        }

        bi = bi.plus(Big(int).times(Big(16).pow(exp++)))
    }
    return bi
}

function BigFromUINTBlob(bl){
  local str = ""
  for(local i = 0; i < bl.len(); i++){
    str = str + format("%.2X", bl[i]);
  }

  return BigFromHexString(str)  //TODO: BUG: This isn't working - probably an endianess thing?
}

zeroBig_ <- Big(0);
maxInt32Big_ <- Big(0x7fffffff);


/*//1450489318530 = 151B7E68C82
local num = BigFromHexString("151B7E68C82");
server.log(num.toString())
server.log("1450489318530")*/
