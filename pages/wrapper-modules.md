# Wrapper Modules

Wrapper modules let you create a custom base for your fixtures, sharing default options and helper functions across all fixtures in your application.

## Overview

Instead of using `Sow` directly:

```elixir
defmodule MyApp.Seeds.Products do
  use Sow, schema: MyApp.Product, keys: [:slug]
  # ...
end
```

You create a wrapper and use that:

```elixir
defmodule MyApp.Seeds.Products do
  use MyApp.Seeds, schema: MyApp.Product, keys: [:slug]
  # Has access to shared helpers!
end
```

## Creating a Wrapper

### Basic Wrapper

```elixir
defmodule MyApp.Seeds do
  use Sow.Wrapper
end
```

### With Default Options

Set defaults that apply to all fixtures using this wrapper:

```elixir
defmodule MyApp.Seeds do
  use Sow.Wrapper

  def __sow_defaults__ do
    [callback: :seed_data]  # All fixtures use :seed_data instead of :records
  end
end
```

### With Helper Functions

Define functions that are available in all fixtures:

```elixir
defmodule MyApp.Seeds do
  use Sow.Wrapper

  # Lookup helpers
  def country_id(code) do
    MyApp.Repo.get_by!(MyApp.Country, code: code).id
  end

  def user_id(email) do
    MyApp.Repo.get_by!(MyApp.User, email: email).id
  end

  # Formatting helpers
  def image_url(path) do
    "https://cdn.example.com/#{path}"
  end

  def slug(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
  end
end
```

## Using the Wrapper

```elixir
defmodule MyApp.Seeds.Products do
  use MyApp.Seeds, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        name: "Premium Widget",
        slug: slug("Premium Widget"),           # Helper from wrapper
        image: image_url("products/widget.png"), # Helper from wrapper
        created_by_id: user_id("admin@example.com") # Helper from wrapper
      }
    ]
  end
end
```

## Complete Example

### The Wrapper Module

```elixir
defmodule MyApp.Seeds do
  @moduledoc """
  Base module for all seed fixtures.

  Use this instead of `Sow` directly to get access to
  shared helpers and default configuration.

  ## Usage

      defmodule MyApp.Seeds.Countries do
        use MyApp.Seeds, schema: MyApp.Country, keys: [:code]

        def records do
          [%{code: "NO", name: "Norway"}]
        end
      end
  """
  use Sow.Wrapper

  alias MyApp.Repo

  @doc """
  Default options for all fixtures.
  """
  def __sow_defaults__ do
    []
  end

  # ─────────────────────────────────────────────────────
  # Lookup Helpers
  # ─────────────────────────────────────────────────────

  @doc """
  Get a country's ID by its code.
  """
  def country_id(code) do
    Repo.get_by!(MyApp.Country, code: code).id
  end

  @doc """
  Get an organization's ID by its slug.
  """
  def org_id(slug) do
    Repo.get_by!(MyApp.Organization, slug: slug).id
  end

  @doc """
  Get a user's ID by their email.
  """
  def user_id(email) do
    Repo.get_by!(MyApp.User, email: email).id
  end

  # ─────────────────────────────────────────────────────
  # Formatting Helpers
  # ─────────────────────────────────────────────────────

  @doc """
  Generate a URL-safe slug from a name.
  """
  def slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  @doc """
  Generate a CDN URL for an asset.
  """
  def cdn_url(path) do
    base = Application.get_env(:my_app, :cdn_url, "https://cdn.example.com")
    "#{base}/#{path}"
  end

  @doc """
  Generate a placeholder image URL.
  """
  def placeholder_image(width, height) do
    "https://via.placeholder.com/#{width}x#{height}"
  end

  # ─────────────────────────────────────────────────────
  # Data Helpers
  # ─────────────────────────────────────────────────────

  @doc """
  Get current UTC datetime for timestamps.
  """
  def now do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  @doc """
  Generate a price in cents from a decimal amount.
  """
  def cents(amount) when is_float(amount) do
    round(amount * 100)
  end

  def cents(amount) when is_integer(amount) do
    amount * 100
  end
end
```

### Using the Wrapper in Fixtures

```elixir
defmodule MyApp.Seeds.Products do
  use MyApp.Seeds, schema: MyApp.Product, keys: [:slug]

  def records do
    [
      %{
        name: "Basic Widget",
        slug: slugify("Basic Widget"),
        price: cents(29.99),
        image: cdn_url("products/basic-widget.png"),
        organization_id: org_id("acme"),
        created_by_id: user_id("admin@example.com"),
        created_at: now()
      },
      %{
        name: "Premium Widget",
        slug: slugify("Premium Widget"),
        price: cents(99.99),
        image: cdn_url("products/premium-widget.png"),
        organization_id: org_id("acme"),
        created_by_id: user_id("admin@example.com"),
        created_at: now()
      }
    ]
  end
end
```

## Multiple Wrappers

You can create different wrappers for different contexts:

```elixir
# For production seed data
defmodule MyApp.Seeds do
  use Sow.Wrapper
  # Production helpers...
end

# For test fixtures
defmodule MyApp.TestFixtures do
  use Sow.Wrapper

  def __sow_defaults__ do
    [callback: :fixtures]
  end

  # Test-specific helpers...
  def random_email do
    "user-#{:rand.uniform(100_000)}@test.example.com"
  end
end
```

## Option Precedence

Options specified in the fixture override wrapper defaults:

```elixir
defmodule MyApp.Seeds do
  use Sow.Wrapper

  def __sow_defaults__ do
    [callback: :seed_data]
  end
end

# Uses :seed_data callback from wrapper defaults
defmodule MyApp.Seeds.Countries do
  use MyApp.Seeds, schema: MyApp.Country, keys: [:code]

  def seed_data do
    [%{code: "NO", name: "Norway"}]
  end
end

# Overrides with :records callback
defmodule MyApp.Seeds.SpecialData do
  use MyApp.Seeds, schema: MyApp.Special, keys: [:id], callback: :records

  def records do
    [%{id: 1, name: "Special"}]
  end
end
```

## Best Practices

### 1. Keep Helpers Focused

Each helper should do one thing:

```elixir
# Good: Single purpose
def country_id(code), do: Repo.get_by!(Country, code: code).id
def country_name(code), do: Repo.get_by!(Country, code: code).name

# Avoid: Too generic
def get_field(schema, where, field), do: ...
```

### 2. Document Your Helpers

```elixir
@doc """
Get a country's ID by its ISO code.

## Examples

    country_id("NO")  # => 42
"""
def country_id(code), do: ...
```

### 3. Handle Errors Gracefully

```elixir
def country_id(code) do
  case Repo.get_by(Country, code: code) do
    nil -> raise "Country not found: #{code}"
    country -> country.id
  end
end
```

### 4. Organize by Category

Group helpers logically:

```elixir
# Lookups
def country_id(code), do: ...
def org_id(slug), do: ...

# Formatting
def slugify(name), do: ...
def cdn_url(path), do: ...

# Data generation
def now, do: ...
def cents(amount), do: ...
```

## Next Steps

- Review [Getting Started](getting-started.html) for basic setup
- Learn about [Associations](associations.html) for relationships
- Explore [Runtime Lookups](runtime-lookups.html) for database queries
