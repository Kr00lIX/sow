defmodule Sow.Wrapper do
  @moduledoc """
  Create custom wrapper modules with shared helpers for fixtures.

  ## Defining a Wrapper

      defmodule MyApp.Fixtures do
        use Sow.Wrapper

        # Default options for all fixtures using this wrapper
        # Can be overridden by individual fixtures
        def __sow_defaults__, do: []

        # Custom helpers available in all fixtures
        def org_id(slug), do: MyApp.Repo.get_by!(MyApp.Org, slug: slug).id
        def image_url(path), do: "https://cdn.example.com/\#{path}"
      end

  ## Using the Wrapper

      defmodule MyApp.Fixtures.Products do
        use MyApp.Fixtures, schema: MyApp.Product, keys: [:slug]

        def records do
          [
            %{
              slug: "widget",
              org_id: org_id("acme"),           # helper from wrapper
              image: image_url("widget.png")     # helper from wrapper
            }
          ]
        end
      end

  ## With Default Options

      defmodule MyApp.Fixtures do
        use Sow.Wrapper

        # Set defaults for all fixtures
        def __sow_defaults__ do
          [callback: :seed_data]
        end
      end

      defmodule MyApp.Fixtures.Countries do
        use MyApp.Fixtures, schema: MyApp.Country, keys: [:code]

        # Uses :seed_data callback by default
        def seed_data do
          [%{code: "NO", name: "Norway"}]
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      defmacro __using__(opts) do
        wrapper = __MODULE__

        # Get defaults at compile time (wrapper is already compiled)
        defaults =
          if function_exported?(wrapper, :__sow_defaults__, 0) do
            wrapper.__sow_defaults__()
          else
            []
          end

        # Merge opts with defaults (opts take precedence)
        merged_opts = Keyword.merge(defaults, opts)

        quote do
          # Use Sow with merged options
          use Sow, unquote(merged_opts)

          # Import wrapper's functions
          import unquote(wrapper)
        end
      end
    end
  end
end
