#version 120

uniform sampler2D colortex0;      // Base color (albedo + baked lighting)
uniform sampler2D depthtex0;      // Scene depth buffer
uniform sampler2D shadowtex0;     // Shadow map

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirectionView;     // Sun direction in view space (normalized, points FROM sun)
uniform vec3 sunColor;             // Linear RGB irradiance scale
uniform float sunIntensity;        // Lux-like scalar
uniform vec2 viewSize;

varying vec2 vTexCoord;

const float SHADOW_BIAS = 0.0015;

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / max(view.w, 1e-6);
}

float sampleShadow(vec3 worldPos) {
    vec4 shadowViewPos = shadowModelView * vec4(worldPos, 1.0);
    vec4 shadowClipPos = shadowProjection * shadowViewPos;

    vec3 shadowNDC = shadowClipPos.xyz / max(shadowClipPos.w, 1e-6);
    vec3 shadowUVZ = shadowNDC * 0.5 + 0.5;

    if (shadowUVZ.x < 0.0 || shadowUVZ.x > 1.0 ||
        shadowUVZ.y < 0.0 || shadowUVZ.y > 1.0 ||
        shadowUVZ.z < 0.0 || shadowUVZ.z > 1.0) {
        return 1.0;
    }

    float shadowDepth = texture2D(shadowtex0, shadowUVZ.xy).r;
    return (shadowUVZ.z - SHADOW_BIAS) <= shadowDepth ? 1.0 : 0.0;
}

void main() {
    vec3 baseColor = texture2D(colortex0, vTexCoord).rgb;
    float depth = texture2D(depthtex0, vTexCoord).r;

    if (depth >= 1.0) {
        gl_FragColor = vec4(baseColor, 1.0);
        return;
    }

    vec3 viewPos = reconstructViewPos(vTexCoord, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    // Temporary flat normal until G-buffer normal integration step.
    vec3 N = vec3(0.0, 0.0, 1.0);
    vec3 L = normalize(-sunDirectionView);

    float NdotL = max(dot(N, L), 0.0);
    float shadow = sampleShadow(worldPos);

    vec3 directLight = sunColor * sunIntensity * NdotL * shadow;
    vec3 lit = baseColor * directLight;

    gl_FragColor = vec4(lit, 1.0);
}
