---
bump: patch
type: fix
---

Fix the response status of a reported exception always being `null`. A Phoenix
router emits its exception event before `Phoenix.Endpoint.RenderErrors` renders
and sends the response, so the conn carries no status yet, and both the
`response_status` in the sample's metadata and the `status` in its environment
were reported as `null`.

The status is now taken from the exception itself, as AppSignal for Plug already
does: the `:plug_status` the exception carries, such as 404 for
`Ecto.NoResultsError`, and 500 for an exception that carries none. Requests that
do not raise keep reporting the status of the response they sent.
