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

  elixir
  #iex> JsonPointer.from_uri("/") # the root-only case
  #[]
  #iex> JsonPointer.from_uri("/foo/bar")
  #["foo", "bar"]
  #iex> JsonPointer.from_uri("/foo~0bar/baz")
  ["foo~bar", "baz"]


  #iex> JsonPointer.from_uri("/currency/%E2%82%AC")
  #["currency", "€"]
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

  #iex> JsonPointer.to_uri(["foo", "bar"])
  #"/foo/bar"
  #iex> JsonPointer.to_uri(["foo~bar", "baz"])
  #"/foo~0bar/baz"
  #iex> JsonPointer.to_uri(["currency","€"])
  #"/currency/%E2%82%AC"
  #iex> JsonPointer.to_uri([], authority: "foo")
  "foo#/"
  ```
  """
  def to_uri(pointer, opts \\ []) do
    str =
      pointer
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

  #iex> JsonPointer.eval([], true)
  #true
  #iex> JsonPointer.eval(["foo~bar"], %{"foo~bar" => "baz"})
  #"baz"
  iex> JsonPointer.eval(["€", "1"], %{"€" => ["quux", "ren"]})
  "ren"
  ```
  """
  def eval(pointer, data), do: eval(pointer, data, [], data)

  defp eval([], data, _path_rev, _src), do: data

  defp eval([leaf | root], array, pointer_rev, src) when is_list(array) do
    eval(root, get_array(array, leaf, pointer_rev, src), [leaf | pointer_rev], src)
  end

  defp eval([leaf | root], object, pointer_rev, src) when is_map(object) do
    eval(root, get_object(object, leaf, pointer_rev, src), [leaf | pointer_rev], src)
  end

  defp eval([leaf | _], other, pointer_rev, src) do
    raise ArgumentError, message: "#{type_name(other)} at #{path(pointer_rev)} of #{inspect src} can not take the path #{leaf}"
  end

  defp get_array(array, leaf, pointer_rev, src) do
    with {index, ""} <- Integer.parse(leaf),
         nil <- if(index < 0, do: :bad_index),
         {:ok, content} <- get_array_index(array, index) do
      content
    else
      :bad_index ->
        raise ArgumentError,
          message: "array at `#{path(pointer_rev)}` of #{Jason.encode! src} does not have an item at index #{leaf}"

      _ ->
        raise ArgumentError,
          message: "array at `#{path(pointer_rev)}` of #{Jason.encode! src} cannot access with non-numerical value #{leaf}"
    end
  end

  defp get_array_index([item | _], 0), do: {:ok, item}
  defp get_array_index([_ | rest], index), do: get_array_index(rest, index - 1)
  defp get_array_index([], _), do: :bad_index

  defp get_object(object, leaf, pointer_rev, src) do
    case Map.fetch(object, leaf) do
      {:ok, value} ->
        value

      _ ->
        raise ArgumentError,
          message: "object at `#{path(pointer_rev)}` of #{Jason.encode! src} cannot access with key `#{leaf}`"
    end
  end

  defp type_name(data) when is_nil(data), do: "null"
  defp type_name(data) when is_boolean(data), do: "boolean"
  defp type_name(data) when is_number(data), do: "number"
  defp type_name(data) when is_binary(data), do: "string"
  defp type_name(data) when is_list(data), do: "array"
  defp type_name(data) when is_map(data), do: "object"

  defp path(pointer_rev) do
    pointer_rev
    |> Enum.reverse()
    |> to_uri
  end

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
