if Code.ensure_loaded?(Phoenix.HTML) and Code.ensure_loaded?(AshPhoenix.Form) do
  defimpl Phoenix.HTML.FormData, for: Ash.Changeset do
    def to_form(changeset, opts) do
      opts = Keyword.drop(opts, [:as, :id])

      case changeset.action do
        %{type: :create} ->
          AshPhoenix.Form.for_create(changeset.resource, changeset.action.name,
            opts ++ [changeset: changeset]
          )

        %{type: :update} ->
          # 简化实现：直接传递 changeset，让 AshPhoenix.Form 处理
          AshPhoenix.Form.for_update(
            changeset.data,
            changeset.action.name,
            opts ++ [changeset: changeset]
          )
        _ ->
          # 使用默认的 create action
          AshPhoenix.Form.for_create(changeset.resource, :create, opts)
      end
    end

    def to_form(source, form, field, opts) do
          require Logger

      case find_inputs_for_type!(source, field) do
        {:one, _cast, module} ->
          [
            AshPhoenix.Form.for_create(
              module,
              :create,
              Keyword.merge(opts,
                as: form.name <> "[#{field}]",
                id: form.id <> "_#{field}"
              )
            )
          ]

        {:many, _cast, module} ->
          existing_data = get_relationship_data(source, field)

          Enum.with_index(existing_data || [], fn item, index ->

          Logger.debug("Update data: #{inspect(item.data)}")
          Logger.debug("Update attributes: #{inspect(item.attributes)}")
          Logger.debug("Update params: #{inspect(item.params)}")
            AshPhoenix.Form.for_update(
              item,
              :update,
              Keyword.merge(opts,
                as: form.name <> "[#{field}][#{index}]",
                id: form.id <> "_#{field}_#{index}"
              )
            )
          end)
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

    defp get_relationship_data(changeset, field) do
      case Map.get(changeset.relationships, field) do
        nil -> changeset.data |> Map.get(field)
        data -> data
      end
    end

    defp find_inputs_for_type!(changeset, field) do
      resource = changeset.resource

      # 首先检查是否是关系
      relationship = Enum.find(resource.__ash_relationships__(), &(&1.name == field))

      case relationship do
        %{cardinality: :one, destination: module} ->
          {:one, nil, module}

        %{cardinality: :many, destination: module} ->
          {:many, nil, module}

        nil ->
          # 如果不是关系，检查是否是嵌入属性
          attribute = Ash.Resource.Info.attribute(resource, field)

          case attribute do
            %{type: {:array, module}} when is_atom(module) ->
              # 处理 embeds_many 类型
              if function_exported?(module, :__ash_resource__, 0) do
                {:many, nil, module}
              else
                raise ArgumentError,
                      "field #{inspect(field)} array type #{inspect(module)} is not an Ash resource"
              end

            %{type: module} when is_atom(module) ->
              # 处理 embeds_one 类型
              if function_exported?(module, :__ash_resource__, 0) do
                {:one, nil, module}
              else
                raise ArgumentError,
                      "field #{inspect(field)} type #{inspect(module)} is not an Ash resource"
              end

            %{type: {:array, {Ash.Type.Union, constraints}}} ->
              # 处理特殊的 Union 数组类型（如果确实存在）
              case get_embed_resource(constraints) do
                nil ->
                  raise ArgumentError,
                        "could not find embed resource for field #{inspect(field)} on #{inspect(resource)}"

                module ->
                  {:many, nil, module}
              end

            %{type: {Ash.Type.Union, constraints}} ->
              # 处理特殊的 Union 类型（如果确实存在）
              case get_embed_resource(constraints) do
                nil ->
                  raise ArgumentError,
                        "could not find embed resource for field #{inspect(field)} on #{inspect(resource)}"

                module ->
                  {:one, nil, module}
              end

            nil ->
              raise ArgumentError,
                    "could not find relationship or embed #{inspect(field)} on #{inspect(resource)}"

            _ ->
              raise ArgumentError,
                    "field #{inspect(field)} is not a relationship or embed on #{inspect(resource)}"
          end
      end
    end

    defp get_embed_resource(constraints) do
      case Keyword.get(constraints, :types) do
        types when is_list(types) ->
          # 查找第一个嵌入资源类型
          Enum.find_value(types, fn
            {_key, %{type: module}} when is_atom(module) ->
              if function_exported?(module, :__ash_resource__, 0), do: module, else: nil

            _ ->
              nil
          end)

        _ ->
          nil
      end
    end
  end
end
