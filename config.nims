task run, "run rx":
  --noNimblePath
  switch("lib", "~/.choosenim/toolchains/nim-0.17.0/lib")
  --threads: on
  --run
  switch("out", "rxx")
  setCommand "c", "rx"

task tests, "test rx":
  --threads: on
  --run
  --path: "."
  setCommand "c", "test"