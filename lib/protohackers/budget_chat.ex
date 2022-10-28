defmodule Protohackers.BudgetChat do
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

    Logger.info("Accepting connections on port #{port}")
    :ets.new(:chat, [:named_table, :public])
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)

    {:ok, pid} =
      Task.Supervisor.start_child(Protohackers.TaskSupervisor, fn ->
        serve(client, %{welcomed: false})
      end)

    :ok = :gen_tcp.controlling_process(client, pid)
    loop_acceptor(socket)
  end

  defp serve(socket, state) do
    if state[:welcomed] == false do
      welcome_string = "What's your name, traveler?\r\n"
      :gen_tcp.send(socket, welcome_string)
      serve(socket, %{welcomed: true})
    end

    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        process(socket, data, state)

      {:error, :closed} ->
        user_quit(socket, state)

      _ ->
        nil
    end
  end

  defp get_users() do
    case :ets.lookup(:chat, "users") do
      [] -> []
      [{"users", users}] -> users
      _ -> []
    end
  end

  defp user_quit(socket, state) do
    case state do
      %{username: username} ->
        users = get_users()
        :ets.insert(:chat, {"users", Enum.reject(users, &(&1 === username))})
        send_all("* #{username} has left the room\r\n", socket)
    end

    :gen_tcp.close(socket)
  end

  defp process(socket, data, state) do
    case state do
      %{welcomed: true} ->
        user = String.trim(data)

        if String.match?(user, ~r/^[[:alnum:]]+$/) do
          clients =
            case :ets.lookup(:chat, "clients") do
              [] -> []
              [{"clients", clients}] -> clients
              _ -> []
            end

          :ets.insert(:chat, {"clients", [socket | clients]})

          users = get_users()
          :ets.insert(:chat, {"users", [user | users]})

          send_all("* #{user} has entered the chat\r\n", socket)
          :gen_tcp.send(socket, "* The room contains: #{Enum.join(users, ", ")}\r\n")
          serve(socket, %{username: user})
        else
          user_quit(socket, state)
        end

      %{username: username} ->
        message = data
        send_all("[#{username}] #{message}", socket)
        serve(socket, %{username: username})

      _ ->
        user_quit(socket, state)
    end
  end

  def send_all(data, except \\ nil) do
    :ets.lookup(:chat, "clients")
    |> Enum.at(0)
    |> elem(1)
    |> Enum.filter(fn e -> e !== except end)
    |> Enum.each(&:gen_tcp.send(&1, data))
  end
end
