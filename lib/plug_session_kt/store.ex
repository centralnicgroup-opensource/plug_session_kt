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
    # case :poolboy.transaction(table, &(:kterl.get(&1, "session:#{sid}"))) do
    kt = connect_kt()
    Logger.debug("looking for a session for ID: #{sid}")
    case :kterl.get(kt, "session:#{sid}") do
      {:ok, :undefined} -> {nil, %{}}
      {:ok, data}       ->
        {:ok, res} = PoisonPlus.decode(elem(data, 3))
        Logger.debug("found session data: #{inspect res}")
        {sid, res}
      _                 -> {nil, %{}}
    end
  end

  def put(_conn, nil, data, state), do: put_new(data, state)
  def put(_conn, sid, data, _) do
    kt = connect_kt()
    # :poolboy.transaction(table, &(:kterl.add(&1, "session:#{sid}", data)))
    Logger.debug("updating session with ID: #{sid} pushing in data: #{inspect data}")
    {:ok, json} = PoisonPlus.encode(data)
    :kterl.replace(kt, "session:#{sid}", json)
    sid
  end

  def delete(_conn, sid, _) do
    kt = connect_kt()
    # :poolboy.transaction(table, &(:kterl.remove(&1, "session:#{sid}")))
    Logger.debug("removing session with ID: #{sid}")
    :kterl.remove(kt, "session:#{sid}")
    :ok
  end

  defp put_new(data, {ttl}, counter \\ 0) when counter < @max_tries do
    # FIXME this should follow our IWMN standard of session:[HMAC USERID]:[random string]
    # IO.puts("no idea where this PID is coming from: #{inspect pid}")
    sid = :crypto.strong_rand_bytes(96) |> Base.encode64
    Logger.debug("creating new session with ID: #{sid} and data: #{inspect data}")
    kt = connect_kt()
    # case :poolboy.transaction(table, &(store_data_with_ttl(&1, ttl, sid, data))) do
      {:ok, json} = PoisonPlus.encode(data)
      case store_data_with_ttl(kt, ttl, sid, json) do
      :ok -> sid
      _   -> put_new(data, {kt, ttl}, counter + 1)
    end
  end

  defp store_data_with_ttl(client, :infinite, sid, data) do
    :kterl.add(client, "session:#{sid}", data)
  end
  defp store_data_with_ttl(client, ttl, sid, data) do
    :kterl.add(client, "session:#{sid}", data, [{:xt, ttl}])
  end

  def connect_kt do
    host = :erlang.binary_to_list(Application.get_env(:kyoto, :host, "127.0.0.1"))
    port = Application.get_env(:kyoto, :port, 1978)
    {:ok, pid} = :kterl.start_link(host, port, 5000)
    pid
  end
end
