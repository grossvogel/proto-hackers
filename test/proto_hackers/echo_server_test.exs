defmodule ProtoHackers.EchoServer.Test do
  use ExUnit.Case

  test "handles concurrent connections" do
    tasks =
      for _ <- 1..5 do
        Task.async(fn ->
          {:ok, socket} = :gen_tcp.connect(~c"localhost", 10_000, mode: :binary, active: false)
          assert :gen_tcp.send(socket, "foo") == :ok
          assert :gen_tcp.send(socket, "bar") == :ok
          :gen_tcp.shutdown(socket, :write)
          assert :gen_tcp.recv(socket, 0, 5000) == {:ok, "foobar"}
        end)
      end

    Enum.each(tasks, &Task.await/1)
  end
end
