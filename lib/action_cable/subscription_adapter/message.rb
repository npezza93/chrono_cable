module ActionCable
  module SubscriptionAdapter
    class Message
      def initialize(id:, payload:)
        @id = id
        @payload = payload
      end

      attr_reader :id, :payload
    end
  end
end
