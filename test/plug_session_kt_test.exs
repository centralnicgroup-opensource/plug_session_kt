defmodule PlugSessionKtTest do
  use ExUnit.Case, async: true
  doctest PlugSessionKt

  @default_opts [
    store: :kt
    key:
    table: :kt_sessions,
    max_age: 60
  ]

  defp put_env do
    Application.put_env()
  end

  setup_all do
    Application.stop(:plug_session_kt)
    put_envs
    :ok = Application.start(:plug_session_kt)
    IO.puts "Kyoto Tycoon has started"
  end


end
