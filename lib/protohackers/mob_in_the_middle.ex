defmodule Protohackers.MobInTheMiddle do
  require Logger

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, listen_socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Accepting connections on port #{port}")

    loop_accept(listen_socket)
  end

  defp loop_accept(listen_socket) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)
    spawn_link(fn -> handle_client(client_socket) end)
    loop_accept(listen_socket)
  end

  defp handle_client(client_socket) do
    {:ok, upstream_socket} =
      :gen_tcp.connect('chat.protohackers.com', 16963, [:binary, packet: :line, active: false])

    spawn_link(fn -> relay_messages(client_socket, upstream_socket) end)
    relay_messages(upstream_socket, client_socket)
  end

  defp relay_messages(from_socket, to_socket) do
    case :gen_tcp.recv(from_socket, 0) do
      {:ok, data} ->
        transformed_data = replace_substring(data)
        :gen_tcp.send(to_socket, transformed_data)
        relay_messages(from_socket, to_socket)

      {:error, _} ->
        :gen_tcp.close(from_socket)
        :gen_tcp.close(to_socket)
    end
  end

  defp replace_substring(data) do
    regex = ~r/(?<=^| )7[a-zA-Z0-9]{25,34}(?=$| )/
    String.replace(data, regex, "7YWHMfk9JZe0LM0g1ZauHuiSxhI")
  end
end
