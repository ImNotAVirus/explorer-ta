defmodule ExplorerTA.TestHelpers do
  @moduledoc """
  Helpers for interactions with Python and pandas-ta
  """

  alias Explorer.DataFrame, as: DF
  alias Explorer.Series

  @fixture_path Path.join(File.cwd!(), "test/fixtures/OANDA_XAUUSD, 5.csv")

  ## Public functions

  def setup_python(env) do
    python_path = Path.join(File.cwd!(), "test/python/bin/python3")
    {:ok, python_pid} = :python.start_link(python_path: String.to_charlist(python_path))
    python = fn m, f, a -> :python.call(python_pid, m, f, a) end
    call_func = fn m, f, a, k -> python.(:builtins, :call_func, [m, f, a, k]) end
    call_method = fn o, f, a, k -> python.(:builtins, :call_method, [o, f, a, k]) end

    # FIXME: not sure how to handle kwargs with erlport
    python.(:builtins, :exec, [
      """
      # Credits: https://github.com/heyoka/pythra/blob/master/priv/python/pythra/obj.py
      import builtins

      def attr(obj, attr_name):
        return getattr(obj, attr_name.decode("utf-8").replace("-", "_"))

      def get_module(modname):
        modname = modname.decode("utf-8")
        try:
          module = __import__('importlib').import_module(modname)
        except ImportError as err:
          parts = modname.split(".")
          modname = parts[0]
          submod = parts[1]
          try:
            parent_module = __import__('importlib').import_module(modname)
            module = attr(parent_module, bytes(submod, "utf-8"))
          except:
            raise(err)
        return module
        
      def kwargs_keys_to_strings(kwargs):
        return [(x.decode("utf-8"), y) for (x, y) in kwargs]

      def decode_args(arg_list):
        new_args = []
        for arg in arg_list:
          if isinstance(arg, bytes):
            arg = arg.decode("utf-8")
          new_args.append(arg)
        return new_args

      def decode_kwargs(kwarg_list):
        new_kwarg_list = []
        for (key, val) in list(kwarg_list):
          if isinstance(val, bytes):
            val = val.decode("utf-8")
          new_kwarg_list.append([key, val])
        return dict(kwargs_keys_to_strings(new_kwarg_list))
        
      def call_method(obj, funcname, args=[], kwarg_list=None):
        if len(kwarg_list) == 0:
          kwarg_list = []
        kwargs = decode_kwargs(kwarg_list)
        args = decode_args(args)
        return attr(obj, funcname)(*args, **kwargs)


      def call_func(modname, funcname, args=[], kwarg_list=None):
        module = get_module(modname)
        return call_method(module, funcname, args, kwarg_list)


      builtins.attr = attr
      builtins.get_module = get_module
      builtins.kwargs_keys_to_strings = kwargs_keys_to_strings
      builtins.decode_args = decode_args
      builtins.decode_kwargs = decode_kwargs
      builtins.call_method = call_method
      builtins.call_func = call_func
      """
    ])

    python_df = call_func.("pandas", "read_csv", [@fixture_path], [])

    # pd.Index(datetime(1970, 1, 1) + sec * pd.offsets.Second())
    datetime = call_func.("datetime", "datetime", [1970, 1, 1], [])
    time = call_method.(python_df, "get", ["time"], [])
    second = call_func.("pandas._libs.tslibs.offsets", "Second", [], [])
    offset_ms = call_func.("operator", "mul", [time, second], [])
    date_series = call_func.("operator", "add", [datetime, offset_ms], [])
    # Cast date_series to pandas datetime to avoid warning
    date_series = call_func.("pandas", "to_datetime", [date_series], [])
    index = call_func.("pandas", "Index", [date_series], [])

    # df.set_index(index) + df.drop(columns="time)
    python_df = call_method.(python_df, "set_index", [index], [])
    python_df = call_method.(python_df, "drop", [], columns: "time")

    Map.put(env, :python_env, %{
      python: python,
      python_df: python_df,
      python_func: call_func,
      python_method: call_method
    })
  end

  def setup_explorer(env) do
    df = DF.from_csv!(@fixture_path)

    time =
      df["time"]
      |> Series.multiply(1000)
      |> Series.cast({:duration, :millisecond})
      |> Series.add(~N"1970-01-01T00:00:00Z")

    df = DF.put(df, "time", time)

    Map.put(env, :df, df)
  end

  def df_get_col(%{python_method: python_method, python_df: python_df}, col) do
    python_method.(python_df, "get", [col], [])
  end

  def pandas_ta(%{python_func: python_func, python_method: python_method}, indicator, args) do
    series = python_func.("pandas_ta", indicator, args, [])
    csv = python_method.(series, "to_csv", [], [])

    csv
    |> List.to_string()
    |> DF.load_csv!()
    |> DF.rename(["time", "values"])
    |> Access.fetch!("values")
  end
end
