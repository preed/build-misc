#!/usr/bin/env python
#
# MIT License
#
# Copyright (c) 2017-2018 Vernier Software & Technology
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE

import json
import os
import pprint
import sys

VERBOSE = os.getenv("DEBUG", False)

with open(sys.argv[1], 'r') as apiDumpObj:
    data = json.load(apiDumpObj)

#pp = pprint.PrettyPrinter(indent=4)
#pp.pprint(data)
#print "Outcome: %s" % (data['outcome'])
#print "platform: %s" % (data['platform'])

#print len(data['steps'])

buildStatus = None

totalSteps = len(data['steps'])

for ndx in range(totalSteps):
    step = data['steps'][ndx]
    if VERBOSE:
        print >> sys.stderr, "Name: %s" % (step['name'])
    continueParsingSteps = True
    for action in step['actions']:
        if VERBOSE:
            print >> sys.stderr, "Step: %s" % (action['step'])
        stepStatus = action['status']

        if VERBOSE:
            print >> sys.stderr, "Status: %s" % (stepStatus)

        if stepStatus == "success":
            buildStatus = 0
        elif stepStatus == "failed":
            buildStatus = 1
            continueParsingSteps = False
            break
        else:
            #print "%d vs %d" % (ndx, len(data['steps']))
            # If we're in the test phase, and we've had success all
            # the way through, then consider that success.
            if action['type'] == "test" and stepStatus == 'running':
                continueParsingSteps = False
                break
            else:
                buildStatus = -1

    if not continueParsingSteps:
        break


print str(buildStatus)
