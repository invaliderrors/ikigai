/// Metal Shading Language for the scene renderer.
// shortcut: compiled from source at startup (a few ms) so `swift build` and `swift test` work without
// Xcode's Metal compiler; move to a precompiled .metal library when Phase 2 grows past the spike.
enum SceneShaders {
    static let source = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut {
        float4 position [[position]];
        float2 uv;
        float alpha;
    };

    struct LayerUniforms {
        float2 parallax;   // smoothed mouse, -1...1
        float time;
        float depth;       // 0 = still, 1 = moves most
        float overscan;    // >1 so parallax never reveals an edge
        int effect;        // 0 none, 1 sway, 2 ripple
    };

    struct ParticleUniforms {
        float2 parallax;
        float time;
        float aspect;      // width / height
        float size;        // in clip-space height units
    };

    constexpr sampler linearClamp(filter::linear, address::clamp_to_edge);

    // A full-screen quad from four vertex ids, enlarged by overscan and shifted by parallax.
    vertex VOut layer_vertex(uint vid [[vertex_id]], constant LayerUniforms &u [[buffer(0)]]) {
        float2 corner = float2((vid & 1) ? 1.0 : -1.0, (vid & 2) ? -1.0 : 1.0);
        VOut out;
        out.position = float4(corner * u.overscan - u.parallax * u.depth * 0.03, 0.0, 1.0);
        out.uv = float2(corner.x * 0.5 + 0.5, 0.5 - corner.y * 0.5);
        out.alpha = 1.0;
        return out;
    }

    // Textures are premultiplied; the mask's red channel scales the effect per pixel.
    fragment float4 layer_fragment(VOut in [[stage_in]], constant LayerUniforms &u [[buffer(0)]],
                                   texture2d<float> image [[texture(0)]], texture2d<float> mask [[texture(1)]]) {
        float2 uv = in.uv;
        float m = mask.sample(linearClamp, uv).r;
        if (u.effect == 1) {        // sway: stronger toward the top, like branches over a fixed trunk
            uv.x += sin(uv.y * 14.0 + u.time * 1.3) * 0.006 * m * (1.0 - uv.y);
        } else if (u.effect == 2) { // water ripple: small sums of waves
            float2 wave = float2(sin(uv.y * 90.0 + u.time * 2.1) + sin(uv.x * 37.0 - u.time * 1.2),
                                 cos(uv.x * 71.0 + u.time * 1.7));
            uv += wave * 0.0022 * m;
        }
        return image.sample(linearClamp, uv);
    }

    float hash(float n) { return fract(sin(n) * 43758.5453); }

    // Stateless particles: each instance's position is a pure function of its id and time,
    // so the CPU does nothing per particle per frame.
    vertex VOut particle_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant ParticleUniforms &u [[buffer(0)]]) {
        float id = float(iid);
        float h1 = hash(id * 12.9898), h2 = hash(id * 78.233), h3 = hash(id * 39.425);
        float fall = fract(h2 + u.time * (0.02 + 0.05 * h3));
        float2 center = float2(h1 * 2.2 - 1.1 + sin(u.time * 0.5 + h1 * 40.0) * 0.02, 1.1 - fall * 2.2);
        center -= u.parallax * 0.03 * (0.3 + 0.7 * h3);
        float2 corner = float2((vid & 1) ? 1.0 : -1.0, (vid & 2) ? -1.0 : 1.0);
        float size = u.size * (0.4 + h3);
        VOut out;
        out.position = float4(center + corner * float2(size / u.aspect, size), 0.0, 1.0);
        out.uv = corner * 0.5 + 0.5;
        out.alpha = 0.35 + 0.65 * h3;
        return out;
    }

    fragment float4 particle_fragment(VOut in [[stage_in]]) {
        float a = smoothstep(1.0, 0.0, length(in.uv - 0.5) * 2.0) * in.alpha;
        return float4(1.0, 0.95, 0.85, 1.0) * a;   // premultiplied
    }
    """
}
