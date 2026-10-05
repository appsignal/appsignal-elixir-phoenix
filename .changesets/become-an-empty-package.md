---
bump: major
type: change
---

Become an empty package that only depends on `appsignal` 3.x, which includes the Phoenix integration. Remove `appsignal_phoenix` from your application's dependencies and depend on `{:appsignal, "~> 3.0"}` instead. Phoenix requests and template rendering are still instrumented automatically, and `Appsignal.Phoenix.LiveView` and `Appsignal.Phoenix.Channel` keep working as they are.
