defmodule Appsignal.Phoenix.LiveView do
  @moduledoc """
  Instruments Phoenix live views and live components.

  ## Usage

  To automatically instrument a module with `Phoenix.LiveView` or `Phoenix.LiveComponent` callbacks,
  add `use Appsignal.Phoenix.LiveView` to the module:

      defmodule AppsignalPhoenixExampleWeb.ExampleLive do
        use Appsignal.Phoenix.LiveView

        def mount(params, session, socket) do
          # ...
        end
      end

  This will instrument many of the common callbacks used by these modules:

    * `Phoenix.LiveView.mount/3`
    * `Phoenix.LiveView.handle_event/3`
    * `Phoenix.LiveView.handle_params/3`
    * `Phoenix.LiveComponent.mount/1`
    * `Phoenix.LiveComponent.update/2`

  Alternatively, you can manually instrument functions in a live view or component using
  `instrument/4`:

      defmodule AppsignalPhoenixExampleWeb.ClockLive do
        use Phoenix.LiveView
        import Appsignal.Phoenix.LiveView, only: [instrument: 4]

        def render(assigns) do
          AppsignalPhoenixExampleWeb.ClockView.render("index.html", assigns)
        end

        def mount(_params, _session, socket) do
          # Wrap the contents of the mount/2 function with a call to
          # Appsignal.Phoenix.LiveView.instrument/4

          instrument(__MODULE__, "mount", socket, fn ->
            :timer.send_interval(1000, self(), :tick)
            {:ok, assign(socket, state: Time.utc_now())}
          end)
        end

        def handle_info(:tick, socket) do
          # Wrap the contents of the handle_info/2 function with a call to
          # Appsignal.Phoenix.LiveView.instrument/4:

          instrument(__MODULE__, "tick", socket, fn ->
            {:ok, assign(socket, state: Time.utc_now())}
          end)
        end
      end

  """
  @tracer Application.get_env(:appsignal, :appsignal_tracer, Appsignal.Tracer)
  @span Application.get_env(:appsignal, :appsignal_span, Appsignal.Span)

  @doc false
  defmacro __using__(_) do
    quote do
      use Appsignal.Phoenix.LiveView.AutoInstrument
      @decorate_all instrument()
    end
  end

  @doc false
  def instrument(module, name, socket, fun) do
    instrument(module, name, %{}, socket, fun)
  end

  def instrument(module, name, params, socket, fun) do
    environment = if socket, do: Appsignal.Metadata.metadata(socket), else: %{}

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
              |> @span.set_sample_data("environment", environment)
              |> @span.add_error(kind, reason, stack)
              |> @tracer.close_span()

            @tracer.ignore()
            :erlang.raise(kind, reason, stack)
        else
          result ->
            _ =
              span
              |> @span.set_sample_data("params", params)
              |> @span.set_sample_data("environment", environment)

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
end
