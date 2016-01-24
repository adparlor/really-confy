require 'yaml'
require 'hashie/mash'
require 'hashie/extensions/parsers/yaml_erb_parser'
require 'hashie/extensions/deep_fetch'
require 'rainbow'

class ReallyConfy

  DEFAULT_OPTIONS = {
    # look for config files under this directory
    config_path: './config',
    # load and reucrisvely merge the config from these files, in the given order (duplicate keys
    # in later files will override those in earlier files)
    config_files: [
      'config.yml',
      'config.secret.yml',
      'config.local.yml'
    ],
    # load will raise a ConfigError if these files are in the git repo
    local_config_files: [
      'config.secret.yml',
      'config.local.yml'
    ],
    # load will raise a ConfigError if these files are missing
    required_config_files: [
      'config.yml',
      'config.secret.yml'
    ],
    # load will print a warning if these files are missing
    suggested_config_files: [
      'config.secret.yml'
    ],
    # the environment key will be selected based on this ENV variable
    env_var_name: 'CONFY_ENV',
    # suppress output to stdout/stderr
    quiet: false,
    # enable colorized output; nil means 'auto', which enables color by default unless the
    # terminal doesn't support it
    color: nil,
    # force the ruby interpreter to exit if ReallyConfy encounters an error during load
    # ... not a good idea to use this with quiet:true unless you know exactly what you're doing
    exit_on_error: false,
    # Don't allow (inadvertent) modification of the config once it's been loaded
    read_only: false
  }

  attr_accessor :config_files
  attr_accessor :config_path
  attr_accessor :local_config_files
  attr_accessor :required_config_files
  attr_accessor :suggested_config_files
  attr_accessor :env_var_name
  attr_accessor :env

  def initialize(opts = {})
    setup(opts)
  end

  def setup(opts)
    read_opts_into_instance_vars(opts, DEFAULT_OPTIONS.keys)
    @env_var_name = @env_var_name.to_s if @env_var_name # ENV keys are always strings
    @env = opts[:env] if opts.has_key? :env

    @rainbow = Rainbow.new
    @rainbow.enabled = @color unless @color.nil?

    ensure_required_config_files_exist
    check_suggested_config_files_exist
    ensure_local_config_files_are_not_in_git
  end

  def load
    existing_config_files =
      config_files.select{|file| File.exists? full_path_to_config_file(file) }

    print_info "Loading config from #{existing_config_files.inspect} for #{env.inspect}"+
      " environment..."

    multi_env_configs =
      existing_config_files.map{|file| load_config_file(file) }

    unless multi_env_configs.any?{|config| config.has_key?(env) }
      fail ConfigError, "#{env.inspect} is not a valid environment! None of the loaded configs"+
        " had a top-level #{env.inspect} key. All configurations should be nested under top"+
        " level keys corresponding to environment names (e.g. 'test', 'development', ...)"
    end

    env_configs = multi_env_configs.map{|multi_env_config|
        deep_merge multi_env_config.fetch('DEFAULTS', empty_config), multi_env_config.fetch(env, empty_config)
      }
    merged_config = env_configs.reduce{|merged_config, config| deep_merge(merged_config, config) }

    merged_config['env'] ||= env

    if @read_only
      merged_config.freeze
    end

    merged_config
  rescue => e
    header = "!!! Couldn't load config for #{env.inspect} environment! !!!"
    print_error ""
    print_error "!"*header.length
    print_error "#{header}"
    print_error "!"*header.length
    print_error ""
    print_error "#{e}"
    print_error ""
    print_error "BACKTRACE:"
    print_error "  #{e.backtrace.join("\n  ")}"
    print_error ""
    print_error "!"*header.length
    print_error ""
    if @exit_on_error
      print_error "Aborting because the :exit_on_error option is true!"
      exit 666
    end
    raise e
  end

  def empty_config
    ReallyConfy::Config.new {}
  end

  def load_config_file(file)
    full_path = full_path_to_config_file(file)

    if File.exists? full_path
      multi_env_config = (ReallyConfy::Config.load full_path)
    else
      multi_env_config = empty_config
    end

    multi_env_config
  end

  private

  def deep_merge(base_hash, other_hash, &block)
    base_hash = base_hash.dup
    other_hash.each_pair do |current_key, other_value|
      this_value = base_hash[current_key]

      base_hash[current_key] = if this_value.is_a?(Hash) && other_value.is_a?(Hash)
        deep_merge(this_value, other_value, &block)
      else
        if block_given? && base_hash.key?(current_key)
          block.call(current_key, this_value, other_value)
        else
          other_value
        end
      end
    end

    base_hash
  end

  def full_path_to_config_file(file)
    File.absolute_path(relative_path_to_config_file(file))
  end

  def relative_path_to_config_file(file)
    File.join(config_path,file)
  end

  def ensure_required_config_files_exist
    required_config_files.each do |file|
      full_path = full_path_to_config_file(file)
      unless File.exists? full_path
        fail ConfigError, "Required config file #{file.inspect} does not exist under"+
          " #{full_path.inspect}!"
      end
    end
  end

  def check_suggested_config_files_exist
    (suggested_config_files - required_config_files).each do |file|
      full_path = full_path_to_config_file(file)
      unless File.exists? full_path
        print_warning "WARNING: Config file #{file.inspect} does not exist!"
      end
    end
  end

  def ensure_local_config_files_are_not_in_git
    return unless git_available?
    return unless we_are_in_a_git_repo?

    local_config_files.each do |file|
      relative_path = relative_path_to_config_file(file)
      if file_is_in_git? relative_path
        fail ConfigError, "Local config file #{relative_path.inspect} exists in the git repo!"
          " Remove this file from your git repo and add it to your .gitignore"
      end
    end
  end

  def git_available?
    begin
      `git`
      true
    rescue Errno::ENOENT => e
      false
    end
  end

  def we_are_in_a_git_repo?
    File.exists? '.git'
  end

  def file_is_in_git?(file)
    git_cmd = "git ls-tree HEAD #{file}"
    git_output = `#{git_cmd}`.strip

    not git_output.empty?
  end

  def print_error(err)
    $stderr.puts @rainbow.wrap(err).red.bright
  end

  def print_warning(warning)
    $stderr.puts @rainbow.wrap(warning).yellow.bright
  end

  def print_info(info)
    $stdout.puts @rainbow.wrap(info).cyan
  end

  def env
    if @env
      return @env
    elsif ENV.has_key? env_var_name
      ENV.fetch(env_var_name)
    else
      fail ConfigError, "Configuration environment couldn't be determined --"+
        " ENV[#{env_var_name.inspect}] is not set! Try running with"+
        " `#{env_var_name.inspect}=yourenvname ...`"
    end
  end

  def read_opts_into_instance_vars(opts, instance_var_keys)
    instance_var_keys.each do |key|
      instance_variable_set(:"@#{key}", opts.fetch(key, ReallyConfy::DEFAULT_OPTIONS.fetch(key)))
    end
  end

  class Config < Hashie::Mash
    include Hashie::Extensions::DeepFetch

    def freeze
      return self if frozen?
      super
      self.values.each do |v|
        v.freeze unless frozen? || value_is_a_singleton?(v)
      end
      self
    end

  private

    def value_is_a_singleton?(value)
      value.nil? || value == true || value == false
    end
  end

  class ConfigError < StandardError
  end

end
