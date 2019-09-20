defmodule FileStore.Adapters.GCS.MixProject do
  use Mix.Project

  def project do
    [
      app: :file_store_gcs,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:goth, ">= 0.0.0"},
      {:httpoison, ">= 0.0.0"},
      {:file_store, path: "../file_store"}
    ]
  end
end
