# Associations

Sow provides several functions for handling Ecto associations in your fixtures. This guide covers all association types and when to use each.

## Overview

| Function | Use Case | Sync Order |
|----------|----------|------------|
| `belongs_to/3` | Foreign key references | Dependency first |
| `has_many/2` | Children via fixture module | Children after parent |
| `has_many_inline/2` | Children defined inline | Children after parent |
| `many_to_many/3` | Join table associations | Related records first |
| `assoc/3` | Auto-detect from schema | Depends on type |

## belongs_to

Use `belongs_to` when a record references another via a foreign key.

### Basic Usage

```elixir
defmodule MyApp.Seeds.Organizations do
  use Sow, schema: MyApp.Organization, keys: [:slug]

  def records do
    [
      %{
        slug: "acme-corp",
        name: "ACME Corporation",
        country: Sow.belongs_to(MyApp.Seeds.Countries, :code, "NO")
      }
    ]
  end
end
```

### How It Works

1. Sow syncs `Countries` fixture first
2. Finds the country where `code = "NO"`
3. Sets `country_id` on the organization record

### Without Lookup

To use the first record from a fixture:

```elixir
country: Sow.belongs_to(MyApp.Seeds.Countries)
```

## has_many

Use `has_many` when children are defined in a separate fixture module.

### Basic Usage

```elixir
# Parent fixture
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        slug: "premium-widget",
        variants: Sow.has_many(MyApp.Seeds.ProductVariants, foreign_key: :product_id)
      }
    ]
  end
end

# Child fixture
defmodule MyApp.Seeds.ProductVariants do
  use Sow, schema: MyApp.ProductVariant, keys: [:product_id, :sku]

  def records do
    [
      %{sku: "SM", name: "Small", price: 1000},
      %{sku: "MD", name: "Medium", price: 1500},
      %{sku: "LG", name: "Large", price: 2000}
    ]
  end
end
```

### How It Works

1. Sow syncs the parent product
2. Gets the parent's ID
3. Syncs each variant with `product_id` set to the parent's ID

### Custom Keys for Children

```elixir
variants: Sow.has_many(MyApp.Seeds.ProductVariants,
  foreign_key: :product_id,
  keys: [:product_id, :sku]  # Override child's default keys
)
```

## has_many_inline

Use `has_many_inline` when you want to define children directly in the parent fixture without creating a separate module.

### Basic Usage

```elixir
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        slug: "premium-widget",
        variants: Sow.has_many_inline(
          [
            %{sku: "SM", name: "Small", price: 1000},
            %{sku: "MD", name: "Medium", price: 1500},
            %{sku: "LG", name: "Large", price: 2000}
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

### Options

| Option | Required | Description |
|--------|----------|-------------|
| `schema` | Yes | Ecto schema for child records |
| `foreign_key` | Yes | Field to inject parent's ID |
| `keys` | No | Search keys for upsert (defaults to schema's primary key) |

### With Nested Relations

Inline records can contain their own associations:

```elixir
defmodule MyApp.Seeds.Flows do
  use Sow, schema: MyApp.Flow, keys: [:slug]

  def records do
    [
      %{
        slug: "onboarding",
        stages: Sow.has_many_inline(
          [
            %{
              position: 1,
              stage: Sow.belongs_to(MyApp.Seeds.Stages, :type, :welcome)
            },
            %{
              position: 2,
              stage: Sow.belongs_to(MyApp.Seeds.Stages, :type, :profile)
            },
            %{
              position: 3,
              stage: Sow.belongs_to(MyApp.Seeds.Stages, :type, :complete)
            }
          ],
          schema: MyApp.FlowStage,
          foreign_key: :flow_id,
          keys: [:flow_id, :stage_id]
        )
      }
    ]
  end
end
```

### When to Use has_many vs has_many_inline

| Use `has_many` when... | Use `has_many_inline` when... |
|------------------------|-------------------------------|
| Children are reused across parents | Children are unique to each parent |
| Children have their own complex logic | Children are simple data |
| You want separate fixture modules | You want everything in one place |

## many_to_many

Use `many_to_many` for join table associations.

### Basic Usage

```elixir
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]

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
end
```

### Required Changeset Setup

Your schema's changeset must handle the association with `put_assoc`:

```elixir
defmodule MyApp.Product do
  use Ecto.Schema
  import Ecto.Changeset

  schema "products" do
    field :slug, :string
    many_to_many :tags, MyApp.Tag, join_through: "product_tags"
  end

  def changeset(product, attrs) do
    product
    |> cast(attrs, [:slug])
    |> maybe_put_assoc(:tags, attrs)
  end

  defp maybe_put_assoc(changeset, key, attrs) do
    case Map.get(attrs, key) do
      nil -> changeset
      assoc -> put_assoc(changeset, key, assoc)
    end
  end
end
```

### How It Works

1. Sow syncs the Tags fixture first
2. Finds tags matching the lookups
3. Passes the tag structs to `put_assoc` in the changeset

## assoc (Auto-detect)

Use `assoc` to let Sow automatically detect the association type from your schema.

### Basic Usage

```elixir
%{
  # Detected as belongs_to from schema
  country: Sow.assoc(MyApp.Seeds.Countries, :code, "NO"),

  # Detected as many_to_many from schema
  tags: [
    Sow.assoc(MyApp.Seeds.Tags, :slug, "featured")
  ],

  # Detected as has_many from schema
  variants: Sow.assoc(MyApp.Seeds.ProductVariants)
}
```

### When to Use

`assoc` is convenient when:
- You want concise code
- Your schema accurately defines all associations
- You're okay with slightly less explicit code

Prefer explicit functions (`belongs_to`, `has_many`, etc.) when:
- You want self-documenting code
- The association type might be ambiguous
- You're training team members on the codebase

## Dependency Resolution

Sow automatically determines the correct sync order based on associations:

```elixir
# These can be in any order
{:ok, _} = Sow.sync_all([
  MyApp.Seeds.Products,       # Depends on Organizations, Tags
  MyApp.Seeds.Countries,      # No dependencies
  MyApp.Seeds.Organizations,  # Depends on Countries
  MyApp.Seeds.Tags            # No dependencies
], MyApp.Repo)

# Sow syncs in order: Countries → Tags → Organizations → Products
```

### Cycle Detection

Sow detects circular dependencies and returns an error:

```elixir
{:error, {:cycle, [ModuleA, ModuleB]}}
```

## Next Steps

- Learn about [Runtime Lookups](runtime-lookups.html) for querying existing data
- Create [Wrapper Modules](wrapper-modules.html) to share helpers
