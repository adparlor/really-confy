# run with `FOOBAR_ENV=test load_config.rb

$: << File.absolute_path('../../lib')
require 'really_confy'

options = {
  env_var_name: 'FOOBAR_ENV',
  config_path: './foobar',
  config_files: ['config.yml', 'local.yml'],
  local_config_files: ['local.yml'],
  required_config_files: ['config.yml']
}

$CONFIG = ReallyConfy.new(options).load

# $CONFIG should now contain the merged Hash for FOOBAR_ENV environment from config.yml,
# and local.yml.
#
# For example, if FOOBAR_ENV=test then $CONFIG would be:
#
#  {
#    "db" => {
#      "adapater" => "mysql2",
#      "hostname" => "localhost",
#      "username" => "tester",
#      "password" => "foobar"
#      "database" => "foo_test"
#    },
#    "env" => "test"
#  }
#

puts $CONFIG.inspect

puts $CONFIG.db.adapater    # => "mysql2"
puts $CONFIG[:db][:adapter] # => "myslq2"
puts $CONFIG.db.adapter?    # true
puts $CONFIG.db.foo?        # false

