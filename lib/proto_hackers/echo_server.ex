defmodule ProtoHackers.EchoServer do
  use GenServer

  require Logger

  defstruct [:listen_socket, :supervisor]

  @buffer_limit 1024 * 100

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
    case receive_bytes(socket) do
      {:ok, data} ->
        result = :gen_tcp.send(socket, data)
        Logger.debug("#{__MODULE__} Sent data: #{inspect(result)}")

      {:error, reason} ->
        Logger.error("Error reading data from socket: #{inspect(reason)}")
    end

    :gen_tcp.close(socket)
  end

  defp receive_bytes(socket, buffer \\ "", bytes_in_buffer \\ 0) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} when byte_size(data) + bytes_in_buffer > @buffer_limit ->
        Logger.error("#{__MODULE__} received too much data!")
        {:error, :too_much_data}

      {:ok, data} ->
        Logger.debug("#{__MODULE__} data received: #{inspect(data)}")
        receive_bytes(socket, [buffer, data], bytes_in_buffer + byte_size(data))

      {:error, :closed} ->
        Logger.debug("#{__MODULE__} connection closed. full message: #{inspect(buffer)}")
        {:ok, buffer}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
