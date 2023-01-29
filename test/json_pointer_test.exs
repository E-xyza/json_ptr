defmodule JsonPointerTest do
  use ExUnit.Case, async: true

  doctest JsonPointer

  describe "for the eval/2 function" do
    test "a string path against an array raises" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval([1, 2, 3], ["foo"])
      end
    end

    test "a missing path raises" do
      assert_raise ArgumentError,
                   ~S(object at `/` of {"bar":"baz"} cannot access with key `foo`),
                   fn ->
                     JsonPointer.eval(%{"bar" => "baz"}, ["foo"])
                   end
    end

    test "true is ok with empty list" do
      assert true == JsonPointer.eval(true, [])
    end

    test "false is ok with empty list" do
      assert false == JsonPointer.eval(false, [])
    end

    test "nil is ok with empty list" do
      assert nil == JsonPointer.eval(nil, [])
    end

    test "number is ok with empty list" do
      assert 1 == JsonPointer.eval(1, [])
      assert 1.1 == JsonPointer.eval(1.1, [])
    end

    test "string is ok with empty list" do
      assert "foo" == JsonPointer.eval("foo", [])
    end

    test "true fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(true, ["foo"])
      end
    end

    test "false fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(false, ["foo"])
      end
    end

    test "nil fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(nil, ["foo"])
      end
    end

    test "number fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(1, ["foo"])
      end

      assert_raise ArgumentError, fn ->
        JsonPointer.eval(1.1, ["foo"])
      end
    end

    test "string fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval("foo", ["foo"])
      end
    end
  end
end
