defmodule Sow.Sync do
  @moduledoc """
  Handles synchronization of fixture records to the database.

  The sync process:
  1. Resolves all relations (syncs dependencies first, collects their IDs)
  2. Prepares the record with resolved foreign keys
  3. Upserts the record based on search keys
  4. Syncs any nested fixtures with the parent's ID
  """

  alias Sow.{Config, Lookup, Relation, Nested, Schema}

  @type sync_result :: {:ok, struct() | [struct()]} | {:error, term()}
  @type sync_result_with_pruned ::
          {:ok, struct() | [struct()], deleted :: [struct()]} | {:error, term()}

  @doc """
  Sync a fixture module's records to the database.

  ## Options

    * `:prune` - if `true`, deletes records not in fixtures. Defaults to `false`.

  ## Returns

    * `{:ok, synced_records}` - when prune is false
    * `{:ok, synced_records, deleted_records}` - when prune is true
    * `{:error, reason}` - on failure
  """
  @spec sync(module(), module(), Keyword.t()) :: sync_result() | sync_result_with_pruned()
  def sync(fixture_module, repo, opts \\ []) do
    config = fixture_module.__sow_config__()
    records = fixture_module.records()
    prune? = Keyword.get(opts, :prune, false)

    case sync_records(records, config, repo) do
      {:ok, synced} when prune? ->
        deleted = prune(synced, config, repo)
        {:ok, synced, deleted}

      {:ok, synced} ->
        {:ok, synced}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Delete records from the database that are not in the synced list.
  """
  def prune(synced_records, %Config{schema: schema}, repo) do
    synced_records = List.wrap(synced_records)
    synced_ids = Enum.map(synced_records, & &1.id)

    import Ecto.Query

    query =
      from(r in schema,
        where: r.id not in ^synced_ids,
        select: r
      )

    {_count, deleted} = repo.delete_all(query, returning: true)
    deleted || []
  end

  @doc """
  Sync records with a given config.
  """
  @spec sync_records(map() | [map()], Config.t(), module()) :: sync_result()
  def sync_records(records, config, repo) when is_list(records) do
    Enum.reduce_while(records, {:ok, []}, fn record, {:ok, acc} ->
      case sync_record(record, config, repo) do
        {:ok, synced} -> {:cont, {:ok, [synced | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, results} -> {:ok, Enum.reverse(results)}
      error -> error
    end
  end

  def sync_records(record, config, repo) when is_map(record) do
    sync_record(record, config, repo)
  end

  @doc """
  Sync a single record.
  """
  @spec sync_record(map(), Config.t(), module()) :: {:ok, struct()} | {:error, term()}
  def sync_record(record, config, repo) do
    schema = config.schema

    with {:ok, resolved, nested_fixtures} <- resolve_record(record, schema, repo),
         {:ok, model} <- upsert(resolved, config, repo),
         {:ok, model} <- sync_nested(model, nested_fixtures, repo) do
      {:ok, model}
    end
  end

  # Resolve relations and extract nested fixtures from a record
  defp resolve_record(record, schema, repo) do
    record
    |> to_map()
    |> Enum.reduce_while({:ok, %{}, []}, fn {key, value}, {:ok, resolved, nested} ->
      case resolve_field(key, value, schema, repo) do
        {:ok, resolved_fields, nested_fixtures} ->
          {:cont, {:ok, Map.merge(resolved, resolved_fields), nested ++ nested_fixtures}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
  end

  # Auto-detect: single Relation with auto: true
  defp resolve_field(key, %Relation{auto: true} = relation, schema, repo) do
    case Schema.association_type(schema, key) do
      :belongs_to ->
        resolve_belongs_to(key, relation, repo)

      :has_many ->
        # Convert to Nested and defer
        nested = relation_to_nested(relation, schema, key)
        {:ok, %{}, [{key, nested}]}

      :has_one ->
        # Treat like has_many but expect single record
        nested = relation_to_nested(relation, schema, key)
        {:ok, %{}, [{key, nested}]}

      :many_to_many ->
        resolve_many_to_many(key, relation, repo)

      nil ->
        # Field not found as association, treat as belongs_to (set _id)
        resolve_belongs_to(key, relation, repo)
    end
  end

  # Explicit belongs_to (assoc: false, auto: false)
  defp resolve_field(key, %Relation{assoc: false, auto: false} = relation, _schema, repo) do
    resolve_belongs_to(key, relation, repo)
  end

  # Explicit many_to_many (assoc: true)
  defp resolve_field(key, %Relation{assoc: true} = relation, _schema, repo) do
    resolve_many_to_many(key, relation, repo)
  end

  # List of relations (many_to_many or auto-detect)
  defp resolve_field(key, [%Relation{} | _] = relations, schema, repo) do
    # Check if auto-detect and it's actually has_many
    first = List.first(relations)

    if first.auto and Schema.association_type(schema, key) == :has_many do
      # Convert to nested, but we need the records from each relation's module
      # This is a special case - user passed list of assoc() for has_many
      nested = relation_to_nested(first, schema, key)
      {:ok, %{}, [{key, nested}]}
    else
      # Many-to-many: sync each and collect models
      results =
        Enum.reduce_while(relations, {:ok, []}, fn relation, {:ok, acc} ->
          case sync_relation(relation, repo) do
            {:ok, model} -> {:cont, {:ok, [model | acc]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case results do
        {:ok, models} -> {:ok, %{key => Enum.reverse(models)}, []}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp resolve_field(key, %Nested{} = nested, _schema, _repo) do
    {:ok, %{}, [{key, nested}]}
  end

  # Runtime database lookup
  defp resolve_field(key, %Lookup{} = lookup, _schema, repo) do
    case resolve_lookup(lookup, repo) do
      {:ok, value} -> {:ok, %{key => value}, []}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_field(key, value, _schema, _repo) do
    {:ok, %{key => value}, []}
  end

  defp resolve_belongs_to(key, relation, repo) do
    case sync_relation(relation, repo) do
      {:ok, related_model} ->
        fk_key = :"#{key}_id"
        {:ok, %{fk_key => related_model.id}, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_many_to_many(key, relation, repo) do
    case sync_relation(relation, repo) do
      {:ok, related_model} ->
        {:ok, %{key => [related_model]}, []}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Resolve a lookup - query database for existing record
  defp resolve_lookup(%Lookup{schema: schema, match: match, field: field}, repo) do
    case resolve_match_criteria(match, repo) do
      {:ok, resolved_match} ->
        case repo.get_by(schema, resolved_match) do
          nil ->
            {:error, {:lookup_not_found, schema, resolved_match}}

          record ->
            {:ok, Map.get(record, field)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Resolve match criteria - handles nested lookups within match map
  defp resolve_match_criteria({key, value}, repo) do
    case resolve_match_value(value, repo) do
      {:ok, resolved} -> {:ok, [{key, resolved}]}
      {:error, reason} -> {:error, reason}
    end
  end

  defp resolve_match_criteria(match, repo) when is_map(match) do
    Enum.reduce_while(match, {:ok, %{}}, fn {key, value}, {:ok, acc} ->
      case resolve_match_value(value, repo) do
        {:ok, resolved} -> {:cont, {:ok, Map.put(acc, key, resolved)}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Nested lookup within match criteria
  defp resolve_match_value(%Lookup{} = lookup, repo) do
    resolve_lookup(lookup, repo)
  end

  defp resolve_match_value(value, _repo), do: {:ok, value}

  defp relation_to_nested(%Relation{module: module}, schema, key) do
    foreign_key = Schema.foreign_key(schema, key) || :"#{schema_name(schema)}_id"

    %Nested{
      module: module,
      foreign_key: foreign_key,
      keys: nil
    }
  end

  defp schema_name(schema) do
    schema
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
    |> String.to_atom()
  end

  defp sync_relation(%Relation{module: module, lookup: lookup}, repo) do
    case module.sync(repo) do
      {:ok, models} when is_list(models) ->
        find_by_lookup(models, lookup)

      {:ok, model} ->
        {:ok, model}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_by_lookup(models, nil), do: {:ok, List.first(models)}

  defp find_by_lookup(models, {key, value}) do
    case Enum.find(models, fn model -> Map.get(model, key) == value end) do
      nil -> {:error, {:not_found, key, value}}
      model -> {:ok, model}
    end
  end

  defp upsert(attrs, %Config{schema: schema, keys: keys}, repo) do
    search_params = Map.take(attrs, keys)

    existing = repo.get_by(schema, search_params)

    struct_or_existing =
      case existing do
        nil ->
          # Set primary key directly on struct (changesets typically don't cast PKs)
          primary_keys = schema.__schema__(:primary_key)
          pk_attrs = Map.take(attrs, primary_keys)
          struct(schema, pk_attrs)

        found ->
          # Preload associations that are being set via put_assoc
          assocs_to_preload = detect_assocs_in_attrs(schema, attrs)
          repo.preload(found, assocs_to_preload)
      end

    struct_or_existing
    |> schema.changeset(attrs)
    |> repo.insert_or_update()
  end

  # Detect which associations in attrs need to be preloaded
  defp detect_assocs_in_attrs(schema, attrs) do
    schema_assocs = schema.__schema__(:associations)

    attrs
    |> Map.keys()
    |> Enum.filter(fn key ->
      key in schema_assocs and is_list(Map.get(attrs, key))
    end)
  end

  defp sync_nested(model, [], _repo), do: {:ok, model}

  defp sync_nested(model, nested_fixtures, repo) do
    Enum.reduce_while(nested_fixtures, {:ok, model}, fn {field, nested}, {:ok, acc_model} ->
      case sync_nested_fixture(acc_model, field, nested, repo) do
        {:ok, updated_model} -> {:cont, {:ok, updated_model}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  # Handle inline records (has_many_inline)
  defp sync_nested_fixture(
         parent,
         field,
         %Nested{records: records, schema: schema, foreign_key: fk, keys: keys},
         repo
       )
       when is_list(records) and not is_nil(schema) do
    # Build config from schema and keys
    primary_keys = schema.__schema__(:primary_key)

    config = %Config{
      schema: schema,
      keys: keys || primary_keys,
      module: nil
    }

    # Inject parent's ID into each record
    records_with_fk = inject_foreign_key(records, fk, parent.id)

    case sync_records(records_with_fk, config, repo) do
      {:ok, synced} ->
        {:ok, Map.put(parent, field, synced)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Handle fixture module reference (has_many)
  defp sync_nested_fixture(
         parent,
         field,
         %Nested{module: module, foreign_key: fk, keys: keys},
         repo
       ) do
    nested_config = module.__sow_config__()
    records = module.records()

    # Override keys if specified in nested
    config = if keys, do: %{nested_config | keys: keys}, else: nested_config

    # Inject parent's ID into each record
    records_with_fk = inject_foreign_key(records, fk, parent.id)

    case sync_records(records_with_fk, config, repo) do
      {:ok, synced} ->
        {:ok, Map.put(parent, field, synced)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp inject_foreign_key(records, fk, parent_id) when is_list(records) do
    Enum.map(records, &inject_foreign_key(&1, fk, parent_id))
  end

  defp inject_foreign_key(record, fk, parent_id) when is_map(record) do
    record
    |> to_map()
    |> Map.put(fk, parent_id)
  end

  # Convert struct to map, dropping Ecto metadata
  defp to_map(%{__struct__: _, __meta__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.drop([:__meta__])
  end

  defp to_map(%{__struct__: _} = struct) do
    Map.from_struct(struct)
  end

  defp to_map(map) when is_map(map), do: map
end
