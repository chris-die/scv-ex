defmodule EventProcessor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    require ExAws
    import Supervisor.Spec

    # TODO: create the queue if it doesn't exist
    # TODO: error handling

    {:ok, response} =
      Application.get_env(:event_processor, :sqs_event_queue_name)
        |> ExAws.SQS.get_queue_url
        |> ExAws.request

    # require Logger
    # Logger.debug(response.body.queue_url)
    
    # List all child processes to be supervised
    children = [
      worker(EventProcessor.SQSProducer, [response.body.queue_url]),
      worker(EventProcessor.SQSConsumer, [])
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: EventProcessor.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
