Rails.application.config.generators do |g|
  # Disable generators we don't need.
  g.javascripts false
  g.stylesheets false
  g.assets false
  g.helper false
  g.test_framework false
  g.channel assets: false
end