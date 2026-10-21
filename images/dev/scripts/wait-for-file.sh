#!/bin/bash

set -e

waitFile="$1"
shift
cmd="$@"

until ! [ -f $waitFile ]
do
  >&2 echo "Waiting while file [$waitFile] exists."
  sleep 5
done
