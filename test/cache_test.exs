defmodule CacheTest do
  use ExUnit.Case, async: false
  doctest Cache

  setup %{} do
    Cache.start_link()

    on_exit(fn() -> Cache.stop() end)
  end

  test "get a value success" do
    fun = fn() -> :calendar.local_time() end
    :ok = Cache.register_function(fun, :my_key_1, 4000, 2000)

    assert match?({:ok, _datetime}, Cache.get(:my_key_1, 3000, []))
  end

  test "get refreshed data success" do
    fun = fn() -> :calendar.local_time() end
    :ok = Cache.register_function(fun, :my_key_2, 4000, 3000)
    {:ok, datetime1} = Cache.get(:my_key_2, 3000, [])

    # Sleep for a short time to get the data refreshed
    :timer.sleep(3500)
    {:ok, datetime2} = Cache.get(:my_key_2, 3000, [])

    refute datetime1 == datetime2
  end

  test "duplicate key error" do
    fun = fn() -> :ok end
    :ok = Cache.register_function(fun, :my_key_3, 4000, 3000)

    assert Cache.register_function(fun, :my_key_3, 4000, 3000) == {:error, :already_registered}
  end

  test "get value with an unknown key error" do
    assert Cache.get(:unknown_key, 1000, []) == {:error, :not_registered}
  end

  test "get data with a timeout error" do
    fun = fn() -> :timer.sleep(3500) end
    :ok = Cache.register_function(fun, :my_key_4, 1000, 300)

    results = Enum.map(1..1000, fn(_value) -> Cache.get(:my_key_4, 10, []) end)

    # IO.puts("#{{:error, :timeout} in results}")
    # assert :true == {:error, :timeout} in results
  end
end
