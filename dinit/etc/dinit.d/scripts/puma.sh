#!/bin/sh

export USERNAME=shum
export DIR=/srv/http/thedarnedestthing.com/application
export PUMA=/usr/lib/ruby/gems/3.2.0/bin/pumactl

cd $DIR
$PUMA start -F puma.rb

