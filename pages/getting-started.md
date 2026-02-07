# Getting Started

This guide will walk you through setting up Sow in your Elixir application and creating your first fixture.

## Installation

Add `sow` to your dependencies in `mix.exs`:

```elixir
def deps do
  [{:sow, "~> 0.1.0"}]
end
```

Run `mix deps.get` to fetch the dependency.

## Configuration

Optionally configure a default repo to avoid passing it to every `sync/2` call:

```elixir
# config/config.exs
config :sow, repo: MyApp.Repo
```

## Your First Fixture

A fixture is a module that defines records to be synced to the database. Let's create a simple countries fixture.

### 1. Define the Schema

First, ensure you have an Ecto schema:

```elixir
defmodule MyApp.Country do
  use Ecto.Schema

  schema "countries" do
    field :code, :string
    field :name, :string
    timestamps()
  end

  def changeset(country, attrs) do
    country
    |> Ecto.Changeset.cast(attrs, [:code, :name])
    |> Ecto.Changeset.validate_required([:code, :name])
  end
end
```

### 2. Create the Fixture Module

```elixir
defmodule MyApp.Seeds.Countries do
  use Sow,
    schema: MyApp.Country,
    keys: [:code]

  def records do
    [
      %{code: "NO", name: "Norway"},
      %{code: "SE", name: "Sweden"},
      %{code: "DK", name: "Denmark"},
      %{code: "FI", name: "Finland"}
    ]
  end
end
```

### 3. Sync to Database

```elixir
# In your seeds.exs or any script
{:ok, countries} = MyApp.Seeds.Countries.sync(MyApp.Repo)

# Or if you configured a default repo
{:ok, countries} = MyApp.Seeds.Countries.sync()
```

## Understanding Keys

The `keys` option tells Sow how to identify records for upsert:

```elixir
use Sow, schema: MyApp.Country, keys: [:code]
```

When syncing:
- Sow looks for existing records where `code` matches
- If found: updates the record
- If not found: inserts a new record

### Composite Keys

Use multiple keys for composite uniqueness:

```elixir
use Sow, schema: MyApp.ProductVariant, keys: [:product_id, :sku]
```

### Default Keys

If you omit `keys`, Sow uses the schema's primary key:

```elixir
# Uses [:id] as keys
use Sow, schema: MyApp.Country
```

## Organizing Fixtures

A common pattern is to organize fixtures in a `Seeds` namespace:

```
lib/my_app/seeds/
├── countries.ex
├── organizations.ex
├── products.ex
└── tags.ex
```

## Running Seeds

### Development Seeds

Create a `priv/repo/seeds.exs` file:

```elixir
alias MyApp.Seeds.{Countries, Organizations, Products}

# Sync all fixtures in dependency order
{:ok, _} = Sow.sync_all([
  Countries,
  Organizations,
  Products
], MyApp.Repo)

IO.puts("Seeds planted successfully!")
```

Run with:

```bash
mix run priv/repo/seeds.exs
```

### In Migrations

You can also sync fixtures in migrations for required data:

```elixir
defmodule MyApp.Repo.Migrations.SeedCountries do
  use Ecto.Migration

  def up do
    {:ok, _} = MyApp.Seeds.Countries.sync(MyApp.Repo)
  end

  def down do
    # Optional: remove seeded data
  end
end
```

## What's Next?

- Learn about [Associations](associations.html) for handling relationships
- Explore [Runtime Lookups](runtime-lookups.html) for querying existing data
- Create [Wrapper Modules](wrapper-modules.html) to share helpers
