defmodule EventProcessor.Mixfile do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :event_processor,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.5",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      name: "Serato SCV Event Processor",
      docs: [source_ref: "v#{@version}", main: "EventProcessor"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      registered: [:event_processor],
      extra_applications: [:logger, :ex_aws, :hackney],
      mod: {EventProcessor.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_aws, "~> 1.1.4"},
      {:poison, ">= 1.2.0"},
      {:hackney, "~> 1.6"},
      {:sweet_xml, "~> 0.6"},
      {:gen_stage, "~> 0.12.0"},
      {:configparser_ex, "~> 0.2.1"},
      {:credo, "~> 0.4.3", only: [:dev, :test]},
      {:ex_doc,  ">= 0.0.0", only: :dev}
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      # {:sibling_app_in_umbrella, in_umbrella: true},
    ]
  end
end
