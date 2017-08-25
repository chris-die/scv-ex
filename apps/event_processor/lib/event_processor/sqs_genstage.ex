defmodule EventProcessor.SQSProducer do
  use GenStage

  def start_link(queue_name, opts \\ []) do
    GenStage.start_link(__MODULE__, queue_name, opts)
  end

  def init(queue_name) do
    {:producer, %{queue: queue_name, current_demand: 0}}
  end

  def handle_cast(:check_messages, %{queue: _, current_demand: 0}) do
    {:noreply, [], 0}
  end

  def handle_cast(:check_messages, state) do
    # TODO: error handling
    {:ok, response} =
      ExAws.SQS.receive_message(
        state.queue,
        max_number_of_messages: min(state.current_demand, 10)
      )
      |> ExAws.request

    GenStage.cast(__MODULE__, :check_messages)

    {:noreply, response.body.messages, state.current_demand - Enum.count(response.body.messages)}
  end

  def handle_demand(demand, state) do
    GenStage.cast(__MODULE__, :check_messages)

    {:noreply, [], demand + state.current_demand}
  end
end

# defmodule EventProcessor.SQSProducer do
#   @moduledoc """
#   This is a simple producer that counts from the given
#   number whenever there is a demand.
#   """

#   use GenStage

#   def start_link(initial) when is_integer(initial) do
#     GenStage.start_link(__MODULE__, initial, name: __MODULE__)
#   end

#   ## Callbacks

#   def init(initial) do
#     {:producer, initial}
#   end

#   def handle_demand(demand, counter) when demand > 0 do
#     # If the counter is 3 and we ask for 2 items, we will
#     # emit the items 3 and 4, and set the state to 5.
#     events = Enum.to_list(counter..counter+demand-1)
#     {:noreply, events, counter + demand}
#   end
# end



defmodule EventProcessor.SQSConsumer do
  use ConsumerSupervisor

  def start_link() do
    ConsumerSupervisor.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    children = [
      worker(EventProcessor.Processor, [], restart: :temporary),
    ]

    {:ok, children, strategy: :one_for_one, subscribe_to: [{EventProcessor.SQSProducer, max_demand: 10, min_demand: 1}]}
  end
end

defmodule EventProcessor.Processor do
  def start_link(message) do
    Task.start_link(__MODULE__, :process_message, [message])
  end

  def process_message(message) do
    require Logger
    Logger.debug("Sleeping for 2s")
    :timer.sleep(2_000)
  end
end

# defmodule EventProcessor.SQSConsumer do
#   #use ConsumerSupervisor

#   def start_link() do
#     children = [EventProcessor.Processor]
#     opts = [strategy: :one_for_one, subscribe_to: [{EventProcessor.SQSProducer, max_demand: 10, min_demand: 1}]]
#     ConsumerSupervisor.start_link(children, opts)
#   end
# end

# defmodule EventProcessor.Processor do
#   def start_link(message) do
#     Task.start_link(__MODULE__, :process_message, [message])
#   end

#   def process_message(message) do
#     require Logger
#     Logger.debug("Sleeping for 2s")
#     :timer.sleep(2_000)
#   end

#   def child_spec(opts) do
#     %{
#       id: __MODULE__,
#       start: {__MODULE__, :start_link, [opts]},
#       type: :worker,
#       restart: :temporary
#     }
#   end
# end
