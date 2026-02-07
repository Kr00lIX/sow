defmodule Sow.Lookup do
  @moduledoc """
  Represents a runtime database lookup to get a field value from an existing record.

  Unlike `belongs_to` which syncs a fixture module, `lookup` queries the database
  directly for an existing record.

  ## Simple lookup by key/value

      # Get country.id where code = "NO"
      country_id: Sow.lookup(MyApp.Country, :code, "NO")

  ## Lookup with custom field extraction

      # Get country.name instead of country.id
      country_name: Sow.lookup(MyApp.Country, :code, "NO", field: :name)

  ## Lookup with multiple match criteria

      # Get organization.id where country_id and name match
      org_id: Sow.lookup(MyApp.Organization, %{country_id: 1, name: "ACME"})

  ## Chained lookups

      # Nested lookup - resolve country_id first, then find organization
      org_id: Sow.lookup(MyApp.Organization, %{
        country_id: Sow.lookup(MyApp.Country, :code, "NO"),
        name: "ACME"
      })
  """

  @type match :: {atom(), any()} | map()

  @type t :: %__MODULE__{
          schema: module(),
          match: match(),
          field: atom()
        }

  defstruct [:schema, :match, field: :id]
end
