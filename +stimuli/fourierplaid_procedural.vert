varying vec2 uv;

void main(void) {
  vec2 pos = gl_Vertex.xy;
  uv = pos * 0.5;
  gl_Position = vec4(pos, 0.0, 1.0);
}
