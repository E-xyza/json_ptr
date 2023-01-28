defmodule JsonPointerTest do
  use ExUnit.Case, async: true

  doctest JsonPointer

  describe "for the eval/2 function" do
    test "a string path against an array raises" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], [1, 2, 3])
      end
    end

    test "a missing path raises" do
      assert_raise KeyError, fn ->
        JsonPointer.eval(["foo"], %{"bar" => "baz"})
      end
    end

    test "true is ok with empty list" do
      assert true == JsonPointer.eval([], true)
    end

    test "false is ok with empty list" do
      assert false == JsonPointer.eval([], false)
    end

    test "nil is ok with empty list" do
      assert nil == JsonPointer.eval([], nil)
    end

    test "number is ok with empty list" do
      assert 1 == JsonPointer.eval([], 1)
      assert 1.1 == JsonPointer.eval([], 1.1)
    end

    test "string is ok with empty list" do
      assert "foo" == JsonPointer.eval([], "foo")
    end

    test "true fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], true)
      end
    end

    test "false fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], false)
      end
    end

    test "nil fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], nil)
      end
    end

    test "number fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], 1)
      end

      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], 1.1)
      end
    end

    test "string fails with list" do
      assert_raise ArgumentError, fn ->
        JsonPointer.eval(["foo"], "foo")
      end
    end
  end
end
