defmodule Timecop do
  alias Timecop.{Clock, ClockSup}
  
  defdelegate start_clock(params \\ %{}), to: ClockSup, as: :start_child
  
  defdelegate list_of_clocks(), to: ClockSup
  
  defdelegate get_state(clock), to: Clock
  
  defdelegate press(clock, index), to: Clock
  
  defdelegate pause(clock), to: Clock
  
  defdelegate resume(clock), to: Clock
  
  defdelegate reset(clock), to: Clock
  
  defdelegate stop_clock(clock), to: Clock, as: :stop
end
