defmodule ProtoHackers.PriceServer do
  use GenServer

  require Logger

  defstruct [:listen_socket, :supervisor]

  @message_length_byts 9

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
      backlog: 100
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
    process_messages(socket, [])
    :gen_tcp.close(socket)
  end

  defp process_messages(socket, prices) do
    case :gen_tcp.recv(socket, @message_length_byts, 10_000) do
      {:ok, data} ->
        Logger.debug("#{__MODULE__} received message #{inspect(data)}")

        case handle_message(socket, prices, data) do
          {:error, reason} ->
            Logger.debug("#{__MODULE__} could not handle message: #{inspect(reason)}")

          {:ok, new_prices} ->
            process_messages(socket, new_prices)
        end

      {:error, :closed} ->
        Logger.debug("#{__MODULE__} connection closed.")

      {:error, reason} ->
        Logger.debug("#{__MODULE__} error #{inspect(reason)}")
    end
  end

  defp handle_message(
         _socket,
         prices,
         "I" <> <<timestamp::big-signed-integer-32, price::big-signed-integer-32>>
       ) do
    Logger.debug("#{__MODULE__} recording price #{price} at timestamp #{timestamp}")
    {:ok, [{timestamp, price} | prices]}
  end

  defp handle_message(
         socket,
         prices,
         "Q" <> <<filter_start::big-signed-integer-32, filter_end::big-signed-integer-32>>
       ) do
    matching_prices =
      prices
      |> Enum.filter(fn {ts, _price} -> ts >= filter_start and ts <= filter_end end)
      |> Enum.map(fn {_ts, price} -> price end)

    average =
      if Enum.empty?(matching_prices),
        do: 0,
        else: trunc(Enum.sum(matching_prices) / length(matching_prices))

    reply = <<average::big-signed-integer-32>>
    result = :gen_tcp.send(socket, reply)

    Logger.debug(
      "#{__MODULE__} sent average price #{average} from #{filter_start} to #{filter_end}: #{result}"
    )

    {:ok, prices}
  end

  defp handle_message(_, _, _), do: {:error, :malformed_message}
end
