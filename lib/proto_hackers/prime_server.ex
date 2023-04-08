defmodule ProtoHackers.PrimeServer do
  use GenServer

  require Logger

  defstruct [:listen_socket, :supervisor]

  def start_link(port: port) do
    GenServer.start_link(__MODULE__, port: port)
  end

  @impl GenServer
  def init(port: port) do
    {:ok, supervisor} = Task.Supervisor.start_link(max_children: 100)

    options = [
      ifaddr: {0, 0, 0, 0},
      mode: :binary,
      active: false,
      reuseaddr: true,
      exit_on_close: false,
      backlog: 100,
      packet: :line
    ]

    case :gen_tcp.listen(port, options) do
      {:ok, listen_socket} ->
        Logger.info("#{__MODULE__} Listening on port #{port}")
        state = %__MODULE__{supervisor: supervisor, listen_socket: listen_socket}
        {:ok, state, {:continue, :accept_connections}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  @impl true
  def handle_continue(:accept_connections, %__MODULE__{} = state) do
    case :gen_tcp.accept(state.listen_socket) do
      {:ok, socket} ->
        Task.Supervisor.start_child(state.supervisor, fn -> handle_connection(socket) end)
        {:noreply, state, {:continue, :accept_connections}}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp handle_connection(socket) do
    receive_bytes(socket)
  end

  defp receive_bytes(socket, carry \\ "") do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} ->
        Logger.debug("#{__MODULE__} data received: #{inspect(data)}")

        if String.ends_with?(data, "\n") do
          process_data(socket, carry <> data)
          receive_bytes(socket)
        else
          receive_bytes(socket, carry <> data)
        end

      {:error, :closed} ->
        Logger.debug("#{__MODULE__} connection closed.")
        :gen_tcp.close(socket)
        {:ok, :closed}

      {:error, reason} ->
        Logger.error("#{__MODULE__} error #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp process_data(socket, data) do
    case Jason.decode(data) do
      {:ok, %{"method" => "isPrime", "number" => number}}
      when is_integer(number) or is_float(number) ->
        send_response(socket, number)

      _ ->
        send_malformed_and_close(socket)
    end
  end

  defp send_malformed_and_close(socket) do
    response = [["{}"], "\n"]
    result = :gen_tcp.send(socket, response)
    Logger.debug("#{__MODULE__} Sent malformed response '#{response}': #{inspect(result)}")
    :gen_tcp.close(socket)
  end

  defp send_response(socket, number) do
    response = [[Jason.encode!(%{method: "isPrime", prime: prime?(number)})], "\n"]
    result = :gen_tcp.send(socket, response)
    Logger.debug("#{__MODULE__} Sent valid response '#{response}': #{inspect(result)}")
  end

  defp prime?(number) when not is_integer(number), do: false

  defp prime?(number) when number < 2, do: false

  defp prime?(n) when n in [2, 3], do: true

  defp prime?(number) do
    Logger.debug("#{__MODULE__} Calculating prime status of '#{number}'")

    if rem(number, 2) == 0 do
      false
    else
      limit = number |> :math.sqrt() |> trunc()

      Enum.reduce_while(1..limit, false, fn i, _prev ->
        factor = 2 * i + 1

        if rem(number, factor) == 0 do
          {:halt, false}
        else
          {:cont, true}
        end
      end)
    end
  end
end
