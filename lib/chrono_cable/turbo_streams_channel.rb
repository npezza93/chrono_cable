module ChronoCable::TurboStreamsChannel
  def stream_from(*args, **options, &block)
    options[:deliver_in_order] = ordered_delivery? unless options.key?(:deliver_in_order)
    super(*args, **options, &block)
  end

  private
    def ordered_delivery?
      params[:deliver_in_order] == true || params[:deliver_in_order] == "true"
    end
end
