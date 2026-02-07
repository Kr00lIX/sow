defmodule Sow.MixProject do
  use Mix.Project

  @version "0.1.0"
  @github_url "https://github.com/Kr00lIX/sow"

  def project do
    [
      app: :sow,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),

      # Hex
      description: "Sow your data seeds - synchronize code-defined fixtures with your database",
      package: package(),

      # Docs
      name: "Sow",
      source_url: @github_url,
      homepage_url: @github_url,
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto, "~> 3.12"},

      # Test
      {:ecto_sql, "~> 3.12", only: :test},
      {:ecto_sqlite3, "~> 0.17", only: :test},

      # Documentation
      {:ex_doc, "~> 0.35", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extras: ["README.md"],
      source_url: @github_url
    ]
  end

  defp package do
    [
      name: "sow",
      licenses: ["MIT"],
      links: %{"GitHub" => @github_url},
      files: ~w(.formatter.exs mix.exs README.md lib LICENSE)
    ]
  end

  defp aliases do
    [
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
