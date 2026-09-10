defmodule Appsignal.Phoenix do
  @moduledoc """
  AppSignal's Phoenix instrumentation instruments calls to Phoenix applications
  to gain performance insights and error reporting.

  ## Installation

  To install `Appsignal.Phoenix` into your Phoenix application, `use
  Appsignal.Phoenix` in your application's endpoint module:

      defmodule AppsignalPhoenixExampleWeb.Endpoint do
        use Phoenix.Endpoint, otp_app: :appsignal_phoenix_example
        use Appsignal.Phoenix

        # ...
      end

  ## Only reporting requests that fail

  Set the `phoenix_errors_only` option to report a request only when it raises
  an exception. Requests that succeed are not reported at all, which reduces the
  number of samples this integration sends:

      config :appsignal, :config,
        otp_app: :my_app,
        name: "my_app",
        phoenix_errors_only: true

  Because a successful request is not reported, instrumentation inside it is not
  reported either: an `Appsignal.instrument/2` call, an Ecto query, or a function
  decorated with `transaction_event()`. Requests that raise are reported in full.

  The option does not apply to applications that `use Appsignal.Plug`, which
  report the request themselves, or to LiveView and channel events.

  """

  @deprecated "Since AppSignal for Phoenix 2.3.0, Phoenix instrumentation is up automatically. The `use Appsignal.Phoenix` line is no longer needed and should be removed from your app's endpoint file."
  defmacro __using__(_) do
  end
end
