defmodule JsonPtr do
  @moduledoc """
  Implementation of JSONPointer.

  This module handles JSONPointers as an internal term representation and
  provides functions to manipulate the JSONPointer term and to use the
  representation to traverse or manipulate JSON data.

  See: https://www.rfc-editor.org/rfc/rfc6901
  for the specification.

  > #### Warning {: .warning}
  >
  > Do not rely on the private internal implementation of JSONPointer, it
  > may change in the future.
  """

  @opaque t :: [String.t()]

  @type json :: nil | boolean | String.t() | number | [json] | %{optional(String.t()) => json}

  @spec from_path(Path.t()) :: t
  @doc """
  converts a path to a JsonPtr

  ```elixir
  iex> JsonPtr.from_path("/") # the root-only case
  []
  iex> JsonPtr.from_path("/foo/bar")
  ["foo", "bar"]
  iex> JsonPtr.from_path("/foo~0bar/baz")
  ["foo~bar", "baz"]
  iex> JsonPtr.from_path("/currency/%E2%82%AC")
  ["currency", "€"]
  ```
  """
  def from_path(path) do
    path
    |> to_string
    |> URI.decode()
    |> String.split("/", trim: true)
    |> Enum.map(&deescape/1)
  end

  @spec from_uri(URI.t() | String.t()) :: t
  @doc """
  converts a URI (or a URI-string) to a JsonPtr.

  ```elixir
  iex> JsonPtr.from_uri("#/foo/bar")
  ["foo", "bar"]
  iex> JsonPtr.from_uri("/foo/bar")
  ["foo", "bar"]
  iex> JsonPtr.from_uri(%URI{path: "/foo/bar"})
  ["foo", "bar"]
  iex> JsonPtr.from_uri(%URI{fragment: "/foo/bar", host: "elixir-lang.org"})
  ["foo", "bar"]
  ```
  """
  def from_uri(%URI{
        fragment: nil,
        host: nil,
        query: nil,
        scheme: nil,
        userinfo: nil,
        port: nil,
        path: path
      })
      when is_binary(path) do
    from_path(path)
  end

  def from_uri(%URI{fragment: path}) do
    from_path(path)
  end

  def from_uri(uri) when is_binary(uri) do
    uri
    |> URI.new!()
    |> from_uri
  end

  @spec to_path(t) :: Path.t()
  @doc """
  creates a JsonPtr to its path equivalent.

  ```elixir
  iex> JsonPtr.to_path(["foo", "bar"])
  "/foo/bar"
  iex> JsonPtr.to_path(["foo~bar", "baz"])
  "/foo~0bar/baz"
  iex> JsonPtr.to_path(["currency","€"])
  "/currency/%E2%82%AC"
  ```
  """
  def to_path(pointer) do
    pointer
    |> Enum.map(fn route -> route |> escape |> URI.encode() end)
    |> then(&Path.join(["/" | &1]))
  end

  @spec to_uri(t) :: URI.t()
  @doc """
  creates a `t:URI.t/0` struct out of a JsonPtr.

  The JsonPtr is placed in the `:fragment` field of the URI.

  ```elixir
  iex> JsonPtr.to_uri(["foo", "bar"])
  %URI{fragment: "/foo/bar"}
  ```
  """
  def to_uri(pointer) do
    %URI{fragment: to_path(pointer)}
  end

  # placeholder in case we change this to be more sophisticated
  defguardp is_pointer(term) when is_list(term)

  @spec resolve_json!(data :: json(), t | String.t()) :: json()
  @doc """
  given some JSON data, resolves the content pointed to by the JsonPtr.

  > #### Note {: .info}
  >
  > the json pointer is the *second* parameter to this function.

  ```elixir
  iex> JsonPtr.resolve_json!(true, "/")
  true
  iex> JsonPtr.resolve_json!(%{"foo~bar" => "baz"}, "/foo~0bar")
  "baz"
  iex> JsonPtr.resolve_json!(%{"€" => ["quux", "ren"]}, JsonPtr.from_path("/%E2%82%AC/1"))
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
  given some JSON data, resolves the content pointed to by the JsonPtr.

  > #### Note {: .info}
  >
  > the json pointer is the *second* parameter to this function.

  ```elixir
  iex> JsonPtr.resolve_json(true, "/")
  {:ok, true}
  iex> JsonPtr.resolve_json(%{"foo~bar" => "baz"}, "/foo~0bar")
  {:ok, "baz"}
  iex> JsonPtr.resolve_json(%{"€" => ["quux", "ren"]}, JsonPtr.from_path("/%E2%82%AC/1"))
  {:ok, "ren"}
  ```
  """
  def resolve_json(data, pointer) when is_binary(pointer),
    do: resolve_json(data, JsonPtr.from_path(pointer))

  def resolve_json(data, pointer) when is_pointer(pointer),
    do: do_resolve_json(pointer, data, [], data)

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
  updates nested JSON data at the location given by the JsonPtr.

  ```elixir
  iex> ptr = JsonPtr.from_path("/foo/0")
  iex> JsonPtr.update_json!(%{"foo" => [1, 2]}, ptr, &(&1 + 1))
  %{"foo" => [2, 2]}
  iex> JsonPtr.update_json!(%{"foo" => %{"0" => 1}}, ptr, &(&1 + 1))
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
  appends path to the JsonPtr.  This may either be a `t:String.t`, a list of `t:String.t`.

  ```elixir
  iex> ptr = JsonPtr.from_path("/foo/bar")
  iex> ptr |> JsonPtr.join("baz") |> JsonPtr.to_path
  "/foo/bar/baz"
  iex> ptr |> JsonPtr.join(["baz", "quux"]) |> JsonPtr.to_path
  "/foo/bar/baz/quux"
  ```
  """
  def join(pointer, next_path) when is_binary(next_path) do
    pointer ++ [next_path |> URI.decode() |> deescape]
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
  rolls back the JsonPtr to the parent of its most distant leaf.

  ```elixir
  iex> {:ok, ptr} = "/foo/bar" |> JsonPtr.from_path |> JsonPtr.backtrack
  iex> JsonPtr.to_path(ptr)
  "/foo"
  ```
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

  ```elixir
  iex> {rest, last} = "/foo/bar" |> JsonPtr.from_path |> JsonPtr.pop
  iex> last
  "bar"
  iex> JsonPtr.to_path(rest)
  "/foo"
  iex> "/" |> JsonPtr.from_path |> JsonPtr.pop
  :error
  ```
  """
  def pop([]), do: :error

  def pop(pointer) do
    [last | rest] = Enum.reverse(pointer)
    {Enum.reverse(rest), last}
  end

  @spec map(t, json, (t, json -> result)) :: [result] when result: term
  @doc """
  Performs a map operation on the JSON data at the given pointer, analogous
  to `Enum.map/2`.

  The iterator function will be passed the updated pointer *and* the data at
  that pointer.

  ```elixir
  iex> ptr = JsonPtr.from_path("/foo")
  iex> JsonPtr.map(ptr, %{"foo" => %{"bar" => "baz"}}, fn ptr, data -> {JsonPtr.to_path(ptr), data} end)
  [{"/foo/bar", "baz"}]
  iex> JsonPtr.map(ptr, %{"foo" => ["bar", "baz"]}, fn ptr, data -> {JsonPtr.to_path(ptr), data} end)
  [{"/foo/0", "bar"}, {"/foo/1", "baz"}]
  ```
  """
  def map(pointer, data, fun) do
    case resolve_json(data, pointer) do
      {:ok, map} when is_map(map) ->
        Enum.map(map, fn {key, value} -> fun.(join(pointer, key), value) end)

      {:ok, list} when is_list(list) ->
        Enum.with_index(list, fn value, index -> fun.(join(pointer, "#{index}"), value) end)

      {:error, _} ->
        []
    end
  end

  @spec each(t, json, (t, json -> any)) :: :ok
  @doc """
  Performs a each operation on the JSON data at the given pointer, analogous
  to `Enum.each/2`.  Returns `:ok` when all iterations are complete

  The iterator function will be passed the updated pointer *and* the data at
  that pointer.

  ```elixir
  iex> ptr = JsonPtr.from_path("/foo")
  iex> JsonPtr.each(ptr, %{"foo" => ["bar", "baz"]}, fn ptr, data -> send(self(), {JsonPtr.to_path(ptr), data}) end)
  :ok
  iex> receive do data -> data end
  {"/foo/0", "bar"}
  iex> receive do data -> data end
  {"/foo/1", "baz"}
  ```
  """
  def each(pointer, data, fun) do
    case resolve_json(data, pointer) do
      {:ok, map} when is_map(map) ->
        Enum.each(map, fn {key, value} -> fun.(join(pointer, key), value) end)

      {:ok, list} when is_list(list) ->
        Enum.with_index(list, fn value, index -> fun.(join(pointer, "#{index}"), value) end)
        :ok

      {:error, _} ->
        :ok
    end
  end

  @spec reduce(t, json, acc, (t, json, acc -> acc)) :: acc when acc: term
  @doc """
  Performs a reduction operation on the JSON data at the given pointer, analogous
  to `Enum.reduce/3`.

  The iterator function will be passed the updated pointer, the data *and* the accumulator at
  that pointer.

  ```elixir
  iex> ptr = JsonPtr.from_path("/foo")
  iex> JsonPtr.reduce(ptr, %{"foo" => %{"bar" => "baz"}}, %{}, &Map.put(&3, JsonPtr.to_path(&1), &2))
  %{"/foo/bar" => "baz"}
  iex> JsonPtr.reduce(ptr, %{"foo" => ["bar", "baz"]}, %{}, &Map.put(&3, JsonPtr.to_path(&1), &2))
  %{"/foo/0" => "bar", "/foo/1" => "baz"}
  ```
  """
  def reduce(pointer, data, acc, fun) do
    case resolve_json(data, pointer) do
      {:ok, map} when is_map(map) ->
        Enum.reduce(map, acc, fn {key, value}, acc -> fun.(join(pointer, key), value, acc) end)

      {:ok, list} when is_list(list) ->
        list
        |> Enum.reduce({acc, 0}, fn value, {acc, index} ->
          {fun.(join(pointer, "#{index}"), value, acc), index + 1}
        end)
        |> elem(0)

      {:error, _} ->
        acc
    end
  end
end
