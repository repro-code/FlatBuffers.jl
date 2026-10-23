# Offsets and lengths read from a corrupt buffer must not read outside of it
mutable struct BoundsVecT
	x::Vector{Float64}
end
struct BoundsPoint
	x::Float64
	y::Float64
end
mutable struct BoundsPointVecT
	x::Vector{BoundsPoint}
end
mutable struct BoundsStringVecT
	x::Vector{String}
end
mutable struct BoundsStructT
	x::BoundsPoint
end

function boundsbuffer(x)
	b = FlatBuffers.build!(x)
	bytes = b.bytes[b.head+1:end]
	return bytes, FlatBuffers.Table(typeof(x), bytes, FlatBuffers.readbuffer(bytes, 0, Int32))
end

@testset "Bounds" begin
	# A vector length beyond the end of the buffer
	for x in (BoundsVecT([1.0, 2.0]), BoundsPointVecT([BoundsPoint(1.0, 2.0)]), BoundsStringVecT(["a", "b"]))
		bytes, t = boundsbuffer(x)
		@test FlatBuffers.read(typeof(x), bytes).x == x.x
		len = FlatBuffers.vector(t, FlatBuffers.offset(t, 4)) - sizeof(Int32)
		bytes[len+1:len+4] = reinterpret(UInt8, [Int32(10^6)])
		@test_throws BoundsError FlatBuffers.read(typeof(x), bytes)
	end
	# An inline struct that extends beyond the end of the buffer
	bytes, t = boundsbuffer(BoundsStructT(BoundsPoint(1.0, 2.0)))
	@test FlatBuffers.read(BoundsStructT, bytes).x == BoundsPoint(1.0, 2.0)
	vtable = t.pos - FlatBuffers.get(t, t.pos, Int32)
	bytes[vtable+5:vtable+6] = reinterpret(UInt8, [Int16(length(bytes) - t.pos - 8)])
	@test_throws BoundsError FlatBuffers.read(BoundsStructT, bytes)
end
