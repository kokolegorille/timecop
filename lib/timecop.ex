defmodule Timecop do
  alias Timecop.{Clock, ClockSup}
  
  defdelegate start_clock(params \\ %{}), to: ClockSup, as: :start_child
  
  defdelegate list_of_clocks(), to: ClockSup
  
  defdelegate stop_clock(clock), to: Clock, as: :stop
end
