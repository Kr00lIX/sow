# Sow 🌱

**Plant your data, watch it grow.**

Sow is an Elixir library for seeding databases with code-defined fixtures. Define your data as Elixir maps, and Sow handles planting (inserting), cultivating (updating), and pruning (deleting) records to keep your database in sync.

## Features

- **Declarative seeds** - Define records as maps in code
- **Smart upserts** - Creates or updates based on search keys
- **Relationship handling** - Supports `belongs_to`, `has_many`, and `many_to_many`
- **Automatic ordering** - Resolves dependencies and syncs in correct order
- **Pruning** - Optionally remove records not in your fixtures

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

Seeds children after the parent, injecting the parent's ID.

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

### Auto-detect with `Sow.assoc`

Let Sow detect the association type from your Ecto schema:

```elixir
%{
  organization: Sow.assoc(Organizations, :slug, "acme"),  # detects belongs_to
  tags: [Sow.assoc(Tags, :slug, "featured")]              # detects many_to_many
}
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

## How It Works

1. **Search Keys** - `keys: [:field]` identifies unique records for upsert
2. **Upsert** - Find by keys → update if exists, insert if not
3. **Dependencies** - `belongs_to`/`many_to_many` sync first; `has_many` syncs after
4. **Pruning** - With `prune: true`, deletes records not in fixtures

## License

MIT
