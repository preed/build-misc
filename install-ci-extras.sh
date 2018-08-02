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

readonly SCRIPT_NAME="$(basename $0)"

if test -n "$APPVEYOR"; then
   readonly PACKAGE_LIST="sampletool_win"
elif test -n "$TRAVIS" || test -n "$CIRCLECI"; then
   readonly PACKAGE_LIST="sampletool_mac"
else
   abort_script "Couldn't detect CI provider."
fi

readonly sampletool_mac_URL="https://example.com/sampletool-1.0.0.zip"
readonly sampletool_mac_FILE="sampletool-1.0.0.zip"
readonly sampletool_mac_SHA256="23423423423423423..."

readonly sampletool_win_URL="https://example.com/sampletool-1.0.0.msi"
readonly sampletool_win_FILE="sampletool-1.0.0.msi"
readonly sampletool_win_SHA256="23423423423423423..."

function get_cached_pkg_location() {
   local _pkg="$1"
   local _varname="${_pkg}_FILE"
   local _pkg_filename="${!_varname}"
   echo "$DIST_CACHE/$_pkg_filename"
}

function download_pkg() {
   local _pkg="$1"

   local _varname="${_pkg}_URL"
   local _pkg_url="${!_varname}"

   local _varname="${_pkg}_FILE"
   local _pkg_filename="${!_varname}"

   local _varname="${_pkg}_SHA256"
   local _pkg_expected_sha="${!_varname}"

   if test -z "$_pkg_url"; then
      abort_script "download_pkg(): No download URL set for package $_pkg"
   fi

   local _cached_pkg="$(get_cached_pkg_location $_pkg)"

   if ! test -f "$_cached_pkg"; then
      echo "*** $SCRIPT_NAME: Downloading $_pkg from $_pkg_url"
      # TODO: add download retry logic
      curl -LsS $_pkg_url -o $_cached_pkg
   else
      echo "*** $SCRIPT_NAME: Using cached copy of $_pkg"
   fi

   local _pkg_checksum="$(shasum -a 256 "$_cached_pkg" | awk '{print $1}')"

   # Windows compat
   _pkg_checksum="$(echo "$_pkg_checksum" | sed -e 's:[^0-9a-f]::g')"

   if [[ "$_pkg_checksum" != "$_pkg_expected_sha" ]]; then
      abort_script "download_pkg(): package checksum did not match:
package sha256: $_pkg_checksum
expected:       $_pkg_expected_sha"
   fi
}

function install_sampletool_mac() {
   local _cached_sampletool="$(get_cached_pkg_location sampletool_mac)"
   unzip -q -d $CI_EXTRAS_DIR $_cached_sampletool
}

function install_sampletool_win() {
   local _cached_sampletool="$(get_cached_pkg_location sampletool_win)"
   powershell -c "msiexec.exe /i $_cached_sampletool /quiet "
}

function main() {
   test -n "$CI_EXTRAS_DIR" || abort_script "CI_EXTRAS_DIR must be set."

   # Make sure the ci extras directory which we, ourselves, expect to exist,
   # does, in fact, exist...
   #
   # (The standard cache directories that are internal to the cache are
   # managed by circle-ci/create-cache-dirs.sh)
   mkdir -pv $CI_EXTRAS_DIR

   echo "PACKAGE_LIST: $PACKAGE_LIST"

   for package in $PACKAGE_LIST; do
      echo
      echo "***"
      echo "*** $SCRIPT_NAME: Installing CI additional dependency $package"
      echo "***"
      echo
      download_pkg $package
      install_$package
      echo "*** $package installation complete"
   done
}

main
