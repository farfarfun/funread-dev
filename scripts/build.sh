#!/bin/sh
set -e

git -C apps/funread switch master
git -C apps/funread-web switch master

cd apps/funread
funbuild build

cd ../..
cd apps/funread-web
funbuild build

cd ../..

funbuild push
