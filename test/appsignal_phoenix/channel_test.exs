defmodule Appsignal.Phoenix.ChannelTest do
  use ExUnit.Case
  alias Appsignal.{Span, Test}

  setup do
    start_supervised!(Test.Tracer)
    start_supervised!(Test.Span)

    %{
      socket: %Phoenix.Socket{
        channel: PhoenixWeb.RoomChannel,
        endpoint: PhoenixWeb.Endpoint,
        handler: PhoenixWeb.UserSocket,
        ref: 2,
        topic: "room:lobby",
        transport: Elixir.Phoenix.Transports.WebSocket,
        id: 1
      }
    }
  end

  describe "instrument/4" do
    setup %{socket: socket} do
      %{return: PhoenixWeb.Channel.handle_in("new_msg", %{}, socket)}
    end

    test "calls the passed function, and returns its return", %{return: return} do
      assert {:noreply, %Phoenix.Socket{}} = return
    end

    test "creates a root span" do
      assert {:ok, [{_, nil}]} = Test.Tracer.get(:create_span)
    end

    test "sets the span's name" do
      assert {:ok, [{%Span{}, "PhoenixWeb.Channel#new_msg"}]} = Test.Span.get(:set_name)
    end

    test "sets the span's namespace" do
      assert {:ok, [{%Span{}, "channel"}]} = Test.Span.get(:set_namespace)
    end

    test "sets the span's environment" do
      assert_environment(%{
        "channel" => PhoenixWeb.RoomChannel,
        "endpoint" => PhoenixWeb.Endpoint,
        "handler" => PhoenixWeb.UserSocket,
        "id" => 1,
        "ref" => 2,
        "topic" => "room:lobby",
        "transport" => Phoenix.Transports.WebSocket
      })
    end

    test "closes the span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end
  end

  describe "instrument/5" do
    setup %{socket: socket} do
      %{return: PhoenixWeb.Channel.handle_in("new_msg", %{"body" => "Hello world!"}, socket)}
    end

    test "calls the passed function, and returns its return", %{return: return} do
      assert {:noreply, %Phoenix.Socket{}} = return
    end

    test "creates a root span" do
      assert {:ok, [{_, nil}]} = Test.Tracer.get(:create_span)
    end

    test "sets the span's name" do
      assert {:ok, [{%Span{}, "PhoenixWeb.Channel#new_msg"}]} = Test.Span.get(:set_name)
    end

    test "sets the span's namespace" do
      assert {:ok, [{%Span{}, "channel"}]} = Test.Span.get(:set_namespace)
    end

    test "sets the span's parameters" do
      assert_params(%{"body" => "Hello world!"})
    end

    test "sets the span's environment" do
      assert_environment(%{
        "channel" => PhoenixWeb.RoomChannel,
        "endpoint" => PhoenixWeb.Endpoint,
        "handler" => PhoenixWeb.UserSocket,
        "id" => 1,
        "ref" => 2,
        "topic" => "room:lobby",
        "transport" => Phoenix.Transports.WebSocket
      })
    end

    test "closes the span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end
  end

  describe "instrument/5, when filter_parameters is set" do
    setup %{socket: socket} do
      Application.put_env(:phoenix, :filter_parameters, {:keep, ["body"]})

      PhoenixWeb.Channel.handle_in(
        "new_msg",
        %{"body" => "Hello world!", "secret" => "hunter2"},
        socket
      )

      Application.delete_env(:phoenix, :filter_parameters)
    end

    test "filters the span's parameters" do
      assert_params(%{"body" => "Hello world!", "secret" => "[FILTERED]"})
    end
  end

  describe "instrument/5, when an error is raised" do
    setup %{socket: socket} do
      try do
        PhoenixWeb.Channel.handle_in("new_msg", %{"body" => "Exception!"}, socket)
      catch
        kind, reason -> %{kind: kind, reason: reason, stack: __STACKTRACE__}
      end
    end

    test "creates a root span" do
      assert {:ok, [{_, nil}]} = Test.Tracer.get(:create_span)
    end

    test "sets the span's name" do
      assert {:ok, [{%Span{}, "PhoenixWeb.Channel#new_msg"}]} = Test.Span.get(:set_name)
    end

    test "sets the span's namespace" do
      assert {:ok, [{%Span{}, "channel"}]} = Test.Span.get(:set_namespace)
    end

    test "sets the span's parameters" do
      assert_params(%{"body" => "Exception!"})
    end

    test "sets the span's environment" do
      assert_environment(%{
        "channel" => PhoenixWeb.RoomChannel,
        "endpoint" => PhoenixWeb.Endpoint,
        "handler" => PhoenixWeb.UserSocket,
        "id" => 1,
        "ref" => 2,
        "topic" => "room:lobby",
        "transport" => Phoenix.Transports.WebSocket
      })
    end

    test "reraises the error", %{kind: kind, reason: reason} do
      assert kind == :error
      assert %RuntimeError{} = reason
    end

    test "adds the error to the span", %{reason: reason, stack: stack} do
      assert {:ok, [{%Span{}, :error, ^reason, ^stack}]} = Test.Span.get(:add_error)
    end

    test "closes the span" do
      assert {:ok, [{%Span{}}]} = Test.Tracer.get(:close_span)
    end

    test "ignores the process in the registry" do
      assert :ets.lookup(:"$appsignal_registry", self()) == [{self(), :ignore}]
    end
  end

  describe "instrument/5, when an error is raised and filter_parameters is set" do
    setup %{socket: socket} do
      try do
        Application.put_env(:phoenix, :filter_parameters, {:keep, ["body"]})

        PhoenixWeb.Channel.handle_in(
          "new_msg",
          %{"body" => "Exception!", "secret" => "hunter2"},
          socket
        )
      catch
        _kind, _reason -> Application.delete_env(:phoenix, :filter_parameters)
      end
    end

    test "filters the span's parameters" do
      assert_params(%{"body" => "Exception!", "secret" => "[FILTERED]"})
    end
  end

  defp assert_environment(asserted_data) do
    {:ok, environment} = Test.Tracer.get(:set_environment)

    assert Enum.any?(environment, fn {data} ->
             data == asserted_data
           end)
  end

  defp assert_params(asserted_data) do
    {:ok, params} = Test.Tracer.get(:set_params)

    assert Enum.any?(params, fn {data} ->
             data == asserted_data
           end)
  end
end
