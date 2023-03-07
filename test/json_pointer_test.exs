defmodule JsonPointerTest do
  use ExUnit.Case, async: true

  doctest JsonPointer

  describe "for the resolve_json!/2 function" do
    test "a string path against an array raises" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!([1, 2, 3], ["foo"])
      end
    end

    test "a missing path raises" do
      assert_raise ArgumentError,
                   ~S(object at `/` of {"bar":"baz"} cannot access with key `foo`),
                   fn ->
                     JsonPointer.resolve_json!(%{"bar" => "baz"}, ["foo"])
                   end
    end

    test "true is ok with empty list" do
      assert true == JsonPointer.resolve_json!(true, [])
    end

    test "false is ok with empty list" do
      assert false == JsonPointer.resolve_json!(false, [])
    end

    test "nil is ok with empty list" do
      assert nil == JsonPointer.resolve_json!(nil, [])
    end

    test "number is ok with empty list" do
      assert 1 == JsonPointer.resolve_json!(1, [])
      assert 1.1 == JsonPointer.resolve_json!(1.1, [])
    end

    test "string is ok with empty list" do
      assert "foo" == JsonPointer.resolve_json!("foo", [])
    end

    test "true fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!(true, ["foo"])
      end
    end

    test "false fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!(false, ["foo"])
      end
    end

    test "nil fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!(nil, ["foo"])
      end
    end

    test "number fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!(1, ["foo"])
      end

      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!(1.1, ["foo"])
      end
    end

    test "string fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve_json!("foo", ["foo"])
      end
    end

    test "multi-level entry works" do
      data =
        Jason.decode!(
          ~S({"oneOf":[{"multipleOf":5,"type":"number"},{"multipleOf":3,"type":"number"},{"type":"object"}]})
        )

      assert 5 == JsonPointer.resolve_json!(data, ["oneOf", "0", "multipleOf"])
    end

    test "join" do
      pointer = JsonPointer.from_uri("/foo")
      assert "/foo/bar" == JsonPointer.to_uri(JsonPointer.join(pointer, "bar"))
    end

    test "escaped" do
      pointer = JsonPointer.from_uri("/definitions")
      joind = JsonPointer.join(pointer, "foo\"bar")

      data =
        Jason.decode!(
          ~S({"definitions":{"foo\"bar":{"type":"number"}},"properties":{"foo\"bar":{"$ref":"#/definitions/foo%22bar"}}})
        )

      JsonPointer.resolve_json!(data, joind)
    end
  end
end
