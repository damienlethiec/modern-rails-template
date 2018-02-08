require "fileutils"
require "shellwords"

RAILS_REQUIREMENT = ">= 5.2.0.rc1"

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  # temporal fix bootsnap bug
  comment_lines 'config/boot.rb', /bootsnap/

  template "Gemfile.tt", force: true
  template 'README.md.tt', force: true
  apply "config/template.rb"
  copy_file 'app/controllers/application_controller.rb', force: true
  copy_file 'Procfile'

  after_bundle do
    # gems configs
    config_gems
    install_optional_gems
    config_optional_gems

    run 'rails db:create db:migrate'

    setup_git
  end
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

# Add this template directory to source_paths so that Thor actions like
# copy_file and template resolve against our source files. If this file was
# invoked remotely via HTTP, that means the files are not present locally.
# In that case, use `git clone` to download them to a local temporary dir.
def add_template_repository_to_source_path
  if __FILE__ =~ %r{\Ahttps?://}
    source_paths.unshift(tempdir = Dir.mktmpdir("rails-template-"))
    at_exit { FileUtils.remove_entry(tempdir) }
    git :clone => [
      "--quiet",
      "https://github.com/damienlethiec/my-rails-template",
      tempdir
    ].map(&:shellescape).join(" ")
  else
    source_paths.unshift(File.dirname(__FILE__))
  end
end

def gemfile_requirement(name)
  @original_gemfile ||= IO.read("Gemfile")
  req = @original_gemfile[/gem\s+['"]#{name}['"]\s*(,[><~= \t\d\.\w'"]*)?.*$/, 1]
  req && req.gsub("'", %(")).strip.sub(/^,\s*"/, ', "')
end

def config_gems
  config_friendly_id
  config_annotate
  config_bullet
  config_erd
end

def config_friendly_id
  # temporal fix bug friendly_id generator
  copy_file 'db/migrate/20180208061509_create_friendly_id_slugs.rb'
end

def config_annotate
  run 'rails g annotate:install'
end

def config_bullet
  insert_into_file 'config/environments/development.rb', before: /^end/ do
    <<-RUBY
  Bullet.enable = true
  Bullet.alert = true
    RUBY
  end
end

def config_erd
  run 'rails g erd:install'
  append_to_file '.gitignore', 'erd.pdf'
end

def install_optional_gems
  add_haml?
  run 'bundle install'
end

def add_haml?
  @haml = yes?('Do you want to use Haml instead of EBR?')
  if @haml
    insert_into_file 'Gemfile', "gem 'haml'\n", after: /'friendly_id'\n/
    insert_into_file 'Gemfile', "gem 'haml-rails'\n", after: /'friendly_id'\n/
  end
end

def config_optional_gems
  run 'rake haml:erb2haml' if @haml
end

def setup_git
  git flow: 'init -d'
  git add: '.'
  git commit: '-m "End of the template generation"'
end

run 'pgrep spring | xargs kill -9'

apply_template!