# run with `CONFY_ENV=test load_config.rb

$: << File.absolute_path('../../lib')
require 'confy'

# Default load behaviour:
#
#   1. load data under CONFY_ENV from config.yml
#   2. recursively merge with data under CONFY_ENV from config.secret.yml
#   3. recursively merge with data under CONFY_ENV from config.local.yml

$CONFIG = Confy.new.load

# $CONFIG should now contain the merged Hash for CONFY_ENV environment from config.yml,
# config.secret.yml, and config.local.yml.
#
# For example, if CONFY_ENV=test then $CONFIG would be:
#
#  {
#    "db" => {
#      "adapater" => "mysql2",
#      "hostname" => "localhost",
#      "username" => "tester",
#      "password" => "secret"
#    },
#    "env" => "test"
#  }

puts $CONFIG.inspect
