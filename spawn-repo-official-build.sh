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

# Static config
readonly REPO="git@github.org:sample/projectcheckout.git"
readonly CLONE_DIR="$CIRCLE_WORKING_DIR/../project"
readonly BUILD_INFO_BRANCH="build-info"
readonly BUILD_BUMP_SCRIPT_CMD="./build/official/bump-build-numbers.py"

readonly BUILD_BUMP_SCRIPT_LOG="/tmp/bump-build-numbers-LOG.txt"

readonly PRIV_SSH_KEY_ENC="$CIRCLE_WORKING_DIR/creds/encrypted"
readonly PRIV_SSH_KEY_DEC="$CIRCLE_WORKING_DIR/creds/decrypted"

# Note: these cannot be be changed without also changing the official build
# logic in the build/official scripts in the main repo, as well.
readonly BUILDER_GIT_USER="Builder"
readonly BUILDER_GIT_EMAIL="builds@example.com"

readonly KICKOFF_BUILD_MARKER_FILE="KICKOFF_OFFICIAL_BUILD.txt"

function strip_string() {
      echo "$1" | sed -e 's:^[[:space:]]*::' | sed -e 's:[[:space:]]*$::'
}

# THIS IS IMPORTANT:
#
# We need this so the git commands below use the ssh key in the
# official-build repo (which has permissions to commit and push back
# to sample), NOT the CircleCI deploy key that's associated with this
# repository.
#
# The important part is that we export this so that the python script below
# (which calls git itself) uses the correct ssh key. Otherwise, when it pushes,
# it will fail.

export GIT_SSH_COMMAND="ssh -i $PRIV_SSH_KEY_DEC"

# Runtime config

build_info_branch="UNKNOWN"

# Is this an official build request?
official_build_request=0

# Should we kick off a build; this is different than the above variable in that
# there are various reasons we'd kick off a build, though not all of them are
# official build "requests"
kickoff_official_build=0

# Additional context for the commit message; this _should_ ALWAYS get filled in
# below
build_reason="UNKNOWN"

# main(), as it were

# Determine if we even need to kick off a build; converted to pseudo-code,
# the logic below roughly is:
#
# if (this is a nightly build job) {
#   kickoff_build_flag = true
# } else {
#    if (list of modified files is ONLY the kickoff build marker) {
#      kickoff_build_flag = true
#      official_build_request_flag = true
#    } else {
#       if (the commit message has "[do official]" in it somewhere) {
#         kickoff_build_flag = true
#         official_build_request_flag = true
#       }
#    }
# }
#

if test -n "$(echo "$CIRCLE_STAGE" | grep '^nightly_build')"; then
   kickoff_official_build=1
   build_reason="Request source: scheduled nightly build"

   if test -z "$BUILD_BRANCH"; then
      echo 'Mis-configured nightly official build circle.yml (missing branch); bailing.' >&2
      exit 1
   fi

   build_info_branch="$BUILD_BRANCH"
else
   # This isn't an official build run triggered by the nightly automated setup.
   # So, check to see if it's a forced-build request.

   last_commit_modified_files="$(cd $CIRCLE_WORKING_DIRECTORY && git log --format=short --pretty="format:" --name-only -n 1 HEAD)"

   last_commit_author="$(cd $CIRCLE_WORKING_DIRECTORY && git log --format='%ce' -n 1 HEAD)"
   last_commit_subject="$(cd $CIRCLE_WORKING_DIRECTORY && git log --format='%s' -n 1 HEAD)"

   build_reason="Request source: ${last_commit_author}; reason: $last_commit_subject"

   echo "Detected last-commit file list: $last_commit_modified_files"

   if [[ "$last_commit_modified_files" == "$KICKOFF_BUILD_MARKER_FILE" ]]; then
      # If this is a build request, then kick off a build
      kickoff_official_build=1
      official_build_request=1

      # The last non-commented line of the kickoff build marker is what we
      # consider "the branch to build"; see request-official-build.sh for more
      # info
      build_info_branch="$(cat $KICKOFF_BUILD_MARKER_FILE | grep -v '^#' | tail -n 1)"
      build_info_branch="$(strip_string "$build_info_branch")"

      # We only support official builds on master and release/ branches right
      # now, so validate that
      if [[ "$build_info_branch" != "master" ]] && [[ -z "$(echo "$build_info_branch" | grep '^release\/.')" ]]; then
         echo 'Official builds may only be requested on the master and release/ branches.' >&2
         exit 1
      fi
   else
      last_commit_full_commit_message="$(cd $CIRCLE_WORKING_DIR && git log --format='%s %b' -n 1 HEAD)"

      if test -n "$(echo "$last_commit_full_commit_message" | grep -i '\[do kickoff\]')"; then
         # We're not an automated build kickoff, nor are we an official build
         # request, but we've been told to kick off a build via a commit.
         #
         # This is mostly to be used in cases where we want a merge of an
         # MR to _also_ kick off an official build (which we won't do by
         # default.)
         kickoff_official_build=1
         official_build_request=1

         # For now, in these cases, always build master; we may decide to
         # change this in the future...
         build_info_branch="master"
      fi
   fi
fi

if [[ "$kickoff_official_build" -eq 0 ]]; then
   echo "Neither nightly automated build job, official build request marker change, or merge request test detected." >&2
   echo "NOT SPAWNING OFFICIAL BUILD." >&2
   exit 0
fi

echo "Attempting to build branch: $build_info_branch"

# -x needs to be turned off here to protect the key
set +x
openssl aes-256-cbc -d -in $PRIV_SSH_KEY_ENC -out $PRIV_SSH_KEY_DEC -k "$PASSWORD"
set -x

# Set permissions, as required by ssh
chmod 0600 $PRIV_SSH_KEY_DEC

# After decrypting the key, because this script is basically the entire
# official build job, set command tracing on, so the log shows what was done.
#
# (This is similar to what we do with circle.yml in the main repo, since all the
# real job logic is in the scripts, not the yml directly.)
set -x

# Show the version of git we're using
git --version


# We check out the specific branch, with a limited depth for performance
# reasons. However, because we manipulate the build-info branch in this clone,
# we also need to fetch it separately; we do that a couple of lines down.
git clone --depth 5 -b $build_info_branch $REPO $CLONE_DIR

cd $CLONE_DIR

# See the comment above the git clone for an explanation of this.
git remote set-branches --add origin $BUILD_INFO_BRANCH
git fetch origin $BUILD_INFO_BRANCH

git config user.name "$BUILDER_GIT_USER"
git config user.email "$BUILDER_GIT_EMAIL"

# This script can return an error to indicate that an official build should not
# be performed. It originally did this to halt the build (so a superfluous build
# was not performed.
#
# So, turn off exit-on-error. But also, capture the output; and if it fails for
# that specific reason, print that to the log, but also return success, so the
# job isn't red.
#
# Of course, the script can fail for other (legit) reasons, and if that's the
# case, then mark the job red.
set +e

# Also, disable execution tracing here, mostly because everything below is
# status reporting; with -x set, we get the output strings in the log multiple
# times, which is hard to read.
set +x

# If this build was the result of a build request, then pass --force to the
# version bump script, so it will ignore whether or not there were previous
# commits and will just kickoff a new official build.
if [[ "$official_build_request" -eq 1 ]]; then
   additional_build_bump_script_args="--force"
else
   additional_build_bump_script_args=""
fi

$BUILD_BUMP_SCRIPT_CMD -m "$build_reason" $additional_build_bump_script_args 2>&1 | tee $BUILD_BUMP_SCRIPT_LOG
bump_rv=${PIPESTATUS[0]}
echo "$BUILD_BUMP_SCRIPT_CMD rv: $bump_rv"
set -e

# Only perform this check is this _wasn't_ a manually-request official build
if [[ "$official_build_request" -eq 0 ]]; then
    no_checkins_mesg="$(cat $BUILD_BUMP_SCRIPT_LOG | grep 'No checkins since last')"
else
    no_checkins_mesg=""
fi

if test -n "$no_checkins_mesg"; then
   exit 0
else
   exit $bump_rv
fi
