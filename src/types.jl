# ═══════════════════════════════════════════════════════════════════
# types.jl — Abstract type hierarchy for YaesuCAT
#
# This file defines the complete type lattice. All behavior is
# determined by dispatch on these types — no `isa` or `typeof` checks
# are used anywhere in this package.
# ═══════════════════════════════════════════════════════════════════

# ── Radio hierarchy ─────────────────────────────────────────────

"""
    AbstractRadio

Root type for all radio transceivers. Subtypes must implement
[`connect!`](@ref), [`disconnect!`](@ref), and the transport interface.
"""
abstract type AbstractRadio end

"""
    AbstractYaesuRadio <: AbstractRadio

Yaesu radios using the CAT command protocol (semicolon-terminated ASCII).
All Yaesu CAT commands share the same framing: `CMD[PARAMS];`
"""
abstract type AbstractYaesuRadio <: AbstractRadio end

# ── Command hierarchy ───────────────────────────────────────────

"""
    AbstractCommand

Root of the command type tree. Every CAT command is a singleton (zero-size)
type descending from one of the capability branches below.
"""
abstract type AbstractCommand end

"""
    SetReadCommand <: AbstractCommand

Commands that support both `set!` and `read`. Most common category.
Corresponds to columns O/O/O in the Yaesu CAT command table.
"""
abstract type SetReadCommand <: AbstractCommand end

"""
    SetOnlyCommand <: AbstractCommand

Commands that only support `set!` (no read/answer).
Column pattern: O/X/X/X in the Yaesu CAT command table.
Examples: `BandDown`, `BandUp`, `CWKeying`.
"""
abstract type SetOnlyCommand <: AbstractCommand end

"""
    ReadOnlyCommand <: AbstractCommand

Commands that only support `read` (with answer).
Column pattern: X/O/O/X in the Yaesu CAT command table.
Examples: `Information`, `Busy`.
"""
abstract type ReadOnlyCommand <: AbstractCommand end

# ── VFO tags (phantom types for compile-time VFO selection) ─────

"""
    AbstractVFO

Phantom type tag for VFO selection. Used as a type parameter to
distinguish VFO-A vs VFO-B commands at compile time.

```julia
FrequencyVFO{A}()  # VFO-A frequency command
FrequencyVFO{B}()  # VFO-B frequency command — different type, different dispatch
```
"""
abstract type AbstractVFO end

"""VFO A tag — used as type parameter `FrequencyVFO{A}`."""
struct A <: AbstractVFO end

"""VFO B tag — used as type parameter `FrequencyVFO{B}`."""
struct B <: AbstractVFO end

# ── Value type hierarchy ────────────────────────────────────────

"""
    AbstractValue

Root for all parameter value types. Using dedicated types instead of
raw `Int`/`String` gives us:
- Type safety (can't pass Hz where WPM is expected)
- Self-documenting call sites
- Dispatch without runtime checks
"""
abstract type AbstractValue end

"""
    AbstractMode <: AbstractValue

Operating modes (CW, USB, LSB, FM, AM, DATA, RTTY variants).
Each mode is a singleton type for zero-cost dispatch.
"""
abstract type AbstractMode <: AbstractValue end

"""
    AbstractBreakInMode <: AbstractValue

CW break-in modes: off, semi, full.
"""
abstract type AbstractBreakInMode <: AbstractValue end

"""
    AbstractAGCMode <: AbstractValue

AGC function settings.
"""
abstract type AbstractAGCMode <: AbstractValue end

"""
    AbstractMeterType <: AbstractValue

Meter display types (compression, ALC, power out, SWR, current).
"""
abstract type AbstractMeterType <: AbstractValue end

"""
    AbstractSwitch <: AbstractValue

Binary on/off toggle. Use `On()` or `Off()` — no booleans needed.
"""
abstract type AbstractSwitch <: AbstractValue end

"""
    AbstractBand <: AbstractValue

HF/VHF band selection values.
"""
abstract type AbstractBand <: AbstractValue end

# ── Transport hierarchy ─────────────────────────────────────────

"""
    AbstractTransport

Abstraction for the serial communication layer. Implement
`write_bytes` and `read_until_terminator` for new transports.
The default [`SerialTransport`](@ref) wraps `LibSerialPort`.
"""
abstract type AbstractTransport end

# ── CW Keyer hierarchy ─────────────────────────────────────────

"""
    AbstractCWKeyer

Root type for CW keying backends. Subtypes control how Morse code
is physically keyed:

- [`RTSKeyer`](@ref): toggles RTS line on the Standard COM port
- [`DTRKeyer`](@ref): toggles DTR line on the Standard COM port
"""
abstract type AbstractCWKeyer end
