defmodule SowTest do
  use ExUnit.Case

  alias Sow.Test.Fixtures.Countries

  describe "fixture config" do
    test "fixtures have correct config" do
      config = Countries.__sow_config__()

      assert config.schema == Sow.Test.Schemas.Country
      assert config.keys == [:code]
      assert config.module == Countries
      assert config.callback == :records
    end

    test "supports custom callback name" do
      defmodule CustomCallbackFixture do
        use Sow,
          schema: Sow.Test.Schemas.Country,
          keys: [:code],
          callback: :modify

        def modify do
          [%{code: "FI", name: "Finland"}]
        end
      end

      config = CustomCallbackFixture.__sow_config__()
      assert config.callback == :modify
    end
  end

  describe "Sow.belongs_to/1 and Sow.belongs_to/3" do
    test "creates relation struct" do
      rel = Sow.belongs_to(Countries)
      assert %Sow.Relation{module: Countries, lookup: nil, assoc: false} = rel
    end

    test "creates relation with lookup" do
      rel = Sow.belongs_to(Countries, :code, "NO")
      assert %Sow.Relation{module: Countries, lookup: {:code, "NO"}, assoc: false} = rel
    end
  end

  describe "Sow.has_many/2" do
    test "creates nested struct" do
      nested = Sow.has_many(Countries, foreign_key: :country_id)

      assert %Sow.Nested{
               module: Countries,
               foreign_key: :country_id
             } = nested
    end
  end

  describe "Sow.many_to_many/1 and Sow.many_to_many/3" do
    test "creates relation struct with assoc flag" do
      rel = Sow.many_to_many(Countries)
      assert %Sow.Relation{module: Countries, lookup: nil, assoc: true} = rel
    end

    test "creates relation with lookup and assoc flag" do
      rel = Sow.many_to_many(Countries, :code, "NO")
      assert %Sow.Relation{module: Countries, lookup: {:code, "NO"}, assoc: true} = rel
    end
  end

  describe "Sow.assoc/1 and Sow.assoc/3 (auto-detect)" do
    test "creates relation struct with auto flag" do
      rel = Sow.assoc(Countries)
      assert %Sow.Relation{module: Countries, lookup: nil, auto: true} = rel
    end

    test "creates relation with lookup and auto flag" do
      rel = Sow.assoc(Countries, :code, "NO")
      assert %Sow.Relation{module: Countries, lookup: {:code, "NO"}, auto: true} = rel
    end
  end
end
