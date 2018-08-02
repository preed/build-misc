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

## This sets up a handler that allows sub-functions to terminate the calling
## shell when necessary. We use this to ensure that we can halt a build script
## that calls us when we need to
trap "exit 1" TERM
export _calling_script_pid="$$"

function abort_script() {
   local _abort_message="$1"

   if test -z "$_abort_message"; then
      _abort_message="$0: unspecified failure. Aborting script execution."
   fi

   echo "$_abort_message" >&2
   kill -s TERM $_calling_script_pid
}

function strip_string() {
   echo "$1" | sed -e 's:^[[:space:]]*::' | sed -e 's:[[:space:]]*$::'
}

function circleci_get_build_status() {
   # Remove any old build statuses we collected up
   rm $CIRCLECI_BUILD_STATUS_MARKER

   set +x
   set +e
   # Note: the trailing : in the argument to -u is necessary; see
   # https://circleci.com/docs/api/v1-reference/#authentication
   curl -sSLf \
      -u ${CIRCLE_CI_API_TOKEN}: \
      https://circleci.com/api/v1.1/project/bitbucket/${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}/${CIRCLE_BUILD_NUM} > $CIRCLECI_BUILD_STATUS_MARKER

   curlRv="$?"
   set -e
   if [[ "$_shell_flags" =~ "x" ]]; then
      set -x
   fi

   if [ "$curlRv" -ne "0" ]; then
      # Unknown
      echo "-1"
      return
   fi

   local _circle_status_value="$($TRAVIS_BUILD_DIR/circle-ci/parse-circleci-build-status.py $CIRCLECI_BUILD_STATUS_MARKER)"

   echo "$(strip_string "$_circle_status_value")"
}

RETRY_COUNT=5
function run_cmd_with_retry() {
   local _cmd=$*
   local _cmd_rv
   local _sleep_count
   local _shell_flags="$-"

   for retry_count in $(seq 1 ${RETRY_COUNT}); do
      # Since the caller expects this command may fail, turn off halt-on-error,
      # but reset it to what it was after the command is run...
      set +e
      "$@"
      _cmd_rv=$?
      if [[ "$_shell_flags" =~ "e" ]]; then
         set -e
      fi

      if [ "$_cmd_rv" -eq "0" ]; then
         break
      fi

      echo "Command \"$_cmd\" failed; return value: $_cmd_rv" >&2
      let _sleep_count=10*$retry_count
      echo "Retrying in $_sleep_count seconds..." >&2
      sleep $_sleep_count
   done
   return $_cmd_rv
}

function run_cmd_exit_on_fail() {
   local _cmd_rv
   local _shell_flags="$-"

   set +e
   "$@"
   _cmd_rv="$?"
   if [[ "$_shell_flags" =~ "e" ]]; then
      set -e
   fi

   if [ "$_cmd_rv" -ne "0" ]; then
      abort_script "run_cmd_exit_on_fail(): command $@ exited with $_cmd_rv"
   fi
}

# We could use cygpath for this, but on AppVeyor, it doesn't seem to work in
# ming64, which is what we're currently using for bash; so, do it manually.
#
# Also, this is in common (as opposed to appveyor), because we want to be
# able to make scripts portable, so we want to be able to call this function
# on scripts in common; so they need access to this function.

function posix_path() {
   # Strip any leading/trailing whitespace
   local _path="$(strip_string "$1")"

   # The following deserves some explanation:
   #
   # If we're on AppVeyor, Echo the lower-case drive with a leading slash;
   # then...
   #
   # * remove the :, using / as a sed marker
   #
   # Then, for all paths...
   #
   # * convert all \'s into /'s (using : is a sed marker, since we're
   # modifying /'s; then...
   #
   # * remove any duplicated /'s, using : as a sed marker (but requires sed
   # to be run with regex extensions on.
   #

   if test -n "$APPVEYOR"; then
      local _lc_drive="$(echo "$_path" | sed -r 's:^[A-Z]:\L&:')"
      _path="$(echo "/$_lc_drive" | sed -e 's/://')"
   fi

   echo "$_path" | sed -e 's:\\:\/:g' | sed -E -e 's:/+:/:g'
}

function win_path() {
   # Strip any leading/trailing whitespace
   local _posix_path="$(strip_string "$1")"

   if test -n "$(echo "$_posix_path" | grep '^/[a-zA-Z]/')"; then
      # We're a full path, with a drive letter...
      #
      # Strip off the leading slash...
      _posix_path="$(echo "$_posix_path" | sed -e 's:^/::')"
      # Add the drive colon
      _posix_path="$(echo "$_posix_path" | sed -e 's;^\([a-zA-Z]\)/;\1:;')"
   fi

   # Finally, flip slashes...
   echo "$_posix_path" | sed -e 's:/:\\:g'
}
