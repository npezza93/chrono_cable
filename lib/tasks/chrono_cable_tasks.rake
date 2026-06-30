desc "Copy over the migrations and set the js for Chrono Cable"
namespace :chrono_cable do
  task :install do
    Rails::Command.invoke :generate, [ "chrono_cable:install" ]
  end
end
