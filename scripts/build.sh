#!/bin/sh
set -e

cd "$(dirname "$0")/.."
exec scripts/setup.sh build all
