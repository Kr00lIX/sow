defmodule Sow.GraphTest do
  use ExUnit.Case

  alias Sow.Graph
  alias Sow.Test.Fixtures.{Countries, Organizations, Products, Tags}

  describe "dependencies/1" do
    test "returns empty list for fixture with no relations" do
      assert Graph.dependencies(Countries) == []
    end

    test "returns dependencies for fixture with relations" do
      deps = Graph.dependencies(Organizations)
      assert Countries in deps
    end

    test "returns nested dependencies" do
      deps = Graph.dependencies(Products)
      assert Organizations in deps
    end

    test "returns many_to_many dependencies (list of relations)" do
      deps = Graph.dependencies(Products)
      # Products has tags: [relation(Tags, ...), relation(Tags, ...)]
      assert Tags in deps
    end
  end

  describe "build_order/1" do
    test "orders fixtures by dependencies" do
      {:ok, order} = Graph.build_order([Products, Countries, Organizations])

      countries_idx = Enum.find_index(order, &(&1 == Countries))
      orgs_idx = Enum.find_index(order, &(&1 == Organizations))
      products_idx = Enum.find_index(order, &(&1 == Products))

      # Countries must come before Organizations
      assert countries_idx < orgs_idx
      # Organizations must come before Products
      assert orgs_idx < products_idx
    end

    test "handles many_to_many dependencies" do
      {:ok, order} = Graph.build_order([Products, Tags, Organizations, Countries])

      tags_idx = Enum.find_index(order, &(&1 == Tags))
      products_idx = Enum.find_index(order, &(&1 == Products))

      # Tags must come before Products (many_to_many dependency)
      assert tags_idx < products_idx
    end

    test "handles fixture with no dependencies" do
      {:ok, order} = Graph.build_order([Countries])
      assert order == [Countries]
    end
  end
end
