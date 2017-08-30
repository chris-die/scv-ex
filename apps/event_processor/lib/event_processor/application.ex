defmodule EventProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    require ExAws

    queue_url = queue_url(
      Application.get_env(:event_processor, :sqs_event_queue_name)
    )

    # List all child processes to be supervised
    #
    # The 10-messages-per-request limit for `receive messages` requests to SQS
    # constrains the amount of demand a producer stage can fulfil.
    #
    # The workaround is to create multiple proucer and consumer stages.

    children = Enum.flat_map(0..9, &([
      Supervisor.child_spec(
        EventProcessor.SQSProducer,
        start: {EventProcessor.SQSProducer, :start_link, [&1, "/#{queue_url}"]},
        type: :worker,
        id: {EventProcessor.SQSProducer, &1}
      ),
      Supervisor.child_spec(
        EventProcessor.SQSConsumer,
        start: {EventProcessor.SQSConsumer, :start_link, [&1, "/#{queue_url}"]},
        type: :worker,
        id: {EventProcessor.SQSConsumer, &1}
      )
    ]))

    Supervisor.start_link(
      children,
      [strategy: :one_for_one, name: EventProcessor.Supervisor]
    )
  end

  defp queue_url(queue_name) do
    queue_name
      |> ExAws.SQS.get_queue_url
      |> ExAws.request
      |> queue_url_response(queue_name)
  end

  defp queue_url_response({:ok, response}, _) do
    response.body.queue_url
      |> String.replace("https://", "")
      |> String.split("/")
      |> tl
      |> Enum.join("/")
  end

  defp queue_url_response({:error, {_, _, detail}}, queue_name) do
    case detail.code do
      "AWS.SimpleQueueService.NonExistentQueue" ->
        queue_name
          |> ExAws.SQS.create_queue(
            receive_message_wait_time_seconds: 20
          )
          |> ExAws.request
          |> queue_url_response(queue_name)
      _ ->
        raise RuntimeError, message: "#{detail.code} - #{detail.message}"
    end
  end

end
