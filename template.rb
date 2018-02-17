require "fileutils"
require "shellwords"
require "tmpdir"

RAILS_REQUIREMENT = ">= 5.2.0.rc1"

def apply_template!
  assert_minimum_rails_version
  add_template_repository_to_source_path

  # temporary fix bootsnap bug
  comment_lines 'config/boot.rb', /bootsnap/

  template "Gemfile.tt", force: true
  template 'README.md.tt', force: true
  apply 'config/template.rb'
  apply 'app/template.rb'
  copy_file 'Procfile'
  copy_file 'Procfile.dev'

  ask_optional_options

  install_optional_gems

  after_bundle do
    setup_uuid if @uuid

    setup_front_end
    setup_npm_packages
    optional_options_front_end

    setup_gems

    run 'bundle binstubs bundler --force'

    run 'rails db:create db:migrate'

    setup_git
    push_github if @github
    setup_overcommit
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
      "https://github.com/damienlethiec/modern-rails-template",
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



def ask_optional_options
  @devise = yes?('Do you want to implement authentication in your app with the Devise gem?')
  @pundit = yes?('Do you want to manage authorizations with Pundit?') if @devise
  @uuid = yes?('Do you want to use UUID for active record primary?')
  @haml = yes?('Do you want to use Haml instead of EBR?')
  @komponent = yes?('Do you want to adopt a component based design for your front-end?')
  @tailwind = yes?('Do you want to use Tailwind as a CSS framework?')
  @github = yes?('Do you want to push your project to Github?')
end

def install_optional_gems
  add_devise if @devise
  add_pundit if @pundit
  add_komponent if @komponent
  add_haml if @haml
end

def add_devise
  insert_into_file 'Gemfile', "gem 'devise'\n", after: /'friendly_id'\n/
  insert_into_file 'Gemfile', "gem 'devise-i18n'\n", after: /'friendly_id'\n/
end

def add_pundit
  insert_into_file 'Gemfile', "gem 'pundit'\n", after: /'friendly_id'\n/
end

def add_haml
  insert_into_file 'Gemfile', "gem 'haml'\n", after: /'friendly_id'\n/
  insert_into_file 'Gemfile', "gem 'haml-rails', git: 'git://github.com/indirect/haml-rails.git'\n", after: /'friendly_id'\n/
end

def add_komponent
  insert_into_file 'Gemfile', "gem 'komponent'\n", after: /'friendly_id'\n/
end



def setup_uuid
  copy_file 'db/migrate/20180208061510_enable_pg_crypto_extension.rb'
  insert_into_file 'config/initializers/generators.rb', "  g.orm :active_record, primary_key_type: :uuid\n", after: /assets: false\n/
end



def setup_front_end
  copy_file '.browserslistrc'
  copy_file 'app/assets/stylesheets/application.scss'
  remove_file 'app/assets/stylesheets/application.css'
  append_to_file 'Procfile', "assets: bin/webpack-dev-server\n"
end

def setup_npm_packages
  add_linters
end

def add_linters
  run 'yarn add eslint babel-eslint eslint-config-airbnb-base eslint-config-prettier eslint-import-resolver-webpack eslint-plugin-import eslint-plugin-prettier lint-staged prettier stylelint stylelint-config-standard --dev'
  copy_file '.eslintrc'
  copy_file '.stylelintrc'
  run 'yarn add normalize.css'
end

def optional_options_front_end
  add_css_framework if @tailwind
end

def add_css_framework
  run 'yarn add tailwindcss --dev'
  run './node_modules/.bin/tailwind init app/javascript/css/tailwind.js'
  copy_file 'app/javascript/css/application.css'
  append_to_file 'app/javascript/packs/application.js', "import '../css/application.css';\n"
  if @komponent
    append_to_file '.postcssrc.yml', "  tailwindcss: './frontend/css/tailwind.js'"
  else
    append_to_file '.postcssrc.yml', "  tailwindcss: './app/javascript/css/tailwind.js'"
  end
end



def setup_gems
  setup_friendly_id
  setup_annotate
  setup_bullet
  setup_erd
  setup_sidekiq
  setup_rubocop
  setup_brakeman
  setup_guard
  setup_komponent if @komponent
  setup_devise if @devise
  setup_pundit if @pundit
  setup_haml if @haml
end

def setup_friendly_id
  # temporal fix bug friendly_id generator
  copy_file 'db/migrate/20180208061509_create_friendly_id_slugs.rb'
end

def setup_annotate
  run 'rails g annotate:install'
  run 'bundle binstubs annotate'
end

def setup_bullet
  insert_into_file 'config/environments/development.rb', before: /^end/ do
    <<-RUBY
  Bullet.enable = true
  Bullet.alert = true
    RUBY
  end
end

def setup_erd
  run 'rails g erd:install'
  append_to_file '.gitignore', 'erd.pdf'
end

def setup_sidekiq
  run 'bundle binstubs sidekiq'
  append_to_file 'Procfile.dev', "worker: bundle exec sidekiq -C config/sidekiq.yml\n"
  append_to_file 'Procfile', "worker: bundle exec sidekiq -C config/sidekiq.yml\n"
end

def setup_rubocop
  run 'bundle binstubs rubocop'
  copy_file '.rubocop'
  copy_file '.rubocop.yml'
  run 'rubocop'
end

def setup_brakeman
  run 'bundle binstubs brakeman'
end

def setup_guard
  run 'bundle binstubs guard'
  run 'guard init livereload bundler'
  append_to_file 'Procfile.dev', "guard: bundle exec guard\n"
  insert_into_file 'config/environments/development.rb', "  config.middleware.insert_after ActionDispatch::Static, Rack::LiveReload\n", before: /^end/
  if @komponent
    insert_into_file 'Guardfile', %q(  watch(%r{frontend/.+\.(#{rails_view_exts * '|'})$})) + "\n", after: /extensions.values.uniq\n/
  end
end

def setup_komponent
  install_komponent
  add_basic_components
end

def install_komponent
  run 'rails g komponent:install --stimulus'
  insert_into_file 'config/initializers/generators.rb', "  g.komponent stimulus: true, locale: true\n", after: /assets: false\n/
  FileUtils.rm_rf 'app/javascript'
  insert_into_file 'app/controllers/application_controller.rb', "  prepend_view_path Rails.root.join('frontend')\n", after: /exception\n/
end

def add_basic_components
  run 'rails g component flash'
  insert_into_file 'app/views/layouts/application.html.erb', "    <%= component 'flash' %>\n", after: /<body>\n/
  run 'rails g component button'
  run 'rails g component card'
  run 'rails g component form'
end

def setup_devise
  run 'rails generate devise:install'
  run 'rails g devise:i18n:views'
  insert_into_file 'config/routes.rb', after: /draw do\n/ do
    <<-RUBY
  require "sidekiq/web"
  mount Sidekiq::Web => '/sidekiq'
    RUBY
  end
  insert_into_file 'config/initializers/devise.rb', "  config.secret_key = Rails.application.credentials.secret_key_base\n", before: /^end/
  run 'rails g devise User'
  insert_into_file 'app/controllers/application_controller.rb', "  before_action :authenticate_user!\n", after: /exception\n/
  insert_into_file 'app/controllers/pages_controller.rb', "  skip_before_action :authenticate_user!, only: :home\n", after: /ApplicationController\n/
end

def setup_pundit
  insert_into_file 'app/controllers/application_controller.rb', before: /^end/ do
    <<-RUBY
    def user_not_authorized
      flash[:alert] = "You are not authorized to perform this action."
      redirect_to(root_path)
    end

    private

    def skip_pundit?
      devise_controller? || params[:controller] =~ /(^(rails_)?admin)|(^pages$)/
    end
    RUBY
  end
  insert_into_file 'app/controllers/application_controller.rb', after: /exception\n/ do
    <<-RUBY
    include Pundit

    after_action :verify_authorized, except: :index, unless: :skip_pundit?
    after_action :verify_policy_scoped, only: :index, unless: :skip_pundit?

    rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
    RUBY
  end
  run 'spring stop'
  run 'rails g pundit:install'
end

def setup_haml
  run 'HAML_RAILS_DELETE_ERB=true rake haml:erb2haml'
end



def setup_git
  git flow: 'init -d'
  git add: '.'
  git commit: '-m "End of the template generation"'
end

def push_github
  @hub = run 'brew ls --versions hub'
  if @hub
    run 'hub create'
    run 'git push origin master'
    run 'git push origin develop'
    run 'hub browse'
  else
    puts 'You first need to install the hub command line tool'
  end
end

def setup_overcommit
  run 'overcommit --install'
  copy_file '.overcommit.yml', force: true
  run 'overcommit --sign'
end

run 'pgrep spring | xargs kill -9'

# launch the main template creation method
apply_template!
