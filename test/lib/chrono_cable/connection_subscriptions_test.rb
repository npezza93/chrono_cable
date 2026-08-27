require "test_helper"

class ChronoCable::ConnectionSubscriptionsTest < ActiveSupport::TestCase
  class Subscriptions
    prepend ChronoCable::ConnectionSubscriptions

    attr_reader :delegated_command

    def initialize(subscription = nil)
      @subscription = subscription
    end

    def execute_command(data)
      @delegated_command = data
    end

    private
      def find(_data)
        @subscription
      end
  end

  test "routes history commands to the existing subscription" do
    received = nil
    subscription = Object.new
    subscription.define_singleton_method(:__history) { |data| received = data }
    subscriptions = Subscriptions.new(subscription)
    command = { "command" => "history", "identifier" => "room", "id" => 4 }

    subscriptions.execute_command command

    assert_same command, received
  end

  test "rejects history commands for an unknown subscription" do
    error = assert_raises(ActionCable::Connection::Subscriptions::UnknownSubscription) do
      Subscriptions.new.execute_command "command" => "history", "identifier" => "missing"
    end

    assert_includes error.message, "missing"
  end

  test "delegates other commands to Action Cable" do
    subscriptions = Subscriptions.new
    command = { "command" => "subscribe", "identifier" => "room" }

    subscriptions.execute_command command

    assert_same command, subscriptions.delegated_command
  end
end
