require "rails/generators"
require "rails/generators/active_record"

class ChronoCable::InstallGenerator < Rails::Generators::Base
  include Rails::Generators::Migration

  source_root File.expand_path("templates", __dir__)

  def self.next_migration_number(dirname)
    ActiveRecord::Generators::Base.next_migration_number(dirname)
  end

  def copy_migrations
    migration_template "create_solid_cable_channels.rb",
      "db/cable_migrate/create_solid_cable_channels.rb"

    migration_template "add_channel_id_to_solid_cable_messages.rb",
      "db/cable_migrate/add_channel_id_to_solid_cable_messages.rb"
  end

  def update_importmap
    return unless File.exist?(File.join(destination_root, "config/importmap.rb"))

    gsub_file "config/importmap.rb",
      /pin\s+["']@rails\/actioncable["'],\s+to:\s+["']actioncable\.esm\.js["']/,
      'pin "@rails/actioncable", to: "chronocable.js"'

    gsub_file "config/importmap.rb",
      /pin\s+["']@hotwired\/turbo-rails["'],\s+to:\s+["']turbo\.min\.js["']/,
      'pin "@hotwired/turbo-rails", to: "chronocable_turbo.min.js"'
  end
end
