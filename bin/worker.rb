#!/usr/bin/env ruby
require File.expand_path("../../lib", __FILE__) + "/etl"
require 'etl/process/worker'
ETL::Process::Worker.new.start