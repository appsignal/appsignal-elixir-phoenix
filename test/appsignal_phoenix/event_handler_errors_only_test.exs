defmodule Appsignal.Phoenix.EventHandlerErrorsOnlyTest do
  # Tests the event handler with the `phoenix_errors_only` option enabled, where
  # a request is only reported when it fails. A successful request still opens
  # its spans, but its root span is never closed, so the trace is never sent.
  use ExUnit.Case
  alias Appsignal.{Span, Test, Tracer}

  setup do
    start_supervised!(Test.Tracer)
    start_supervised!(Test.Span)

    config = Application.get_env(:appsignal, :config)

    Application.put_env(
      :appsignal,
      :config,
      Enum.into(config, %{phoenix_errors_only: true})
    )

    on_exit(fn -> Application.put_env(:appsignal, :config, config) end)

    :ok
  end

  describe "after a successful request" do
    setup do
      endpoint_start()
      router_dispatch_start()
      render_start()
      render_stop()
      endpoint_stop()
      router_dispatch_stop()
    end

    test "opens the endpoint and the router dispatch span" do
      assert {:ok, [{"http_request", %Span{}}, {"http_request", nil}]} =
               Test.Tracer.get(:create_span)
    end

    test "does not open a render span" do
      {:ok, calls} = Test.Tracer.get(:create_span)

      assert length(calls) == 2
    end

    test "does not close any span" do
      assert :error == Test.Tracer.get(:close_span)
    end

    test "does not describe the root span" do
      assert :error == Test.Span.get(:set_sample_data_if_nil)
      assert :error == Test.Span.get(:set_sample_data)
      assert :error == Test.Span.get(:set_name_if_nil)
    end

    test "leaves no spans behind" do
      assert [] == Tracer.lookup(self())
    end
  end

  describe "after a successful request that is halted before it reaches the router" do
    setup do
      endpoint_start()
      endpoint_stop()
    end

    test "does not close any span" do
      assert :error == Test.Tracer.get(:close_span)
    end

    test "leaves no spans behind" do
      assert [] == Tracer.lookup(self())
    end
  end

  describe "after a successful request without an endpoint" do
    # A Plug application that forwards to a Phoenix router emits the router
    # dispatch events without the endpoint ones.
    setup do
      router_dispatch_start()
      router_dispatch_stop()
    end

    test "does not close any span" do
      assert :error == Test.Tracer.get(:close_span)
    end

    test "leaves no spans behind" do
      assert [] == Tracer.lookup(self())
    end
  end

  describe "after a successful request through a forwarded router" do
    # `Phoenix.Router.forward` re-enters the router, so the router dispatch
    # events nest. Only the outermost dispatch stop discards the request.
    test "discards the request when the outermost dispatch is done" do
      endpoint_start()
      router_dispatch_start()
      router_dispatch_start()
      endpoint_stop()

      router_dispatch_stop()
      assert [_ | _] = Tracer.lookup(self())

      router_dispatch_stop()
      assert [] == Tracer.lookup(self())

      assert :error == Test.Tracer.get(:close_span)
    end
  end

  describe "after a successful request, then another in the same process" do
    # Bandit serves every keep-alive request on a connection from one process.
    setup do
      endpoint_start()
      router_dispatch_start()
      endpoint_stop()
      router_dispatch_stop()

      endpoint_start()
    end

    test "opens a root span for the second request" do
      # `Appsignal.Test.Tracer` records calls with the most recent one first.
      assert {:ok, [{"http_request", nil} | _]} = Test.Tracer.get(:create_span)
    end
  end

  describe "after a request that raises" do
    setup do
      endpoint_start()
      router_dispatch_start()
      router_dispatch_exception()
    end

    test "sets the root span's name" do
      assert {:ok, [{%Span{}, "AppsignalPhoenixExampleWeb.PageController#index"}]} =
               Test.Span.get(:set_name_if_nil)
    end

    test "sets the root span's error" do
      assert {:ok, [{%Span{}, :error, %RuntimeError{}, []}]} = Test.Span.get(:add_error)
    end

    test "sets the root span's sample data" do
      {:ok, calls} = Test.Span.get(:set_sample_data_if_nil)

      assert [{%Span{}, "params", %{"foo" => "bar"}}] =
               Enum.filter(calls, fn {_span, key, _value} -> key == "params" end)
    end

    test "closes the root span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end

    test "ignores the process" do
      assert [{_pid, :ignore}] = Tracer.lookup(self())
    end
  end

  describe "after a request that raises once its response was sent" do
    # The endpoint stop event fires from a `register_before_send` callback, so it
    # arrives before the router dispatch is done. It must not discard the spans
    # of a request that can still fail.
    setup do
      endpoint_start()
      router_dispatch_start()
      endpoint_stop()
      router_dispatch_exception()
    end

    test "sets the root span's error" do
      assert {:ok, [{%Span{}, :error, %RuntimeError{}, []}]} = Test.Span.get(:add_error)
    end

    test "closes the root span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end
  end

  describe "after a request that raises without an endpoint" do
    setup do
      router_dispatch_start()
      router_dispatch_exception()
    end

    test "sets the root span's error" do
      assert {:ok, [{%Span{}, :error, %RuntimeError{}, []}]} = Test.Span.get(:add_error)
    end

    test "closes the root span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end
  end

  describe "after a successful request whose root span was opened elsewhere" do
    # The shape of an application that uses `Appsignal.Plug`, which opens the
    # root span itself and reports the request either way. Discarding the spans
    # this handler opens would only leave that trace incomplete.
    setup do
      root_span = Tracer.create_span("http_request")

      endpoint_start()
      router_dispatch_start()
      render_start()
      render_stop()
      endpoint_stop()
      router_dispatch_stop()

      [root_span: root_span]
    end

    test "closes the spans it opened" do
      {:ok, calls} = Test.Tracer.get(:close_span)

      assert length(calls) == 3
    end

    test "describes the root span" do
      {:ok, calls} = Test.Span.get(:set_sample_data_if_nil)

      assert [{%Span{}, "params", %{"foo" => "bar"}}] =
               Enum.filter(calls, fn {_span, key, _value} -> key == "params" end)
    end

    test "leaves the root span in the registry", %{root_span: root_span} do
      assert [{_pid, ^root_span}] = Tracer.lookup(self())
    end
  end

  defp endpoint_start do
    :telemetry.execute(
      [:phoenix, :endpoint, :start],
      %{system_time: -576_460_736_044_040_000},
      %{conn: %Plug.Conn{private: %{phoenix_endpoint: PhoenixWeb.Endpoint}}, options: []}
    )
  end

  defp endpoint_stop do
    :telemetry.execute(
      [:phoenix, :endpoint, :stop],
      %{duration: 49_474_000},
      %{conn: conn(), options: []}
    )
  end

  defp router_dispatch_start do
    :telemetry.execute(
      [:phoenix, :router_dispatch, :start],
      %{system_time: -576_460_736_044_040_000},
      %{
        conn: %Plug.Conn{private: %{phoenix_endpoint: PhoenixWeb.Endpoint}},
        plug: AppsignalPhoenixExampleWeb.PageController,
        plug_opts: :index,
        route: "/",
        path_params: %{},
        pipe_through: [:browser],
        log: :info
      }
    )
  end

  defp router_dispatch_stop do
    :telemetry.execute(
      [:phoenix, :router_dispatch, :stop],
      %{duration: 49_474_000},
      %{
        conn: conn(),
        plug: AppsignalPhoenixExampleWeb.PageController,
        plug_opts: :index,
        route: "/foo/:bar",
        path_params: %{},
        pipe_through: [:browser],
        log: :info
      }
    )
  end

  defp router_dispatch_exception do
    :telemetry.execute(
      [:phoenix, :router_dispatch, :exception],
      %{duration: 49_474_000},
      %{conn: conn(), reason: %RuntimeError{}, stacktrace: [], options: []}
    )
  end

  defp render_start do
    :telemetry.execute(
      [:phoenix, :controller, :render, :start],
      %{system_time: -576_460_736_044_040_000},
      %{view: PhoenixWeb.View, template: "template", format: "html"}
    )
  end

  defp render_stop do
    :telemetry.execute([:phoenix, :controller, :render, :stop], %{duration: 49_474_000}, %{})
  end

  defp conn do
    %Plug.Conn{
      params: %{"foo" => "bar"},
      private: %{
        phoenix_action: :index,
        phoenix_controller: AppsignalPhoenixExampleWeb.PageController
      },
      port: 80,
      request_path: "/",
      status: 200
    }
  end
end
