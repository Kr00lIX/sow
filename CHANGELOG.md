# Changelog

All notable changes to this project will be documented in this file.

## [0.1.2] - 2025-02-08

### Added

- **`Sow.Wrapper`** - Create custom wrapper modules with shared helpers
  ```elixir
  defmodule MyApp.Seeds do
    use Sow.Wrapper
    def country_id(code), do: Repo.get_by!(Country, code: code).id
  end
  ```

- **Configurable callback name** - Use `callback: :seed_data` option instead of default `:records`

- **Comprehensive hexdocs documentation**
  - Getting Started guide
  - Associations guide (belongs_to, has_many, has_many_inline, many_to_many)
  - Runtime Lookups guide
  - Wrapper Modules guide

## [0.1.1] - 2025-02-07

### Added

- **`Sow.lookup/2,3,4`** - Runtime database lookups for foreign keys
  - Simple key/value lookup: `Sow.lookup(Country, :code, "NO")`
  - Custom field extraction: `Sow.lookup(Country, :code, "NO", field: :name)`
  - Multi-criteria lookup: `Sow.lookup(Organization, %{country_id: 1, name: "ACME"})`
  - Chained/nested lookups for complex queries

- **`Sow.has_many_inline/2`** - Inline nested records without separate fixture module
  ```elixir
  variants: Sow.has_many_inline(
    [%{sku: "SMALL"}, %{sku: "LARGE"}],
    schema: ProductVariant,
    foreign_key: :product_id,
    keys: [:product_id, :sku]
  )
  ```

- **Automatic primary key detection** - `keys` now defaults to schema's primary key
- **Ecto struct support** - `records/0` can return Ecto structs (auto-converted to maps)
- **Primary key handling** - Sets PK directly on struct before changeset (fixes insert issues)

### Changed

- Hex publication configuration added (package, docs, LICENSE)

## [0.1.0] - 2025-02-07

### Added

- Initial release
- `use Sow` macro for defining fixture modules
- `Sow.belongs_to/1,3` for belongs_to associations
- `Sow.has_many/2` for has_many associations
- `Sow.many_to_many/1,3` for many_to_many associations
- `Sow.assoc/1,3` for auto-detecting association type
- `Sow.sync_all/2` for syncing multiple fixtures in dependency order
- Pruning support with `prune: true` option
- Dependency graph with topological sorting
