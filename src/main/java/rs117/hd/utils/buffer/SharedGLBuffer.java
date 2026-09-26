package rs117.hd.utils.buffer;

/**
 * Compatibility GL buffer used by UBOCompute. Aurora's zone renderer no longer
 * uses the legacy OpenCL model-processing path, so this is now a normal GL buffer.
 */
public class SharedGLBuffer extends GLBuffer {
	public SharedGLBuffer(String name, int target, int glUsage, int ignoredClUsage) {
		super(name, target, glUsage);
	}
}
