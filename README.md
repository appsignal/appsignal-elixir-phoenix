# appsignal_phoenix

Since AppSignal for Elixir 3.0, the Phoenix integration is part of the
[`appsignal`](https://github.com/appsignal/appsignal-elixir) package. This
package is empty, and only depends on `appsignal` 3.x.

Remove `appsignal_phoenix` from your dependencies and depend on `appsignal`
instead:

``` elixir
defp deps do
  [
    {:appsignal, "~> 3.0"}
  ]
end
```

Then run:

``` shell
mix deps.unlock appsignal_phoenix appsignal_plug
mix deps.get
```

Phoenix requests and template rendering are still instrumented automatically,
and `Appsignal.Phoenix.LiveView.attach/0`, `Appsignal.Phoenix.LiveView` and
`Appsignal.Phoenix.Channel` keep working as they are. See the [upgrade
guide](https://docs.appsignal.com/elixir/installation/upgrade-from-2-to-3)
and the [Phoenix integration
documentation](https://docs.appsignal.com/elixir/integrations/phoenix.html).

The source of `appsignal_phoenix` 2.x is on the
[`2.x-latest`](https://github.com/appsignal/appsignal-elixir-phoenix/tree/2.x-latest)
branch.
