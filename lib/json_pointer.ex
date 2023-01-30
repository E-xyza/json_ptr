defmodule JsonPointer do
  @moduledoc """
  Implementation of JSONPointer.

  A JSONpointer URI is converted into an internal term representation and this representation
  may be used with `resolve!/2` to parse a decoded JSON term.

  See: https://www.rfc-editor.org/rfc/rfc6901
  for the specification.

  Note:  Do not rely on the private internal implementation of JSON, it may change in the future.
  """

  @opaque t :: [String.t()]

  @type json :: nil | boolean | String.t() | number | [json] | %{optional(String.t()) => json}

  @spec from_uri(String.t()) :: t
  @doc """
  converts a uri to a JSONJsonPointer

  ```elixir
  iex> JsonPointer.from_uri("/") # the root-only case
  []
  iex> JsonPointer.from_uri("/foo/bar")
  ["foo", "bar"]
  iex> JsonPointer.from_uri("/foo~0bar/baz")
  ["foo~bar", "baz"]
  iex> JsonPointer.from_uri("/currency/%E2%82%AC")
  ["currency", "€"]
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

  ```
  iex> JsonPointer.to_uri(["foo", "bar"])
  "/foo/bar"
  iex> JsonPointer.to_uri(["foo~bar", "baz"])
  "/foo~0bar/baz"
  iex> JsonPointer.to_uri(["currency","€"])
  "/currency/%E2%82%AC"
  iex> JsonPointer.to_uri([], authority: "foo")
  "foo#/"
  ```
  """
  def to_uri(pointer, opts \\ []) do
    str = Enum.map_join(pointer, "/", fn route -> route |> escape |> URI.encode() end)

    lead =
      List.wrap(
        if opts[:authority] do
          [opts[:authority], "#"]
        end
      )

    IO.iodata_to_binary([lead, "/", str])
  end

  # placeholder in case we change this to be more sophisticated
  defguardp is_pointer(term) when is_list(term)

  @spec resolve!(data :: json(), t | String.t()) :: json()
  @doc """
  resolves a JSONPointer given a pointer and some json data

  ```elixir
  iex> JsonPointer.resolve!(true, "/")
  true
  iex> JsonPointer.resolve!(%{"foo~bar" => "baz"}, "/foo~0bar")
  "baz"
  iex> JsonPointer.resolve!(%{"€" => ["quux", "ren"]}, JsonPointer.from_uri("/%E2%82%AC/1"))
  "ren"
  ```
  """
  def resolve!(data, pointer) do
    case resolve(data, pointer) do
      {:ok, result} -> result
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @spec resolve(data :: json(), t | String.t()) :: {:ok, json()} | {:error, String.t()}
  @doc """
  resolves a JSONPointer given a pointer and some json data

  ```elixir
  iex> JsonPointer.resolve(true, "/")
  {:ok, true}
  iex> JsonPointer.resolve(%{"foo~bar" => "baz"}, "/foo~0bar")
  {:ok, "baz"}
  iex> JsonPointer.resolve(%{"€" => ["quux", "ren"]}, JsonPointer.from_uri("/%E2%82%AC/1"))
  {:ok, "ren"}
  ```
  """
  def resolve(data, pointer) when is_binary(pointer),
    do: resolve(data, JsonPointer.from_uri(pointer))

  def resolve(data, pointer) when is_pointer(pointer), do: do_resolve(pointer, data, [], data)

  defp do_resolve([], data, _path_rev, _src), do: {:ok, data}

  defp do_resolve([leaf | root], array, pointer_rev, src) when is_list(array) do
    with {:ok, value} <- get_array(array, leaf, pointer_rev, src) do
      do_resolve(root, value, [leaf | pointer_rev], src)
    end
  end

  defp do_resolve([leaf | root], object, pointer_rev, src) when is_map(object) do
    with {:ok, value} <- get_object(object, leaf, pointer_rev, src) do
      do_resolve(root, value, [leaf | pointer_rev], src)
    end
  end

  defp do_resolve([leaf | _], other, pointer_rev, src) do
    {:error,
     "#{type_name(other)} at #{path(pointer_rev)} of #{inspect(src)} can not take the path #{leaf}"}
  end

  defp get_array(array, leaf, pointer_rev, src) do
    with {index, ""} <- Integer.parse(leaf),
         nil <- if(index < 0, do: :bad_index),
         {:ok, content} <- get_array_index(array, index) do
      {:ok, content}
    else
      :bad_index ->
        {:error,
         "array at `#{path(pointer_rev)}` of #{Jason.encode!(src)} does not have an item at index #{leaf}"}

      _ ->
        {:error,
         "array at `#{path(pointer_rev)}` of #{Jason.encode!(src)} cannot access with non-numerical value #{leaf}"}
    end
  end

  defp get_array_index([item | _], 0), do: {:ok, item}
  defp get_array_index([_ | rest], index), do: get_array_index(rest, index - 1)
  defp get_array_index([], _), do: :bad_index

  defp get_object(object, leaf, pointer_rev, src) do
    case Map.fetch(object, leaf) do
      fetched = {:ok, _} ->
        fetched

      _ ->
        {:error,
         "object at `#{path(pointer_rev)}` of #{Jason.encode!(src)} cannot access with key `#{leaf}`"}
    end
  end

  @spec traverse(t, String.t) :: t
  def traverse(pointer, next_path) do
    pointer ++ [next_path |> escape |> URI.encode]
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
