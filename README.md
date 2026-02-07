# Sow 🌱

**Plant your data, watch it grow.**

Sow is an Elixir library for seeding databases with code-defined fixtures. Define your data as Elixir maps, and Sow handles planting (inserting), cultivating (updating), and pruning (deleting) records to keep your database in sync.

## Features

- **Declarative seeds** - Define records as maps in code
- **Smart upserts** - Creates or updates based on search keys
- **Relationship handling** - Supports `belongs_to`, `has_many`, and `many_to_many`
- **Inline nested records** - Define children inline with `has_many_inline`
- **Runtime lookups** - Query existing database records with `Sow.lookup`
- **Automatic ordering** - Resolves dependencies and syncs in correct order
- **Pruning** - Optionally remove records not in your fixtures
- **Wrapper modules** - Share helpers across fixtures with custom wrappers

## Installation

```elixir
def deps do
  [{:sow, "~> 0.1.0"}]
end
```

```elixir
# config/config.exs (optional)
config :sow, repo: MyApp.Repo
```

## Quick Start

```elixir
defmodule MyApp.Seeds.Countries do
  use Sow, schema: MyApp.Country, keys: [:code]

  def records do
    [
      %{code: "NO", name: "Norway"},
      %{code: "SE", name: "Sweden"}
    ]
  end
end

# Sow your seeds
{:ok, countries} = MyApp.Seeds.Countries.sync(MyApp.Repo)
```

## Configuration Options

```elixir
use Sow,
  schema: MyApp.Country,       # Required: Ecto schema module
  keys: [:code],               # Optional: search keys for upsert (defaults to primary key)
  callback: :records           # Optional: callback function name (defaults to :records)
```

### Custom Callback Names

Use a different callback name when needed:

```elixir
defmodule MyApp.Seeds.Countries do
  use Sow, schema: MyApp.Country, keys: [:code], callback: :seed_data

  def seed_data do
    [%{code: "NO", name: "Norway"}]
  end
end
```

## Associations

### belongs_to

Seeds the dependency first, then sets the foreign key.

```elixir
defmodule MyApp.Seeds.Organizations do
  use Sow, schema: MyApp.Organization, keys: [:slug]

  def records do
    [
      %{
        slug: "acme-norway",
        name: "ACME Norway",
        country: Sow.belongs_to(MyApp.Seeds.Countries, :code, "NO")
      }
    ]
  end
end
```

### has_many

Seeds children after the parent using a separate fixture module.

```elixir
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        slug: "premium-widget",
        name: "Premium Widget",
        variants: Sow.has_many(MyApp.Seeds.ProductVariants, foreign_key: :product_id)
      }
    ]
  end
end
```

### has_many_inline

Define nested records inline without a separate fixture module:

```elixir
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        slug: "premium-widget",
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
    ]
  end
end
```

Inline records can contain relations too:

```elixir
flow_stages: Sow.has_many_inline(
  [
    %{position: 1, stage: Sow.belongs_to(StageFixture, :type, :intro)},
    %{position: 2, stage: Sow.belongs_to(StageFixture, :type, :payment)}
  ],
  schema: MyApp.FlowStage,
  foreign_key: :flow_id,
  keys: [:flow_id, :stage_id]
)
```

### many_to_many

Seeds related records first, then associates them via `put_assoc`.

```elixir
def records do
  [
    %{
      slug: "premium-widget",
      tags: [
        Sow.many_to_many(MyApp.Seeds.Tags, :slug, "featured"),
        Sow.many_to_many(MyApp.Seeds.Tags, :slug, "new")
      ]
    }
  ]
end
```

Your schema's changeset must handle many_to_many with `put_assoc`:

```elixir
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
```

### Auto-detect with `Sow.assoc`

Let Sow detect the association type from your Ecto schema:

```elixir
%{
  organization: Sow.assoc(Organizations, :slug, "acme"),  # detects belongs_to
  tags: [Sow.assoc(Tags, :slug, "featured")],             # detects many_to_many
  variants: Sow.assoc(ProductVariants)                    # detects has_many
}
```

## Runtime Lookups

Use `Sow.lookup` to query existing database records instead of syncing fixtures:

```elixir
defmodule MyApp.Seeds.Organizations do
  use Sow, schema: MyApp.Organization, keys: [:slug]

  def records do
    [
      %{
        slug: "acme-norway",
        # Get country.id where code = "NO"
        country_id: Sow.lookup(MyApp.Country, :code, "NO")
      }
    ]
  end
end
```

### Lookup Options

```elixir
# Simple lookup - returns :id by default
country_id: Sow.lookup(MyApp.Country, :code, "NO")

# Custom field extraction
country_name: Sow.lookup(MyApp.Country, :code, "NO", field: :name)

# Multiple match criteria
org_id: Sow.lookup(MyApp.Organization, %{country_id: 1, name: "ACME"})

# Chained lookups
org_id: Sow.lookup(MyApp.Organization, %{
  country_id: Sow.lookup(MyApp.Country, :code, "NO"),
  name: "ACME"
})
```

## Wrapper Modules

Create wrapper modules to share helpers across fixtures:

```elixir
defmodule MyApp.Seeds do
  use Sow.Wrapper

  # Default options for all fixtures
  def __sow_defaults__ do
    [callback: :seed_data]
  end

  # Shared helpers
  def country_id(code), do: MyApp.Repo.get_by!(MyApp.Country, code: code).id
  def image_url(path), do: "https://cdn.example.com/#{path}"
end
```

Use your wrapper instead of `Sow` directly:

```elixir
defmodule MyApp.Seeds.Products do
  use MyApp.Seeds, schema: MyApp.Product, keys: [:slug]

  def seed_data do
    [
      %{
        slug: "widget",
        image: image_url("widget.png"),  # helper from wrapper
        country_id: country_id("NO")     # helper from wrapper
      }
    ]
  end
end
```

## Pruning

Remove records that aren't in your fixtures:

```elixir
# Default: only create/update
{:ok, seeded} = Countries.sync(Repo)

# With pruning: also delete stale records
{:ok, seeded, pruned} = Countries.sync(Repo, prune: true)
```

## Seeding Multiple Fixtures

Sow automatically resolves dependencies and seeds in the correct order:

```elixir
{:ok, results} = Sow.sync_all([
  MyApp.Seeds.Products,       # depends on Organizations, Tags
  MyApp.Seeds.Countries,      # no dependencies
  MyApp.Seeds.Organizations,  # depends on Countries
  MyApp.Seeds.Tags            # no dependencies
], MyApp.Repo)

# Sow sorts: Countries → Tags → Organizations → Products
```

## Using Ecto Structs

You can return Ecto structs from `records/0` instead of maps:

```elixir
def records do
  [
    %MyApp.Country{id: 1, code: "NO", name: "Norway"},
    %MyApp.Country{id: 2, code: "SE", name: "Sweden"}
  ]
end
```

Sow automatically converts structs to maps for processing.

## How It Works

1. **Search Keys** - `keys: [:field]` identifies unique records for upsert
2. **Upsert** - Find by keys → update if exists, insert if not
3. **Dependencies** - `belongs_to`/`many_to_many` sync first; `has_many` syncs after
4. **Pruning** - With `prune: true`, deletes records not in fixtures

## Documentation

Full documentation is available at [HexDocs](https://hexdocs.pm/sow).

## License

MIT - see [LICENSE](LICENSE) for details.
