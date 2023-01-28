defmodule JsonPointer do
  @moduledoc false

  # JSONPointer implementation.  Internally, it's managed as a
  # list of strings, with the head of the list being the outermost
  # leaf in the JSON structure, and the end of the list being the
  # root.

  @type t :: [String.t()]
  alias Exonerate.Type

  @spec from_uri(String.t()) :: t
  @doc """
  converts a uri to a JSONJsonPointer

  ```elixir
  iex> alias Exonerate.JsonPointer
  iex> JsonPointer.from_uri("/") # the root-only case
  []
  iex> JsonPointer.from_uri("/bar/foo")
  ["foo", "bar"]
  iex> JsonPointer.from_uri("/baz/foo~0bar")
  ["foo~bar", "baz"]
  iex> JsonPointer.from_uri("/currency/%E2%82%AC")
  ["€", "currency"]
  ```
  """
  def from_uri("/" <> rest) do
    rest
    |> URI.decode()
    |> String.split("/", trim: true)
    |> Enum.map(&deescape/1)
  end

  @spec to_uri(t, keyword) :: String.t()
  @doc """
  creates a JSONPointer to its URI equivalent.

  options
  - `:authority` prepends a context to the uri.

  ```elixir
  iex> JsonPointer.to_uri(["foo", "bar"])
  "/bar/foo"
  iex> JsonPointer.to_uri(["foo~bar", "baz"])
  "/baz/foo~0bar"
  iex> JsonPointer.to_uri(["€", "currency"])
  "/currency/%E2%82%AC"
  iex> JsonPointer.to_uri([], authority: "foo")
  "foo#/"
  ```
  """
  def to_uri(path, opts \\ []) do
    str =
      path
      |> Enum.map(&escape/1)
      |> Enum.map(&URI.encode/1)
      |> Enum.join("/")

    lead =
      List.wrap(
        if opts[:authority] do
          [opts[:authority], "#"]
        end
      )

    IO.iodata_to_binary([lead, "/", str])
  end

  @spec eval(pointer :: t, data :: Type.json()) :: Type.json()
  @doc """
  evaluates a JSONPointer given a pointer and some json data

  ```elixir
  iex> JsonPointer.eval([], true)
  true
  iex> JsonPointer.eval(["foo~bar"], %{"foo~bar" => "baz"})
  "baz"
  iex> JsonPointer.eval(["€", "1"], %{"€" => ["quux", "ren"]})
  "ren"
  ```
  """
  def eval([], data), do: data

  def eval([leaf | root], data) do
    case eval(root, data) do
      array when is_list(array) ->
        get_array(array, leaf, root)

      object when is_map(object) ->
        get_object(object, leaf, root)

      _ ->
        raise ArgumentError, message: "#{type_name(data)} can not take a path"
    end
  end

  defp get_array(array, leaf, where) do
    case Integer.parse(leaf) do
      {number, ""} ->
        Enum.at(array, number)

      _ ->
        raise ArgumentError,
          message: "array at `#{to_uri(where)}` cannot access at non-numerical value #{leaf}"
    end
  end

  defp get_object(object, leaf, where) do
    case Map.get(object, leaf) do
      {:ok, value} ->
        value

      _ ->
        raise ArgumentError, message: "object at `#{to_uri(where)}` cannot access at key `where`"
    end
  end

  defp type_name(data) when is_nil(data), do: "null"
  defp type_name(data) when is_boolean(data), do: "boolean"
  defp type_name(data) when is_number(data), do: "number"
  defp type_name(data) when is_binary(data), do: "string"
  defp type_name(data) when is_list(data), do: "array"
  defp type_name(data) when is_map(data), do: "object"

  @spec deescape(String.t()) :: String.t()
  defp deescape(string) do
    string
    |> String.replace("~1", "/")
    |> String.replace("~0", "~")
  end

  @spec escape(String.t()) :: String.t()
  defp escape(string) do
    string
    |> String.replace("~", "~0")
    |> String.replace("/", "~1")
  end
end
