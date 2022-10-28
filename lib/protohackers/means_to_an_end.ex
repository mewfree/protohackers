defmodule Protohackers.MeansToAnEnd do
  require Logger

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: 0, active: false, reuseaddr: true]
      )

    Logger.info("Accepting connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Protohackers.TaskSupervisor, fn -> serve(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket, prices \\ []) do
    case :gen_tcp.recv(socket, 9) do
      {:ok, data} ->
        process(socket, data, prices)

      {:error, :closed} ->
        :gen_tcp.close(socket)
    end
  end

  defp calculate_mean(prices, mintime, maxtime) do
    filtered_prices =
      prices
      |> Enum.filter(fn {timestamp, _price} ->
        mintime <= timestamp and timestamp <= maxtime
      end)
      |> Enum.map(fn {_timestamp, price} -> price end)

    if length(filtered_prices) > 0 do
      round(Enum.sum(filtered_prices) / length(filtered_prices))
    else
      0
    end
  end

  defp process(socket, data, prices) do
    case data do
      <<73, timestamp::big-integer-signed-size(8)-unit(4),
        price::big-integer-signed-size(8)-unit(4)>> ->
        serve(socket, [{timestamp, price} | prices])

      <<81, mintime::big-integer-signed-size(8)-unit(4),
        maxtime::big-integer-signed-size(8)-unit(4)>> ->
        mean = calculate_mean(prices, mintime, maxtime)
        :gen_tcp.send(socket, <<mean::big-integer-signed-32>>)
        serve(socket, prices)
    end
  end
end
