Rails.application.routes.draw do
  mount ChronoCable::Engine => "/chrono_cable"
end
