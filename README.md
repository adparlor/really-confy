# Comfy
##### A simple YAML configuration loader.

We use Confy to configure [Grape](https://github.com/ruby-grape/grape)
applications, but it's flexible enough for just about anything.

Features:

- Loads your app's configuration from multiple, merged config files
- Prevents you from putting sensitive config values into your git repo
- Warns you if suggested config files are missing

The default setup assumes that you have three different config files:

```
config/config.yml
config/config.secret.yml
config/config.local.yml
```

The configuration from each of these files will be loaded and merged. See
below for a description of each file's intended role.

```ruby
require 'confy'
confy = Confy.new(env_var_name: 'MY_APP_ENV')
$CONFIG = confy.load
```

`env_var_name` tells Confy to look for ENV['MY_APP_ENV'] to choose the
appropriate set of options from the config files (e.g. `test`, `development`,
`production`). For example, to use a `test` configuration, you would start
your app on the command line with `MY_APP_ENV=test ruby my_app.rb`.

That's it. `$CONFIG` now holds a Hash with your app's full configuration.


The default config file layout is as follows:

### config/config.yml

This is the main config for your application. This file should contain all of
the options necessary to boot your app, with sensible defaults for all
required values. It *should* be checked in to your git repo and distributed
with the rest of your code.

Example:

```yaml
development:
  db:
    adapter: mysql2
    hostname: localhost
    username: root
    database: foobar_dev

production:
  db:
    adapter: mysql2
    hostname: localhost
    username: root
    database: foobar_prod
```

### config/config.secret.yml

Sensitive information -- passwords, API keys, etc. -- should go here. Confy
will not allow you to check this file into your git repo, and will warn you if
this file is missing.

Example:

```yaml
development:
  db:
    password: secret

production:
  db:
    password: topsecret
```

### config/config.local.yml

Installation-specific overrides can be placed here. For example, if your main
`config.yml` has `root` as the default database user, you could override this
for a specific installation by setting a different value for this key in the
`config.local.yml` file.

This file is entirely optional. Since this file is intended as a way of
specifying local overrides for the main `config.yml` distributed with your
code, Confy will not allow you to check the `config.loca.yml` file into your
git repo.

Example:

```yaml
development:
  db:
    username: foobar

production:
  db:
    username: foobar
```


## Options

Confy itself is configured through an options Hash given as the first argment
to `Confy.new`. For example:

```ruby
confy = Confy.new(
    env_var_name: 'GRAPE_ENV',
    config_path: File.absolute_path(__FILE__)+'/../../conf'
    config_files: ['app.yml', 'local.yml'],
    required_config_files: ['app.yml'],
    local_config_files: ['local.yml'],
    suggested_config_files: ['local.yml'],
    symbol_keys: true
  )

```

See `DEFAULT_OPTIONS` in `confy.rb` for a list of all available options. Options include:

- `:config_files` (default: `["config.yml", "config.secret.yml", "config.local.yml"]`)

  The list of all config files that will be loaded. Files are loaded in
  order, with each subsequent file's key values recursively merged in.

- `:config_path` (default: `./config`)

  Config files should be placed in this directory.

- `:required_config_files`  (default: `["config.yml"]`)

  If any one of these files doesn't exist, `Confy#load` will print an
  error message to stderr and fail with a `Confy::ConfigError`.

- `:local_config_files`  (default: `["config.secret.yml", "config.local.yml"]`)

  These files are meant to exist locally only. If any of these files are found
  in the git repo, `Confy#load` will print an error message to stderr and fail
  with a `Confy::ConfigError`.

- `:suggested_config_files`  (default: `[config.secret.yml"]`)

  If any of these files are missing, `Confy#load` will print a warning to
  stderr but will allow you to proceed.

- `:symbol_keys` (default: `false`)

  By default `Confy#load` return a Hash with Strings for keys. If
  `:symbol_keys` is true, a Hash with Symbols for keys will be returned
  instead.

- `:indifferent_keys` (default: `false`)

  `Confy#load` will return an ActiveSupport::HashWithIndifferentAccess instead
  of a regular Hash. This makes it possible to access config files usinb both
  Strings and Symbols (e.g. `config[:foo] == config['foo']`).

- `:quiet` (default: `false`)

  Suppresses output to stdout/stderr. Confy will still raise `ConfigErrors`,
  but will not print anything on its ow.


### `DEFAULTS` environment

In addition to environment keys (`production`, `test`, etc.), every config
file can also contain a special `DEFAULTS` key. The configuration
under this key will be used for all environments. For example:

```yaml
DEFAULTS:
  db:
    adapter: mysql2
    hostname: localhost

test:
  db:
    username: tester

production:
  db:
    username: prod
```

When loaded under the `'test'` env, the above config would contain:

```ruby
{
  "db" => {
    "adapater" => "mysql2",
    "hostname" => "localhost",
    "username" => "tester"
  }
}
```

... and under the `'production'` env, ti would contain:

```ruby
{
  "db" => {
    "adapater" => "mysql2",
    "hostname" => "localhost",
    "username" => "prod"
  }
}
```

