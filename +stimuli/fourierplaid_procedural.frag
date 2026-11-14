uniform float kx;
uniform float ky;
uniform float phaseRad;
uniform float amplitude;
varying vec2 uv;

const float PI = 3.14159265358979323846;

void main(void) {
  float theta = 2.0 * PI * (kx * uv.x + ky * uv.y) + phaseRad;
  float dev = amplitude * cos(theta);
  gl_FragColor = vec4(dev, dev, dev, 1.0);
}
