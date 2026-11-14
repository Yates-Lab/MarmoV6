/* GLSL Fragment Shader for Hartley Stimuli (FINAL) */
/* This version includes amplitude control to avoid argument conflicts. */

uniform float kx;
uniform float ky;
uniform float our_sign;
uniform float amplitude; // <-- ADD THIS

varying vec2 texCoord;
const float PI = 3.1415926535;

void main() {
    // 1. Calculate phase and the cas() function value
    float phase = 2.0 * PI * (kx * texCoord.x + ky * texCoord.y);
    float hartley_val = our_sign * (cos(phase) + sin(phase));

    // 2. Normalize to [-1, 1] to get the deviation from gray
    float deviation = hartley_val / 1.41421356;

    // 3. Scale the deviation by the desired amplitude (contrast)
    float final_deviation = amplitude * deviation; // <-- USE IT HERE

    // 4. Set the final color.
    gl_FragColor = vec4(final_deviation, final_deviation, final_deviation, 1.0);
}