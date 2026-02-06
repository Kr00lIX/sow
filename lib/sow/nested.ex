defmodule Sow.Nested do
  @moduledoc """
  Represents nested fixtures that are synced after the parent.

  The parent's ID is injected into each nested record via the foreign_key.

  ## Examples

      defmodule MyApp.Fixtures.Product do
        use Sow, schema: MyApp.Product, keys: [:slug]

        def records do
          %{
            slug: "premium",
            variants: Sow.has_many(MyApp.Fixtures.ProductVariant, foreign_key: :product_id)
          }
        end
      end

  During sync:
  1. Parent record is inserted/updated first
  2. Each nested fixture record gets `product_id: parent.id` injected
  3. Nested records are then synced
  """

  @type t :: %__MODULE__{
          module: module(),
          foreign_key: atom(),
          keys: [atom()] | nil
        }

  defstruct [:module, :foreign_key, :keys]
end
