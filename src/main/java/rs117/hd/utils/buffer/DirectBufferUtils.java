package rs117.hd.utils.buffer;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.FloatBuffer;
import java.nio.IntBuffer;

/**
 * Small Java-NIO direct-buffer allocator used by the renderer.
 *
 * This deliberately avoids LWJGL renderer-specific allocation helpers for ordinary
 * temporary and staging allocation. OpenGL-mapped buffers remain owned by the GL
 * buffer layer where mapping is intrinsic to the renderer architecture.
 */
public final class DirectBufferUtils
{
	private DirectBufferUtils()
	{
	}

	public static ByteBuffer createByteBuffer(int bytes)
	{
		if (bytes < 0)
			throw new IllegalArgumentException("Negative direct-buffer size: " + bytes);
		return ByteBuffer.allocateDirect(bytes).order(ByteOrder.nativeOrder());
	}

	public static IntBuffer createIntBuffer(int ints)
	{
		return createByteBuffer(Math.multiplyExact(ints, Integer.BYTES)).asIntBuffer();
	}

	public static FloatBuffer createFloatBuffer(int floats)
	{
		return createByteBuffer(Math.multiplyExact(floats, Float.BYTES)).asFloatBuffer();
	}
}
