"""
    YaesuCAT

A Julia package for controlling Yaesu transceivers via the CAT (Computer Aided Transceiver)
protocol. Currently supports the FT-891, designed for extensibility to other Yaesu models.

## Design Principles

This package follows idiomatic Julia design:

- **Multiple dispatch** over type hierarchies replaces runtime type checks entirely.
  Every CAT command is a singleton type; `set!` and `read` dispatch on `(Radio, Command, Value)`.
- **Parametric types** ensure all connection handles are concretely typed at compile time.
- **Trait-based capabilities** encode which commands support Set/Read/Answer without inheritance.
- **Value types** replace raw integers/strings — `CW()` not `"3"`, `WPM(17)` not `17`.

## Architecture (mirrors [kd-boss/CAT](https://github.com/kd-boss/CAT))

The C++ reference library uses `Namespace::Command::Set/Read/Answer` with `enum class` parameters.
We translate this to Julia as:

| C++ (kd-boss/CAT)                            | Julia (YaesuCAT.jl)                        |
|:----------------------------------------------|:--------------------------------------------|
| `Yaesu::Commands::FT891::FreqA::Set(freq)`   | `set!(radio, FrequencyVFO{A}(), Hz(freq))` |
| `Yaesu::Commands::FT891::FreqA::Read()`      | `read(radio, FrequencyVFO{A}())`           |
| `Yaesu::Commands::FT891::FreqA::Answer(buf)` | `decode(FrequencyVFO{A}(), raw)`           |
| `enum class MeterType { COMP, ALC, ... }`    | `abstract type MeterType end; struct COMP <: MeterType end` |
| Namespace per radio                           | Dispatch on `AbstractRadio` subtypes       |

## Quick Start

```julia
using YaesuCAT

radio = FT891("/dev/ttyUSB0"; baudrate=9600)
connect!(radio)

set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
set!(radio, Mode(), CW())
set!(radio, KeySpeed(), WPM(17))

freq = read(radio, FrequencyVFO{A}())  # → Hz(14060000)

# CW via keyer memory (radio's internal keyer handles timing)
set!(radio, KeyerMemory(1), "CQ CQ DE SA0KAM K")
set!(radio, CWKeying(), KeyerSlot(1))

# CW via RTS line toggling (you control the timing)
keyer = RTSKeyer("/dev/ttyUSB1")
send_morse!(keyer, "CQ CQ DE SA0KAM K", WPM(17))

disconnect!(radio)
```
"""
module YaesuCAT

using LibSerialPort

# ── Type hierarchy ──────────────────────────────────────────────
include("types.jl")

# ── Value types (compile-time type-stable parameters) ──────────
include("values.jl")

# ── CAT protocol encoding/decoding ─────────────────────────────
include("protocol.jl")

# ── Command definitions ────────────────────────────────────────
include("commands/commands.jl")

# ── Transport (serial I/O) ─────────────────────────────────────
include("transport.jl")

# ── Radio implementations ──────────────────────────────────────
include("radios.jl")

# ── CW / Morse code keying ─────────────────────────────────────
include("morse.jl")

# ── Exports ─────────────────────────────────────────────────────

# Radio types
export FT891

# Type hierarchy (for dispatch and documentation)
export AbstractRadio, AbstractYaesuRadio, AbstractCommand,
       SetReadCommand, SetOnlyCommand, ReadOnlyCommand,
       AbstractVFO, AbstractValue, AbstractMode, AbstractBreakInMode,
       AbstractAGCMode, AbstractMeterType, AbstractSwitch, AbstractBand,
       AbstractTransport, AbstractCWKeyer

# Core verbs
export connect!, disconnect!, set!, read, send_cmd!, read_response, query

# Protocol (for testing and custom tools)
export encode_set, encode_read, decode_answer

# VFO tags
export A, B

# Command types
export FrequencyVFO, Mode, AFGain, MicGain, MonitorLevel, TXState,
       KeySpeed, Keyer, KeyPitch, CWKeying, KeyerMemory,
       BreakIn, CWSpot, AutoNotch, ManualNotch, Contour,
       IFShift, AGCFunction, Identification, Information,
       MeterSwitch, ReadMeter, Power, BandSelect, BandUp, BandDown,
       Lock, AntennaControl, FastStep, Clarifier, VoxStatus,
       VoxGain, VoxDelay, Dimmer, MenuAccess

# Value types
export Hz, WPM, MilliSeconds, Level, Pitch
export CW, CW_R, LSB, USB, AM, AM_N, FM, FM_N, DATA_L, DATA_U, RTTY_L, RTTY_U
export KeyerSlot, MessageSlot
export BreakInOff, SemiBreakIn, FullBreakIn
export AGC_Off, AGC_Fast, AGC_Mid, AGC_Slow, AGC_Auto
export COMP, ALC, PO, SWR, METER_ID
export On, Off
export Band160m, Band80m, Band60m, Band40m, Band30m, Band20m,
       Band17m, Band15m, Band12m, Band10m, Band6m

# Morse / CW keying
export RTSKeyer, DTRKeyer, send_morse!, text_to_morse, MORSE_TABLE
export DIT, DAH, ELEMENT_GAP, CHAR_GAP, WORD_GAP, duration_units, is_key_down

# Transport (for testing and custom backends)
export SerialTransport, NullTransport

end # module
