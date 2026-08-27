module ChronoCable::ConnectionSubscriptions
  def execute_command(data)
    if data["command"] == "history"
      fetch_history data
    else
      super
    end
  end

  def fetch_history(data)
    subscription = find(data)
    raise UnknownSubscription.new(data["identifier"]) unless subscription
    subscription.__send__(:__history, data)
  end
end
