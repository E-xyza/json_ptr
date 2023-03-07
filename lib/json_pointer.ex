defmodule JsonPointer do
  @moduledoc """
  Implementation of JSONPointer.

  A JSONpointer URI is converted into an internal term representation and this representation
  may be used with `resolve_json!/2` to parse a decoded JSON term.

  See: https://www.rfc-editor.org/rfc/rfc6901
  for the specification.

  Note:  Do not rely on the private internal implementation of JSON, it may change in the future.
  """

  @opaque t :: [String.t()]

  @type json :: nil | boolean | String.t() | number | [json] | %{optional(String.t()) => json}

  @spec from_path(Path.t()) :: t
  @doc """
  converts a path to a JSONJsonPointer

  ```elixir
  iex> JsonPointer.from_path("/") # the root-only case
  []
  iex> JsonPointer.from_path("/foo/bar")
  ["foo", "bar"]
  iex> JsonPointer.from_path("/foo~0bar/baz")
  ["foo~bar", "baz"]
  iex> JsonPointer.from_path("/currency/%E2%82%AC")
  ["currency", "€"]
  ```
  """
  def from_path("/" <> rest) do
    rest
    |> URI.decode()
    |> String.split("/", trim: true)
    |> Enum.map(&deescape/1)
  end

  @spec to_path(t, keyword) :: Path.t()
  @doc """
  creates a JSONPointer to its URI equivalent.

  options
  - `:authority` prepends a context to the path.

  ```
  iex> JsonPointer.to_path(["foo", "bar"])
  "/foo/bar"
  iex> JsonPointer.to_path(["foo~bar", "baz"])
  "/foo~0bar/baz"
  iex> JsonPointer.to_path(["currency","€"])
  "/currency/%E2%82%AC"
  iex> JsonPointer.to_path([], authority: "foo")
  "foo#/"
  ```
  """
  def to_path(pointer, opts \\ []) do
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

  @spec resolve_json!(data :: json(), t | String.t()) :: json()
  @doc """
  resolve_jsons a JSONPointer given a pointer and some json data

  ```elixir
  iex> JsonPointer.resolve_json!(true, "/")
  true
  iex> JsonPointer.resolve_json!(%{"foo~bar" => "baz"}, "/foo~0bar")
  "baz"
  iex> JsonPointer.resolve_json!(%{"€" => ["quux", "ren"]}, JsonPointer.from_path("/%E2%82%AC/1"))
  "ren"
  ```
  """
  def resolve_json!(data, pointer) do
    case resolve_json(data, pointer) do
      {:ok, result} -> result
      {:error, msg} -> raise ArgumentError, msg
    end
  end

  @spec resolve_json(data :: json(), t | String.t()) :: {:ok, json()} | {:error, String.t()}
  @doc """
  resolve_jsons a JSONPointer given a pointer and some json data

  ```elixir
  iex> JsonPointer.resolve_json(true, "/")
  {:ok, true}
  iex> JsonPointer.resolve_json(%{"foo~bar" => "baz"}, "/foo~0bar")
  {:ok, "baz"}
  iex> JsonPointer.resolve_json(%{"€" => ["quux", "ren"]}, JsonPointer.from_path("/%E2%82%AC/1"))
  {:ok, "ren"}
  ```
  """
  def resolve_json(data, pointer) when is_binary(pointer),
    do: resolve_json(data, JsonPointer.from_path(pointer))

  def resolve_json(data, pointer) when is_pointer(pointer), do: do_resolve_json(pointer, data, [], data)

  defp do_resolve_json([], data, _path_rev, _src), do: {:ok, data}

  defp do_resolve_json([leaf | root], array, pointer_rev, src) when is_list(array) do
    with {:ok, value} <- get_array(array, leaf, pointer_rev, src) do
      do_resolve_json(root, value, [leaf | pointer_rev], src)
    end
  end

  defp do_resolve_json([leaf | root], object, pointer_rev, src) when is_map(object) do
    with {:ok, value} <- get_object(object, leaf, pointer_rev, src) do
      do_resolve_json(root, value, [leaf | pointer_rev], src)
    end
  end

  defp do_resolve_json([leaf | _], other, pointer_rev, src) do
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

  @spec update_json!(data :: json, t, (json -> json)) :: json
  @doc """
  updates nested json data at the expected location

  ```elixir
  iex> ptr = JsonPointer.from_path("/foo/0")
  iex> JsonPointer.update_json!(%{"foo" => [1, 2]}, ptr, &(&1 + 1))
  %{"foo" => [2, 2]}
  iex> JsonPointer.update_json!(%{"foo" => %{"0" => 1}}, ptr, &(&1 + 1))
  %{"foo" => %{"0" => 2}}
  ```
  """
  def update_json!(object, [head | rest], transformation) when is_map(object) do
    Map.update!(object, head, &update_json!(&1, rest, transformation))
  end

  def update_json!(list, [head | rest], transformation) when is_list(list) and is_binary(head) do
    update_json!(list, [String.to_integer(head) | rest], transformation)
  end

  def update_json!(list, [head | rest], transformation) when is_list(list) and is_integer(head) do
    List.update_at(list, head, &update_json!(&1, rest, transformation))
  end

  def update_json!(data, [], transformation), do: transformation.(data)

  @spec join(t, String.t() | [String.t()]) :: t
  @doc """
  appends information to the JsonPointer structure.  Can take either a url path-alike or a list of
  traversals.

  ```elixir
  iex> ptr = JsonPointer.from_path("/foo/bar")
  iex> ptr |> JsonPointer.join("baz") |> JsonPointer.to_path
  "/foo/bar/baz"
  iex> ptr |> JsonPointer.join("baz/quux") |> JsonPointer.to_path
  "/foo/bar/baz/quux"
  iex> ptr |> JsonPointer.join(["baz", "quux"]) |> JsonPointer.to_path
  "/foo/bar/baz/quux"
  ```
  """
  def join(pointer, next_path) when is_binary(next_path) do
    join(pointer, String.split(next_path, "/"))
  end

  def join(pointer, next_path) when is_list(next_path) do
    pointer ++ Enum.map(next_path, fn part -> part |> URI.decode() |> deescape end)
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
    |> to_path
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

  @spec backtrack(t) :: {:ok, t} | :error
  @doc """
  iex> {:ok, ptr} = "/foo/bar" |> JsonPointer.from_path |> JsonPointer.backtrack
  iex> JsonPointer.to_path(ptr)
  "/foo"
  """
  def backtrack([]), do: :error
  def backtrack(list), do: {:ok, do_backtrack(list, [])}

  defp do_backtrack([_last], so_far), do: Enum.reverse(so_far)
  defp do_backtrack([a | b], so_far), do: do_backtrack(b, [a | so_far])

  @spec backtrack!(t) :: t
  @doc """
  like `backtrack/1`, but raises if attempted to backtrack from the root.
  """
  def backtrack!(pointer) do
    case backtrack(pointer) do
      {:ok, pointer} ->
        pointer

      :error ->
        raise ArgumentError,
          message: "the JSONPointer `/` is a root pointer and cannot be backtracked"
    end
  end

  @spec pop(t) :: {t, String.t()} | :error
  @doc """
  returns the last part of the pointer and the pointer without it.
  iex> {rest, last} = "/foo/bar" |> JsonPointer.from_path |> JsonPointer.pop
  iex> last
  "bar"
  iex> JsonPointer.to_path(rest)
  "/foo"
  iex> "/" |> JsonPointer.from_path |> JsonPointer.pop
  :error
  """
  def pop([]), do: :error

  def pop(pointer) do
    [last | rest] = Enum.reverse(pointer)
    {Enum.reverse(rest), last}
  end
end
