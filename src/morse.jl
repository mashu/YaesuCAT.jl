# ═══════════════════════════════════════════════════════════════════
# morse.jl — CW keying via serial line control (RTS/DTR)
#
# The FT-891's KY CAT command only triggers playback of stored
# messages (keyer memories 1–5 or message keyer 1–5). It does NOT
# accept arbitrary text for CW transmission.
#
# For arbitrary CW, the FT-891 supports "PC KEYING" (menu 07-12):
# the computer toggles RTS or DTR on the Standard COM port to
# key the transmitter directly — essentially a software straight key.
#
# This module implements that approach:
#   1. Text → Morse element sequence (pure, no I/O)
#   2. Element sequence → timed RTS/DTR toggling (I/O)
#
# Timing follows the PARIS standard:
#   dit  = 1 unit    dah      = 3 units
#   intra-char gap = 1 unit   inter-char gap = 3 units
#   word gap       = 7 units
#   unit duration  = 1200 / WPM  ms
#
# Note on kd-boss/CAT:
#   The C++ library handles CWKeying the same way — `KY::Set()`
#   only triggers stored message playback. Arbitrary text keying
#   via RTS/DTR is outside the scope of pure CAT serialization,
#   which is why we implement it as a separate keyer type.
# ═══════════════════════════════════════════════════════════════════

# ── Morse code table ────────────────────────────────────────────

"""
    MORSE_TABLE::Dict{Char, String}

International Morse Code lookup. Keys are uppercase characters,
values are strings of `'.'` (dit) and `'-'` (dah).
"""
const MORSE_TABLE = Dict{Char, String}(
    'A' => ".-",     'B' => "-...",   'C' => "-.-.",   'D' => "-..",
    'E' => ".",      'F' => "..-.",   'G' => "--.",    'H' => "....",
    'I' => "..",     'J' => ".---",   'K' => "-.-",    'L' => ".-..",
    'M' => "--",     'N' => "-.",     'O' => "---",    'P' => ".--.",
    'Q' => "--.-",   'R' => ".-.",    'S' => "...",    'T' => "-",
    'U' => "..-",    'V' => "...-",   'W' => ".--",    'X' => "-..-",
    'Y' => "-.--",   'Z' => "--..",
    '0' => "-----",  '1' => ".----",  '2' => "..---",  '3' => "...--",
    '4' => "....-",  '5' => ".....",  '6' => "-....",  '7' => "--...",
    '8' => "---..",  '9' => "----.",
    '/' => "-..-.",  '?' => "..--..", '.' => ".-.-.-", ',' => "--..--",
    '=' => "-...-",  '+' => ".-.-.",  '-' => "-....-", '@' => ".--.-.",
    '!' => "-.-.--",
)

# ── Morse element types (for type-stable timing sequences) ──────

"""
    MorseElement

Sum-type encoding of Morse timing elements. Stored as a `UInt8` for
compact representation in timing vectors.

| Value | Meaning          | Duration (units) |
|:------|:-----------------|:-----------------|
| 0x01  | Dit (key down)   | 1                |
| 0x02  | Dah (key down)   | 3                |
| 0x10  | Element gap      | 1                |
| 0x11  | Character gap    | 3                |
| 0x12  | Word gap         | 7                |
"""
const DIT          = 0x01
const DAH          = 0x02
const ELEMENT_GAP  = 0x10
const CHAR_GAP     = 0x11
const WORD_GAP     = 0x12

const MorseElement = UInt8

"""
    duration_units(element::MorseElement) → Int

Return the timing duration in Morse units for the given element.
"""
duration_units(e::MorseElement) = _duration_units(e)

_duration_units(e::UInt8) = begin
    e == DIT         && return 1
    e == DAH         && return 3
    e == ELEMENT_GAP && return 1
    e == CHAR_GAP    && return 3
    e == WORD_GAP    && return 7
    return 0
end

"""
    is_key_down(element::MorseElement) → Bool

Returns `true` for elements that require the key to be pressed (dit, dah).
"""
is_key_down(e::MorseElement) = (e == DIT || e == DAH)

# ── Text → Morse conversion ────────────────────────────────────

"""
    text_to_morse(text::AbstractString) → Vector{MorseElement}

Convert a text string to a flat vector of `MorseElement` timing codes.
Unknown characters are silently skipped.

```julia
elements = text_to_morse("CQ CQ")
# [DAH, ELEMENT_GAP, DIT, ELEMENT_GAP, DAH, ELEMENT_GAP, DIT,
#  CHAR_GAP,
#  DAH, ELEMENT_GAP, DAH, ELEMENT_GAP, DIT, ELEMENT_GAP, DAH,
#  WORD_GAP,
#  DAH, ELEMENT_GAP, DIT, ELEMENT_GAP, DAH, ELEMENT_GAP, DIT,
#  CHAR_GAP,
#  DAH, ELEMENT_GAP, DAH, ELEMENT_GAP, DIT, ELEMENT_GAP, DAH]
```
"""
function text_to_morse(text::AbstractString)
    elements = MorseElement[]
    words = split(uppercase(strip(String(text))))
    for (wi, word) in enumerate(words)
        for (ci, ch) in enumerate(word)
            morse = get(MORSE_TABLE, ch, nothing)
            morse === nothing && continue
            for (ei, sym) in enumerate(morse)
                push!(elements, sym == '.' ? DIT : DAH)
                ei < length(morse) && push!(elements, ELEMENT_GAP)
            end
            ci < length(word) && push!(elements, CHAR_GAP)
        end
        wi < length(words) && push!(elements, WORD_GAP)
    end
    elements
end

# ── Keyer types ─────────────────────────────────────────────────

"""
    RTSKeyer <: AbstractCWKeyer

CW keyer that toggles the RTS line on a serial port.
Requires FT-891 menu `07-12 PC KEYING` set to `RTS`.

The keyer uses the **Standard COM port** (the lower-numbered `/dev/ttyUSB`
port), separate from the Enhanced port used for CAT commands.

```julia
keyer = RTSKeyer("/dev/ttyUSB1")
send_morse!(keyer, "CQ CQ DE SA0KAM K", WPM(17))
close(keyer)
```
"""
mutable struct RTSKeyer <: AbstractCWKeyer
    port::Union{SerialPort, Nothing}
    portname::String
end

RTSKeyer(portname::String) = RTSKeyer(nothing, portname)

"""
    DTRKeyer <: AbstractCWKeyer

CW keyer that toggles the DTR line. Same as [`RTSKeyer`](@ref) but
for radios configured with `07-12 PC KEYING = DTR`.
"""
mutable struct DTRKeyer <: AbstractCWKeyer
    port::Union{SerialPort, Nothing}
    portname::String
end

DTRKeyer(portname::String) = DTRKeyer(nothing, portname)

# ── Open / close keyer ports ────────────────────────────────────

function _open_keyer!(keyer::AbstractCWKeyer)
    if keyer.port === nothing
        keyer.port = LibSerialPort.open(keyer.portname, 9600)  # baud irrelevant
    end
    keyer
end

function Base.close(keyer::AbstractCWKeyer)
    if keyer.port !== nothing
        close(keyer.port)
        keyer.port = nothing
    end
end

# ── Key down/up dispatch (no type checks!) ──────────────────────

"""Toggle the keying line high (transmit)."""
function _key_down(keyer::RTSKeyer)
    sp_set_rts(keyer.port.ref, SP_RTS_ON)
end

function _key_down(keyer::DTRKeyer)
    sp_set_dtr(keyer.port.ref, SP_DTR_ON)
end

"""Toggle the keying line low (receive)."""
function _key_up(keyer::RTSKeyer)
    sp_set_rts(keyer.port.ref, SP_RTS_OFF)
end

function _key_up(keyer::DTRKeyer)
    sp_set_dtr(keyer.port.ref, SP_DTR_OFF)
end

# ── Main keying function ────────────────────────────────────────

"""
    send_morse!(keyer::AbstractCWKeyer, text::AbstractString, speed::WPM)

Send arbitrary Morse code by toggling the keyer's serial control line.

Opens the serial port if not already open. The port is left open after
sending so multiple messages can be sent without re-opening.

## Arguments
- `keyer`: An [`RTSKeyer`](@ref) or [`DTRKeyer`](@ref) connected to the Standard COM port
- `text`: ASCII text to send as Morse code
- `speed`: Keying speed as [`WPM`](@ref)

## Timing
Uses PARIS standard timing: 1 unit = 1200/WPM milliseconds.

## FT-891 Setup
- Menu `07-12 PC KEYING`: set to `RTS` (for RTSKeyer) or `DTR` (for DTRKeyer)
- Mode must be `CW` or `CW-R`
- Keyer type (menu 04-01) should be set to `OFF` for straight-key emulation

## Example
```julia
keyer = RTSKeyer("/dev/ttyUSB1")
send_morse!(keyer, "CQ CQ DE SA0KAM SA0KAM K", WPM(17))
send_morse!(keyer, "5NN TU", WPM(17))
close(keyer)
```
"""
function send_morse!(keyer::AbstractCWKeyer, text::AbstractString, speed::WPM)
    _open_keyer!(keyer)
    elements = text_to_morse(text)
    unit_s = 1.2 / speed.value  # 1200ms / WPM, converted to seconds

    _key_up(keyer)
    sleep(0.05)

    for element in elements
        dur = duration_units(element) * unit_s
        if is_key_down(element)
            _key_down(keyer)
            sleep(dur)
            _key_up(keyer)
        else
            sleep(dur)
        end
    end

    _key_up(keyer)  # safety: ensure key is up at end
    nothing
end

"""
    send_morse!(keyer::AbstractCWKeyer, elements::Vector{MorseElement}, speed::WPM)

Send pre-computed Morse elements. Useful when you want to pre-process
the text once and send it multiple times.
"""
function send_morse!(keyer::AbstractCWKeyer, elements::Vector{MorseElement}, speed::WPM)
    _open_keyer!(keyer)
    unit_s = 1.2 / speed.value

    _key_up(keyer)
    sleep(0.05)

    for element in elements
        dur = duration_units(element) * unit_s
        if is_key_down(element)
            _key_down(keyer)
            sleep(dur)
            _key_up(keyer)
        else
            sleep(dur)
        end
    end

    _key_up(keyer)
    nothing
end
