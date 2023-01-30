defmodule JsonPointerTest do
  use ExUnit.Case, async: true

  doctest JsonPointer

  describe "for the resolve!/2 function" do
    test "a string path against an array raises" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!([1, 2, 3], ["foo"])
      end
    end

    test "a missing path raises" do
      assert_raise ArgumentError,
                   ~S(object at `/` of {"bar":"baz"} cannot access with key `foo`),
                   fn ->
                     JsonPointer.resolve!(%{"bar" => "baz"}, ["foo"])
                   end
    end

    test "true is ok with empty list" do
      assert true == JsonPointer.resolve!(true, [])
    end

    test "false is ok with empty list" do
      assert false == JsonPointer.resolve!(false, [])
    end

    test "nil is ok with empty list" do
      assert nil == JsonPointer.resolve!(nil, [])
    end

    test "number is ok with empty list" do
      assert 1 == JsonPointer.resolve!(1, [])
      assert 1.1 == JsonPointer.resolve!(1.1, [])
    end

    test "string is ok with empty list" do
      assert "foo" == JsonPointer.resolve!("foo", [])
    end

    test "true fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!(true, ["foo"])
      end
    end

    test "false fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!(false, ["foo"])
      end
    end

    test "nil fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!(nil, ["foo"])
      end
    end

    test "number fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!(1, ["foo"])
      end

      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!(1.1, ["foo"])
      end
    end

    test "string fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.resolve!("foo", ["foo"])
      end
    end

    test "multi-level entry works" do
      data =
        Jason.decode!(
          ~S({"oneOf":[{"multipleOf":5,"type":"number"},{"multipleOf":3,"type":"number"},{"type":"object"}]})
        )

      assert 5 == JsonPointer.resolve!(data, ["oneOf", "0", "multipleOf"])
    end
  end
end
