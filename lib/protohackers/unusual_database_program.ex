defmodule Protohackers.UnusualDatabaseProgram do
  require Logger

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, socket} = :gen_udp.open(port, [:binary, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")
    :ets.new(:udp, [:named_table, :public])
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, {client_ip, client_port, message}} = :gen_udp.recv(socket, 0)

    cond do
      String.contains?(message, "=") ->
        [key, value] = String.split(message, "=", parts: 2)
        :ets.insert(:udp, {key, value})

      message == "version" ->
        :gen_udp.send(socket, client_ip, client_port, "version=mewfree v0.1")

      true ->
        case :ets.lookup(:udp, message) do
          [{_, value}] -> :gen_udp.send(socket, client_ip, client_port, "#{message}=#{value}")
          _ -> :gen_udp.send(socket, client_ip, client_port, "#{message}=")
        end
    end

    loop_acceptor(socket)
  end
end
