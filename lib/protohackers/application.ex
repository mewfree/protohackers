defmodule Protohackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: Protohackers.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> Protohackers.SmokeTest.accept(4040) end},
        restart: :permanent,
        id: 0
      ),
      Supervisor.child_spec({Task, fn -> Protohackers.PrimeTime.accept(4041) end},
        restart: :permanent,
        id: 1
      ),
      Supervisor.child_spec({Task, fn -> Protohackers.MeansToAnEnd.accept(4042) end},
        restart: :permanent,
        id: 2
      ),
      Supervisor.child_spec({Task, fn -> Protohackers.BudgetChat.accept(4043) end},
        restart: :permanent,
        id: 3
      ),
      Supervisor.child_spec({Task, fn -> Protohackers.UnusualDatabaseProgram.accept(4044) end},
        restart: :permanent,
        id: 4
      )
    ]

    opts = [strategy: :one_for_one, name: Protohackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
