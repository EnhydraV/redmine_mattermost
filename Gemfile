# frozen_string_literal: true

gem 'redmine_plugin_kit'
gem 'slim-rails'

group :development do
  # this is only used for development.
  # if you want to use it, do:
  # - create .enable_dev file in the plugin directory
  # - remove rubocop entries from REDMINE/Gemfile
  # - remove REDMINE/.rubocop* files
  if File.file? File.expand_path './.enable_dev', __dir__
    gem 'rubocop', require: false
    gem 'rubocop-minitest', require: false
    gem 'rubocop-performance', require: false
    gem 'rubocop-rails', require: false
    gem 'slim_lint', require: false
  end
end
