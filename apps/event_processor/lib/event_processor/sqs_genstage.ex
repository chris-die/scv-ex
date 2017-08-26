defmodule EventProcessor.SQSProducer do
  use GenStage

  def start_link(queue_name) do
    GenStage.start_link(__MODULE__, queue_name, name: __MODULE__)
  end

  def init(queue_name) do
    {:producer, %{queue: queue_name, current_demand: 0}}
  end

  def handle_cast(:check_messages, %{queue: _, current_demand: 0} = state) do
    {:noreply, [], state}
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

    {
      :noreply,
      response.body.messages,
      %{state | current_demand: state.current_demand - Enum.count(response.body.messages)}
    }
  end

  def handle_demand(demand, state) do
    GenStage.cast(__MODULE__, :check_messages)

    {
      :noreply,
      [],
      %{state | current_demand: demand + state.current_demand}
    }
  end
end

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
