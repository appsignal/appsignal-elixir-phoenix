defmodule Appsignal.Phoenix.LiveViewTelemetry do
  use GenServer
  require Appsignal.Utils
  import Appsignal.Utils, only: [module_name: 1]

  @tracer Appsignal.Utils.compile_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Appsignal.Utils.compile_env(:appsignal, :appsignal_span, Appsignal.Span)
  @appsignal_namespace "live_view"

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    events = [
      {"live_view.mount", [:phoenix, :live_view, :mount]},
      {"live_view.handle_params", [:phoenix, :live_view, :handle_params]},
      {"live_view.handle_event", [:phoenix, :live_view, :handle_event]},
      {"live_component.handle_event", [:phoenix, :live_component, :handle_event]}
    ]

    for {name, event} <- events do
      :telemetry.attach("#{name}.start", event ++ [:start], &handle_event_start/4, name)
      :telemetry.attach("#{name}.stop", event ++ [:stop], &handle_event_stop/4, name)

      :telemetry.attach(
        "#{name}.exception",
        event ++ [:exception],
        &handle_event_exception/4,
        name
      )
    end

    {:ok, nil}
  end

  defp handle_event_start(_event, _params, metadata, event_name) do
    @appsignal_namespace
    |> @tracer.create_span(@tracer.current_span(),
      start_time: :os.system_time(),
      pid: metadata.socket.root_pid
    )
    |> @span.set_name(module_name(metadata.socket.view))
    |> @span.set_attribute("type", event_type(event_name))
    |> @span.set_attribute("appsignal:category", event_name)
    |> maybe_set_sample_data(metadata[:params], :params)
    |> maybe_set_sample_data(metadata[:session], :session_data)
    |> maybe_set_attribute(metadata[:uri], :uri)
    |> maybe_set_attribute(metadata[:event], :event)
  end

  defp handle_event_stop(_event, _params, metadata, _event_name) do
    metadata.socket.root_pid
    |> @tracer.current_span()
    |> @tracer.close_span(end_time: :os.system_time())
  end

  defp handle_event_exception(_event, _params, metadata, _event_name) do
    metadata.socket.root_pid
    |> @tracer.current_span()
    |> @span.add_error(metadata.kind, metadata.reason, metadata.stacktrace)
    |> @tracer.close_span(end_time: :os.system_time())

    @tracer.ignore(metadata.socket.root_pid)
  end

  defp event_type(event_name), do: event_name |> String.split(".") |> Enum.at(-1)

  defp maybe_set_sample_data(span, val, key) when is_map(val) do
    case @span.set_sample_data(span, to_string(key), val) do
      nil -> span
      span -> span
    end
  end

  defp maybe_set_sample_data(span, _val, _key), do: span

  defp maybe_set_attribute(span, val, key) when is_binary(val) do
    case @span.set_attribute(span, to_string(key), val) do
      nil -> span
      span -> span
    end
  end

  defp maybe_set_attribute(span, _val, _key), do: span
end
