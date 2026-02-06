# ═══════════════════════════════════════════════════════════════════
# transport.jl — Serial transport layer
#
# Abstracts the physical serial connection. The parametric design
# ensures that the `Radio{T}` handle carries a concrete transport
# type, making all method calls on the radio type-stable.
# ═══════════════════════════════════════════════════════════════════

# ── Serial transport (production) ───────────────────────────────

"""
    SerialTransport <: AbstractTransport

Production serial transport wrapping a LibSerialPort `SerialPort`.
Stores the port name, baud rate, and timeout for connection management.

The FT-891 uses 8 data bits, no parity, 2 stop bits (8N2).
"""
mutable struct SerialTransport <: AbstractTransport
    port::Union{SerialPort, Nothing}
    portname::String
    baudrate::Int
    timeout_ms::Int
end

function SerialTransport(portname::String; baudrate::Int=9600, timeout_ms::Int=200)
    SerialTransport(nothing, portname, baudrate, timeout_ms)
end

"""
    open_transport!(t::SerialTransport)

Open the serial port with FT-891 settings (8N2, no flow control).
"""
function open_transport!(t::SerialTransport)
    t.port = LibSerialPort.open(t.portname, t.baudrate)
    # FT-891 expects 8 data bits, no parity, 2 stop bits
    sp_set_bits(t.port.ref, 8)
    sp_set_parity(t.port.ref, SP_PARITY_NONE)
    sp_set_stopbits(t.port.ref, 2)
    set_flow_control(t.port)
    sleep(0.05)
    t
end

"""
    close_transport!(t::SerialTransport)

Close the serial port and release resources.
"""
function close_transport!(t::SerialTransport)
    if t.port !== nothing
        close(t.port)
        t.port = nothing
    end
    t
end

"""
    is_open(t::SerialTransport) → Bool

Check if the transport has an open port.
"""
is_open(t::SerialTransport) = t.port !== nothing

"""
    write_bytes(t::SerialTransport, data::AbstractString)

Write raw bytes to the serial port.
"""
function write_bytes(t::SerialTransport, data::AbstractString)
    t.port === nothing && throw(ErrorException("Transport not open"))
    write(t.port, data)
    nothing
end

"""
    read_until_terminator(t::SerialTransport; timeout_ms=t.timeout_ms) → String

Read bytes from the serial port until the CAT terminator `;` is received
or the timeout expires. Returns the accumulated string (including terminator).
"""
function read_until_terminator(t::SerialTransport; timeout_ms::Int=t.timeout_ms)
    t.port === nothing && throw(ErrorException("Transport not open"))
    buf = UInt8[]
    deadline = time() + timeout_ms / 1000.0
    while time() < deadline
        nb = bytesavailable(t.port)
        if nb > 0
            chunk = read(t.port, nb)
            append!(buf, chunk)
            UInt8(TERMINATOR) in buf && break
        else
            sleep(0.002)
        end
    end
    String(buf)
end

# ── Null transport (for testing / dry-run) ──────────────────────

"""
    NullTransport <: AbstractTransport

A no-op transport for testing and dry-run scenarios.
`write_bytes` records commands; `read_until_terminator` returns a configurable response.

```julia
t = NullTransport()
push!(t.responses, "FA014060000;")  # pre-load a mock response
```
"""
mutable struct NullTransport <: AbstractTransport
    sent::Vector{String}
    responses::Vector{String}
    is_open::Bool
end

NullTransport() = NullTransport(String[], String[], false)

open_transport!(t::NullTransport) = (t.is_open = true; t)
close_transport!(t::NullTransport) = (t.is_open = false; t)
is_open(t::NullTransport) = t.is_open

function write_bytes(t::NullTransport, data::AbstractString)
    push!(t.sent, String(data))
    nothing
end

function read_until_terminator(t::NullTransport; timeout_ms::Int=100)
    isempty(t.responses) ? "" : popfirst!(t.responses)
end
