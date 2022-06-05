defmodule Cache do
  use GenServer

  @type key :: atom()
  @type ttl :: non_neg_integer()
  @type options :: list()
  @type time_out :: non_neg_integer()
  @type refresh_interval :: non_neg_integer()
  @type result :: {:ok, any()} |
                  {:error, time_out()} |
                  {:error, :not_registered}


  @spec start_link([
          {:debug, [:log | :statistics | :trace | {any, any}]}
          | {:hibernate_after, :infinity | non_neg_integer}
          | {:name, atom | {:global, any} | {:via, atom, any}}
          | {:spawn_opt, [:link | :monitor | {any, any}]}
          | {:timeout, :infinity | non_neg_integer}
        ]) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], [{:name, __MODULE__}|opts])
  end

  @spec stop :: :ok
  def stop() do
    GenServer.cast(Cache, :stop)
  end

  @spec register_function(fun(), key(), ttl(), refresh_interval()) :: :ok | {:error, :already_registered}
  def register_function(fun, key, ttl, refresh_interval) when is_function(fun, 0) and
                                                              is_atom(key) and
                                                              is_integer(ttl) and
                                                              is_integer(refresh_interval) and
                                                              ttl > 0 and refresh_interval > 0 do
    GenServer.call(Cache, {:register_fun, fun, key, ttl, refresh_interval})
  end

  @spec get(key(), time_out(), options()) :: result()
  def get(key, time_out, _options) when is_atom(key) and
                                   is_integer(time_out) and
                                   time_out > 0 do
    GenServer.call(Cache, {:get, key, time_out})
  end

  @impl true
  @spec init([]) :: {:ok, []}
  def init([]) do
    :ets.new(:cache, [:named_table, :public, {:keypos, 1}])
    {:ok, []}
  end

  @impl true
  def handle_call({:register_fun, fun, key, ttl, refresh_interval}, _from, state) do
    case :ets.lookup(:cache, key) do
      [] ->
        now = CacheUtils.get_current_time_in_millisec()
        :ets.insert(:cache, {key, fun.(), ttl, refresh_interval, now})
        CacheStore.start_link(key, fun, refresh_interval)
        {:reply, :ok, [key|state]}
      [_value] -> {:reply, {:error, :already_registered}, state}
    end
  end
  def handle_call({:get, key, time_out}, _from, state) do
    case :ets.lookup(:cache, key) do
      [] -> {:reply, {:error, :not_registered}, state}
      [{key, value, ttl, _refresh_interval, then}] ->
        reply = get_value(key, value, ttl, then, time_out)
        {:reply, reply, state}
    end
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, state}
  end
  def handle_cast(_info, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.map(state, fn(key) -> exit(key) end)
  end

  defp get_value(key, value, ttl, then, time_out) do
    now = CacheUtils.get_current_time_in_millisec()
    case now - then < ttl do
      :true -> {:ok, value}
      :false -> CacheStore.get(key, time_out)
    end
  end
end
