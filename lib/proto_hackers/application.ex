defmodule ProtoHackers.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {ProtoHackers.EchoServer, [port: 10_000]},
      {ProtoHackers.PrimeServer, [port: 10_001]},
      {ProtoHackers.PriceServer, [port: 10_002]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProtoHackers.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
