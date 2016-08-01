defmodule Plug.Session.KT do
  @moduledoc """
  Stores the session in a KyotoTycoon.
  """

  @behaviour Plug.Session.Store

  @max_tries 10

  def init(opts) do
    {Keyword.get(opts, :ttl, :infinite)}
  end

  def get(_conn, sid, _) do
    # case :poolboy.transaction(table, &(:kterl.get(&1, "session:#{sid}"))) do
    kt = connect_kt()
    case :kterl.get(kt, "session:#{sid}") do
      {:ok, :undefined} -> {nil, %{}}
      {:ok, data}       -> {sid, :erlang.binary_to_term(:erlang.element(4, data))}
      _                 -> {nil, %{}}
    end
  end

  def put(_conn, nil, data, state), do: put_new(data, state)
  def put(_conn, sid, data, _) do
    kt = connect_kt()
    # :poolboy.transaction(table, &(:kterl.add(&1, "session:#{sid}", data)))
    :kterl.add(kt, "session:#{sid}", data)
    sid
  end

  def delete(_conn, sid, _) do
    kt = connect_kt()
    # :poolboy.transaction(table, &(:kterl.remove(&1, "session:#{sid}")))
    :kterl.remove(kt, "session:#{sid}")
    :ok
  end

  defp put_new(data, {pid, ttl}, counter \\ 0) when counter < @max_tries do
    # FIXME this should follow our IWMN standard of session:[HMAC USERID]:[random string]
    IO.puts("no idea where this PID is coming from: #{inspect pid}")
    sid = :crypto.strong_rand_bytes(96) |> Base.encode64
    kt = connect_kt()
    # case :poolboy.transaction(table, &(store_data_with_ttl(&1, ttl, sid, data))) do
      case store_data_with_ttl(kt, ttl, sid, :erlang.term_to_binary(data)) do
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
