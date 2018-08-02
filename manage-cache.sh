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

# This is a weird function that smoothes out the differences in how Travis
# and AppVeyor do cache management. (AppVeyor doesn't create directories if
# the cache entries are empty, while Travis does.)

function guarded_dir_cp() {
   src="$1"
   dest="$2"

   mkdir -p "$dest" || true

   if test -d "$src"; then
      cp -a "$src" "$dest"
   fi
}

if test -n "$APPVEYOR"; then
   . appveyor-cache-config.sh
elif test -n "$CIRCLECI"; then
   . circle-ci-cache-config.sh
else
   echo "$0: Couldn't detect CI platform; bailing" >&2
   exit 1
fi

if test -z "$CACHE_DIR"; then
   echo "$0: CACHE_DIR must be defined (either in the CI.yml or in cache-config.sh)" >&2
   exit 1
fi

if [[ "$1" == "restore" ]]; then
   ci_service_restore_cache
elif [[ "$1" == "populate" ]]; then
   ci_service_populate_cache
elif [[ "$1" == "list" ]]; then
   if test -d "$CACHE_DIR"; then
      find "$CACHE_DIR" -type f
   else
      echo "Cache directory $CACHE_DIR does not exist." >&2
   fi
else
   echo "Usage: $0 [ restore | populate | list ]" >&2
   exit 1
fi
