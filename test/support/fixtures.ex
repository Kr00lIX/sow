defmodule Sow.Test.Fixtures do
  @moduledoc """
  Test fixtures for Sow tests.
  """

  alias Sow.Test.Schemas.{Country, Organization, Product, ProductVariant, Tag}

  defmodule Countries do
    use Sow,
      schema: Country,
      keys: [:code]

    def records do
      [
        %{code: "NO", name: "Norway"},
        %{code: "SE", name: "Sweden"},
        %{code: "DK", name: "Denmark"}
      ]
    end
  end

  defmodule Organizations do
    use Sow,
      schema: Organization,
      keys: [:slug]

    def records do
      [
        %{
          slug: "org-norway",
          name: "Norwegian Org",
          country: Sow.belongs_to(Countries, :code, "NO")
        },
        %{
          slug: "org-sweden",
          name: "Swedish Org",
          country: Sow.belongs_to(Countries, :code, "SE")
        }
      ]
    end
  end

  defmodule Tags do
    use Sow,
      schema: Tag,
      keys: [:slug]

    def records do
      [
        %{name: "Featured", slug: "featured"},
        %{name: "New", slug: "new"},
        %{name: "Sale", slug: "sale"}
      ]
    end
  end

  defmodule ProductVariants do
    use Sow,
      schema: ProductVariant,
      keys: [:product_id, :sku]

    def records do
      [
        %{sku: "SMALL", name: "Small"},
        %{sku: "LARGE", name: "Large"}
      ]
    end
  end

  defmodule Products do
    use Sow,
      schema: Product,
      keys: [:organization_id, :type]

    def records do
      [
        %{
          type: "subscription",
          name: "Premium Subscription",
          price: 9900,
          organization: Sow.belongs_to(Organizations, :slug, "org-norway"),
          variants: Sow.has_many(ProductVariants, foreign_key: :product_id),
          tags: [
            Sow.many_to_many(Tags, :slug, "featured"),
            Sow.many_to_many(Tags, :slug, "new")
          ]
        }
      ]
    end
  end
end
