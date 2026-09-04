require "test_helper"
require "generators/chrono_cable/install/install_generator"

module ChronoCable
  class InstallGeneratorTest < Rails::Generators::TestCase
    tests InstallGenerator
    destination Rails.root.join("tmp/generators")
    setup :prepare_destination

    test "installs migrations and browser bundles" do
      FileUtils.mkdir_p File.join(destination_root, "config")
      File.write File.join(destination_root, "config/importmap.rb"),
        %(pin "@rails/actioncable", to: "actioncable.esm.js"\npin "@hotwired/turbo-rails", to: "turbo.min.js"\n)

      run_generator

      assert_migration "db/migrate/create_solid_cable_channels.rb" do |migration|
        assert_match "create_table :solid_cable_channels", migration
      end
      assert_migration "db/migrate/add_channel_id_to_solid_cable_messages.rb" do |migration|
        assert_match "add_column :solid_cable_messages, :channel_id", migration
      end
      assert_file "config/importmap.rb",
        %(pin "@rails/actioncable", to: "chronocable.js"\npin "@hotwired/turbo-rails", to: "chronocable_turbo.min.js"\n)
    end
  end
end
