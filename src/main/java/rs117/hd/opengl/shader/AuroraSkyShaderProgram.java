package rs117.hd.opengl.shader;

import static org.lwjgl.opengl.GL33C.GL_FRAGMENT_SHADER;
import static org.lwjgl.opengl.GL33C.GL_VERTEX_SHADER;

public class AuroraSkyShaderProgram extends ShaderProgram
{
	public AuroraSkyShaderProgram()
	{
		super(t -> t
			.add(GL_VERTEX_SHADER, "aurora_sky_vert.glsl")
			.add(GL_FRAGMENT_SHADER, "aurora_sky_frag.glsl"));
	}
}
