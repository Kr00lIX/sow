defmodule Sow do
  @moduledoc """
  A library for synchronizing code-defined fixtures with a database.

  ## Usage

      defmodule MyApp.Fixtures.Countries do
        use Sow,
          schema: MyApp.Country,
          keys: [:code]

        def records do
          [
            %{code: "NO", name: "Norway"},
            %{code: "SE", name: "Sweden"}
          ]
        end
      end

  ## belongs_to (sync dependency first)

      defmodule MyApp.Fixtures.Organizations do
        use Sow,
          schema: MyApp.Organization,
          keys: [:slug]

        def records do
          [
            %{
              slug: "org-norway",
              country: Sow.belongs_to(MyApp.Fixtures.Countries, :code, "NO")
            }
          ]
        end
      end

  ## has_many (sync children after parent)

      defmodule MyApp.Fixtures.Products do
        use Sow,
          schema: MyApp.Product,
          keys: [:org_id, :type]

        def records do
          %{
            type: :subscription,
            variants: Sow.has_many(MyApp.Fixtures.ProductVariants, foreign_key: :product_id)
          }
        end
      end

  ## many_to_many

  For many_to_many, the related records are synced first, then passed to `put_assoc`:

      defmodule MyApp.Fixtures.Products do
        use Sow,
          schema: MyApp.Product,
          keys: [:slug]

        def records do
          %{
            slug: "premium",
            tags: [
              Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "featured"),
              Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "new")
            ]
          }
        end
      end

  ## Auto-detect with assoc (shorthand)

  Use `Sow.assoc/1-3` to auto-detect the association type from the Ecto schema:

      defmodule MyApp.Fixtures.Products do
        use Sow,
          schema: MyApp.Product,
          keys: [:slug]

        def records do
          %{
            slug: "premium",
            # Auto-detects belongs_to from schema
            organization: Sow.assoc(MyApp.Fixtures.Organizations, :slug, "org"),
            # Auto-detects many_to_many from schema
            tags: [
              Sow.assoc(MyApp.Fixtures.Tags, :slug, "featured")
            ],
            # Auto-detects has_many from schema
            variants: Sow.assoc(MyApp.Fixtures.ProductVariants)
          }
        end
      end

  Note: Your schema's changeset must handle many_to_many with `put_assoc`:

      def changeset(product, attrs) do
        product
        |> cast(attrs, [:slug, :name])
        |> maybe_put_assoc(:tags, attrs)
      end

      defp maybe_put_assoc(changeset, key, attrs) do
        case Map.get(attrs, key) do
          nil -> changeset
          assoc -> put_assoc(changeset, key, assoc)
        end
      end
  """

  @type keys :: [atom()]
  @type record :: map()

  @doc """
  Returns the fixture records to sync.
  Can return a single map or a list of maps.

  The callback name can be customized with the `:callback` option:

      use Sow, schema: MyApp.Country, keys: [:code], callback: :modify
      def modify, do: [...]
  """
  @callback records() :: record() | [record()]

  defmacro __using__(opts) do
    callback = Keyword.get(opts, :callback, :records)

    quote do
      @behaviour Sow

      @sow_schema unquote(opts[:schema])
      @sow_keys unquote(opts[:keys]) || @sow_schema.__schema__(:primary_key)
      @sow_callback unquote(callback)

      @doc false
      def __sow_config__ do
        %Sow.Config{
          schema: @sow_schema,
          keys: @sow_keys,
          module: __MODULE__,
          callback: @sow_callback
        }
      end

      @doc """
      Sync this fixture's records to the database.

      ## Options

        * `:prune` - if `true`, deletes records in the database that are not
          defined in the fixture. Defaults to `false`.

      ## Examples

          # Sync without pruning (default)
          Countries.sync(Repo)

          # Sync and delete records not in fixtures
          Countries.sync(Repo, prune: true)
      """
      def sync(repo \\ Sow.default_repo(), opts \\ []) do
        Sow.Sync.sync(__MODULE__, repo, opts)
      end
    end
  end

  @doc """
  Marks a belongs_to association. The referenced fixture is synced first,
  and its ID is assigned to `{field_name}_id`.

  ## Examples

      # Sync the Countries fixture, use the first record's ID
      %{country: Sow.belongs_to(MyApp.Fixtures.Countries)}

      # Sync Countries fixture, find by code "NO", use that record's ID
      %{country: Sow.belongs_to(MyApp.Fixtures.Countries, :code, "NO")}
  """
  def belongs_to(fixture_module) do
    %Sow.Relation{module: fixture_module}
  end

  def belongs_to(fixture_module, lookup_key, lookup_value) do
    %Sow.Relation{module: fixture_module, lookup: {lookup_key, lookup_value}}
  end

  @doc """
  Marks a has_many association. Children are synced after the parent,
  with the parent's ID injected via the foreign_key.

  ## Examples

      %{
        variants: Sow.has_many(MyApp.Fixtures.ProductVariants, foreign_key: :product_id)
      }
  """
  def has_many(fixture_module, opts) do
    %Sow.Nested{
      module: fixture_module,
      foreign_key: Keyword.fetch!(opts, :foreign_key),
      keys: Keyword.get(opts, :keys)
    }
  end

  @doc """
  Marks a has_many association with inline records (no separate fixture module needed).

  Children are synced after the parent, with the parent's ID injected via the foreign_key.

  ## Options

    * `:schema` - (required) the Ecto schema module for the nested records
    * `:foreign_key` - (required) the foreign key field to inject parent's ID
    * `:keys` - (optional) search keys for upsert, defaults to schema's primary key

  ## Examples

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

  Records can also contain relations:

      flow_stages: Sow.has_many_inline(
        [
          %{position: 1, stage: Sow.belongs_to(StageFixture, :type, :select_client)},
          %{position: 2, stage: Sow.belongs_to(StageFixture, :type, :payment)}
        ],
        schema: MyApp.FlowStage,
        foreign_key: :flow_id,
        keys: [:flow_id, :stage_id]
      )
  """
  def has_many_inline(records, opts) when is_list(records) do
    %Sow.Nested{
      records: records,
      schema: Keyword.fetch!(opts, :schema),
      foreign_key: Keyword.fetch!(opts, :foreign_key),
      keys: Keyword.get(opts, :keys)
    }
  end

  @doc """
  Marks a many_to_many association. The referenced fixture is synced first,
  and the model is passed to `put_assoc` in the changeset.

  Use as a list for multiple associations:

      %{
        tags: [
          Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "featured"),
          Sow.many_to_many(MyApp.Fixtures.Tags, :slug, "new")
        ]
      }
  """
  def many_to_many(fixture_module) do
    %Sow.Relation{module: fixture_module, assoc: true}
  end

  def many_to_many(fixture_module, lookup_key, lookup_value) do
    %Sow.Relation{module: fixture_module, lookup: {lookup_key, lookup_value}, assoc: true}
  end

  @doc """
  Auto-detect association type from the Ecto schema.

  This is a shorthand that inspects the schema to determine whether the field
  is belongs_to, has_many, or many_to_many, and handles it appropriately.

  ## Examples

      # Auto-detect and sync
      %{country: Sow.assoc(MyApp.Fixtures.Countries)}

      # With lookup
      %{country: Sow.assoc(MyApp.Fixtures.Countries, :code, "NO")}

      # Works for all association types
      %{
        organization: Sow.assoc(Organizations, :slug, "org"),  # belongs_to
        tags: [Sow.assoc(Tags, :slug, "featured")],            # many_to_many
        variants: Sow.assoc(ProductVariants)                   # has_many
      }
  """
  def assoc(fixture_module) do
    %Sow.Relation{module: fixture_module, auto: true}
  end

  def assoc(fixture_module, lookup_key, lookup_value) do
    %Sow.Relation{module: fixture_module, lookup: {lookup_key, lookup_value}, auto: true}
  end

  @doc """
  Runtime database lookup to get a field value from an existing record.

  Unlike `belongs_to` which syncs a fixture, `lookup` queries the database
  directly for an existing record and extracts a field (default: `:id`).

  ## Examples

      # Simple lookup - get country.id where code = "NO"
      country_id: Sow.lookup(MyApp.Country, :code, "NO")

      # With custom field extraction
      country_name: Sow.lookup(MyApp.Country, :code, "NO", field: :name)

      # Multiple match criteria
      org_id: Sow.lookup(MyApp.Organization, %{country_id: 1, name: "ACME"})

      # Chained lookups - resolve country_id first, then find organization
      org_id: Sow.lookup(MyApp.Organization, %{
        country_id: Sow.lookup(MyApp.Country, :code, "NO"),
        name: "ACME"
      })
  """
  # lookup/2 - map match without opts
  def lookup(schema, match) when is_map(match) do
    %Sow.Lookup{schema: schema, match: match, field: :id}
  end

  # lookup/3 - key/value without opts, or map match with opts
  def lookup(schema, key, value) when is_atom(key) do
    %Sow.Lookup{schema: schema, match: {key, value}, field: :id}
  end

  def lookup(schema, match, opts) when is_map(match) and is_list(opts) do
    %Sow.Lookup{schema: schema, match: match, field: Keyword.get(opts, :field, :id)}
  end

  # lookup/4 - key/value with opts
  def lookup(schema, key, value, opts) when is_atom(key) and is_list(opts) do
    %Sow.Lookup{schema: schema, match: {key, value}, field: Keyword.get(opts, :field, :id)}
  end

  @doc """
  Returns the default repo configured in application env.
  """
  def default_repo do
    Application.get_env(:sow, :repo) ||
      raise "No default repo configured. Set config :sow, :repo, MyApp.Repo"
  end

  @doc """
  Sync multiple fixture modules in dependency order.
  """
  def sync_all(modules, repo \\ default_repo()) do
    Sow.Graph.sync_in_order(modules, repo)
  end
end
