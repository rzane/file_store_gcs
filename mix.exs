defmodule FileStore.Adapters.GCS.MixProject do
  use Mix.Project

  def project do
    [
      app: :file_store_gcs,
      version: "0.1.0",
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [extra_applications: [:logger]]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:goth, "~> 1.3-rc"},
      {:hackney, "~> 1.17"},
      {:google_api_storage, "~> 0.33"},
      {:file_store, path: "../file_store"},
      {:gcs_signed_url, "~> 0.4"}
    ]
  end
end
