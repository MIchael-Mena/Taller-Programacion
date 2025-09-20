# IO.puts("Hello world from Elixir")
x = 1 + 2
IO.puts(x)
case {1, 2, 3} do
  {1, x, 3} when (x > 0 and x < 3) ->
    IO.puts("Will match")
  {1, x, 3} when (x < 0 or x > 3) ->
    IO.puts("Will not match")
  _ ->
    IO.puts("Would match, if guard condition were not satisfied")
end
# IO.puts("Will match")
