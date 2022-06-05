defmodule CacheUtils do
  @spec get_current_time_in_millisec() :: non_neg_integer
  def get_current_time_in_millisec() do
    {_date, time} = :calendar.local_time()
    :calendar.time_to_seconds(time) * 1000
  end
end
