defmodule ProtoHackers.PriceServer.Test do
  use ExUnit.Case

  @messages [
    Base.decode16!("490000303900000065"),
    Base.decode16!("490000303A00000066"),
    Base.decode16!("490000303B00000064"),
    Base.decode16!("490000A00000000005"),
    Base.decode16!("510000300000004000")
  ]

  test "handles all kinds of price data" do
    {:ok, socket} = :gen_tcp.connect(~c"localhost", 10_002, mode: :binary, active: false)
    Enum.each(@messages, &:gen_tcp.send(socket, &1))
    assert :gen_tcp.recv(socket, 4, 5000) == {:ok, Base.decode16!("00000065")}
    :gen_tcp.shutdown(socket, :write)
  end
end
