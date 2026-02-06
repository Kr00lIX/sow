defmodule Sow.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring database access.
  """

  use ExUnit.CaseTemplate

  alias Sow.Test.Repo

  using do
    quote do
      alias Sow.Test.Repo
      import Sow.DataCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
