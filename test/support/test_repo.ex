defmodule AshBackpex.TestRepo do
  @moduledoc false
  use AshSqlite.Repo,
    otp_app: :ash_backpex
end
