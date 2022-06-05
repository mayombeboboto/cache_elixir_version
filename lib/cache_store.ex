defmodule CacheStore do
  use GenServer

  @type key :: atom()
  @type refresh_interval :: non_neg_integer()
  @type time_out :: non_neg_integer()
  @type result :: {:ok, any()} | {:error, :timeout}

  defmodule State do
    defstruct key: nil,
              func: nil,
              refresh_interval: nil
  end

  @spec start_link(key(), fun(), refresh_interval()) :: {:ok, pid()}
  def start_link(name, func, refresh_interval) do
    GenServer.start(__MODULE__, [name, func, refresh_interval], [{:name, name}])
  end

  @spec get(key(), time_out()) :: result()
  def get(name, time_out) do
    try do
      GenServer.call(name, :get, time_out)
    rescue
      _error -> {:error, :timeout}
    end
  end

  @impl true
  def init([key, fun, refresh_interval]) do
    :erlang.process_flag(:trap_exit, :true)
    :erlang.send_after(refresh_interval, self(), :refresh)
    {:ok, %State{ key: key,
                  func: fun,
                  refresh_interval: refresh_interval }}
  end

  @impl true
  def handle_call(:get, _from, state) do
    fun = state.func
    refresh_interval = state.refresh_interval
    :erlang.send_after(refresh_interval, self(), :refresh)
    {:reply, {:ok, fun.()}, state}
  end

  @impl true
  def handle_cast(_msg, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, state=%State{ key: key, func: fun }) do
    [{key, _value, ttl, refresh_interval, _then}] = :ets.lookup(:cache, key)
    new_value = fun.()
    now = CacheUtils.get_current_time_in_millisec()
    :ets.insert(:cache, {key, new_value, ttl, refresh_interval, now})
    :erlang.send_after(refresh_interval, self(), :refresh)
    {:noreply, state}
  end
  def handle_info(_info, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, _state) do
    :ok
  end
end
