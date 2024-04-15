defmodule ExplorerTA.OverlapTest do
  use ExUnit.Case, async: true

  alias Explorer.Backend.Series
  alias Explorer.Series
  alias ExplorerTA.Overlap
  alias ExplorerTA.TestHelpers

  ## Setup

  setup_all {ExplorerTA.TestHelpers, :setup_python}
  setup_all {ExplorerTA.TestHelpers, :setup_explorer}

  ## Tests

  test "dema/2 Exponential Moving Average", %{python_env: python_env, df: df} do
    close = TestHelpers.df_get_col(python_env, "close")
    pandas_ta = TestHelpers.pandas_ta(python_env, "dema", [close, 25])

    explorer_ta = Overlap.dema(df["close"], 25)

    assert_series_equals explorer_ta, pandas_ta
  end

  test "ema/2 Exponential Moving Average", %{python_env: python_env, df: df} do
    close = TestHelpers.df_get_col(python_env, "close")
    pandas_ta = TestHelpers.pandas_ta(python_env, "ema", [close, 25])

    explorer_ta = Overlap.ema(df["close"], 25)

    assert_series_equals explorer_ta, pandas_ta
  end

  test "rma/2 Exponential Moving Average", %{python_env: python_env, df: df} do
    close = TestHelpers.df_get_col(python_env, "close")
    pandas_ta = TestHelpers.pandas_ta(python_env, "rma", [close, 25])

    explorer_ta = Overlap.rma(df["close"], 25)

    assert_series_equals explorer_ta, pandas_ta
  end

  test "sma/2 - Simple Moving Average", %{python_env: python_env, df: df} do
    close = TestHelpers.df_get_col(python_env, "close")
    pandas_ta = TestHelpers.pandas_ta(python_env, "sma", [close, 25])

    explorer_ta = Overlap.sma(df["close"], 25)

    assert_series_equals explorer_ta, pandas_ta
  end

  ## Private functions

  def assert_series_equals(s1, s2, chunk_size \\ :infinity) do
    s1 = s1 |> Series.round(10) |> Series.to_list()
    s2 = s2 |> Series.round(10) |> Series.to_list()

    case chunk_size do
      :infinity ->
        assert s1 == s2

      _ ->
        s1
        |> Enum.chunk_every(chunk_size)
        |> Enum.zip(Enum.chunk_every(s2, chunk_size))
        |> Enum.each(fn {chunk1, chunk2} ->
          assert chunk1 == chunk2
        end)
    end
  end
end
