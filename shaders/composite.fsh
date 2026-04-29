#version 120

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform sampler2D shadow;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 sunDirWorld;
uniform vec3 sunColor;
uniform float sunIlluminance;

const float SHADOW_BIAS = 0.0007;

vec3 reconstructViewPos(vec2 uv, float depth) {
    vec4 ndc = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * ndc;
    return view.xyz / max(view.w, 1e-6);
}

float shadowVisibility(vec3 worldPos) {
    vec4 shadowView = shadowModelView * vec4(worldPos, 1.0);
    vec4 shadowClip = shadowProjection * shadowView;

    if (shadowClip.w <= 0.0) {
        return 1.0;
    }

    vec3 shadowNdc = shadowClip.xyz / shadowClip.w;
    vec3 shadowUv = shadowNdc * 0.5 + 0.5;

    if (shadowUv.x < 0.0 || shadowUv.x > 1.0 ||
        shadowUv.y < 0.0 || shadowUv.y > 1.0 ||
        shadowUv.z < 0.0 || shadowUv.z > 1.0) {
        return 1.0;
    }

    float mapDepth = texture2D(shadow, shadowUv.xy).r;
    return (shadowUv.z - SHADOW_BIAS <= mapDepth) ? 1.0 : 0.0;
}

void main() {
    vec3 albedo = texture2D(colortex0, texcoord).rgb;
    float depth = texture2D(depthtex0, texcoord).r;

    if (depth > 0.9999) {
        gl_FragColor = vec4(albedo, 1.0);
        return;
    }

    vec3 viewPos = reconstructViewPos(texcoord, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    // Temporary flat-up normal; replace with G-buffer normal sample when available.
    vec3 N = vec3(0.0, 1.0, 0.0);
    vec3 L = normalize(-sunDirWorld);

    float NdotL = max(dot(N, L), 0.0);
    float vis = shadowVisibility(worldPos);

    vec3 E = sunColor * sunIlluminance;
    vec3 Lo = albedo * E * NdotL * vis;

    gl_FragColor = vec4(Lo, 1.0);
}
