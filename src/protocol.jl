# ═══════════════════════════════════════════════════════════════════
# protocol.jl — CAT command encoding / decoding (pure functions)
#
# Following kd-boss/CAT, this layer handles ONLY serialization.
# Each command type gets `encode_set`, `encode_read`, and/or
# `decode_answer` methods via multiple dispatch. No I/O occurs here.
#
# Design: The generic functions below are extended in commands/*.jl
# for each concrete command type. This is the Julia equivalent of
# the C++ `Command::Set()`, `Command::Read()`, `Command::Answer()`
# static methods in the reference implementation.
# ═══════════════════════════════════════════════════════════════════

const TERMINATOR = ';'

# ── Generic encoding/decoding interface ─────────────────────────

"""
    encode_set(cmd, value) → String

Encode a Set command into a CAT protocol string (with terminator).
Dispatches on `(CommandType, ValueType)` — fully resolved at compile time.

```julia
encode_set(FrequencyVFO{A}(), Hz(14_060_000))  # → "FA014060000;"
encode_set(Mode(), CW())                        # → "MD03;"
encode_set(KeySpeed(), WPM(17))                  # → "KS017;"
```
"""
function encode_set end

"""
    encode_read(cmd) → String

Encode a Read command (request for current value).

```julia
encode_read(FrequencyVFO{A}())  # → "FA;"
encode_read(KeySpeed())          # → "KS;"
```
"""
function encode_read end

"""
    decode_answer(cmd, raw::AbstractString) → value

Decode an Answer string from the radio into the appropriate value type.

```julia
decode_answer(FrequencyVFO{A}(), "FA014060000")  # → Hz(14060000)
decode_answer(KeySpeed(), "KS017")                 # → WPM(17)
decode_answer(Mode(), "MD03")                      # → CW()
```
"""
function decode_answer end

# ── Encoding helpers ────────────────────────────────────────────

"""
    pad_int(n::Int, width::Int) → String

Zero-pad an integer to the given width. Used extensively in CAT parameter encoding.
"""
pad_int(n::Int, width::Int) = lpad(string(n), width, '0')

"""
    terminate(s::AbstractString) → String

Append the CAT terminator `;` if not already present.
"""
terminate(s::AbstractString) = endswith(s, TERMINATOR) ? String(s) : s * TERMINATOR

# ── Mode encoding tables (dispatch-based, no Dict lookup) ───────

"""    mode_code(m::AbstractMode) → String"""
mode_code(::LSB)    = "1"
mode_code(::USB)    = "2"
mode_code(::CW)     = "3"
mode_code(::FM)     = "4"
mode_code(::AM)     = "5"
mode_code(::RTTY_L) = "6"
mode_code(::CW_R)   = "7"
mode_code(::DATA_L) = "8"
mode_code(::RTTY_U) = "9"
mode_code(::FM_N)   = "B"
mode_code(::DATA_U) = "C"
mode_code(::AM_N)   = "D"

"""    decode_mode(code::AbstractString) → AbstractMode"""
decode_mode(c::AbstractString) = _decode_mode(Val(Symbol(c)))

_decode_mode(::Val{Symbol("1")}) = LSB()
_decode_mode(::Val{Symbol("2")}) = USB()
_decode_mode(::Val{Symbol("3")}) = CW()
_decode_mode(::Val{Symbol("4")}) = FM()
_decode_mode(::Val{Symbol("5")}) = AM()
_decode_mode(::Val{Symbol("6")}) = RTTY_L()
_decode_mode(::Val{Symbol("7")}) = CW_R()
_decode_mode(::Val{Symbol("8")}) = DATA_L()
_decode_mode(::Val{Symbol("9")}) = RTTY_U()
_decode_mode(::Val{Symbol("B")}) = FM_N()
_decode_mode(::Val{Symbol("C")}) = DATA_U()
_decode_mode(::Val{Symbol("D")}) = AM_N()

# ── Break-in encoding ──────────────────────────────────────────

breakin_code(::BreakInOff)  = "0"
breakin_code(::SemiBreakIn) = "1"
breakin_code(::FullBreakIn) = "2"

# ── AGC encoding ────────────────────────────────────────────────

agc_code(::AGC_Off)  = "0"
agc_code(::AGC_Fast) = "1"
agc_code(::AGC_Mid)  = "2"
agc_code(::AGC_Slow) = "3"
agc_code(::AGC_Auto) = "4"

# ── Meter type encoding ────────────────────────────────────────

meter_code(::COMP)     = "0"
meter_code(::ALC)      = "1"
meter_code(::PO)       = "2"
meter_code(::SWR)      = "3"
meter_code(::METER_ID) = "4"

# ── Switch encoding ─────────────────────────────────────────────

switch_code(::On)  = "1"
switch_code(::Off) = "0"

# ── Band encoding ───────────────────────────────────────────────

band_code(::Band160m) = "00"
band_code(::Band80m)  = "01"
band_code(::Band60m)  = "02"
band_code(::Band40m)  = "03"
band_code(::Band30m)  = "04"
band_code(::Band20m)  = "05"
band_code(::Band17m)  = "06"
band_code(::Band15m)  = "07"
band_code(::Band12m)  = "08"
band_code(::Band10m)  = "09"
band_code(::Band6m)   = "10"
