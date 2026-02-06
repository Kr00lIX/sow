defmodule Sow.Schema do
  @moduledoc """
  Helpers for introspecting Ecto schemas.
  """

  @doc """
  Get the association type for a field in a schema.

  Returns:
  - `:belongs_to` for belongs_to associations
  - `:has_many` for has_many associations
  - `:has_one` for has_one associations
  - `:many_to_many` for many_to_many associations
  - `nil` if the field is not an association
  """
  @spec association_type(module(), atom()) ::
          :belongs_to | :has_many | :has_one | :many_to_many | nil
  def association_type(schema, field) do
    case schema.__schema__(:association, field) do
      nil ->
        nil

      # Check struct type first for many_to_many
      %Ecto.Association.ManyToMany{} ->
        :many_to_many

      # belongs_to: BelongsTo struct or parent relationship
      %Ecto.Association.BelongsTo{} ->
        :belongs_to

      %{cardinality: :one, relationship: :parent} ->
        :belongs_to

      # has_one
      %{cardinality: :one, relationship: :child} ->
        :has_one

      # has_many
      %{cardinality: :many, relationship: :child} ->
        :has_many

      _other ->
        nil
    end
  end

  @doc """
  Get the foreign key for a has_many or has_one association.
  """
  @spec foreign_key(module(), atom()) :: atom() | nil
  def foreign_key(schema, field) do
    case schema.__schema__(:association, field) do
      %{related_key: key} -> key
      _ -> nil
    end
  end
end
