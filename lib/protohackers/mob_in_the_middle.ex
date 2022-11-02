defmodule Protohackers.MobInTheMiddle do
  require Logger

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: false, reuseaddr: true]
      )

    {:ok, upstream_socket} =
      :gen_tcp.connect("chat.protohackers.com", 16963, [:binary, packet: :line])

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket, upstream_socket)
  end

  defp loop_acceptor(socket, upstream_socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Protohackers.TaskSupervisor, fn ->
        serve(client, upstream_socket)
      end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket, upstream_socket)
  end

  defp serve(socket, upstream_socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        :gen_tcp.send(upstream_socket, data) |> IO.inspect()
        :gen_tcp.send(socket, data)
        serve(socket, upstream_socket)

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end
end
