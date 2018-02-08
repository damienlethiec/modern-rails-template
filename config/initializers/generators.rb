Rails.application.config.generators do |g|
  # Disable generators we don't need.
  g.javascripts false
  g.stylesheets false
  g.assets false
  g.helper false
  g.scaffold_stylesheet false
end