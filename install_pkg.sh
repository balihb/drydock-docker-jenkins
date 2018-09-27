#!/bin/sh

set -xe

apt-get -q update
DEBIAN_FRONTEND="noninteractive" apt-get -q install -y -o Dpkg::Options::="--force-confnew" --no-install-recommends "$@"
apt-get -q autoremove
apt-get -q clean -y
rm -rf /var/lib/apt/lists/*
rm -f /var/cache/apt/*.bin
