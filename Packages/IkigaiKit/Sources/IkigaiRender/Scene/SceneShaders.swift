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
        float4 tint;       // particles: premultiplied colour; layers: unused
    };

    struct LayerUniforms {
        float4 bounds;     // visible part of the image: minU, minV, maxU, maxV (origin top-left)
        float2 parallax;   // smoothed mouse, -1...1
        float time;
        float depth;       // 0 = still, 1 = moves most
        float overscan;    // >1 so parallax never reveals an edge
        int effect;        // 0 none, 1 sway, 2 ripple, 3 wave, 4 shake, 5 scroll
        float glow;        // glow intensity, for glow_fragment
    };

    struct ParticleUniforms {
        float2 parallax;
        float time;
        float aspect;      // width / height
        float size;        // in clip-space height units
        int style;         // 0 snow, 1 rain, 2 dust, 3 petals, 4 embers
    };

    constexpr sampler linearClamp(filter::linear, address::clamp_to_edge);
    constexpr sampler linearRepeatX(filter::linear, s_address::repeat, t_address::clamp_to_edge);

    // A quad covering only the layer's visible part, enlarged by overscan and shifted by parallax.
    vertex VOut layer_vertex(uint vid [[vertex_id]], constant LayerUniforms &u [[buffer(0)]]) {
        float2 uv = float2((vid & 1) ? u.bounds.z : u.bounds.x, (vid & 2) ? u.bounds.w : u.bounds.y);
        float2 clip = float2(uv.x * 2.0 - 1.0, 1.0 - uv.y * 2.0);
        VOut out;
        out.position = float4(clip * u.overscan - u.parallax * u.depth * 0.03, 0.0, 1.0);
        out.uv = uv;
        out.tint = float4(1.0);
        return out;
    }

    // Textures are premultiplied; the mask's red channel scales the effect per pixel.
    fragment float4 layer_fragment(VOut in [[stage_in]], constant LayerUniforms &u [[buffer(0)]],
                                   texture2d<float> image [[texture(0)]], texture2d<float> mask [[texture(1)]]) {
        float2 uv = in.uv;
        if (u.effect == 0) { return image.sample(linearClamp, uv); }  // no mask read for plain layers
        float m = mask.sample(linearClamp, uv).r;
        if (u.effect == 1) {        // sway: stronger toward the top, like branches over a fixed trunk
            uv.x += sin(uv.y * 14.0 + u.time * 1.3) * 0.006 * m * (1.0 - uv.y);
        } else if (u.effect == 2) { // water ripple: small sums of waves
            float2 wave = float2(sin(uv.y * 90.0 + u.time * 2.1) + sin(uv.x * 37.0 - u.time * 1.2),
                                 cos(uv.x * 71.0 + u.time * 1.7));
            uv += wave * 0.0022 * m;
        } else if (u.effect == 3) { // wave: a slow vertical swell travelling sideways, like cloth or tall grass
            uv.y += sin(uv.x * 9.0 + u.time * 1.4) * 0.008 * m;
        } else if (u.effect == 4) { // shake: fine jitter, like heat haze
            uv += float2(sin(u.time * 37.0 + uv.y * 50.0), cos(u.time * 29.0 + uv.x * 45.0)) * 0.0015 * m;
        } else if (u.effect == 5) { // scroll: drift sideways and wrap, for clouds or fog; the mask sets the speed
            uv.x = fract(uv.x + u.time * 0.008 * (0.25 + m));
            return image.sample(linearRepeatX, uv);
        }
        return image.sample(linearClamp, uv);
    }

    // A pre-blurred copy of the layer, added on top with a slow pulse.
    fragment float4 glow_fragment(VOut in [[stage_in]], constant LayerUniforms &u [[buffer(0)]],
                                  texture2d<float> glow [[texture(0)]]) {
        float pulse = 0.85 + 0.15 * sin(u.time * 1.2);
        return glow.sample(linearClamp, in.uv) * u.glow * pulse;
    }

    // An integer hash (lowbias32). fract(sin(x)) loses precision for large x in 32-bit floats,
    // which made particles with nearby ids share positions and line up in strands.
    float hash(uint x) {
        x ^= x >> 16; x *= 0x7feb352du; x ^= x >> 15; x *= 0x846ca68bu; x ^= x >> 16;
        return float(x) / 4294967295.0;
    }

    // Stateless particles: each instance's position is a pure function of its id and time,
    // so the CPU does nothing per particle per frame.
    vertex VOut particle_vertex(uint vid [[vertex_id]], uint iid [[instance_id]], constant ParticleUniforms &u [[buffer(0)]]) {
        uint seed = iid * 4u;
        float h1 = hash(seed), h2 = hash(seed + 1u), h3 = hash(seed + 2u), h4 = hash(seed + 3u);
        float t = u.time;
        float2 center, extent;
        float alpha;
        float3 colour;
        // Sideways wobble takes its phase from h4, never from h1 (which sets x): x = a·h1 + b·sin(c·h1)
        // stalls wherever its slope a + b·c·cos(...) reaches zero, piling particles into vertical strands.
        if (u.style == 1) {         // rain: fast, slanted streaks
            float fall = fract(h2 + t * (0.9 + 0.6 * h3));
            center = float2(h1 * 2.4 - 1.2 + fall * 0.25, 1.15 - fall * 2.3);
            extent = float2(0.0009, 0.035 * (0.5 + h3));
            alpha = 0.2 + 0.3 * h3;
            colour = float3(0.75, 0.85, 1.0);
        } else if (u.style == 2) {  // dust: slow drift in every direction, flickering
            center = float2(h1 * 2.2 - 1.1 + sin(t * 0.07 + h2 * 30.0) * 0.08, h2 * 2.2 - 1.1 + cos(t * 0.05 + h1 * 30.0) * 0.08);
            extent = float2(0.0025 * (0.4 + h3));
            alpha = (0.2 + 0.5 * h3) * (0.6 + 0.4 * sin(t * (0.5 + h4) + h1 * 20.0));
            colour = float3(1.0, 0.9, 0.7);
        } else if (u.style == 3) {  // petals: fall slowly and drift sideways
            float fall = fract(h2 + t * (0.015 + 0.03 * h3));
            center = float2(h1 * 2.4 - 1.2 + sin(t * 0.4 + h4 * 6.2832) * 0.06 + fall * 0.3, 1.1 - fall * 2.2);
            extent = float2(0.012, 0.007) * (0.6 + h3);
            alpha = 0.7 + 0.3 * h3;
            colour = float3(1.0, 0.72, 0.8);
        } else if (u.style == 4) {  // embers: rise, flicker and fade
            float rise = fract(h2 + t * (0.03 + 0.06 * h3));
            center = float2(h1 * 2.2 - 1.1 + sin(t * 0.8 + h4 * 6.2832) * 0.03, -1.1 + rise * 2.2);
            extent = float2(0.004 * (0.5 + h3));
            alpha = (1.0 - rise) * (0.6 + 0.4 * sin(t * 3.0 + h4 * 40.0));
            colour = float3(1.0, 0.55, 0.2);
        } else {                    // snow: falls with a gentle sway
            float fall = fract(h2 + t * (0.02 + 0.05 * h3));
            center = float2(h1 * 2.2 - 1.1 + sin(t * 0.5 + h4 * 6.2832) * 0.02, 1.1 - fall * 2.2);
            extent = float2(u.size * (0.4 + h3));
            alpha = 0.35 + 0.65 * h3;
            colour = float3(1.0, 0.95, 0.85);
        }
        center -= u.parallax * 0.03 * (0.3 + 0.7 * h3);
        float2 corner = float2((vid & 1) ? 1.0 : -1.0, (vid & 2) ? -1.0 : 1.0);
        VOut out;
        out.position = float4(center + corner * float2(extent.x / u.aspect, extent.y), 0.0, 1.0);
        out.uv = corner * 0.5 + 0.5;
        out.tint = float4(colour * alpha, alpha);
        return out;
    }

    fragment float4 particle_fragment(VOut in [[stage_in]]) {
        return in.tint * smoothstep(1.0, 0.0, length(in.uv - 0.5) * 2.0);   // premultiplied
    }
    """
}
