defmodule PlugSessionKt do
@moduledoc """
Kyoto Tychoon Session Store
"""

use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    opts = [strategy: :one_for_one, name: PlugSessionKt.Supervisor]

    Supervisor.start_link([pool_spec()], opts)
  end

  def pool_spec() do
    worker_args = {:redo, conf[:kterl]}
    child_spec(conf[:name], conf[:pool], worker_args)
  end

  defp conf() do
    Application.get_env(:plug_session_kt, :config)
  end

  defp child_spec(pool_name, pool_args, kt_args)do
    strategy = Keyword.get(pool_args, :strategy, :fifo)
    pool_args = [strategy: strategy, name: {:local, pool_name}, worker_module: PlugSessionKt.Worker] ++ pool_args

    :poolboy.child_spec(pool_name, pool_args, kt_args)
  end
end
