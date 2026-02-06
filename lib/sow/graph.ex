defmodule Sow.Graph do
  @moduledoc """
  Builds a dependency graph from fixture modules and provides topological sorting
  for correct sync order.

  Dependencies are extracted from:
  - `relation/1` and `relation/3` calls (must sync before parent)
  - `nested/2` calls (must sync after parent, but module itself may have deps)
  """

  alias Sow.{Relation, Nested}

  @doc """
  Sync multiple fixture modules in dependency order.

  Builds a dependency graph, topologically sorts it, and syncs each module.
  """
  @spec sync_in_order([module()], module()) :: {:ok, map()} | {:error, term()}
  def sync_in_order(modules, repo) do
    case build_order(modules) do
      {:ok, ordered} ->
        sync_ordered(ordered, repo, %{})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Build the correct sync order for a list of fixture modules.
  Returns modules in order such that dependencies come before dependents.
  """
  @spec build_order([module()]) :: {:ok, [module()]} | {:error, {:cycle, [module()]}}
  def build_order(modules) do
    graph = build_graph(modules)
    topological_sort(graph, modules)
  end

  @doc """
  Extract all dependencies from a fixture module.
  """
  @spec dependencies(module()) :: [module()]
  def dependencies(module) do
    records = module.records()

    extract_deps(records, [])
    |> Enum.uniq()
  end

  # Build adjacency list: module -> [modules it depends on]
  defp build_graph(modules) do
    Enum.reduce(modules, %{}, fn module, acc ->
      deps = dependencies(module) |> Enum.filter(&(&1 in modules))
      Map.put(acc, module, deps)
    end)
  end

  # Kahn's algorithm for topological sort
  defp topological_sort(graph, modules) do
    # Calculate in-degrees
    in_degrees = calculate_in_degrees(graph, modules)

    # Start with nodes that have no dependencies
    queue = Enum.filter(modules, fn m -> Map.get(in_degrees, m, 0) == 0 end)

    do_topological_sort(queue, graph, in_degrees, [])
  end

  # in_degree = number of dependencies (nodes that must be processed before this one)
  defp calculate_in_degrees(graph, _modules) do
    Map.new(graph, fn {module, deps} -> {module, length(deps)} end)
  end

  defp do_topological_sort([], _graph, in_degrees, result) do
    # Check if all nodes processed
    remaining = Enum.filter(in_degrees, fn {_k, v} -> v > 0 end)

    if remaining == [] do
      {:ok, Enum.reverse(result)}
    else
      cycle_modules = Enum.map(remaining, fn {m, _} -> m end)
      {:error, {:cycle, cycle_modules}}
    end
  end

  defp do_topological_sort([current | rest], graph, in_degrees, result) do
    # Get modules that depend on current
    dependents =
      Enum.filter(graph, fn {_mod, deps} -> current in deps end)
      |> Enum.map(fn {mod, _} -> mod end)

    # Decrease in-degree for each dependent
    updated_degrees =
      Enum.reduce(dependents, in_degrees, fn dep, acc ->
        Map.update!(acc, dep, &(&1 - 1))
      end)

    # Add newly available nodes to queue
    new_available =
      Enum.filter(dependents, fn dep -> Map.get(updated_degrees, dep) == 0 end)

    do_topological_sort(
      rest ++ new_available,
      graph,
      Map.put(updated_degrees, current, -1),
      [current | result]
    )
  end

  defp extract_deps(records, acc) when is_list(records) do
    Enum.reduce(records, acc, &extract_deps/2)
  end

  defp extract_deps(record, acc) when is_map(record) do
    Enum.reduce(record, acc, fn {_key, value}, inner_acc ->
      extract_deps_from_value(value, inner_acc)
    end)
  end

  defp extract_deps_from_value(%Relation{module: module}, acc), do: [module | acc]
  defp extract_deps_from_value(%Nested{module: module}, acc), do: [module | acc]

  defp extract_deps_from_value(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &extract_deps_from_value/2)
  end

  defp extract_deps_from_value(_value, acc), do: acc

  defp sync_ordered([], _repo, results), do: {:ok, results}

  defp sync_ordered([module | rest], repo, results) do
    case module.sync(repo) do
      {:ok, synced} ->
        sync_ordered(rest, repo, Map.put(results, module, synced))

      {:error, reason} ->
        {:error, {module, reason}}
    end
  end
end
