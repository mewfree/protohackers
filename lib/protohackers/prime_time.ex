defmodule Protohackers.PrimeTime do
  require Logger
  require Jason

  @doc """
  Starts accepting connections on the given `port`.
  """
  def accept(port) do
    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [:binary, packet: :line, active: false, reuseaddr: true]
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

  defp serve(socket, rest \\ "") do
    socket
    |> read_line(rest)
    |> write_response(socket)

    serve(socket, rest)
  end

  defp is_prime?(n) when n < 0 or not is_integer(n), do: false

  defp is_prime?(n) when n in [2, 3], do: true

  defp is_prime?(n) do
    floored_sqrt =
      :math.sqrt(n)
      |> Float.floor()
      |> round

    !Enum.any?(2..floored_sqrt, &(rem(n, &1) == 0))
  end

  defp read_line(socket, rest) do
    {:ok, data} = :gen_tcp.recv(socket, 0)

    if String.ends_with?(data, "\n") do
      json = Jason.decode(rest <> data)

      case json do
        {:ok, %{"method" => "isPrime", "number" => number}} when is_number(number) ->
          Jason.encode!(%{method: "isPrime", prime: is_prime?(number)})

        _ ->
          "Nope"
      end
    else
      serve(socket, rest <> data)
      :stop
    end
  end

  defp write_response(response, socket) do
    unless response == :stop, do: :gen_tcp.send(socket, response <> "\n")
  end
end
