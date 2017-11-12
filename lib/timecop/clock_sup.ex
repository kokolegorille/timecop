defmodule Timecop.ClockSup do
  use Supervisor
  alias Timecop.Clock
  @name __MODULE__

  def start_link(_params) do
    Supervisor.start_link(@name, nil, name: @name)
  end

  def start_child(initial_state \\ %{}) do
    initial_state = %{
      uuid: UUID.uuid4(),
      created_at: :os.system_time(:millisecond)
    } |> Map.merge(initial_state)
    
    Supervisor.start_child(__MODULE__, [initial_state])
  end

  def init(_) do
    children = [
      worker(Clock, [], restart: :temporary)
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
  
  def list_of_clocks do
    Supervisor.which_children(@name) 
    |> Enum.map(&elem(&1, 1))
    |> Enum.map(&Clock.get_state(&1))
  end
end