# ═══════════════════════════════════════════════════════════════════
# values.jl — Concrete value types for type-safe CAT parameters
#
# Instead of passing raw integers and strings, we wrap every
# parameter in a purpose-built type. This:
#   1. Prevents swapping Hz for WPM at the call site
#   2. Enables dispatch without type-checking
#   3. Documents units and valid ranges at the type level
# ═══════════════════════════════════════════════════════════════════

# ── Numeric value wrappers ──────────────────────────────────────

"""
    Hz(value::Int)

Frequency in Hertz. Range for FT-891: 30_000 — 56_000_000 Hz.

```julia
set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
```
"""
struct Hz <: AbstractValue
    value::Int
end

"""
    WPM(value::Int)

CW keyer speed in words per minute. Range: 4–60 WPM.

```julia
set!(radio, KeySpeed(), WPM(17))
```
"""
struct WPM <: AbstractValue
    value::Int
end

"""
    MilliSeconds(value::Int)

Duration in milliseconds. Used for VOX delay, etc.
"""
struct MilliSeconds <: AbstractValue
    value::Int
end

"""
    Pitch(value::Int)

CW sidetone pitch in Hz. Range: 300–1050 Hz, 10 Hz steps.
"""
struct Pitch <: AbstractValue
    value::Int
end

"""
    Level(value::Int)

Generic 0–255 or 0–100 level (AF gain, mic gain, etc.).
"""
struct Level <: AbstractValue
    value::Int
end

# ── Operating modes (singleton types → zero-cost dispatch) ──────

"""CW mode (mode code `3`)."""
struct CW     <: AbstractMode end
"""CW reverse (mode code `7`)."""
struct CW_R   <: AbstractMode end
"""Lower sideband (mode code `1`)."""
struct LSB    <: AbstractMode end
"""Upper sideband (mode code `2`)."""
struct USB    <: AbstractMode end
"""AM (mode code `5`)."""
struct AM     <: AbstractMode end
"""AM narrow (mode code `D`)."""
struct AM_N   <: AbstractMode end
"""FM (mode code `4`)."""
struct FM     <: AbstractMode end
"""FM narrow (mode code `B`)."""
struct FM_N   <: AbstractMode end
"""Data lower sideband (mode code `8`)."""
struct DATA_L <: AbstractMode end
"""Data upper sideband (mode code `C`)."""
struct DATA_U <: AbstractMode end
"""RTTY lower (mode code `6`)."""
struct RTTY_L <: AbstractMode end
"""RTTY upper (mode code `9`)."""
struct RTTY_U <: AbstractMode end

# ── Break-in modes ──────────────────────────────────────────────

"""CW break-in disabled."""
struct BreakInOff   <: AbstractBreakInMode end
"""Semi break-in (QSK with delay)."""
struct SemiBreakIn  <: AbstractBreakInMode end
"""Full break-in (QSK, instant RX between elements)."""
struct FullBreakIn  <: AbstractBreakInMode end

# ── AGC modes ───────────────────────────────────────────────────

struct AGC_Off  <: AbstractAGCMode end
struct AGC_Fast <: AbstractAGCMode end
struct AGC_Mid  <: AbstractAGCMode end
struct AGC_Slow <: AbstractAGCMode end
struct AGC_Auto <: AbstractAGCMode end

# ── Meter types ─────────────────────────────────────────────────

"""Compression meter."""
struct COMP     <: AbstractMeterType end
"""ALC meter."""
struct ALC      <: AbstractMeterType end
"""Power output meter."""
struct PO       <: AbstractMeterType end
"""SWR meter."""
struct SWR      <: AbstractMeterType end
"""Current (ID) meter."""
struct METER_ID <: AbstractMeterType end

# ── On/Off toggle ───────────────────────────────────────────────

"""Switch-on value."""
struct On  <: AbstractSwitch end
"""Switch-off value."""
struct Off <: AbstractSwitch end

# ── CW keying slot selectors ───────────────────────────────────

"""
    KeyerSlot(n::Int)

Selects keyer memory slot 1–5 for CW playback via `CWKeying` command.
"""
struct KeyerSlot <: AbstractValue
    slot::Int
    function KeyerSlot(n::Int)
        1 <= n <= 5 || throw(ArgumentError("KeyerSlot must be 1–5, got $n"))
        new(n)
    end
end

"""
    MessageSlot(n::Int)

Selects message keyer slot 1–5 (mapped to KY params 6–A).
"""
struct MessageSlot <: AbstractValue
    slot::Int
    function MessageSlot(n::Int)
        1 <= n <= 5 || throw(ArgumentError("MessageSlot must be 1–5, got $n"))
        new(n)
    end
end

# ── Band selection ──────────────────────────────────────────────

struct Band160m <: AbstractBand end
struct Band80m  <: AbstractBand end
struct Band60m  <: AbstractBand end
struct Band40m  <: AbstractBand end
struct Band30m  <: AbstractBand end
struct Band20m  <: AbstractBand end
struct Band17m  <: AbstractBand end
struct Band15m  <: AbstractBand end
struct Band12m  <: AbstractBand end
struct Band10m  <: AbstractBand end
struct Band6m   <: AbstractBand end

# ── Convenience: extract raw numeric value ──────────────────────

"""
    raw_value(v) → numeric

Extract the raw numeric payload from a value wrapper.
Defined per-type — no runtime dispatch needed.
"""
raw_value(v::Hz)           = v.value
raw_value(v::WPM)          = v.value
raw_value(v::MilliSeconds) = v.value
raw_value(v::Pitch)        = v.value
raw_value(v::Level)        = v.value
raw_value(v::KeyerSlot)    = v.slot
raw_value(v::MessageSlot)  = v.slot

# ── Show methods for REPL friendliness ──────────────────────────

Base.show(io::IO, v::Hz)           = print(io, "Hz(", v.value, ")")
Base.show(io::IO, v::WPM)          = print(io, "WPM(", v.value, ")")
Base.show(io::IO, v::MilliSeconds) = print(io, "MilliSeconds(", v.value, ")")
Base.show(io::IO, v::Pitch)        = print(io, "Pitch(", v.value, ")")
Base.show(io::IO, v::Level)        = print(io, "Level(", v.value, ")")
Base.show(io::IO, v::KeyerSlot)    = print(io, "KeyerSlot(", v.slot, ")")
Base.show(io::IO, v::MessageSlot)  = print(io, "MessageSlot(", v.slot, ")")

Base.show(io::IO, ::CW)     = print(io, "CW()")
Base.show(io::IO, ::CW_R)   = print(io, "CW_R()")
Base.show(io::IO, ::LSB)    = print(io, "LSB()")
Base.show(io::IO, ::USB)    = print(io, "USB()")
Base.show(io::IO, ::AM)     = print(io, "AM()")
Base.show(io::IO, ::AM_N)   = print(io, "AM_N()")
Base.show(io::IO, ::FM)     = print(io, "FM()")
Base.show(io::IO, ::FM_N)   = print(io, "FM_N()")
Base.show(io::IO, ::DATA_L) = print(io, "DATA_L()")
Base.show(io::IO, ::DATA_U) = print(io, "DATA_U()")
Base.show(io::IO, ::RTTY_L) = print(io, "RTTY_L()")
Base.show(io::IO, ::RTTY_U) = print(io, "RTTY_U()")
