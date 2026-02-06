# ═══════════════════════════════════════════════════════════════════
# radios.jl — Concrete radio types and high-level API
#
# The radio type is parametric on its transport, so
# `FT891{SerialTransport}` and `FT891{NullTransport}` are distinct
# concrete types — the compiler resolves all dispatch statically.
#
# The high-level `set!` and `read` methods combine:
#   1. Encoding (protocol.jl + commands.jl)  — pure, no I/O
#   2. Transport (transport.jl)              — serial I/O
#   3. Decoding (protocol.jl + commands.jl)  — pure, no I/O
# ═══════════════════════════════════════════════════════════════════

# ── FT-891 ──────────────────────────────────────────────────────

"""
    FT891{T <: AbstractTransport} <: AbstractYaesuRadio

Yaesu FT-891 HF/50 MHz transceiver. Parametric on transport type `T`
for compile-time type stability.

## Constructors

```julia
# Production — serial port (uses SerialTransport internally)
radio = FT891("/dev/ttyUSB0"; baudrate=9600, timeout_ms=200)

# Testing — null transport
radio = FT891(NullTransport())
```

## Radio identification

The FT-891 returns `"0670"` for the `ID` command.
"""
struct FT891{T <: AbstractTransport} <: AbstractYaesuRadio
    transport::T
end

function FT891(portname::String; baudrate::Int=9600, timeout_ms::Int=200)
    FT891(SerialTransport(portname; baudrate, timeout_ms))
end

Base.show(io::IO, r::FT891) = print(io, "FT891(", r.transport, ")")
Base.show(io::IO, t::SerialTransport) = print(io, t.portname, "@", t.baudrate)
Base.show(io::IO, ::NullTransport) = print(io, "NullTransport")

# ── Connection lifecycle ────────────────────────────────────────

"""
    connect!(radio::AbstractYaesuRadio)

Open the serial transport to the radio. Must be called before any
`set!` or `read` operations.
"""
connect!(radio::FT891) = (open_transport!(radio.transport); radio)

"""
    disconnect!(radio::AbstractYaesuRadio)

Close the serial transport and release the port.
"""
disconnect!(radio::FT891) = (close_transport!(radio.transport); radio)

# ── Low-level command I/O ───────────────────────────────────────

"""
    send_cmd!(radio, cmd_str::AbstractString)

Send a raw CAT command string. Terminator is appended if missing.
Prefer the typed `set!` / `read` API for safety.
"""
function send_cmd!(radio::AbstractYaesuRadio, cmd_str::AbstractString)
    write_bytes(radio.transport, terminate(cmd_str))
end

"""
    read_response(radio; timeout_ms) → String

Read raw bytes from the radio until the terminator `;` or timeout.
"""
function read_response(radio::AbstractYaesuRadio; timeout_ms::Int=-1)
    t = radio.transport
    kw = timeout_ms > 0 ? (; timeout_ms) : (;)
    resp = read_until_terminator(t; kw...)
    rstrip(resp, TERMINATOR)
end

"""
    query(radio, cmd_str) → String

Send a raw command and return the stripped response.
"""
function query(radio::AbstractYaesuRadio, cmd_str::AbstractString)
    send_cmd!(radio, cmd_str)
    read_response(radio)
end

# ═══════════════════════════════════════════════════════════════════
# High-level typed API: set! and read
#
# These are the primary user-facing functions. They dispatch on
# (RadioType, CommandType, ValueType) — a triple that uniquely
# determines encoding, transport, and decoding at compile time.
# ═══════════════════════════════════════════════════════════════════

# ── set! for SetReadCommand and SetOnlyCommand ──────────────────

"""
    set!(radio, cmd, value)

Set a radio parameter. The command type and value type together
determine the CAT string that gets sent.

```julia
set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
set!(radio, Mode(), CW())
set!(radio, KeySpeed(), WPM(17))
set!(radio, CWKeying(), KeyerSlot(1))
```
"""
function set!(radio::AbstractYaesuRadio, cmd::SetReadCommand, value)
    write_bytes(radio.transport, encode_set(cmd, value))
    nothing
end

function set!(radio::AbstractYaesuRadio, cmd::SetOnlyCommand, value)
    write_bytes(radio.transport, encode_set(cmd, value))
    nothing
end

# set! for commands that store text (KeyerMemory takes a String)
function set!(radio::AbstractYaesuRadio, cmd::KeyerMemory, message::AbstractString)
    write_bytes(radio.transport, encode_set(cmd, message))
    nothing
end

# set! for parameterless set-only commands (BandUp, BandDown)
function set!(radio::AbstractYaesuRadio, cmd::SetOnlyCommand)
    write_bytes(radio.transport, encode_set(cmd))
    nothing
end

# set! for MenuAccess with raw string params
function set!(radio::AbstractYaesuRadio, cmd::MenuAccess, params::AbstractString)
    write_bytes(radio.transport, encode_set(cmd, params))
    nothing
end

# ── read for SetReadCommand and ReadOnlyCommand ─────────────────

"""
    read(radio, cmd) → value

Read a radio parameter. Returns a typed value (e.g., `Hz`, `WPM`, `CW()`).

```julia
freq = read(radio, FrequencyVFO{A}())  # → Hz(14060000)
wpm  = read(radio, KeySpeed())          # → WPM(17)
mode = read(radio, Mode())              # → CW()
id   = read(radio, Identification())    # → "0670"
```
"""
function Base.read(radio::AbstractYaesuRadio, cmd::SetReadCommand)
    write_bytes(radio.transport, encode_read(cmd))
    raw = read_until_terminator(radio.transport)
    decode_answer(cmd, rstrip(raw, TERMINATOR))
end

function Base.read(radio::AbstractYaesuRadio, cmd::ReadOnlyCommand)
    write_bytes(radio.transport, encode_read(cmd))
    raw = read_until_terminator(radio.transport)
    decode_answer(cmd, rstrip(raw, TERMINATOR))
end

# read for KeyerMemory (which is a SetReadCommand but takes a slot)
function Base.read(radio::AbstractYaesuRadio, cmd::KeyerMemory)
    write_bytes(radio.transport, encode_read(cmd))
    raw = read_until_terminator(radio.transport)
    decode_answer(cmd, rstrip(raw, TERMINATOR))
end
