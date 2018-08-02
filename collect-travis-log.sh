#!/usr/bin/env bash
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

set -e
test -n "$DEBUG" && set -x

. ci-functions.sh

SLEEP_COUNT=10

echo "Sleeping $SLEEP_COUNT seconds to let the travis log propogate through the API before we download it..."
sleep $SLEEP_COUNT

dest_dir=.
test -d "$dest_dir" || mkdir -pv "$dest_dir"

echo "Storing Travis CI log from this run in ${dest_dir}..."

# Reset bash eXecution loggin so we don't leak API token credentials
set +x
curl -sSL \
     -H "Authorization: token $TRAVIS_API_USER_TOKEN" \
     -H 'Travis-API-Version: 3' \
     -H 'Accept: text/plain' \
     https://api.travis-ci.com/job/${TRAVIS_JOB_ID}/log > ${dest_dir}/log.txt
