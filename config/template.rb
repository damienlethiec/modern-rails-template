copy_file 'config/initializers/generators.rb'
copy_file 'config/initializers/i18n.rb'
copy_file 'config/initializers/sidekiq.rb'
copy_file 'config/initializers/redis.rb'

copy_file 'config/routes.rb', force: true

insert_into_file 'config/environments/development.rb', after: /config\.action_mailer\.raise_delivery_errors = false\n/ do
  <<-RUBY
  config.action_mailer.default_url_options = { :host => "localhost:3000" }
  config.action_mailer.asset_host = "http://localhost:3000"
  RUBY
end

copy_file 'config/sidekiq.yml'

remove_file 'config/locales/en.yml'
copy_file 'config/locales/defaults/en.yml'
copy_file 'config/locales/models/en.yml'
copy_file 'config/locales/views/en.yml'
copy_file 'config/locales/defaults/fr.yml'
copy_file 'config/locales/models/fr.yml'
copy_file 'config/locales/views/fr.yml'
