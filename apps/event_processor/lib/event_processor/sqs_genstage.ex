defmodule EventProcessor.SQSProducer do
  use GenStage

  def start_link(id, queue_url) do
    GenStage.start_link(__MODULE__, {:ok, id, queue_url}, name: stage_name(id))
  end

  def init({:ok, id, queue_url}) do
    {:producer, %{id: id, queue_url: queue_url, current_demand: 0}}
  end

  def handle_cast(:check_messages, %{id: _, queue_url: _, current_demand: 0} = state) do
    {:noreply, [], state}
  end

  def handle_cast(:check_messages, state) do
    # TODO: error handling
    {:ok, response} =
      ExAws.SQS.receive_message(
        state.queue_url,
        max_number_of_messages: min(state.current_demand, 10),
        visibility_timeout: 10,
        wait_time_seconds: 20
      )
      |> ExAws.request

    state.id |> stage_name |> GenStage.cast(:check_messages)

    {
      :noreply,
      response.body.messages,
      %{state | current_demand: state.current_demand - Enum.count(response.body.messages)}
    }
  end

  def handle_demand(demand, state) do
    state.id |> stage_name |> GenStage.cast(:check_messages)

    {
      :noreply,
      [],
      %{state | current_demand: demand + state.current_demand}
    }
  end

  defp stage_name(id) do
    String.to_atom("#{__MODULE__}.#{id}")
  end
end

defmodule EventProcessor.SQSConsumer do
  use ConsumerSupervisor

  def start_link(id, queue_url) do
    name = String.to_atom("#{__MODULE__}.#{id}")
    ConsumerSupervisor.start_link(__MODULE__, {:ok, id, queue_url}, name: name)
  end

  def init({:ok, id, queue_url}) do
    children = [
      worker(EventProcessor.Processor, [queue_url], restart: :temporary),
      # Supervisor.child_spec(
      #   EventProcessor.Processor,
      #   start: {EventProcessor.Processor, :start_link, [queue_url]},
      #   type: :worker,
      #   restart: :temporary
      # )
    ]

    name = String.to_atom("Elixir.EventProcessor.SQSProducer.#{id}")
    subscriptions = [{name, [max_demand: 10, min_demand: 1]}]

    {:ok, children, strategy: :one_for_one, subscribe_to: subscriptions}
  end
end

defmodule EventProcessor.Processor do
  def start_link(queue_url, message) do
    Task.start_link(__MODULE__, :process_message, [queue_url, message])
  end

  def process_message(queue_url, message) do
    require Logger
    Logger.debug(inspect(message.body))

    ExAws.SQS.delete_message(queue_url, message.receipt_handle)
    |> ExAws.request
  end
end
