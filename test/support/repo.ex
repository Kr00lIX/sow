defmodule Sow.Test.Repo do
  use Ecto.Repo,
    otp_app: :sow,
    adapter: Ecto.Adapters.SQLite3
end
