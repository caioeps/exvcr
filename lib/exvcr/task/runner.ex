defmodule ExVCR.Task.Runner do
  @moduledoc """
  Provides task processing logics, which will be invoked by custom mix tasks.
  """
  import ExPrintf
  @header_format "  %-40s %-30s\n"
  @count_format  "  %-40s %-30d\n"
  @date_format   "%04d/%02d/%02d %02d:%02d:%02d"
  @json_file_pattern %r/\.json$/

  @doc """
  Use specified path to show the list of vcr cassettes.
  """
  def show_vcr_cassettes(path_list) do
    Enum.each(path_list, fn(path) ->
      read_cassettes(path) |> print_cassettes(path)
      IO.puts ""
    end)
  end

  defp read_cassettes(path) do
    file_names = find_json_files(path)
    date_times = Enum.map(file_names, &(extract_last_modified_time(path, &1)))
    Enum.zip(file_names, date_times)
  end

  defp find_json_files(path) do
    if File.exists?(path) do
      File.ls!(path)
        |> Enum.filter(&(&1 =~ @json_file_pattern))
        |> Enum.sort
    else
      raise ExVCR.PathNotFoundError.new(message: "Specified path '#{path}' for reading cassettes was not found.")
    end
  end

  defp extract_last_modified_time(path, file_name) do
    {{year, month, day}, {hour, min, sec}} = File.stat!(Path.join(path, file_name)).mtime
    sprintf(@date_format, [year, month, day, hour, min, sec])
  end

  defp print_cassettes(items, path) do
    IO.puts "Showing list of cassettes in [#{path}]"
    printf(@header_format, ["[File Name]", "[Last Update]"])
    Enum.each(items, fn({name, date}) -> printf(@header_format, [name, date]) end)
  end


  @doc """
  Use specified path to delete cassettes.
  """
  def delete_cassettes(path, file_patterns, is_interactive // false) do
    path |> find_json_files
         |> Enum.filter(&(&1 =~ file_patterns))
         |> Enum.each(&(delete_and_print_name(path, &1, is_interactive)))
  end

  defp delete_and_print_name(path, file_name, true) do
    line = IO.gets("delete #{file_name}? ")
    if String.upcase(line) == "Y\n" do
      delete_and_print_name(path, file_name, false)
    end
  end

  defp delete_and_print_name(path, file_name, false) do
    case Path.expand(file_name, path) |> File.rm do
      :ok    -> IO.puts "Deleted #{file_name}."
      :error -> IO.puts "Failed to delete #{file_name}"
    end
  end


  @doc """
  Check and show which cassettes are used by the test execution.
  """
  def check_cassettes(record) do
    count_hash = create_count_hash(record.files, HashDict.new)
    Enum.each(record.dirs, fn(dir) ->
      cassettes = read_cassettes(dir)
      print_check_cassettes(cassettes, dir, count_hash)
      IO.puts ""
    end)
  end

  defp create_count_hash([], acc), do: acc
  defp create_count_hash([head|tail], acc) do
    file = Path.basename(head)
    count = HashDict.get(acc, file, 0)
    hash  = HashDict.put(acc, file, count + 1)
    create_count_hash(tail, hash)
  end

  defp print_check_cassettes(items, path, counts_hash) do
    IO.puts "Showing hit counts of cassettes in [#{path}]"
    printf(@header_format, ["[File Name]", "[Hit Counts]"])
    Enum.each(items, fn({name, _date}) ->
      printf(@count_format, [name, HashDict.get(counts_hash, name, 0)])
    end)
  end
end