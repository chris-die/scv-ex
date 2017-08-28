defmodule EventProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    require ExAws

    # TODO: create the queue if it doesn't exist
    # TODO: error handling

    {:ok, response} =
      Application.get_env(:event_processor, :sqs_event_queue_name)
        |> ExAws.SQS.get_queue_url
        |> ExAws.request

    queue_url = String.replace(response.body.queue_url, "https://", "")
        |> String.split("/")
        |> tl
        |> Enum.join("/")

    # List all child processes to be supervised
    children = [
      Supervisor.child_spec(
        EventProcessor.SQSProducer,
        start: {EventProcessor.SQSProducer, :start_link, ["/#{queue_url}"]},
        type: :worker
      ),
      Supervisor.child_spec(
        EventProcessor.SQSConsumer,
        start: {EventProcessor.SQSConsumer, :start_link, ["/#{queue_url}"]},
        type: :worker
      )
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
