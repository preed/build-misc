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

if [ "$UID" -ne 0 ]; then
   echo "This script is intended to be run in a CircleCI docker container to set up the necessary user and related environment, so the scripts don't run as root. As such, it's also intended to be run as root." >&2
   exit 1
fi

# Add the builder user; but ignore prompts for "name, room, etc."
adduser builder --disabled-password < /dev/null

# Make the builder user the owner of everything in the build-root (which is
# created by circle because the working_directory is currently under /build
chown -R builder:builder /build

# Add the CIRCLE_ environment variables to THE TOP of .bashrc
mv ~builder/.bashrc ~builder/.bashrc.orig
export | grep CIRCLE_ >> ~builder/.bashrc
cat ~builder/.bashrc.orig >> ~builder/.bashrc
chmod 0600 ~builder/.bashrc

# Grab the known_hosts from the root user (which is initialized by CircleCI
# with entries for GitHub and Bitbucket, which we need).

mkdir -pv ~builder/.ssh/
cat ~/.ssh/known_hosts >> ~builder/.ssh/known_hosts
chmod 0700 ~builder/.ssh
chmod 0600 ~builder/.ssh/known_hosts

# Finally, make sure all the files we've created in builder's home directory
# are owned by the builder user.
chown -R builder:builder ~builder
