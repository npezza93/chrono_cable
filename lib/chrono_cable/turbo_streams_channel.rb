module ChronoCable::TurboStreamsChannel
  def stream_from(*args, **options, &block)
    super(*args, deliver_in_order: params[:deliver_in_order].to_s == "true", **options, &block)
  end
end
