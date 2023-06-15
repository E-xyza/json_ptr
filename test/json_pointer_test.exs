defmodule JsonPtrTest do
  use ExUnit.Case, async: true

  doctest JsonPtr

  describe "for the resolve_json!/2 function" do
    test "a string path against an array raises" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!([1, 2, 3], ["foo"])
      end
    end

    test "a missing path raises" do
      assert_raise ArgumentError,
                   ~S(object at `/` of {"bar":"baz"} cannot access with key `foo`),
                   fn ->
                     JsonPtr.resolve_json!(%{"bar" => "baz"}, ["foo"])
                   end
    end

    test "true is ok with empty list" do
      assert true == JsonPtr.resolve_json!(true, [])
    end

    test "false is ok with empty list" do
      assert false == JsonPtr.resolve_json!(false, [])
    end

    test "nil is ok with empty list" do
      assert nil == JsonPtr.resolve_json!(nil, [])
    end

    test "number is ok with empty list" do
      assert 1 == JsonPtr.resolve_json!(1, [])
      assert 1.1 == JsonPtr.resolve_json!(1.1, [])
    end

    test "string is ok with empty list" do
      assert "foo" == JsonPtr.resolve_json!("foo", [])
    end

    test "true fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!(true, ["foo"])
      end
    end

    test "false fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!(false, ["foo"])
      end
    end

    test "nil fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!(nil, ["foo"])
      end
    end

    test "number fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!(1, ["foo"])
      end

      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!(1.1, ["foo"])
      end
    end

    test "string fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPtr.resolve_json!("foo", ["foo"])
      end
    end

    test "multi-level entry works" do
      data =
        Jason.decode!(
          ~S({"oneOf":[{"multipleOf":5,"type":"number"},{"multipleOf":3,"type":"number"},{"type":"object"}]})
        )

      assert 5 == JsonPtr.resolve_json!(data, ["oneOf", "0", "multipleOf"])
    end

    test "join" do
      pointer = JsonPtr.from_path("/foo")
      assert "/foo/bar" == JsonPtr.to_path(JsonPtr.join(pointer, "bar"))
    end

    test "escaped" do
      pointer = JsonPtr.from_path("/definitions")
      joind = JsonPtr.join(pointer, "foo\"bar")

      data =
        Jason.decode!(
          ~S({"definitions":{"foo\"bar":{"type":"number"}},"properties":{"foo\"bar":{"$ref":"#/definitions/foo%22bar"}}})
        )

      JsonPtr.resolve_json!(data, joind)
    end
  end
end
