# YaesuCAT.jl

A Julia package for controlling Yaesu transceivers via the CAT (Computer Aided Transceiver)
protocol. Currently supports the **FT-891**, designed for extensibility to other models.

## Design Philosophy

This package uses idiomatic Julia patterns throughout:

| Principle | How |
|:----------|:----|
| **Multiple dispatch** | Every CAT command is a type; `set!`/`read` dispatch on `(Radio, Command, Value)` |
| **No type checking** | No `isa`, `typeof`, or `if/else` on types anywhere — behavior is selected via dispatch |
| **Parametric types** | `FT891{T}` is concrete for each transport; `FrequencyVFO{A}` vs `FrequencyVFO{B}` resolved at compile time |
| **Value types** | `Hz(14_060_000)` not `14060000`; `CW()` not `"3"` — prevents mixing units |
| **Testability** | `NullTransport` lets you test encoding/decoding without hardware |

## Reference

This package is inspired by [kd-boss/CAT](https://github.com/kd-boss/CAT), a C++ library
for Yaesu radio control. The Julia translation maps C++ patterns to Julia idioms:

| C++ (kd-boss/CAT) | Julia (YaesuCAT.jl) |
|:---|:---|
| `namespace Yaesu::Commands::FT891` | Dispatch on `FT891{T}` type |
| `struct Command { static Set(); Read(); Answer(); }` | `encode_set(cmd, val)`, `encode_read(cmd)`, `decode_answer(cmd, raw)` |
| `enum class MeterType { COMP, ALC, ... }` | `abstract type AbstractMeterType end; struct COMP <: AbstractMeterType end` |
| Capability via presence of static methods | Capability via abstract parent: `SetReadCommand`, `SetOnlyCommand`, `ReadOnlyCommand` |

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/mashu/YaesuCAT.jl")
```

## Quick Start

```julia
using YaesuCAT

radio = FT891("/dev/ttyUSB0"; baudrate=9600)
connect!(radio)

set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
set!(radio, Mode(), CW())
set!(radio, KeySpeed(), WPM(17))

freq = read(radio, FrequencyVFO{A}())  # → Hz(14060000)

disconnect!(radio)
```

For hardware setup, full usage examples, testing without a radio, and CW keying, see [Getting Started](guide.md) and [CW Keying](cw.md).
