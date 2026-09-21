import Foundation

/// DuoFold uses the analytic fold maps from DhananjayBhosale/MacDuo.
enum DepthShaders {
    static let source = #"""

    #include <metal_stdlib>
    using namespace metal;
    struct RefUniforms { float progress; float perspective; float blur; float shadow; float2 size; float fadeOnly; uint effect; float defocus; float coverage; float tilt; float referenceAngle; };
    struct Varying { float4 position [[position]]; float2 uv; };

    vertex Varying depthVertex(uint id [[vertex_id]]) {
        const float2 p[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
        Varying v;
        v.position = float4(p[id],0,1);
        v.uv = float2((p[id].x+1)*0.5f,1-(p[id].y+1)*0.5f);
        return v;
    }

    // Sigma is a fraction of image height so the preview and the Retina desktop
    // agree. Zero sigma reads the untouched source, keeping the open image exact.
    static float3 foldSample(texture2d<float> desktop, texture2d<float> pyramid,
                             sampler s, float2 uv, float sigmaUV) {
        if (!(sigmaUV > 0.0f)) return desktop.sample(s,uv).rgb;
        float sigma = sigmaUV*float(desktop.get_height());
        // Each 2x level contributes 1.25 source-pixel variance per axis.
        float lod = 0.5f*log2(1.0f+sigma*sigma*2.4f);
        lod = min(lod,float(pyramid.get_num_mip_levels()-1));
        return pyramid.sample(s,uv,level(lod)).rgb;
    }

    // ---------------------------------------------------------------- Ghost
    // Intersect a stationary viewer's ray through the moving panel with the
    // original desktop plane. The hinge stays fixed; panel pixels compensate
    // for tilt so the desktop appears anchored behind the physical display.
    // Fix the viewer relative to the keyboard, not to each new resting screen.
    static float4 foldGhost(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                            sampler s, thread const RefUniforms& u, float p) {
        float height = 1.0f-uv.y;
        float perspective = clamp(u.perspective,0.0f,1.0f);
        float viewerDistance = mix(2.6f,1.6f,perspective);
        // Shallow resting angles use an upright virtual plane: a real viewer
        // may otherwise lie behind it. This continuous fallback keeps eyeZ >= 1.6.
        float reference = clamp(u.referenceAngle,90.0f,140.0f)*M_PI_F/180.0f;
        float eyeY = 1.6f*sin(reference)+viewerDistance*cos(reference);
        float eyeZ = viewerDistance*sin(reference)-1.6f*cos(reference);
        float angle = clamp(u.tilt >= 0 ? u.tilt : p*M_PI_F*0.5f,0.0f,85.0f*M_PI_F/180.0f);
        float depth = height*sin(angle);
        float rayScale = eyeZ/(eyeZ-depth);
        float2 sourceUV = float2(0.5f+(uv.x-0.5f)*rayScale,
                                1.0f-(eyeY+(height*cos(angle)-eyeY)*rayScale));
        // Ease the first 1.7 degrees without a pixel jump from exact passthrough.
        float onset = clamp(angle/0.03f,0.0f,1.0f);
        onset = onset*onset*onset*(onset*(onset*6.0f-15.0f)+10.0f);
        sourceUV = mix(uv,sourceUV,onset);
        float focus = u.defocus >= 0 ? pow(clamp(u.defocus,0.0f,1.0f),1.25f) : p*p;
        // Defocus measures distance from the hinge, while the onset remains
        // gentle for the first few degrees, independent of the resting angle.
        float separation = pow(height,1.65f);
        float sigmaUV = clamp(u.blur,0.0f,1.0f)*0.045f*focus*separation;
        // Tilt slightly minifies fine content even with user defocus off.
        sigmaUV = max(sigmaUV,0.5f*max(0.0f,rayScale-1.0f)/float(desktop.get_height()));
        float3 color = foldSample(desktop,pyramid,s,sourceUV,sigmaUV);
        // Soften the exposed sides along with the content, instead of cutting
        // a sharp trapezoid out of an already blurred image. At zero tilt the
        // exact-passthrough branch retains every original edge pixel.
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float2 feather = max(float2(3.0f*sigmaUV/aspect,3.0f*sigmaUV),fwidth(sourceUV));
        float2 border = smoothstep(-feather,feather,sourceUV)
                       *(1.0f-smoothstep(1.0f-feather,1.0f+feather,sourceUV));
        float edgeCoverage = mix(1.0f,border.x*border.y,smoothstep(0.0f,0.025f,angle));
        float shade = 1.0f-clamp(u.shadow,0.0f,1.0f)*0.10f*focus*height;
        float disappear = 1.0f-smoothstep(0.86f,1.0f,p);
        return float4(color*shade*edgeCoverage*disappear,1);
    }

    // ---------------------------------------------------------------- Roll
    // The sheet stays flat from the hinge up to a tangent height that descends
    // with the angle. Above it the material wraps a cylinder whose radius grows
    // like a spiral roll, so arc length is the inverse map: one asin per pixel.
    static float4 foldRoll(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, thread const RefUniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float thickness = 0.028f+0.055f*persp;
        float tangent = 1.0f-p;
        float radius = sqrt(0.0001f+thickness*p/M_PI_F);
        float feather = 0.0022f+0.004f*soft;

        // The lowest material on the roll: the loose edge stops before the
        // underside once the whole image has been taken up.
        float edgeAngle = clamp((1.0f-tangent)/max(radius,1e-5f),M_PI_F*0.5f,M_PI_F*1.5f);
        float lowest = min(tangent,tangent+radius*sin(edgeAngle));

        float3 plane = desktop.sample(s,uv).rgb;
        plane *= 1.0f-shad*0.5f*exp(-max(0.0f,lowest-h)/(0.05f+0.05f*soft));
        float3 color = plane*smoothstep(0.0f,feather,tangent-h);

        float k = clamp((h-tangent)/max(radius,1e-5f),-1.0f,1.0f);
        float theta = M_PI_F-asin(k);
        float arc = tangent+radius*theta;
        float facing = max(abs(cos(theta)),0.015f);
        float sigmaUV = min(0.45f/(facing*float(desktop.get_height())),0.03f)
                      + soft*0.030f*(u.defocus >= 0 ? u.defocus : p)*(0.25f+0.75f*(1.0f-facing));
        float3 rolled = foldSample(desktop,pyramid,s,float2(uv.x,1.0f-arc),sigmaUV);
        float lambert = max(0.0f,0.548f*sin(theta)-0.836f*cos(theta));
        float gloss = pow(lambert,14.0f);
        rolled *= mix(1.0f,0.42f+0.58f*lambert,0.35f+0.65f*shad)+gloss*(0.08f+0.20f*shad);
        float onRoll = smoothstep(0.0f,feather,radius-abs(h-tangent))
                     * smoothstep(0.0f,feather*2.0f+0.5f*sigmaUV,1.0f-arc);
        color = mix(color,rolled,onRoll);
        return float4(min(color,float3(1.0f))*(1.0f-smoothstep(0.88f,1.0f,p)),1);
    }

    // ------------------------------------------------------------- Shutter
    // Four quarter-height panels, each a pure translation of its own band, so
    // pixels inside a panel stay rigid. Front to back: the first panel that
    // covers the pixel wins, which is what makes the overlapping rims visible.
    static float4 foldShutter(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                              sampler s, thread const RefUniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        const float panel = 0.25f;
        float sink = panel+0.12f*persp;
        float relief = shad*smoothstep(0.0f,0.10f,p);
        float feather = 0.0016f+0.004f*soft;
        float3 color = float3(0.0f);
        float covered = 0.0f;
        for (uint j=0;j<4;j++) {
            float drop = p*(panel*float(j)+sink);
            float row = h+drop;
            float low = panel*float(j);
            float inset = persp*0.022f*float(j)*p/aspect;
            float cover = smoothstep(0.0f,feather,low+panel-row)*smoothstep(0.0f,feather,row-low)
                        * smoothstep(0.0f,feather,uv.x-inset)*smoothstep(0.0f,feather,1.0f-inset-uv.x);
            cover *= 1.0f-covered;
            if (cover <= 0.0f) continue;
            float sigmaUV = soft*0.014f*float(j)*(u.defocus >= 0 ? u.defocus : p);
            float3 slab = foldSample(desktop,pyramid,s,float2(uv.x,1.0f-row),sigmaUV);
            // The bevel on this panel's own top edge, then the shadow the panel
            // in front of it drops across this one.
            float rim = 1.0f+relief*0.35f*exp(-(low+panel-row)/(0.004f+0.008f*soft));
            float shade = 1.0f-relief*0.09f*float(j)*p;
            if (j > 0u) {
                float frontTop = panel*float(j)-p*(panel*float(j-1u)+sink);
                shade *= 1.0f-relief*0.55f*exp(-max(0.0f,h-frontTop)/(0.012f+0.03f*soft));
            }
            color += min(slab*rim*shade,float3(1.0f))*cover;
            covered += cover;
        }
        return float4(color*(1.0f-smoothstep(0.90f,1.0f,p)),1);
    }

    // ---------------------------------------------------------------- Flex
    // One continuous sheet: a dome silhouette, vertical foreshortening toward the
    // tipped-back top edge, and a horizontal cylindrical unwrap (asin) for the
    // inward bow. Everything is one continuous deformation of the same image.
    static float4 foldFlex(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, thread const RefUniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float h = 1.0f-uv.y;
        float lateral = (uv.x-0.5f)*2.0f;
        float collapse = 1.0f-0.85f*smoothstep(0.72f,1.0f,p);
        float top = (1.0f-0.40f*p)*collapse*(1.0f-p*0.10f*lateral*lateral);
        float eta = h/max(top,1e-4f);
        float bend = p*(0.45f+1.15f*persp);
        float material = eta*(1.0f+bend*eta)/(1.0f+bend);
        float waist = 1.0f-p*(0.10f+0.15f*persp)*material*material;
        float across = lateral/max(waist,1e-3f);
        float arc = p*(0.32f+0.42f*persp);
        float sweep = sin(arc);
        float unwrap = arc > 1e-4f ? asin(clamp(across*sweep,-0.99999f,0.99999f))/arc : across;
        float2 src = float2(0.5f+0.5f*unwrap,1.0f-material);

        float lean = clamp((1.0f+bend)/(1.0f+2.0f*bend*eta),0.02f,1.0f);
        float toward = clamp(lean*cos(unwrap*arc),0.02f,1.0f);
        float sigmaUV = min(0.45f/(lean*float(desktop.get_height())),0.02f)
                      + soft*(u.defocus >= 0 ? u.defocus : p)*(0.012f+0.030f*(1.0f-toward)+0.014f*eta);
        float3 color = foldSample(desktop,pyramid,s,src,sigmaUV);
        color *= mix(1.0f,0.35f+0.65f*toward,0.30f+0.70f*shad);
        // A glossy reflection band placed by the surface normal, not by a timeline.
        float sheenWidth = 0.10f+0.35f*arc;
        float sheen = exp(-pow((unwrap*arc+0.75f*arc)/sheenWidth,2.0f))*(0.35f+0.65f*eta);
        color += sheen*(0.05f+0.13f*shad)*p;
        color *= 1.0f-shad*0.30f*smoothstep(0.0f,0.10f,p)*exp(-h/0.03f);

        float fade = 0.0022f+0.004f*soft+1.2f*sigmaUV;
        float mask = smoothstep(0.0f,fade,1.0f-abs(across))*smoothstep(0.0f,fade,top-h)
                   * smoothstep(0.0f,p*(0.012f+0.025f*soft)+0.5f*sigmaUV,h);
        return float4(min(color,float3(1.0f))*mask*(1.0f-smoothstep(0.90f,1.0f,p)),1);
    }

    // ---------------------------------------------------------------- Iris
    // Eight blades, each a half plane with a curved leading edge, closing on a
    // centre just above the hinge. The aperture is the maximum of the eight edge
    // functions, so coverage has no gaps; blade order only decides the shading,
    // which is what draws the overlapping seams. The desktop itself stays put.
    static float4 foldIris(float2 uv, texture2d<float> desktop, texture2d<float> pyramid,
                           sampler s, thread const RefUniforms& u, float p) {
        float persp = clamp(u.perspective,0.0f,1.0f);
        float soft = clamp(u.blur,0.0f,1.0f);
        float shad = clamp(u.shadow,0.0f,1.0f);
        float aspect = max(u.size.x,1.0f)/max(u.size.y,1.0f);
        float2 q = float2((uv.x-0.5f)*aspect,(1.0f-uv.y)-0.14f);
        float aperture = 1.32f*pow(1.0f-p,1.3f);
        float curve = 0.30f*persp;
        float twist = p*(0.16f+0.22f*persp);
        const uint blades = 8u;
        float pitch = 2.0f*M_PI_F/float(blades);
        float overhang = aperture*tan(M_PI_F/float(blades))+0.10f;

        float outside = -1e9f;
        uint owner = 0u, strongest = 0u;
        bool claimed = false;
        float ownerEdge = 0.0f;
        for (uint i=0;i<blades;i++) {
            float phi = float(i)*pitch+twist;
            float along = q.x*cos(phi)+q.y*sin(phi);
            float across = q.y*cos(phi)-q.x*sin(phi);
            float edge = along-aperture-curve*across*across;
            if (edge > outside) { outside = edge; strongest = i; }
            if (!claimed && edge >= 0.0f && across >= -overhang) {
                claimed = true; owner = i; ownerEdge = edge;
            }
        }
        if (!claimed) { owner = strongest; ownerEdge = max(outside,0.0f); }

        float inside = max(0.0f,-outside);
        // Keep gaining optical depth after the first 15 degrees, rather than
        // reaching full rim blur while the rest of the screen is nearly sharp.
        float rimSigma = soft*0.030f*(u.defocus >= 0 ? u.defocus : 1.0f)*exp(-inside/(0.035f+0.05f*soft));
        float3 color = foldSample(desktop,pyramid,s,uv,rimSigma);
        color *= 1.0f-shad*0.55f*exp(-inside/(0.028f+0.055f*soft));

        float phiOwner = float(owner)*pitch+twist;
        float tone = 0.052f+0.040f*(0.5f+0.5f*cos(phiOwner+0.7f));
        float body = tone*(1.0f-0.35f*smoothstep(0.0f,0.5f,ownerEdge));
        float seam = 1.0f;
        if (owner > 0u) {
            float phiAbove = float(owner-1u)*pitch+twist;
            float alongAbove = q.x*cos(phiAbove)+q.y*sin(phiAbove);
            float acrossAbove = q.y*cos(phiAbove)-q.x*sin(phiAbove);
            float past = -(acrossAbove+overhang);
            if (alongAbove >= aperture && past > 0.0f) {
                seam = 1.0f-(0.25f+0.45f*shad)*exp(-past/(0.010f+0.03f*soft));
            }
        }
        float shine = 0.26f*exp(-ownerEdge/(0.0035f+0.012f*soft));
        float3 blade = (body*seam+shine)*(1.0f-smoothstep(0.88f,1.0f,p));
        float aa = 1.5f/max(u.size.y,1.0f)+soft*0.0035f;
        return float4(min(mix(color,blade,smoothstep(0.0f,aa,outside)),float3(1.0f)),1);
    }

    static float4 foldEffectPixel(float2 screenUV, texture2d<float> desktop,
        texture2d<float> pyramid, thread const RefUniforms& u) {
        constexpr sampler s(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
        float p = clamp(u.progress,0.0f,1.0f);
        if (p < 0.00001f) return float4(desktop.sample(s,screenUV).rgb,1);
        if (u.fadeOnly > 0.5f) return float4(desktop.sample(s,screenUV).rgb*(1-p),1);
        if (p >= 1.0f) return float4(0,0,0,1);
        if (u.effect == 5u) return foldGhost(screenUV,desktop,pyramid,s,u,p);
        if (u.effect >= 1u && u.effect <= 4u) {
            float4 result;
            if (u.effect == 1u) result = foldRoll(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 2u) result = foldShutter(screenUV,desktop,pyramid,s,u,p);
            else if (u.effect == 3u) result = foldFlex(screenUV,desktop,pyramid,s,u,p);
            else result = foldIris(screenUV,desktop,pyramid,s,u,p);
            // Introduce the material's seams and contact shadows continuously.
            // Without this short angle-driven onset, fixed antialias widths and
            // depth shading can flash when the exact-open branch disengages.
            if (p < 0.04f) {
                result.rgb = mix(desktop.sample(s,screenUV).rgb,result.rgb,smoothstep(0.0f,0.04f,p));
            }
            return result;
        }

        // The physical lid already supplies the camera's trapezoid. Expand the
        // image around its bottom-centre hinge so icons swell and upper content
        // leaves through the top. A bounded map avoids singularities at closure.
        float height = 1.0f-screenUV.y;
        float expansion = 1.0f+p*(0.12f+mix(0.30f,0.66f,clamp(u.perspective,0.0f,1.0f))*height);
        float2 uv = float2(0.5f+(screenUV.x-0.5f)/expansion,1.0f-height/expansion);

        // Sigma is measured as a fraction of image height, matching the preview
        // and Retina desktop. The hinge stays more focused, but not pin-sharp.
        float focus = u.defocus >= 0 ? u.defocus : pow(p,0.7f);
        float spread = 0.12f+0.88f*pow(height,1.15f);
        float sigmaUV = clamp(u.blur,0.0f,1.0f)*0.052f*focus*spread;
        float sigma = sigmaUV*float(desktop.get_height());
        // Each 2x level contributes 1.25 source-pixel variance per axis.
        float lod = 0.5f*log2(1.0f+sigma*sigma*2.4f);
        lod = min(lod,float(pyramid.get_num_mip_levels()-1));
        float3 color = pyramid.sample(s,uv,level(lod)).rgb;
        // Feather in display coordinates: zooming the source beyond its borders
        // must not remove the dark surround. Side widths use height units to keep
        // the same optical width on different display aspect ratios.
        float softness = clamp(u.blur,0.0f,1.0f);
        float topWidth = p*(0.075f+0.15f*softness)+1.5f*sigmaUV;
        float sideWidth = (p*(0.055f+0.12f*softness)+1.5f*sigmaUV)*u.size.y/u.size.x;
        float bottomWidth = p*(0.012f+0.025f*softness)+0.5f*sigmaUV;
        float mask = smoothstep(0.0f,topWidth,screenUV.y)*smoothstep(0.0f,bottomWidth,height)
                   * smoothstep(0.0f,sideWidth,screenUV.x)*smoothstep(0.0f,sideWidth,1.0f-screenUV.x);
        float shade = 1.0f-clamp(u.shadow,0.0f,1.0f)*0.12f*p*p*height;
        float disappear = 1.0f-smoothstep(0.86f,1.0f,p);
        return float4(color*mask*shade*disappear,1);
    }


    struct Uniforms {
        float4 column0;
        float4 column1;
        float4 column2;
        float4 screenAndOrigin;
        float4 paddedAndBlur;
        float4 shape;
        float4 light;
        float4 mode;
    };

    fragment float4 depthFragment(float4 position [[position]],
                                   constant Uniforms &uniforms [[buffer(0)]],
                                   texture2d<float> picture [[texture(0)]],
                                   texture2d<float> pyramid [[texture(1)]]) {
        constexpr sampler linearSampler(coord::normalized, address::clamp_to_edge, filter::linear, mip_filter::linear);
        float2 screenSize = uniforms.screenAndOrigin.xy;
        float2 paddedOrigin = uniforms.screenAndOrigin.zw;
        float2 paddedSize = uniforms.paddedAndBlur.xy;
        float pixelScale = uniforms.shape.z;
        float progress = clamp(uniforms.mode.x, 0.0f, 1.0f);
        float2 screenPoint = float2(position.x / max(pixelScale, 1.0f),
                                    screenSize.y - position.y / max(pixelScale, 1.0f));
        float3x3 screenToPicture = float3x3(uniforms.column0.xyz,
                                            uniforms.column1.xyz,
                                            uniforms.column2.xyz);
        float3 mapped = screenToPicture * float3(screenPoint, 1.0f);
        if (abs(mapped.z) < 1e-6f) return float4(0.0f, 0.0f, 0.0f, 1.0f);
        float2 picturePoint = mapped.xy / mapped.z;
        float2 unit = (picturePoint - paddedOrigin) / max(paddedSize, float2(1.0f));
        if (unit.x < 0.0f || unit.x > 1.0f || unit.y < 0.0f || unit.y > 1.0f)
            return float4(0.0f, 0.0f, 0.0f, 1.0f);
        float2 screenUV = float2(unit.x, 1.0f - unit.y);
        RefUniforms ref;
        ref.progress = progress;
        ref.perspective = 0.7f;
        ref.blur = clamp(uniforms.paddedAndBlur.w, 0.0f, 1.0f);
        ref.shadow = clamp(uniforms.light.y, 0.0f, 1.0f);
        ref.size = screenSize;
        ref.fadeOnly = 0.0f;
        ref.effect = uint(max(0.0f, uniforms.mode.y));
        ref.defocus = progress;
        ref.coverage = 1.0f;
        ref.tilt = progress * 1.5707963f;
        ref.referenceAngle = 105.0f;
        return foldEffectPixel(screenUV, picture, pyramid, ref);
    }
    """#
}
