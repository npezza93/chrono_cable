module ChronoCable
  class Engine < ::Rails::Engine
    isolate_namespace ChronoCable

    initializer "chrono_cable" do
      ActiveSupport.on_load(:action_cable) do
        ::ChronoCable.install!
      end
    end
  end
end
