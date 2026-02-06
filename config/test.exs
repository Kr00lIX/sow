import Config

config :sow, Sow.Test.Repo,
  database: "priv/repo/test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :sow,
  ecto_repos: [Sow.Test.Repo],
  repo: Sow.Test.Repo
