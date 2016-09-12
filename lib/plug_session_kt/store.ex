defmodule PlugSessionKT.Store do
  @moduledoc """
  Stores the session in a KyotoTycoon.
  """

  require Logger

  @behaviour Plug.Session.Store
  @max_tries 10

  def init(opts) do
    {Keyword.get(opts, :ttl, :infinite)}
  end

  def get(_conn, sid, _) do
    Logger.debug("looking for a session for ID: #{sid}")
    case :kterl.get(kt, "session:#{sid}") do
      {:ok, :undefined} -> {nil, %{}}
      {:ok, data}       ->
        Logger.debug("found session data: #{inspect res}")
        {sid, data}
      _                 -> {nil, %{}}
    end
  end


  ###
  # Used to be called store_data_with_ttl seemed to more a put type of thing feel free to revert
  ###
  def put(_conn, client, :infinite, sid, data) do
    :kterl.add(client, "session:#{sid}", data)
  end

  def put(_conn, client, ttl, sid, data) do
    :kterl.add(client, "session:#{sid}", data, [{:xt, ttl}])
  end

  def update(_conn, sid, data) do
    Logger.debug("updating session with ID: #{sid} pushing in data: #{inspect data}")
    :kterl.replace(kt, "session:#{sid}", data)
    sid
  end

  def delete(_conn, sid, _) do
    Logger.debug("removing session with ID: #{sid}")
    :kterl.remove(kt, "session:#{sid}")
    :ok
  end

  def connect_kt do
    host = :erlang.binary_to_list(Application.get_env(:kyoto, :host, "127.0.0.1"))
    port = Application.get_env(:kyoto, :port, 1978)
    {:ok, pid} = :kterl.start_link(host, port, 5000)
    pid
  end
end
