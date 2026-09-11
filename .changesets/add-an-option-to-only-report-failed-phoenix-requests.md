---
bump: minor
type: add
---

Add the `phoenix_errors_only` option. When it is enabled, a Phoenix request is
only reported when it raises an exception. Requests that succeed are not
reported at all, which reduces the number of samples the integration sends:

```elixir
config :appsignal, :config,
  otp_app: :my_app,
  name: "my_app",
  phoenix_errors_only: true
```

Because a successful request is not reported, instrumentation inside it is not
reported either: an `Appsignal.instrument/2` call, an Ecto query, or a function
decorated with `transaction_event()`. Requests that raise are reported in full,
with their duration, action name, parameters, environment and session data
unchanged.

The option does not apply to applications that `use Appsignal.Plug`, which
report the request themselves, or to LiveView and channel events.
