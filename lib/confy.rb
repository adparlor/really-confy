require 'yaml'
require 'active_support/core_ext/hash/deep_merge'

class Confy

  DEFAULT_OPTIONS = {
    config_path: './config',
    config_files: [
      'config.yml',
      'config.secret.yml',
      'config.local.yml'
    ],
    local_config_files: [
      'config.secret.yml',
      'config.local.yml'
    ],
    required_config_files: [
      'config.yml',
      'config.secret.yml'
    ],
    env_var_name: 'CONFY_ENV',
    symbol_keys: false,
    indifferent_keys: false
  }

  attr_accessor :config_files
  attr_accessor :config_path
  attr_accessor :local_config_files
  attr_accessor :required_config_files
  attr_accessor :env_var_name
  attr_accessor :env

  def initialize(opts = {})
    setup(opts)
  end

  def setup(opts)
    read_opts_into_instance_vars(opts, DEFAULT_OPTIONS.keys)
    @env_var_name = @env_var_name.to_s if @env_var_name # ENV keys are always strings
    @env = opts[:env] if opts.has_key? :env

    ensure_required_config_files_exist
    ensure_local_config_files_are_not_in_git

    if @symbol_keys && @indifferent_keys
      fail ArgumentError,
        ":symbol_keys and :indifferent_keys options cannot be used together!"
    end

    require 'active_support/core_ext/hash/keys' if @symbol_keys
    require 'active_support/core_ext/hash/indifferent_access' if @indifferent_keys
  end

  def load
    multi_env_configs = config_files
      .select{|file| File.exists? full_path_to_config_file(file) }
      .map{|file| load_config_file(file) }

    unless multi_env_configs.any?{|config| config.is_a?(Hash) && config.has_key?(env) }
      fail ConfigError, "#{env.inspect} is not a valid environment! None of the loaded configs"+
        " had a top-level #{env.inspect} key. All configurations should be nested under top"+
        " level keys corresponding to environment names (e.g. 'test', 'development', ...)"
    end

    env_configs = multi_env_configs.map{|multi_env_config|
        multi_env_config.fetch('DEFAULTS', {}).deep_merge multi_env_config.fetch(env, {})
      }
    merged_config = env_configs.reduce{|merged_config, config| merged_config.deep_merge(config) }

    merged_config['env'] ||= env

    merged_config.deep_symbolize_keys! if @symbol_keys
    merged_config = merged_config.with_indifferent_access if @indifferent_keys

    merged_config
  end

  def load_config_file(file)
    full_path = full_path_to_config_file(file)
    multi_env_config = (YAML.load_file full_path)

    # YAML.load_file will return false if given an empty file to load
    return {} if multi_env_config == false

    unless multi_env_config.is_a? Hash
      fail ConfigError, "Config file #{file.inspect} must contain a YAML-encoded Hash, but"+
        " it seems to contain a #{multi_env_config.class}"
    end

    multi_env_config
  end

  private

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
      instance_variable_set(:"@#{key}", opts.fetch(key, Confy::DEFAULT_OPTIONS.fetch(key)))
    end
  end

  class ConfigError < StandardError
  end

end