defmodule Sow.Test.Schemas do
  @moduledoc """
  Test schemas for Sow tests.
  """

  defmodule Country do
    use Ecto.Schema
    import Ecto.Changeset

    schema "countries" do
      field(:code, :string)
      field(:name, :string)
    end

    def changeset(country, attrs) do
      country
      |> cast(attrs, [:code, :name])
      |> validate_required([:code, :name])
    end
  end

  defmodule Organization do
    use Ecto.Schema
    import Ecto.Changeset

    schema "organizations" do
      field(:slug, :string)
      field(:name, :string)
      field(:country_id, :integer)

      belongs_to(:country, Sow.Test.Schemas.Country, define_field: false)
    end

    def changeset(org, attrs) do
      org
      |> cast(attrs, [:slug, :name, :country_id])
      |> validate_required([:slug, :name])
    end
  end

  defmodule Tag do
    use Ecto.Schema
    import Ecto.Changeset

    schema "tags" do
      field(:name, :string)
      field(:slug, :string)

      many_to_many(:products, Sow.Test.Schemas.Product, join_through: "products_tags")
    end

    def changeset(tag, attrs) do
      tag
      |> cast(attrs, [:name, :slug])
      |> validate_required([:name, :slug])
    end
  end

  defmodule Product do
    use Ecto.Schema
    import Ecto.Changeset

    schema "products" do
      field(:type, :string)
      field(:name, :string)
      field(:price, :integer)
      field(:organization_id, :integer)

      belongs_to(:organization, Sow.Test.Schemas.Organization, define_field: false)
      has_many(:variants, Sow.Test.Schemas.ProductVariant)
      many_to_many(:tags, Sow.Test.Schemas.Tag, join_through: "products_tags")
    end

    def changeset(product, attrs) do
      product
      |> cast(attrs, [:type, :name, :price, :organization_id])
      |> validate_required([:type, :name])
      |> maybe_put_assoc(:tags, attrs)
    end

    defp maybe_put_assoc(changeset, key, attrs) do
      case Map.get(attrs, key) do
        nil -> changeset
        assoc -> put_assoc(changeset, key, assoc)
      end
    end
  end

  defmodule ProductVariant do
    use Ecto.Schema
    import Ecto.Changeset

    schema "product_variants" do
      field(:sku, :string)
      field(:name, :string)
      field(:product_id, :integer)

      belongs_to(:product, Sow.Test.Schemas.Product, define_field: false)
    end

    def changeset(variant, attrs) do
      variant
      |> cast(attrs, [:sku, :name, :product_id])
      |> validate_required([:sku, :name, :product_id])
    end
  end
end
