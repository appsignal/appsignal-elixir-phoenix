---
bump: "patch"
---

Currently, a root span is created when a template is rendered outside of an existing root span. This produces a span that doesn't have any context that has a unique span name.

This patch makes sure `Appsignal.View` doesn't create root spans anymore, skipping any template renders that can't be added to any existing trace.
