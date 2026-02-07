# Runtime Lookups

While `belongs_to` syncs a fixture and uses the result, sometimes you need to reference data that already exists in the database without syncing it. That's where `Sow.lookup` comes in.

## Overview

| Feature | `belongs_to` | `lookup` |
|---------|--------------|----------|
| Syncs fixture | Yes | No |
| Queries database | After sync | Directly |
| Creates dependency | Yes | No |
| Use case | Fixture references | Existing data |

## Basic Usage

```elixir
defmodule MyApp.Seeds.Organizations do
  use Sow, schema: MyApp.Organization, keys: [:slug]

  def records do
    [
      %{
        slug: "acme-norway",
        name: "ACME Norway",
        # Query the database directly for country.id where code = "NO"
        country_id: Sow.lookup(MyApp.Country, :code, "NO")
      }
    ]
  end
end
```

## When to Use Lookup

### 1. Referencing Core Data

When your fixtures reference data managed elsewhere (migrations, admin UI, etc.):

```elixir
# Countries are managed in migrations, not fixtures
country_id: Sow.lookup(MyApp.Country, :code, "NO")
```

### 2. Cross-Module References

When fixtures in different modules reference each other without creating dependencies:

```elixir
# Don't want to sync Users fixture, just reference existing user
created_by_id: Sow.lookup(MyApp.User, :email, "admin@example.com")
```

### 3. Avoiding Circular Dependencies

When two fixtures would otherwise create a cycle:

```elixir
# Instead of belongs_to which would create dependency
parent_org_id: Sow.lookup(MyApp.Organization, :slug, "parent-corp")
```

## API Reference

### Simple Lookup

```elixir
# Returns :id field by default
Sow.lookup(schema, key, value)

# Example
country_id: Sow.lookup(MyApp.Country, :code, "NO")
# → Queries: SELECT id FROM countries WHERE code = 'NO'
```

### Custom Field

```elixir
# Return a different field
Sow.lookup(schema, key, value, field: :field_name)

# Example
country_name: Sow.lookup(MyApp.Country, :code, "NO", field: :name)
# → Queries: SELECT name FROM countries WHERE code = 'NO'
```

### Multiple Match Criteria

```elixir
# Match on multiple fields
Sow.lookup(schema, %{field1: value1, field2: value2})

# Example
org_id: Sow.lookup(MyApp.Organization, %{country_id: 1, type: "enterprise"})
# → Queries: SELECT id FROM organizations WHERE country_id = 1 AND type = 'enterprise'
```

### Chained Lookups

Lookups can be nested to resolve values in order:

```elixir
# First lookup country_id, then use it to find organization
org_id: Sow.lookup(MyApp.Organization, %{
  country_id: Sow.lookup(MyApp.Country, :code, "NO"),
  name: "ACME"
})
```

This resolves as:
1. Query countries for `id` where `code = "NO"` → returns `42`
2. Query organizations for `id` where `country_id = 42 AND name = "ACME"`

## Examples

### E-commerce Fixtures

```elixir
defmodule MyApp.Seeds.Orders do
  use Sow, schema: MyApp.Order, keys: [:reference]

  def records do
    [
      %{
        reference: "ORD-001",
        # Look up existing customer
        customer_id: Sow.lookup(MyApp.Customer, :email, "john@example.com"),
        # Look up product by SKU
        product_id: Sow.lookup(MyApp.Product, :sku, "WIDGET-PRO"),
        # Look up shipping zone
        shipping_zone_id: Sow.lookup(MyApp.ShippingZone, %{
          country_id: Sow.lookup(MyApp.Country, :code, "NO"),
          type: "standard"
        })
      }
    ]
  end
end
```

### Multi-tenant Fixtures

```elixir
defmodule MyApp.Seeds.TenantData do
  use Sow, schema: MyApp.Setting, keys: [:tenant_id, :key]

  def records do
    [
      %{
        tenant_id: Sow.lookup(MyApp.Tenant, :slug, "acme"),
        key: "theme",
        value: "dark"
      },
      %{
        tenant_id: Sow.lookup(MyApp.Tenant, :slug, "acme"),
        key: "timezone",
        value: "Europe/Oslo"
      }
    ]
  end
end
```

### Using Lookup with Inline Records

```elixir
defmodule MyApp.Seeds.Flows do
  use Sow, schema: MyApp.Flow, keys: [:slug]

  def records do
    [
      %{
        slug: "checkout",
        stages: Sow.has_many_inline(
          [
            %{
              position: 1,
              # Lookup stage that's managed elsewhere
              stage_id: Sow.lookup(MyApp.Stage, :type, "cart")
            },
            %{
              position: 2,
              stage_id: Sow.lookup(MyApp.Stage, :type, "payment")
            }
          ],
          schema: MyApp.FlowStage,
          foreign_key: :flow_id,
          keys: [:flow_id, :position]
        )
      }
    ]
  end
end
```

## Error Handling

If a lookup fails to find a record, Sow raises at sync time:

```elixir
** (Ecto.NoResultsError) expected at least one result but got none in query:

from c0 in MyApp.Country,
  where: c0.code == ^"XX"
```

Ensure the data exists before syncing fixtures that depend on it.

## Comparison with belongs_to

```elixir
# belongs_to: Syncs Countries fixture, then uses result
country: Sow.belongs_to(MyApp.Seeds.Countries, :code, "NO")

# lookup: Just queries database, no sync
country_id: Sow.lookup(MyApp.Country, :code, "NO")
```

Key differences:
- `belongs_to` creates a dependency in the sync graph
- `lookup` has no dependencies, queries at sync time
- `belongs_to` sets the association field (`:country`)
- `lookup` sets the foreign key field (`:country_id`)

## Next Steps

- Create [Wrapper Modules](wrapper-modules.html) to share lookup helpers
- Learn about [Associations](associations.html) for fixture-based references
