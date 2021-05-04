defmodule Appsignal.Phoenix.EventHandler do
  @tracer Application.get_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Application.get_env(:appsignal, :appsignal_span, Appsignal.Span)
  @moduledoc false

  require Logger

  def attach do
    handlers = %{
      [:phoenix, :endpoint, :start] => &phoenix_endpoint_start/4,
      [:phoenix, :endpoint, :stop] => &phoenix_endpoint_stop/4
    }

    for {event, fun} <- handlers do
      case :telemetry.attach({__MODULE__, event}, event, fun, :ok) do
        :ok ->
          Appsignal.Logger.debug("Appsignal.Phoenix.EventHandler attached to #{inspect(event)}")
          :ok

        {:error, _} = error ->
          Logger.warn(
            "Appsignal.Phoenix.EventHandler not attached to #{inspect(event)}: #{inspect(error)}"
          )

          error
      end
    end
  end

  def phoenix_endpoint_start(
        _event,
        _measurements,
        %{conn: %Plug.Conn{private: %{phoenix_endpoint: endpoint}, request_path: path}},
        _config
      ) do
    parent = @tracer.current_span()

    "http_request"
    |> @tracer.create_span(parent)
    |> @span.set_name(span_name(path, endpoint))
    |> @span.set_attribute("appsignal:category", "call.phoenix_endpoint")
  end

  defp phoenix_endpoint_stop(_event, _measurements, _metadata, _config) do
    @tracer.close_span(@tracer.current_span())
  end

  defp span_name("" = _path, endpoint), do: span_name(endpoint)
  defp span_name(nil = _path, endpoint), do: span_name(endpoint)
  defp span_name(path, _endpoint), do: path
  defp span_name(endpoint), do: "#{module_name(endpoint)}.call/2"

  defp module_name("Elixir." <> module), do: module
  defp module_name(module) when is_binary(module), do: module
  defp module_name(module), do: module |> to_string() |> module_name()
end
