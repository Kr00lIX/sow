defmodule Sow.IntegrationTest do
  use Sow.DataCase

  alias Sow.Test.Schemas.{Country, Organization, Product, ProductVariant, Tag}

  # Simple fixtures for integration tests
  defmodule Fixtures do
    defmodule Countries do
      use Sow,
        schema: Country,
        keys: [:code]

      def records do
        [
          %{code: "NO", name: "Norway"},
          %{code: "SE", name: "Sweden"}
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
          %{name: "New", slug: "new"}
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

  describe "creating new records" do
    test "creates simple records" do
      {:ok, countries} = Fixtures.Countries.sync(Repo)

      assert length(countries) == 2
      assert Enum.find(countries, &(&1.code == "NO"))
      assert Enum.find(countries, &(&1.code == "SE"))

      # Verify in database
      assert Repo.aggregate(Country, :count) == 2
    end

    test "creates records with belongs_to relations" do
      {:ok, orgs} = Fixtures.Organizations.sync(Repo)

      assert length(orgs) == 1
      org = List.first(orgs)
      assert org.slug == "org-norway"
      assert org.country_id != nil

      # Verify country was created
      country = Repo.get!(Country, org.country_id)
      assert country.code == "NO"
    end

    test "creates records with has_many relations" do
      {:ok, [product]} = Fixtures.Products.sync(Repo)

      assert product.name == "Premium Subscription"

      # Verify variants were created
      variants = Repo.all(ProductVariant)
      assert length(variants) == 2
      assert Enum.all?(variants, &(&1.product_id == product.id))
    end

    test "creates records with many_to_many relations" do
      {:ok, [product]} = Fixtures.Products.sync(Repo)

      # Reload with tags preloaded
      product = Repo.preload(product, :tags)

      assert length(product.tags) == 2
      assert Enum.any?(product.tags, &(&1.slug == "featured"))
      assert Enum.any?(product.tags, &(&1.slug == "new"))
    end
  end

  describe "updating existing records" do
    test "updates existing record when keys match" do
      # First sync creates
      {:ok, countries1} = Fixtures.Countries.sync(Repo)
      norway = Enum.find(countries1, &(&1.code == "NO"))
      original_id = norway.id

      # Second sync should update, not create
      {:ok, countries2} = Fixtures.Countries.sync(Repo)
      norway2 = Enum.find(countries2, &(&1.code == "NO"))

      assert norway2.id == original_id
      assert Repo.aggregate(Country, :count) == 2
    end

    test "updates record with changed values" do
      # Create initial record
      {:ok, _} = Fixtures.Countries.sync(Repo)

      # Define fixture with updated name
      defmodule UpdatedCountries do
        use Sow, schema: Country, keys: [:code]

        def records do
          [%{code: "NO", name: "Kingdom of Norway"}]
        end
      end

      {:ok, [country]} = UpdatedCountries.sync(Repo)

      assert country.name == "Kingdom of Norway"
      assert Repo.aggregate(Country, :count) == 2
    end

    test "updates nested has_many records" do
      # Create initial product with variants
      {:ok, [product1]} = Fixtures.Products.sync(Repo)

      initial_variant_ids =
        Repo.all(ProductVariant)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      # Sync again
      {:ok, [product2]} = Fixtures.Products.sync(Repo)

      assert product1.id == product2.id

      # Variants should be updated, not duplicated
      current_variant_ids =
        Repo.all(ProductVariant)
        |> Enum.map(& &1.id)
        |> Enum.sort()

      assert initial_variant_ids == current_variant_ids
    end
  end

  describe "sync_all with dependency order" do
    test "syncs fixtures in correct dependency order" do
      # Sync all at once - should handle dependencies automatically
      # Note: ProductVariants is synced via has_many from Products, not directly
      {:ok, results} =
        Sow.sync_all(
          [
            Fixtures.Products,
            Fixtures.Countries,
            Fixtures.Organizations,
            Fixtures.Tags
          ],
          Repo
        )

      # All fixtures should be synced
      assert Map.has_key?(results, Fixtures.Countries)
      assert Map.has_key?(results, Fixtures.Organizations)
      assert Map.has_key?(results, Fixtures.Products)
      assert Map.has_key?(results, Fixtures.Tags)

      # Verify records exist
      assert Repo.aggregate(Country, :count) == 2
      assert Repo.aggregate(Organization, :count) == 1
      assert Repo.aggregate(Product, :count) == 1
      assert Repo.aggregate(Tag, :count) == 2
      # Variants are synced via has_many
      assert Repo.aggregate(ProductVariant, :count) == 2
    end
  end

  describe "using Sow.assoc (auto-detect)" do
    defmodule AutoDetectFixtures do
      defmodule Organizations do
        use Sow, schema: Organization, keys: [:slug]

        def records do
          [
            %{
              slug: "auto-org",
              name: "Auto Org",
              # Auto-detect belongs_to
              country: Sow.assoc(Fixtures.Countries, :code, "NO")
            }
          ]
        end
      end
    end

    test "auto-detects belongs_to from schema" do
      {:ok, [org]} = AutoDetectFixtures.Organizations.sync(Repo)

      assert org.slug == "auto-org"
      assert org.country_id != nil

      country = Repo.get!(Country, org.country_id)
      assert country.code == "NO"
    end
  end

  describe "has_many_inline (inline nested records)" do
    defmodule InlineFixtures do
      defmodule Products do
        use Sow, schema: Product, keys: [:organization_id, :type]

        def records do
          [
            %{
              type: "inline-test",
              name: "Inline Product",
              price: 5000,
              organization: Sow.belongs_to(Fixtures.Organizations, :slug, "org-norway"),
              variants:
                Sow.has_many_inline(
                  [
                    %{sku: "INLINE-S", name: "Inline Small"},
                    %{sku: "INLINE-L", name: "Inline Large"}
                  ],
                  schema: ProductVariant,
                  foreign_key: :product_id,
                  keys: [:product_id, :sku]
                )
            }
          ]
        end
      end
    end

    test "creates records with inline has_many" do
      {:ok, [product]} = InlineFixtures.Products.sync(Repo)

      assert product.name == "Inline Product"
      assert length(product.variants) == 2

      skus = Enum.map(product.variants, & &1.sku) |> Enum.sort()
      assert skus == ["INLINE-L", "INLINE-S"]
    end

    test "inline has_many is idempotent" do
      {:ok, _} = InlineFixtures.Products.sync(Repo)
      {:ok, _} = InlineFixtures.Products.sync(Repo)
      {:ok, [product]} = InlineFixtures.Products.sync(Repo)

      # Should still have 2 variants, not duplicated
      assert length(product.variants) == 2

      variants = Repo.all(ProductVariant) |> Enum.filter(&(&1.product_id == product.id))
      assert length(variants) == 2
    end
  end

  describe "Sow.lookup (runtime database lookup)" do
    test "looks up existing record by key/value" do
      # First, create countries
      {:ok, _} = Fixtures.Countries.sync(Repo)

      # Define fixture that uses lookup instead of belongs_to
      defmodule LookupFixtures.Organizations do
        use Sow, schema: Organization, keys: [:slug]

        def records do
          [
            %{
              slug: "lookup-org",
              name: "Lookup Org",
              # Use lookup instead of belongs_to - no syncing, just DB query
              country_id: Sow.lookup(Country, :code, "NO")
            }
          ]
        end
      end

      {:ok, [org]} = LookupFixtures.Organizations.sync(Repo)

      assert org.slug == "lookup-org"
      assert org.country_id != nil

      country = Repo.get!(Country, org.country_id)
      assert country.code == "NO"
    end

    test "lookup with custom field extraction" do
      {:ok, countries} = Fixtures.Countries.sync(Repo)
      norway = Enum.find(countries, &(&1.code == "NO"))

      defmodule LookupFieldFixture do
        use Sow, schema: Tag, keys: [:slug]

        def records do
          [
            %{
              slug: "lookup-field-test",
              # Get name field instead of id
              name: Sow.lookup(Country, :code, "NO", field: :name)
            }
          ]
        end
      end

      {:ok, [tag]} = LookupFieldFixture.sync(Repo)
      assert tag.name == "Norway"
    end

    test "returns error when lookup not found" do
      defmodule LookupNotFoundFixture do
        use Sow, schema: Organization, keys: [:slug]

        def records do
          [
            %{
              slug: "not-found-org",
              name: "Not Found Org",
              country_id: Sow.lookup(Country, :code, "NONEXISTENT")
            }
          ]
        end
      end

      assert {:error, {:lookup_not_found, Country, [code: "NONEXISTENT"]}} =
               LookupNotFoundFixture.sync(Repo)
    end

    test "chained lookups" do
      # Create countries and organizations first
      {:ok, _} = Fixtures.Countries.sync(Repo)
      {:ok, _} = Fixtures.Organizations.sync(Repo)

      defmodule ChainedLookupFixture do
        use Sow, schema: Product, keys: [:organization_id, :type]

        def records do
          [
            %{
              type: "chained-lookup",
              name: "Chained Lookup Product",
              price: 1000,
              # Chained lookup: first find country, then find org by country_id
              organization_id:
                Sow.lookup(Organization, %{
                  country_id: Sow.lookup(Country, :code, "NO"),
                  slug: "org-norway"
                })
            }
          ]
        end
      end

      {:ok, [product]} = ChainedLookupFixture.sync(Repo)

      assert product.name == "Chained Lookup Product"
      assert product.organization_id != nil

      org = Repo.get!(Organization, product.organization_id)
      assert org.slug == "org-norway"
    end
  end

  describe "idempotency" do
    test "syncing multiple times produces same result" do
      # Sync 3 times
      {:ok, _} = Fixtures.Products.sync(Repo)
      {:ok, _} = Fixtures.Products.sync(Repo)
      {:ok, products} = Fixtures.Products.sync(Repo)

      # Should still have only 1 product
      assert length(products) == 1
      assert Repo.aggregate(Product, :count) == 1
      assert Repo.aggregate(ProductVariant, :count) == 2
      assert Repo.aggregate(Country, :count) == 2
      assert Repo.aggregate(Organization, :count) == 1
      assert Repo.aggregate(Tag, :count) == 2
    end
  end

  describe "pruning (delete records not in fixtures)" do
    test "prune: true deletes records not defined in fixtures" do
      # Manually insert extra countries not in fixtures
      Repo.insert!(%Country{code: "FI", name: "Finland"})
      Repo.insert!(%Country{code: "DK", name: "Denmark"})

      assert Repo.aggregate(Country, :count) == 2

      # Sync with prune - should delete FI and DK, create NO and SE
      {:ok, synced, deleted} = Fixtures.Countries.sync(Repo, prune: true)

      # Synced countries
      assert length(synced) == 2
      assert Enum.any?(synced, &(&1.code == "NO"))
      assert Enum.any?(synced, &(&1.code == "SE"))

      # Deleted countries
      assert length(deleted) == 2
      assert Enum.any?(deleted, &(&1.code == "FI"))
      assert Enum.any?(deleted, &(&1.code == "DK"))

      # Only fixture countries remain
      assert Repo.aggregate(Country, :count) == 2
    end

    test "prune: true returns empty deleted list when all records match" do
      # First sync creates the fixtures
      {:ok, _} = Fixtures.Countries.sync(Repo)

      # Second sync with prune - nothing to delete
      {:ok, synced, deleted} = Fixtures.Countries.sync(Repo, prune: true)

      assert length(synced) == 2
      assert deleted == []
      assert Repo.aggregate(Country, :count) == 2
    end

    test "prune: false (default) does not delete extra records" do
      # Manually insert extra country
      Repo.insert!(%Country{code: "FI", name: "Finland"})

      # Sync without prune (default)
      {:ok, synced} = Fixtures.Countries.sync(Repo)

      # Should not return deleted tuple
      assert length(synced) == 2

      # All 3 countries should exist
      assert Repo.aggregate(Country, :count) == 3
    end

    test "prune works with fixture that defines subset of existing records" do
      # First sync all countries
      {:ok, _} = Fixtures.Countries.sync(Repo)
      assert Repo.aggregate(Country, :count) == 2

      # Define fixture with only one country
      defmodule SingleCountry do
        use Sow, schema: Country, keys: [:code]

        def records do
          [%{code: "NO", name: "Norway"}]
        end
      end

      # Sync with prune - should keep only Norway
      {:ok, synced, deleted} = SingleCountry.sync(Repo, prune: true)

      assert length(synced) == 1
      assert hd(synced).code == "NO"

      assert length(deleted) == 1
      assert hd(deleted).code == "SE"

      assert Repo.aggregate(Country, :count) == 1
    end

    test "prune handles empty fixture gracefully" do
      # Insert some countries
      Repo.insert!(%Country{code: "FI", name: "Finland"})
      Repo.insert!(%Country{code: "DK", name: "Denmark"})

      defmodule EmptyCountries do
        use Sow, schema: Country, keys: [:code]

        def records do
          []
        end
      end

      # Sync empty fixture with prune - should delete all
      {:ok, synced, deleted} = EmptyCountries.sync(Repo, prune: true)

      assert synced == []
      assert length(deleted) == 2
      assert Repo.aggregate(Country, :count) == 0
    end
  end
end
