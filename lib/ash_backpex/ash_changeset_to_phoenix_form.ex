if Code.ensure_loaded?(Phoenix.HTML) and Code.ensure_loaded?(AshPhoenix.Form) do
  defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
    def to_form(changeset, opts) do

      opts = Enum.map(opts, fn {key, value} -> {key, to_string(value)} end)

      case changeset.action do
        %{type: :create} ->
          AshPhoenix.Form.for_create(
            changeset.resource,
            changeset.action.name,
            opts
          )
          # |> Phoenix.HTML.FormData.to_form(as: as)

        %{type: :update} ->
          # 简化实现：直接传递 changeset，让 AshPhoenix.Form 处理
          AshPhoenix.Form.for_update(
            changeset.data,
            changeset.action.name,
            opts
          )
          # |> Phoenix.HTML.FormData.to_form(as: as)

        _ ->
          # 使用默认的 create action
          AshPhoenix.Form.for_create(changeset.resource, :create, opts)
          # |> Phoenix.HTML.FormData.to_form(as: as)
      end
    end

    def input_value(changeset, form, field) do
      AshPhoenix.Form.value(form, field) || Map.get(changeset.data, field)
    end

    def input_type(changeset, _form, field) do
      AshPhoenix.Form.input_type(changeset.resource, field)
    end

    def input_validations(changeset, form, field) do
      AshPhoenix.Form.input_validations(form, field)
    end

  end
end
