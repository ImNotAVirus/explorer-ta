defmodule ExplorerTA.Overlap do
  @moduledoc """
  TODO: Documentation
  """

  alias Explorer.Series

  ## Public API

  @doc """
  Exponential Moving Average (EMA)

  The Exponential Moving Average is more responsive moving average compared to the
  Simple Moving Average (SMA).  The weights are determined by alpha which is
  proportional to it's length.  There are several different methods of calculating
  EMA.  One method uses just the standard definition of EMA and another uses the
  SMA to generate the initial value for the rest of the calculation.

  Sources:

    - https://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:moving_averages
    - https://www.investopedia.com/ask/answers/122314/what-exponential-moving-average-ema-formula-and-how-ema-calculated.asp

  """
  def ema(src, length) do
    alpha = 2 / (length + 1)

    sma_nth = src |> Series.slice(0..(length - 1)) |> Series.mean()
    list = Enum.reverse([sma_nth | List.duplicate(nil, length - 1)])
    start = Series.from_list(list)

    Series.concat(
      start,
      Series.slice(src, length..-1)
    )
    |> Series.ewm_mean(alpha: alpha, adjust: false)
  end

  @doc """
  wildeR's Moving Average (RMA)

  The WildeR's Moving Average is simply an Exponential Moving Average (EMA) with
  a modified alpha = 1 / length.

  Sources:

    - https://tlc.thinkorswim.com/center/reference/Tech-Indicators/studies-library/V-Z/WildersSmoothing
    - https://www.incrediblecharts.com/indicators/wilder_moving_average.php

  NOTE: Pinescript use SMA (see `ema/2`)

  """
  def rma(src, length) do
    alpha = 1 / length
    Series.ewm_mean(src, alpha: alpha, min_periods: length)
  end

  @doc """
  Simple Moving Average (SMA)

  The Simple Moving Average is the classic moving average that is the equally
  weighted average over n periods.

  Sources:

    - https://www.tradingtechnologies.com/help/x-study/technical-indicator-definitions/simple-moving-average-sma/
  """
  def sma(src, length) do
    src
    |> Series.window_mean(length)
    # Set nil values for the `length - 1` first values
    |> Series.shift(-(length - 1))
    |> Series.shift(length - 1)
  end
end
