defmodule Appsignal.Phoenix.LiveView.AutoInstrument do
  @moduledoc false
  use Decorator.Define, instrument: 0

  # Provides instrumentation for common `Phoenix.LiveView` and `Phoenix.LiveComponent` callbacks.
  #
  # To use, call:
  #
  #   use Appsignal.Phoenix.LiveView.AutoInstrument
  #   @decorate_all instrument()
  #
  def instrument(body, context)

  #
  # Phoenix.LiveView
  #

  # mount(params, session, socket) when params :: :not_mounted_at_router
  def instrument(body, %{module: module, name: :mount, args: [:not_mounted_at_router, _, socket]}) do
    do_instrument(module, :mount, %{}, socket, body)
  end

  # mount(params, session, socket) when params :: map
  def instrument(body, %{module: module, name: :mount, args: [params, _session, socket]}) do
    do_instrument(module, :mount, params, socket, body)
  end

  # handle_event(event, unsigned_params, socket)
  def instrument(body, %{module: module, name: :handle_event, args: [event, params, socket]}) do
    do_instrument(module, "event:#{event}", params, socket, body)
  end

  # handle_params(unsigned_params, uri, socket)
  def instrument(body, %{module: module, name: :handle_params, args: [params, _uri, socket]}) do
    do_instrument(module, :params, params, socket, body)
  end

  # TODO: Provide implementation of Appsignal.Metadata for `nil` when socket is unavailable.
  # render(assigns)
  # def instrument(body, %{module: module, name: :render, args: [_assigns]}) do
  #   do_instrument(module, :render, %{}, nil, body)
  # end

  #
  # Phoenix.LiveComponent
  #

  # mount(socket)
  def instrument(body, %{module: module, name: :mount, args: [socket]}) do
    do_instrument(module, :mount, %{}, socket, body)
  end

  # TODO: Provide implementation of Appsignal.Metadata for `nil` when socket is unavailable.
  # preload(assigns)
  # def instrument(body, %{module: module, name: :preload, args: [_assigns]}) do
  #   do_instrument(module, :preload, %{}, nil, body)
  # end

  # update(assigns, socket)
  def instrument(body, %{module: module, name: :upload, args: [_assigns, socket]}) do
    do_instrument(module, :upload, %{}, socket, body)
  end

  #
  # Fallback
  #

  # For non-callback functions, take no action.
  def instrument(body, _), do: body

  defp do_instrument(module, name, params, socket, body) do
    # credo:disable-for-lines:2 Credo.Check.Design.AliasUsage
    quote do
      Appsignal.Phoenix.LiveView.instrument(
        unquote(module),
        unquote(name),
        unquote(Macro.escape(params)),
        unquote(socket),
        fn -> unquote(body) end
      )
    end
  end
end
