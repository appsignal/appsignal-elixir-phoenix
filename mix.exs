defmodule Appsignal.Phoenix.MixProject do
  use Mix.Project

  def project do
    [
      app: :appsignal_phoenix,
      version: "2.8.2",
      description:
        "An empty package. AppSignal's Phoenix instrumentation is part of the appsignal package since version 3.0.0.",
      package: %{
        maintainers: ["Jeff Kreeftmeijer"],
        licenses: ["MIT"],
        links: %{"GitHub" => "https://github.com/appsignal/appsignal-elixir-phoenix"}
      },
      elixir: "~> 1.12",
      deps: deps()
    ]
  end

  def application do
    []
  end

  defp deps do
    [
      {:appsignal, "~> 3.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end
end
