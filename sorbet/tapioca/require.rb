# typed: true
# frozen_string_literal: true

require "active_support/all"
require "dotenv/load"
require "faraday"
require "net/http/digest_auth"
require "pry"
require "rspec/its"
require "rspec/sorbet"
require "rubocop"
require "sorbet-runtime"
require "vcr"
require "zeitwerk"
