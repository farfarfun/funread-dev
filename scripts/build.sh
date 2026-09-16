#!/bin/sh
set -e

git -C apps/funread switch master
git -C apps/funread-dat switch master
git -C apps/funread-api switch master
git -C apps/funread-web switch master

cd apps/funread
funbuild build
cd ../..

cd apps/funread-dat
funbuild build
cd ../..

cd apps/funread-api
funbuild build
cd ../..

cd apps/funread-web
funbuild build
cd ../..

funbuild push
