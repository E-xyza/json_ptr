defmodule JsonPointer.MixProject do
  use Mix.Project

  def project do
    [
      app: :json_ptr,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      package: [
        description: "JSONPointer tools",
        licenses: ["MIT"],
        files: ~w(lib mix.exs README* LICENSE* VERSIONS*),
        links: %{"GitHub" => "https://github.com/E-xyza/json_pointer"}
      ],
      deps: deps(),
      source_url: "https://github.com/E-xyza/json_pointer/",
      docs: [main: "JsonPointer"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4.0"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
