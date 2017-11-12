defmodule Timecop.Clock do
  use GenServer
  require Logger
  
  @name __MODULE__
  @tick_time 100
  @default_number_of_clocks 2
  
  defstruct [
    uuid: nil,
    count: 0,
    status: :running,
    number_of_clocks: nil,    
    active_clock: 0,
    remainings: %{},
    ticker_ref: nil,
    #
    clock_type: :game_type
  ]
  
  # API
  
  def start_link(initial_state \\ %{}) do
    uuid = initial_state
    |> Map.get(:uuid, UUID.uuid4())
    
    GenServer.start_link(@name, initial_state, name: via_tuple(uuid))
  end
  
  def get_state(clock) when is_pid(clock), do: GenServer.call(clock, :get_state)
  def get_state(clock) when is_binary(clock), do: get_state(whereis(clock))
  
  def whereis(name), do: :gproc.whereis_name({:n, :l, {:clock, name}})
  
  def stop(clock) when is_pid(clock), do: GenServer.cast(clock, :stop)
  def stop(clock) when is_binary(clock), do: stop(whereis(clock))
  
  def press(clock, index) when is_pid(clock), do: GenServer.cast(clock, {:press, index})
  def press(clock) when is_binary(clock), do: press(whereis(clock))
  
  def pause(clock) when is_pid(clock), do: GenServer.cast(clock, :pause)
  def pause(clock) when is_binary(clock), do: pause(whereis(clock))
  
  def resume(clock) when is_pid(clock), do: GenServer.cast(clock, :resume)
  def resume(clock) when is_binary(clock), do: resume(whereis(clock))
  
  def reset(clock) when is_pid(clock), do: GenServer.cast(clock, :reset)
  def reset(clock) when is_binary(clock), do: reset(whereis(clock))
  
  # SERVER 
  
  def init(initial_state) do
    state = build_state(initial_state)
    {:ok, struct(@name, state)}
  end
  
  def handle_call(:get_state, _from, state) do
    {:reply, serialize_state(state), state}
  end
  
  def handle_cast({:press, index}, %{
    count: count,
    active_clock: active_clock,
    number_of_clocks: number_of_clocks,
    remainings: remainings,
    ticker_ref: ticker_ref,
    status: status
  } = state) 
  when index == active_clock and status == :running do 
    
    # Update clock with remains of ticker
    elapsed = Process.read_timer(ticker_ref)
    new_remainings = update_active_clock(active_clock, remainings, elapsed)
    
    # Cancel timer
    Process.cancel_timer(ticker_ref)
    
    # Set the active clock to the next clock
    new_active_clock = rem(active_clock + 1, number_of_clocks)
    
    # Start a new timer
    new_ticker_ref = Process.send_after(self(), :tick, @tick_time)
    
    # Update state
    new_state = %{state |
      count: count + 1,
      active_clock: new_active_clock,
      remainings: new_remainings,
      ticker_ref: new_ticker_ref
    }
    
    {:noreply, new_state}
  end
  def handle_cast({:press, index}, state) do 
    Logger.debug "clock #{index} is not active"
    {:noreply, state}
  end
    
  def handle_cast(:pause, %{ticker_ref: ticker_ref} = state) 
  when is_nil(ticker_ref) do 
    {:noreply, state}
  end
  def handle_cast(:pause, %{
    active_clock: active_clock, 
    remainings: remainings,
    ticker_ref: ticker_ref
  } = state) do 
    
    key = get_key(active_clock)
    elapsed = Process.read_timer(ticker_ref)
    new_remainings = update_active_clock(active_clock, remainings, elapsed)
    
    Process.cancel_timer(ticker_ref)
    
    new_state = if Map.get(new_remainings, key) <= 0 do
      
      # Period has ended, check if lost on time, or start new period
      # eg: byoyomi
      
      Logger.debug "clock #{active_clock} lost on time"
      %{state | 
        remainings: new_remainings, 
        status: :time_elapsed,
        ticker_ref: nil
      }
    else
      Logger.debug "clock #{active_clock} paused #{inspect new_remainings}"
      %{state | 
        remainings: new_remainings,
        ticker_ref: nil,
        status: :paused
      }
    end
    {:noreply, new_state}
  end
  
  def handle_cast(:resume, %{ticker_ref: ticker_ref} = state) 
  when is_nil(ticker_ref) do 
    new_ticker_ref = Process.send_after(self(), :tick, @tick_time)
    {:noreply, %{state | ticker_ref: new_ticker_ref, status: :running}}
  end
  def handle_cast(:resume, state), do: {:noreply, state}
  
  def handle_cast(:reset, state), do: {:noreply, state}
  
  def handle_cast(:stop, state), do: {:stop, :normal, %{state | status: :closing}}
  
  def handle_info(:tick, %{
    active_clock: active_clock, 
    remainings: remainings
  } = state) do
    
    key = get_key(active_clock)
    new_remainings = update_active_clock(active_clock, remainings, @tick_time)    
    new_state = if Map.get(new_remainings, key) <= 0 do
      
      # Period has ended, check if lost on time, or start new period
      # eg: byoyomi
      
      Logger.debug "clock #{active_clock} lost on time"
      %{state | 
        remainings: new_remainings, 
        status: :time_elapsed,
        ticker_ref: nil
      }
    else
      Logger.debug "clock #{active_clock} ticking #{inspect new_remainings}"
      new_ticker_ref = Process.send_after(self(), :tick, @tick_time)
      %{state | 
        remainings: new_remainings,
        ticker_ref: new_ticker_ref
      }
    end
    
    {:noreply, new_state}
  end
  
  def terminate(reason, _state) do
		Logger.debug "#{@name} is stopping : #{inspect reason}"
		:ok
  end
  
  # PRIVATE

  defp via_tuple(name) do
    {:via, :gproc, {:n, :l, {:clock, name}}}
  end
  
  # Customize state here!
  defp serialize_state(%{
    count: count, 
    status: status, 
    active_clock: active_clock,
    remainings: remainings
  } = state) do
    %{
      count: count,
      status: status,
      active_clock: active_clock,
      remainings: remainings
    }
  end
  
  defp update_active_clock(active_clock, remainings, elapsed) do
    Map.update!(remainings, get_key(active_clock), &(&1 - (elapsed || 0)))
  end
  
  defp get_key(active_clock), do: String.to_atom("clock_#{active_clock}")
  
  defp build_state(initial_state) do
    number_of_clocks = Map.get(initial_state, :number_of_clocks, @default_number_of_clocks)
    active_clock = Map.get(initial_state, :active_clock, 0)
    
    remainings = 0..(number_of_clocks - 1) |> Enum.reduce(%{}, fn x, acc -> 
      key = get_key(active_clock)
      
      # Setup initial time, based on settings
      # Can setup multiple periods
      # Each period can have different period_type
      
      Map.put(acc, key, 30_000)
    end)
    ticker_ref = Process.send_after(self(), :tick, @tick_time)
    
    Map.merge(initial_state, %{
      active_clock: active_clock,
      number_of_clocks: number_of_clocks,
      remainings: remainings,
      ticker_ref: ticker_ref
    })
  end
end