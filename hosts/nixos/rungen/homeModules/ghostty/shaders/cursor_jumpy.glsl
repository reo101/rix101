float ease(float x) {
    return pow(1.0 - x, 10.0);
}

float sdBox(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float getSdfRectangle(in vec2 p, in vec2 xy, in vec2 b)
{
    vec2 d = abs(p - xy) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// Smooth minimum function for blending distances
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// Distance to a line segment with variable width
float sdCapsule(vec2 p, vec2 a, vec2 b, float r1, float r2) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    float r = mix(r1, r2, h);
    return length(pa - ba * h) - r;
}

// Bezier curve evaluation
vec2 bezierQuad(vec2 a, vec2 b, vec2 c, float t) {
    float u = 1.0 - t;
    return u * u * a + 2.0 * u * t * b + t * t * c;
}

// Derivative of quadratic bezier for tangent calculation
vec2 bezierQuadDerivative(vec2 a, vec2 b, vec2 c, float t) {
    return 2.0 * (1.0 - t) * (b - a) + 2.0 * t * (c - b);
}

vec2 normalize(vec2 value, float isPosition) {
    return (value * 2.0 - (iResolution.xy * isPosition)) / iResolution.y;
}

float blend(float t)
{
    float sqr = t * t;
    return sqr / (2.0 * (sqr - t) + 1.0);
}

float antialising(float distance) {
    return 1. - smoothstep(0., normalize(vec2(2., 2.), 0.).x, distance);
}

vec2 getRectangleCenter(vec4 rectangle) {
    return vec2(rectangle.x + (rectangle.z / 2.), rectangle.y - (rectangle.w / 2.));
}

/* Amber glow color palette */
const vec4 TRAIL_COLOR = vec4(0.2, 0.75, 0.25, 1.0);              // Warm amber base
const vec4 CURRENT_CURSOR_COLOR = TRAIL_COLOR;                     // Use same amber hue
const vec4 PREVIOUS_CURSOR_COLOR = TRAIL_COLOR;                    // Use same amber hue
const vec4 TRAIL_COLOR_ACCENT = vec4(0.2, 0.85, 0.4, 1.0);        // Lighter amber accent
const vec4 TRAIL_COLOR_GLOW = vec4(0.2, 0.6, 0.1, 1.0);          // Deeper amber for glow
const float DURATION = 0.5;
const float OPACITY = 0.25;                                        // Higher opacity for dramatic effect

// Comet tail parameters
const float TAIL_LENGTH_FACTOR = 1.5;                              // How long the tail extends
const float CURVE_STRENGTH = 0.3;                                  // How much the tail curves
const float TAPER_START = 0.1;                                     // Where tapering begins (0-1, 0=immediate, 1=at end)
const float TAPER_POWER = 6.0;                                     // How dramatically the tail tapers (higher = more dramatic)
const float HEAD_WIDTH_MULTIPLIER = 1.3;                           // Make head thicker than cursor
const float MIN_TAIL_WIDTH = 0.0005;                               // Minimum width at tail end
const float GLOW_INTENSITY = 0.4;
const int TAIL_SEGMENTS = 8;                                       // Number of segments for smooth tail

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    #if !defined(WEB)
    fragColor = texture(iChannel0, fragCoord.xy / iResolution.xy);
    #endif

    vec2 vu = normalize(fragCoord, 1.);
    vec2 offsetFactor = vec2(-.5, 0.5);

    vec4 currentCursor = vec4(normalize(iCurrentCursor.xy, 1.), normalize(iCurrentCursor.zw, 0.));
    vec4 previousCursor = vec4(normalize(iPreviousCursor.xy, 1.), normalize(iPreviousCursor.zw, 0.));

    // Compute animation progress
    float progress = blend(clamp((iTime - iTimeCursorChange) / DURATION, 0.0, 1.0));
    float easedProgress = ease(progress);

    vec4 newColor = vec4(fragColor);

    vec2 centerCC = getRectangleCenter(currentCursor);
    vec2 centerCP = getRectangleCenter(previousCursor);
    float lineLength = distance(centerCC, centerCP);
    float distanceToEnd = distance(vu.xy, centerCC);
    float alphaModifier = distanceToEnd / (lineLength * (easedProgress));

    if (alphaModifier > 1.0) {
        alphaModifier = 1.0;
    }

    // Current cursor rectangle
    float sdfCursor = getSdfRectangle(vu, currentCursor.xy - (currentCursor.zw * offsetFactor), currentCursor.zw * 0.5);

    // Create curved comet tail only if there's movement
    if (lineLength > 0.001) {
        // Calculate control point for bezier curve to create natural curve
        vec2 direction = normalize(centerCC - centerCP);
        vec2 perpendicular = vec2(-direction.y, direction.x);

        // Control point offset based on movement direction and distance
        float curveOffset = CURVE_STRENGTH * lineLength * sign(dot(perpendicular, vec2(1.0, 0.0)));
        vec2 controlPoint = mix(centerCP, centerCC, 0.5) + perpendicular * curveOffset;

        // Extend the tail beyond the previous position
        vec2 tailEnd = centerCP - direction * lineLength * TAIL_LENGTH_FACTOR;

        // Create the comet tail using multiple capsules
        float minTrailDist = 1000.0;

        for (int i = 0; i < TAIL_SEGMENTS; i++) {
            float t1 = float(i) / float(TAIL_SEGMENTS);
            float t2 = float(i + 1) / float(TAIL_SEGMENTS);

            // Sample points along the bezier curve
            vec2 p1 = bezierQuad(centerCC, controlPoint, tailEnd, t1);
            vec2 p2 = bezierQuad(centerCC, controlPoint, tailEnd, t2);

            // Calculate width with dramatic tapering that starts after TAPER_START
            float baseWidth1 = currentCursor.z * 0.5 * HEAD_WIDTH_MULTIPLIER;
            float baseWidth2 = currentCursor.z * 0.5 * HEAD_WIDTH_MULTIPLIER;

            // Apply tapering - more aggressive approach
            float taperT1 = smoothstep(TAPER_START, 1.0, t1);
            float taperT2 = smoothstep(TAPER_START, 1.0, t2);

            // Exponential tapering with enforced minimum
            float width1 = mix(baseWidth1, MIN_TAIL_WIDTH, pow(taperT1, TAPER_POWER));
            float width2 = mix(baseWidth2, MIN_TAIL_WIDTH, pow(taperT2, TAPER_POWER));

            // Ensure minimum width
            width1 = max(width1, MIN_TAIL_WIDTH);
            width2 = max(width2, MIN_TAIL_WIDTH);

            float segmentDist = sdCapsule(vu, p1, p2, width1, width2);
            minTrailDist = min(minTrailDist, segmentDist);
        }

        // Apply trail coloring with dramatic falloff
        if (minTrailDist < 0.05) {
            // Calculate position along tail for color variation
            float tailT = 0.0;
            vec2 closestPoint = centerCC;
            float minDist = distance(vu, centerCC);

            // Find closest point on curve for color interpolation
            for (int i = 0; i <= 20; i++) {
                float t = float(i) / 20.0;
                vec2 curvePoint = bezierQuad(centerCC, controlPoint, tailEnd, t);
                float dist = distance(vu, curvePoint);
                if (dist < minDist) {
                    minDist = dist;
                    tailT = t;
                    closestPoint = curvePoint;
                }
            }

            // Dramatic color and opacity falloff
            float intensityFalloff = pow(1.0 - tailT, 2.0);
            float widthFalloff = pow(1.0 - tailT, TAPER_POWER);

            // Create amber gradient from bright to deep
            vec4 amberTrail = mix(TRAIL_COLOR_ACCENT, TRAIL_COLOR_GLOW, tailT * 0.8);

            // Main trail body
            float trailAlpha = antialising(minTrailDist) * OPACITY * intensityFalloff;
            newColor = mix(newColor, amberTrail, trailAlpha);

            // Outer glow effect
            float glowRadius = 0.015 * (1.0 + widthFalloff);
            float glowFalloff = 1.0 - smoothstep(-glowRadius, glowRadius, minTrailDist);
            vec4 glowColor = mix(TRAIL_COLOR_GLOW, TRAIL_COLOR, 0.2);
            newColor = mix(newColor, glowColor, glowFalloff * GLOW_INTENSITY * intensityFalloff);

            // Inner bright core for comet effect
            float coreRadius = 0.003 * widthFalloff;
            float coreFalloff = 1.0 - smoothstep(-coreRadius, coreRadius, minTrailDist);
            newColor = mix(newColor, TRAIL_COLOR_ACCENT, coreFalloff * 0.6 * intensityFalloff);
        }
    }

    // Composite with scene and keep cursor on top
    newColor = mix(fragColor, newColor, 1.0 - alphaModifier);
    fragColor = mix(newColor, fragColor, step(sdfCursor, 0));
}
