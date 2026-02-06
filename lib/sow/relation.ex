defmodule Sow.Relation do
  @moduledoc """
  Represents a relation to another fixture that must be synced before the parent.

  Used for `belongs_to`, `many_to_many`, and auto-detected associations.

  ## belongs_to

  The referenced fixture is synced first, and the record's ID is set as `{field}_id`:

      %{country: Sow.belongs_to(MyApp.Fixtures.Countries, :code, "NO")}

  ## many_to_many

  The referenced fixture is synced first, and the model is passed to `put_assoc`:

      %{tags: [
        Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "featured"),
        Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "new")
      ]}

  ## Auto-detect with assoc

  When `auto: true`, the association type is detected from the Ecto schema:

      %{country: Sow.assoc(MyApp.Fixtures.Countries, :code, "NO")}
  """

  @type t :: %__MODULE__{
          module: module(),
          lookup: {atom(), any()} | nil,
          assoc: boolean(),
          auto: boolean()
        }

  defstruct [:module, :lookup, assoc: false, auto: false]
end
