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

readonly CIRCLE_LOG_HOME="$HOME/build-log"

SLEEP_COUNT=10

echo "Sleeping $SLEEP_COUNT seconds to let the Circle log propagate through the API before we download it..."
sleep $SLEEP_COUNT

dest_dir=.
test -d "$dest_dir" || mkdir -pv "$dest_dir"

echo "Storing Circle CI log from this run in ${dest_dir}..."

mkdir -p $CIRCLE_LOG_HOME

log_file="${dest_dir}/log.txt"
log_file_part="$CIRCLE_LOG_HOME/log-part.txt"
job_info="$CIRCLE_LOG_HOME/job.json"

# Optimization: Since we collect the log at multiple points int he build, and
# since the older log file parts won't change, store off the log_part_count and
# start collecting logs from that point, not re-collect _all_ the logs_

shell_flags="$-"
      
set +x
curl -sSLf \
     -u ${CIRCLE_CI_API_TOKEN}: \
     https://circleci.com/api/v1.1/project/bitbucket/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/$CIRCLE_BUILD_NUM > $job_info
if [[ "$_shell_flags" =~ "x" ]]; then
   set -x
fi

stepNumbers="$(grep '"step" :' $job_info | awk '{print $3}' | sed -e 's:,::g')"

for step in $stepNumbers; do
   echo -n '.' >&2
   # Turn off -x so we don't leak the API token; and turn off -e, because the
   # curl command _could_ fail here.
   set +x
   set +e
   # Note: the trailing : in the argument to -u is necessary; see
   # https://circleci.com/docs/api/v1-reference/#authentication
   curl -sSLf \
      -u ${CIRCLE_CI_API_TOKEN}: \
      https://circleci.com/api/v1.1/project/bitbucket/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM}/output/${step}/0?file=true > $log_file_part
   curlRv="$?"
   set -e
   if [[ "$_shell_flags" =~ "x" ]]; then
      set -x
   fi

   if [ "$curlRv" -ne "0" ]; then
      error_str="MISSING LOG PART FOR STEP $step"
      echo "$error_str" >&2
      echo "$error_str" >> $log_file
   fi

   echo "=============" >> $log_file
   echo -n "LOG PART " >> $log_file
   echo "$(printf '%02d:' "$step")" >> $log_file

   cat $log_file_part >> $log_file
   # Add a last new line, in case the log part doesn't have one in it
   echo >> $log_file

   sleep 1
done

# This echoes a newline, since we use echo -n above as a progress indicator
echo
