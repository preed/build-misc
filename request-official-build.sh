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

#set -x
#set -e

GIT="${GIT:-git}"

readonly BUILD_MARKER_FILE="KICKOFF_OFFICIAL_BUILD.txt"

if test -n "$($GIT status --porcelain -uno)"; then
   echo 'This tool cannot be used when your repository contains modifications.' >&2
   echo 'Commit these modifications, or use "git stash" to stow them away.' >&2
   exit 1
fi

echo "Switching to master branch..."

$GIT checkout master
git_rv=$?

if [[ "$git_rv" -ne 0 ]]; then
   echo 'Switching to the master branch failed; you must be on master to submit an official build request.' >&2
   echo 'Once on master, you may re-run this command.' >&2
   exit $git_rv
fi

$GIT pull --rebase origin master
git_rv=$?

if [[ "$git_rv" -ne 0 ]]; then
   echo 'Updating the this Git clone failed in preparation to submit an official build request failed. The above error must be corrected before proceeding.' >&2
   echo 'Once fixed, you may re-run this command.' >&2
   exit $git_rv
fi

echo -n "Enter which branch you'd like to request an official build on: "
read git_branch

echo -n "Enter the reason for requesting this build: "
read build_reason

echo
echo "	Branch to build: $git_branch"
echo "	Build request reason: $build_reason"
echo
echo -n "Are these correct? Press 'enter' for yes, Ctrl-C for no. "
read

epoch="$(date +%s)"
user="$(whoami)"
machine="$(hostname)"

echo "# $epoch; $user; $machine" > $BUILD_MARKER_FILE
echo "$git_branch" >> $BUILD_MARKER_FILE

$GIT commit -m "$build_reason" $BUILD_MARKER_FILE

echo "Submitting build request..."
$GIT push origin master
 
git_rv=$?

if [[ $git_rv -ne 0 ]]; then
   echo 'The "git push" of the build request failed; this may be because the master branch changed on the server.' >&2
   echo 'You can attempt to remedy this by running "git pull --rebase origin master" followed by a "git push origin master"' >&2
   exit $git_rv
fi

exit 0
