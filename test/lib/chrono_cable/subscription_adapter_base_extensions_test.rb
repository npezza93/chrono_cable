require "test_helper"

class ChronoCable::SubscriptionAdapterBaseExtensionsTest < ActiveSupport::TestCase
  class Adapter
    include ChronoCable::SubscriptionAdapterBaseExtensions
  end

  test "adapters opt out of history by default" do
    adapter = Adapter.new

    assert_not adapter.supports_history?
    assert_nil adapter.earliest_id("messages")
    assert_raises(NotImplementedError) { adapter.history("messages", after_id: 1) }
  end
end
