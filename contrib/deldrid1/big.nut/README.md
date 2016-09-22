
# big.nut #

This is an Electric Imp Squirrel fork of [big.js](https://github.com/MikeMcl/big.js/) - A small, fast JavaScript library for arbitrary-precision decimal arithmetic.

The little sister to [bignumber.js](https://github.com/MikeMcl/bignumber.js/).
See also [decimal.js](https://github.com/MikeMcl/decimal.js/), and [here](https://github.com/MikeMcl/big.js/wiki) for the difference between them.

## Features

  - Simple API
  - Replicates the `toExponential`, `toFixed` and `toPrecision` methods of JavaScript's Number type
  - Stores values in an accessible decimal floating point format
  - No dependencies
  - Comprehensive [documentation](http://mikemcl.github.io/big.js/) and test set

## Differences from Big.js

  - There are no Class properties - currently everything is an instance property.  This means that Big.DP isn't "sticky" like the Big.js library.
    - This decision needs to be reviewed.  We also need to make sure things like cloning preserve properties correctly.

## Load

Copy the big.class.nut file into your Electric Imp Agent.


## Use

*In all examples below, `local`, semicolons and `toString` calls are not shown.
If a commented-out value is in quotes it means `toString` has been called on the preceding expression.*

The library exports a single function: Big, the constructor of Big number instances.
It accepts a value of type Number, String or Big number Object.

    x = Big(123.4567)
    y = Big('123456.7e-3')             
    z = Big(x)
    x.eq(y) && x.eq(z) && y.eq(z)      // true

A Big number is immutable in the sense that it is not changed by its methods.

    0.3 - 0.1                          // 0.19999999999999998
    x = Big(0.3)
    x.minus(0.1)                       // "0.2"
    x                                  // "0.3"

The methods that return a Big number can be chained.

    x.div(y).plus(z).times(9).minus('1.234567801234567e+8').plus(976.54321).div('2598.11772')
    x.sqrt().div(y).pow(3).gt(y.mod(z))    // true

Like JavaScript's Number type, there are `toExponential`, `toFixed` and `toPrecision` methods.

    x = new Big(255.5)
    x.toExponential(5)                 // "2.55500e+2"
    x.toFixed(5)                       // "255.50000"
    x.toPrecision(5)                   // "255.50"

The maximum number of decimal places and the rounding mode used to round the results of the `div`, `sqrt` and `pow`
(with negative exponent) methods is determined by the value of the `DP` and `RM` properties of the `Big` number constructor.  

The other methods always give the exact result.  

(From *v3.0.0*, multiple Big number constructors can be created, see Change Log below.)

    Big.DP = 10
    Big.RM = 1

    x = Big(2);
    y = Big(3);
    z = x.div(y)                       // "0.6666666667"
    z.sqrt()                           // "0.8164965809"
    z.pow(-3)                          // "3.3749999995"
    z.times(z)                         // "0.44444444448888888889"
    z.times(z).round(10)               // "0.4444444445"


The value of a Big number is stored in a decimal floating point format in terms of a coefficient, exponent and sign.

    x = Big(-123.456);
    x.c                                // [1,2,3,4,5,6]    coefficient (i.e. significand)
    x.e                                // 2                exponent
    x.s                                // -1               sign

For further information see the [API](http://mikemcl.github.io/big.js/) reference from the *doc* folder.

## Test

The *test* directory contains the test scripts for each Big number method.

The tests can be run inside the imp Agent.

Be warned - many of the tests must be ran manually because of agent memory limitations.  In the future these tests may be converted to .json files so that the agent can HTTP GET them a chunk at a time.

## Performance

Performance has not yet been tested.  It does generally work though :)

## Feedback

Feedback is welcome.

Bugs/comments/questions?
Open an issue, or email


## Licence

See LICENCE.

## Change Log

####3.1.3

* Minor documentation updates.
* Initial Conversion to Squirrel.

####3.1.2

* README typo.

####3.1.1

* API documentation update, including FAQ additions.

####3.1.0

* Renamed and exposed `TO_EXP_NEG` and `TO_EXP_POS` as `Big.E_NEG` and
 `Big.E_POS`.

####3.0.2

* Remove *.npmignore*, use `files` field in *package.json* instead.

####3.0.1

* Added `sub`, `add` and `mul` aliases.
* Clean-up after lint.

####3.0.0

* 10/12/14 Added [multiple constructor functionality](http://mikemcl.github.io/big.js/#faq).
* No breaking changes or other additions, but a major code reorganisation,
 so *v3* seemed appropiate.

####2.5.2

* 1/11/14 Added bower.json.

####2.5.1

* 8/06/14 Amend README requires.

####2.5.0

* 26/01/14 Added `toJSON` method so serialization uses `toString`.

####2.4.1

* 17/10/13 Conform signed zero to IEEEE 754 (2008).

####2.4.0

* 19/09/13 Throw instances of `Error`.

####2.3.0

* 16/09/13 Added `cmp` method.

####2.2.0

* 11/07/13 Added 'round up' mode.

####2.1.0

* 26/06/13 Allow e.g. `.1` and `2.`.

####2.0.0

* 12/05/13 Added `abs` method and replaced `cmp` with `eq`, `gt`, `gte`, `lt`, and `lte` methods.

####1.0.1

* Changed default value of MAX_DP to 1E6

####1.0.0

* 7/11/2012 Initial release
