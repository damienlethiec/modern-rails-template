RAILS_REQUIREMENT = ">= 5.2.0.rc1"

def apply_template!
  assert_minimum_rails_version

  # temporal fix bootsnap bug
  copy_file 'config/boot.rb', force: true

  run('rails db:migrate')
end

def assert_minimum_rails_version
  requirement = Gem::Requirement.new(RAILS_REQUIREMENT)
  rails_version = Gem::Version.new(Rails::VERSION::STRING)
  return if requirement.satisfied_by?(rails_version)

  prompt = "This template requires Rails #{RAILS_REQUIREMENT}. "\
           "You are using #{rails_version}. Continue anyway?"
  exit 1 if no?(prompt)
end

apply_template!