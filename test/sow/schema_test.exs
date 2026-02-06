defmodule Sow.SchemaTest do
  use ExUnit.Case

  alias Sow.Schema
  alias Sow.Test.Schemas.{Organization, Product}

  describe "association_type/2" do
    test "detects belongs_to" do
      assert Schema.association_type(Organization, :country) == :belongs_to
    end

    test "detects has_many" do
      assert Schema.association_type(Product, :variants) == :has_many
    end

    test "detects many_to_many" do
      assert Schema.association_type(Product, :tags) == :many_to_many
    end

    test "returns nil for non-association fields" do
      assert Schema.association_type(Product, :name) == nil
    end

    test "returns nil for non-existent fields" do
      assert Schema.association_type(Product, :nonexistent) == nil
    end
  end
end
