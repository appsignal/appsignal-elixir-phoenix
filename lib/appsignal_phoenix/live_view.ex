defmodule Appsignal.Phoenix.LiveView do
  require Appsignal.Utils
  @tracer Appsignal.Utils.compile_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Appsignal.Utils.compile_env(:appsignal, :appsignal_span, Appsignal.Span)
  @os Appsignal.Utils.compile_env(:appsignal, :os, :os)

  def instrument(module, name, socket, fun) do
    instrument(module, name, %{}, socket, fun)
  end

  def instrument(module, name, params, socket, fun) do
    Appsignal.instrument(
      "#{Appsignal.Utils.module_name(module)}##{name}",
      fn span ->
        _ = @span.set_namespace(span, "live_view")

        try do
          fun.()
        catch
          kind, reason ->
            stack = __STACKTRACE__

            _ =
              span
              |> @span.set_sample_data("params", params)
              |> @span.set_sample_data("environment", Appsignal.Metadata.metadata(socket))
              |> @span.add_error(kind, reason, stack)
              |> @tracer.close_span()

            @tracer.ignore()
            :erlang.raise(kind, reason, stack)
        else
          result ->
            _ =
              span
              |> @span.set_sample_data("params", params)
              |> @span.set_sample_data("environment", Appsignal.Metadata.metadata(socket))

            result
        end
      end
    )
  end

  def live_view_action(module, name, socket, function) do
    instrument(module, name, socket, function)
  end

  def live_view_action(module, name, params, socket, function) do
    instrument(module, name, params, socket, function)
  end

  def handle_event_start(
        [:phoenix, :live_view, name, :start],
        %{system_time: system_time},
        metadata,
        _event_name
      ) do
    "live_view"
    |> @tracer.create_span(nil, start_time: system_time)
    |> @span.set_name("#{Appsignal.Utils.module_name(metadata[:socket].view)}##{name}")
    |> @span.set_attribute("appsignal:category", "#{name}.live_view")
    |> @span.set_sample_data("params", metadata[:params])
    |> @span.set_sample_data("session_data", metadata[:session])
  end

  def handle_event_stop(_event, _params, _metadata, _event_name) do
    @tracer.close_span(@tracer.current_span(), end_time: @os.system_time())
  end
end
