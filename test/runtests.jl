using Test

# Since this is a standalone package, we include directly for testing
# In a real setup, you'd do `using YaesuCAT`
include(joinpath(@__DIR__, "..", "src", "YaesuCAT.jl"))
using .YaesuCAT

# Tests simulate the FT-891 serial interface via NullTransport (no real radio needed).
# The same API works with a real radio: use FT891("/dev/ttyUSB0") which uses SerialTransport.

@testset "YaesuCAT.jl" begin

    @testset "Value types" begin
        @test Hz(14_060_000).value == 14_060_000
        @test WPM(17).value == 17
        @test KeyerSlot(3).slot == 3
        @test_throws ArgumentError KeyerSlot(0)
        @test_throws ArgumentError KeyerSlot(6)
        @test MessageSlot(1).slot == 1
        @test_throws ArgumentError MessageSlot(0)
    end

    @testset "Protocol encoding — Frequency" begin
        @test encode_set(FrequencyVFO{A}(), Hz(14_250_000)) == "FA014250000;"
        @test encode_set(FrequencyVFO{B}(), Hz(7_074_000))  == "FB007074000;"
        @test encode_read(FrequencyVFO{A}()) == "FA;"
        @test encode_read(FrequencyVFO{B}()) == "FB;"
    end

    @testset "Protocol decoding — Frequency" begin
        @test decode_answer(FrequencyVFO{A}(), "FA014250000") == Hz(14_250_000)
        @test decode_answer(FrequencyVFO{B}(), "FB007074000") == Hz(7_074_000)
    end

    @testset "Protocol encoding — Mode" begin
        @test encode_set(Mode(), CW())     == "MD03;"
        @test encode_set(Mode(), USB())    == "MD02;"
        @test encode_set(Mode(), LSB())    == "MD01;"
        @test encode_set(Mode(), DATA_U()) == "MD0C;"
        @test encode_set(Mode(), FM_N())   == "MD0B;"
        @test encode_read(Mode()) == "MD0;"
    end

    @testset "Protocol decoding — Mode" begin
        @test decode_answer(Mode(), "MD03") isa CW
        @test decode_answer(Mode(), "MD02") isa USB
        @test decode_answer(Mode(), "MD0C") isa DATA_U
    end

    @testset "Protocol encoding — Key Speed" begin
        @test encode_set(KeySpeed(), WPM(4))  == "KS004;"
        @test encode_set(KeySpeed(), WPM(17)) == "KS017;"
        @test encode_set(KeySpeed(), WPM(60)) == "KS060;"
        @test_throws ArgumentError encode_set(KeySpeed(), WPM(3))
        @test_throws ArgumentError encode_set(KeySpeed(), WPM(61))
    end

    @testset "Protocol decoding — Key Speed" begin
        @test decode_answer(KeySpeed(), "KS017") == WPM(17)
        @test decode_answer(KeySpeed(), "KS004") == WPM(4)
    end

    @testset "Protocol encoding — Keyer" begin
        @test encode_set(Keyer(), On())  == "KR1;"
        @test encode_set(Keyer(), Off()) == "KR0;"
    end

    @testset "Protocol encoding — Key Pitch" begin
        @test encode_set(KeyPitch(), Pitch(600)) == "KP30;"
        @test encode_set(KeyPitch(), Pitch(300)) == "KP00;"
        @test encode_set(KeyPitch(), Pitch(1050)) == "KP75;"
        @test_throws ArgumentError encode_set(KeyPitch(), Pitch(290))
        @test_throws ArgumentError encode_set(KeyPitch(), Pitch(605))
    end

    @testset "Protocol encoding — CW Keying (playback)" begin
        @test encode_set(CWKeying(), KeyerSlot(1))   == "KY1;"
        @test encode_set(CWKeying(), KeyerSlot(5))   == "KY5;"
        @test encode_set(CWKeying(), MessageSlot(1)) == "KY6;"
        @test encode_set(CWKeying(), MessageSlot(5)) == "KYA;"
    end

    @testset "Protocol encoding — Keyer Memory" begin
        @test encode_set(KeyerMemory(1), "CQ CQ DE TEST") == "KM1CQ CQ DE TEST;"
        @test encode_read(KeyerMemory(3)) == "KM3;"
        long_msg = repeat("A", 51)
        @test_throws ArgumentError encode_set(KeyerMemory(1), long_msg)
    end

    @testset "Protocol encoding — TX State" begin
        @test encode_set(TXState(), On())  == "TX1;"
        @test encode_set(TXState(), Off()) == "TX0;"
    end

    @testset "Protocol encoding — Break-in" begin
        @test encode_set(BreakIn(), BreakInOff())  == "BI0;"
        @test encode_set(BreakIn(), SemiBreakIn())  == "BI1;"
        @test encode_set(BreakIn(), FullBreakIn()) == "BI2;"
    end

    @testset "Protocol encoding — Power" begin
        @test encode_set(Power(), Level(50))  == "PC050;"
        @test encode_set(Power(), Level(100)) == "PC100;"
        @test_throws ArgumentError encode_set(Power(), Level(4))
        @test_throws ArgumentError encode_set(Power(), Level(101))
    end

    @testset "Protocol encoding — Band Select" begin
        @test encode_set(BandSelect(), Band20m()) == "BS05;"
        @test encode_set(BandSelect(), Band40m()) == "BS03;"
        @test encode_set(BandSelect(), Band6m())  == "BS10;"
    end

    @testset "Protocol encoding — Misc commands" begin
        @test encode_set(CWSpot(), On())    == "CS1;"
        @test encode_set(CWSpot(), Off())   == "CS0;"
        @test encode_set(Lock(), On())      == "LK1;"
        @test encode_set(VoxStatus(), On()) == "VX1;"
        @test encode_set(AFGain(), Level(128)) == "AG0128;"
        @test encode_read(Identification()) == "ID;"
        @test encode_read(Information()) == "IF;"
    end

    @testset "Protocol encoding — AGC" begin
        @test encode_set(AGCFunction(), AGC_Off())  == "GT00;"
        @test encode_set(AGCFunction(), AGC_Fast()) == "GT01;"
        @test encode_set(AGCFunction(), AGC_Slow()) == "GT03;"
    end

    @testset "Protocol encoding — Meter" begin
        @test encode_set(MeterSwitch(), COMP()) == "MS0;"
        @test encode_set(MeterSwitch(), SWR())  == "MS3;"
    end

    @testset "Morse code — text_to_morse" begin
        # "E" is a single dit
        elements = text_to_morse("E")
        @test elements == [DIT]

        # "T" is a single dah
        elements = text_to_morse("T")
        @test elements == [DAH]

        # "ET" = dit, char_gap, dah
        elements = text_to_morse("ET")
        @test elements == [DIT, CHAR_GAP, DAH]

        # Space produces word gap
        elements = text_to_morse("E T")
        @test elements == [DIT, WORD_GAP, DAH]

        # "CQ" encoding
        elements = text_to_morse("CQ")
        @test elements[1] == DAH        # C: -
        @test elements[2] == ELEMENT_GAP
        @test elements[3] == DIT        # C: .
        @test elements[4] == ELEMENT_GAP
        @test elements[5] == DAH        # C: -
        @test elements[6] == ELEMENT_GAP
        @test elements[7] == DIT        # C: .
        @test elements[8] == CHAR_GAP   # between C and Q
    end

    @testset "Morse code — timing" begin
        @test duration_units(DIT) == 1
        @test duration_units(DAH) == 3
        @test duration_units(ELEMENT_GAP) == 1
        @test duration_units(CHAR_GAP) == 3
        @test duration_units(WORD_GAP) == 7
        @test is_key_down(DIT) == true
        @test is_key_down(DAH) == true
        @test is_key_down(ELEMENT_GAP) == false
        @test is_key_down(WORD_GAP) == false
    end

    @testset "NullTransport — round trip" begin
        transport = NullTransport()
        radio = FT891(transport)
        connect!(radio)

        # Test that set! sends the encoded command
        set!(radio, FrequencyVFO{A}(), Hz(14_060_000))
        @test transport.sent[end] == "FA014060000;"

        set!(radio, Mode(), CW())
        @test transport.sent[end] == "MD03;"

        set!(radio, KeySpeed(), WPM(17))
        @test transport.sent[end] == "KS017;"

        set!(radio, CWKeying(), KeyerSlot(1))
        @test transport.sent[end] == "KY1;"

        set!(radio, KeyerMemory(2), "CQ TEST")
        @test transport.sent[end] == "KM2CQ TEST;"

        # Test read with mock responses
        push!(transport.responses, "FA014060000;")
        freq = read(radio, FrequencyVFO{A}())
        @test freq == Hz(14_060_000)

        push!(transport.responses, "KS017;")
        wpm = read(radio, KeySpeed())
        @test wpm == WPM(17)

        push!(transport.responses, "MD03;")
        mode = read(radio, Mode())
        @test mode isa CW

        push!(transport.responses, "ID0670;")
        id = read(radio, Identification())
        @test id == "0670"

        disconnect!(radio)
    end

    @testset "Type stability" begin
        # Verify that the main API methods are type-stable
        # (encode functions return String, decode functions return concrete types)
        @test encode_set(FrequencyVFO{A}(), Hz(14_060_000)) isa String
        @test encode_set(Mode(), CW()) isa String
        @test encode_read(FrequencyVFO{A}()) isa String
        @test decode_answer(FrequencyVFO{A}(), "FA014060000") isa Hz
        @test decode_answer(KeySpeed(), "KS017") isa WPM
        @test decode_answer(Mode(), "MD03") isa CW
        @test decode_answer(Identification(), "ID0670") isa String
    end

end
