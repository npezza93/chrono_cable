require "test_helper"

class ChronoCable::TurboStreamsChannelTest < ActiveSupport::TestCase
  class Channel
    prepend ChronoCable::TurboStreamsChannel

    attr_reader :stream

    def initialize(params = {})
      @params = params
    end

    def params
      @params
    end

    def stream_from(*args, **options, &block)
      @stream = [ args, options, block ]
    end
  end

  test "passes the data attribute through while preserving an explicit option" do
    enabled = Channel.new(deliver_in_order: "true")
    disabled = Channel.new
    explicit = Channel.new(deliver_in_order: "false")

    enabled.stream_from "messages"
    disabled.stream_from "messages"
    explicit.stream_from "messages", deliver_in_order: true

    assert enabled.stream.second[:deliver_in_order]
    assert_not disabled.stream.second[:deliver_in_order]
    assert explicit.stream.second[:deliver_in_order]
  end
end
