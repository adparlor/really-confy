# run with `FOOBAR_ENV=test load_config.rb

$: << File.absolute_path('../../lib')
require 'confy'

options = {
  env_var_name: 'FOOBAR_ENV',
  config_path: './foobar',
  config_files: ['config.yml', 'local.yml'],
  local_config_files: ['local.yml'],
  required_config_files: ['config.yml'],
  symbol_keys: false, # cannot be used together with :indifferent_keys
  indifferent_keys: true
}

$CONFIG = Confy.new(options).load

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

# Also, because the :indifferent_keys option is true, the following would both print "localhost":

puts $CONFIG['db']['adapter'] # => "localhost"
puts $CONFIG[:db][:adapter]   # => "localhost"
