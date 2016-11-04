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

  def get(_conn, sid, {table, _}) do
    Logger.debug("looking for a session for ID: #{sid}")
    case :poolboy.transaction(table, &(:kterl.get(&1, "session:#{decode_sid(sid)}"))) do
      {:ok, :undefined} -> {nil, %{}}
      {:ok, data}       ->
        {:ok, res} = PoisonPlus.decode(:kterl_result.get_value(data))
        res1 = Map.put(res, "__expire", :kterl_result.get_exptime(data))
        Logger.debug("found session data: #{inspect res1}")
        {sid, res1}
      _                 -> {nil, %{}}
    end
  end

  def put(_conn, nil, data, state), do: put_new(data, state)
  def put(_conn, sid, data, _) do
    kt = connect_kt()
    Logger.debug("updating session with ID: #{decoded_sid(sid)} pushing in data: #{inspect data}")
    {ttl, data1} = Map.pop(data, "__expire", now())
    {:ok, json} = PoisonPlus.encode(data1)
    :kterl.replace(kt, "session:#{decoded_sid(sid)}", json, [{:xt, ttl}])
    sid
  end

  def delete(_conn, sid, _) do
    kt = connect_kt()
    Logger.debug("removing session with ID: #{decoded_sid(sid)}")
    :kterl.remove(kt, "session:#{decoded_sid(sid)}")
    :ok
  end

  defp put_new(data, {ttl}, counter \\ 0) when counter < @max_tries do
    # FIXME this should follow our IWMN standard of session:[HMAC USERID]:[random string]
    # IO.puts("no idea where this PID is coming from: #{inspect pid}")
    sid = :crypto.strong_rand_bytes(96) |> Base.encode64
    Logger.debug("creating new session with ID: #{decoded_sid(sid)} and data: #{inspect data}")
    kt = connect_kt()
    {:ok, json} = PoisonPlus.encode(data)
      case store_data_with_ttl(kt, ttl, sid, json) do
      :ok -> sid
      _   -> put_new(data, {kt, ttl}, counter + 1)
    end
  end

  defp store_data_with_ttl(client, :infinite, sid, data) do
    :kterl.add(client, "session:#{decoded_sid(sid)}", data)
  end
  defp store_data_with_ttl(client, ttl, sid, data) do
    :kterl.add(client, "session:#{decoded_sid(sid)}", data, [{:xt, ttl}])
  end

  defp decoded_sid(sid) do
    URI.decode(sid)
  end

  defp now do
    DateTime.utc_now |> DateTime.to_unix
  end

  def connect_kt do
    host = :erlang.binary_to_list(Application.get_env(:kyoto, :host, "127.0.0.1"))
    port = Application.get_env(:kyoto, :port, 1978)
    {:ok, pid} = :kterl.start_link(host, port, 5000)
    pid
  end

end
