require "test_helper"

class ChronoCable::SubscriptionAdapterBaseExtensionsTest < ActiveSupport::TestCase
  class Adapter
    include ChronoCable::SubscriptionAdapterBaseExtensions
  end

  test "adapters opt out of history by default" do
    adapter = Adapter.new

    assert_not adapter.supports_history?
  end
end
