{:ok, _} = Sow.Test.Repo.start_link()

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Sow.Test.Repo, :manual)
