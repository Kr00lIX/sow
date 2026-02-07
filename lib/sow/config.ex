defmodule Sow.Config do
  @moduledoc """
  Configuration struct for a fixture module.
  """

  @type t :: %__MODULE__{
          schema: module(),
          keys: [atom()],
          module: module(),
          callback: atom()
        }

  defstruct [:schema, :keys, :module, callback: :records]
end
