NDN-Squirrel: An NDN Client Library for Squirrel
================================================

Prerequisites
=============

NDN-Squirrel runs both in standard Squirrel and on the Electric Imp platform
(tested with an IMP 005). To use standard Squirrel, install the distribution
from http://squirrel-lang.org so that you can run `sq` on the command line.

Build
=====

All Squirrel code must be in one file, so NDN-Squirrel has simple shell scripts
to cat all the files together. To make the main library file `ndn-squirrel.nut`,
in a terminal change directory to the NDN-Squirrel root and enter:

    ./make-ndn-squirrel.sh

To make the examples, enter the following (which also runs `make-ndn-squirrel.sh`):

    ./make-examples.sh

The output example files are in the bin subdirectory. For example, using the
standard Squirrel command line, you can run:

    sq bin/test-encode-decode-data.nut

To run the unit tests, in a terminal enter:

    ./make-unit-tests.sh
    sq bin/unit-tests.app.nut

Files
=====

Running ./make-ndn-squirrel.sh (see above) makes a single Squirrel file
`ndn-squirrel.nut` contaning the NDN-Squirrel library.

Running ./make-examples.sh makes the following example applications which have
ndn-squirrel.nut plus the example code and other files concatenated into one file.
To distinguish it from the example code, the output file name includes "app". For
example, examples/test-encode-decode-data.nut has the output file
bin/test-encode-decode-data.app.nut .

* bin/test-encode-decode-data.app.nut: Encode and decode a data packet, including signing the data packet.
* bin/test-encode-decode-interest.app.nut: Encode and decode an interest, testing interest selectors and the name URI.
* bin/test-encode-decode-benchmark.app.nut: Show the benchmarks to encode and decode various kinds of Data packet.
* bin/test-imp-publish-async.device.app.nut: On the Imp Device connect to a local MicroForwarder which has a route to the Agent, accept interests with prefix /testecho and echo back a data packet. See test-imp-echo-consumer.agent.nut.
* bin/test-imp-echo-consumer.agent.app.nut: On the Agent, select a word and send the interest /testecho/word to the Imp Device which is echoed by test-imp-publish-async.device.nut.
* bin/test-micro-forwarder.app.nut: Simulate the communication of test-imp-publish-async.device.nut and test-imp-echo-consumer.agent.nut in one app using the micro-forwarder and stubs for the agent and device.
