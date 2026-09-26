package rs117.hd.model;

/** Mutable so the renderer can pool these tiny frame-cache entries. */
public class ModelOffsets {
    public int faceCount;
    public int vertexOffset;
    public int uvOffset;

    public ModelOffsets() {}

    public ModelOffsets(int faceCount, int vertexOffset, int uvOffset) {
        set(faceCount, vertexOffset, uvOffset);
    }

    public ModelOffsets set(int faceCount, int vertexOffset, int uvOffset) {
        this.faceCount = faceCount;
        this.vertexOffset = vertexOffset;
        this.uvOffset = uvOffset;
        return this;
    }
}
