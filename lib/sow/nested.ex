defmodule Sow.Nested do
  @moduledoc """
  Represents nested fixtures that are synced after the parent.

  The parent's ID is injected into each nested record via the foreign_key.

  ## With a fixture module

      defmodule MyApp.Seeds.Product do
        use Sow, schema: MyApp.Product, keys: [:slug]

        def records do
          %{
            slug: "premium",
            variants: Sow.has_many(MyApp.Seeds.ProductVariant, foreign_key: :product_id)
          }
        end
      end

  ## With inline records

      def records do
        %{
          slug: "premium",
          variants: Sow.has_many_inline(
            [
              %{sku: "SMALL", name: "Small"},
              %{sku: "LARGE", name: "Large"}
            ],
            schema: MyApp.ProductVariant,
            foreign_key: :product_id,
            keys: [:product_id, :sku]
          )
        }
      end

  During sync:
  1. Parent record is inserted/updated first
  2. Each nested record gets `product_id: parent.id` injected
  3. Nested records are then synced
  """

  @type t :: %__MODULE__{
          module: module() | nil,
          records: [map()] | nil,
          schema: module() | nil,
          foreign_key: atom(),
          keys: [atom()] | nil
        }

  defstruct [:module, :records, :schema, :foreign_key, :keys]
end
