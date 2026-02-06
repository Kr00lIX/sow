defmodule Sow.Test.Repo.Migrations.CreateTestTables do
  use Ecto.Migration

  def change do
    create table(:countries) do
      add :code, :string, null: false
      add :name, :string, null: false
    end

    create unique_index(:countries, [:code])

    create table(:organizations) do
      add :slug, :string, null: false
      add :name, :string, null: false
      add :country_id, references(:countries)
    end

    create unique_index(:organizations, [:slug])

    create table(:tags) do
      add :name, :string, null: false
      add :slug, :string, null: false
    end

    create unique_index(:tags, [:slug])

    create table(:products) do
      add :type, :string, null: false
      add :name, :string, null: false
      add :price, :integer
      add :organization_id, references(:organizations)
    end

    create table(:products_tags, primary_key: false) do
      add :product_id, references(:products, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:products_tags, [:product_id, :tag_id])

    create table(:product_variants) do
      add :sku, :string, null: false
      add :name, :string, null: false
      add :product_id, references(:products, on_delete: :delete_all), null: false
    end

    create unique_index(:product_variants, [:product_id, :sku])
  end
end
