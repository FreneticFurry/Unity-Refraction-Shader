Shader "Frenetic/Standard-MultiGrabpass" {
    Properties {
        [Header(Standard)] [Space] [Space]
        _Color("Texture Color/Tint", Color) = (1, 1, 1, 1)
        _Light("Lighting Color/Tint", Color) = (1, 1, 1, 1)
        _Transparency("Transparency", Range(0, 1)) = 1
        _MainTex("Texture (RGBA)", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalIntensity("Normal Intensity", Range(-2, 2)) = 0
        _EmissTex("Emission (RGBA)", 2D) = "black" {}
        _EmissionColor("Emission Tint", Color) = (0, 0, 0, 0)
        _EmissionIntensity("Emission Intensity", Range(0, 2)) = 0
        _Smooth("Smoothness", Range(0, 1)) = 0.3
        _Mat("Metallic", Range(0, 1)) = 0.5
		[Header(Normal Map Scrolling)]
        _NormalScroll("Normal Scroll", Vector) = (0,0,0,0)
        [Header(Refraction)] [Space] [Space]
        _IOR("IOR", Range(0, 2)) = 1
        _IORT("IOR-Type", Range(-0.5, 0.5)) = 0
        _AberrationAmount("Aberration Amount", Range(0, 0.1)) = 0
        _BlurAMT("Blur", Range(0, 1)) = 0
        [Header(Tint Outline)] [Space] [Space]
        _OutterTintColor("Outter Tint Color", Color) = (0, 0, 0, 0)
		_InnerTintColor("Inner Tint Color", Color) = (1, 1, 1, 0)
        _OutterTintRadius("Outter Tint Radius", Range(0, 1)) = 0
        _InnerTintRadius("Inner Tint Radius", Range(0, 1)) = 1
    }

    SubShader {
        Tags { "RenderType"="Geometry" "Queue"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 200

        GrabPass {  }

        CGPROGRAM
		#pragma surface surf Standard finalcolor:Tint 
        #pragma target 5.0
        #pragma multi_compile_instancing

		struct Input {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            float4 screenPos;
            float3 worldPos;
        };

        sampler2D _MainTex;
        sampler2D _NormalMap;
        sampler2D _GrabTexture;
        sampler2D _EmissTex;
        uniform float4 _Light;
        uniform float4 _Color;
        uniform float _Mat;
        uniform float _Smooth;
        uniform float _IOR;
        uniform float _IORT;
        uniform float _BlurAMT;
        uniform fixed4 _OutterTintColor;
		uniform fixed4 _InnerTintColor;
        uniform float _OutterTintRadius;
		uniform float _InnerTintRadius;
        uniform float _NormalIntensity;
        uniform float _AberrationAmount;
        uniform fixed2 _NormalScroll;
        uniform float4 _EmissionColor;
        uniform float _EmissionIntensity;
        uniform float _Transparency;

        float4 blur(sampler2D tex, float2 uv, float r) {
            float4 c = 0;
            float ws = 0;
        
            float wss[25] = { 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075 };
            [unroll(5)]
            for (int x = -2; x <= 2; x++) {
                [unroll(5)]
                for (int y = -2; y <= 2; y++) {
                    float2 off = float2(x, y) * r;
                    float w = wss[(x + 2) * 5 + (y + 2)];
                    ws += w;
                    c += tex2D(tex, uv + off) * w;
                }
            }
            return c / ws;
        }
        
        inline float4 Refraction(Input i, SurfaceOutputStandard o, float IOR, float BA) {
            float4 screenPos = i.screenPos;
            screenPos.y = (screenPos.y) * _ProjectionParams.xy * -1;
            float3 RO = (IOR - 1) * mul(UNITY_MATRIX_V, float4(o.Normal, 0.0)) * (_IORT - dot(o.Normal/2, normalize(UnityWorldSpaceViewDir(i.worldPos)))) / length(i.worldPos - _WorldSpaceCameraPos);
            float2 grabUV = (screenPos.xyz / screenPos.w + float2(RO.xy));
            float2 aberrationUV_R = grabUV + float2(_AberrationAmount/35, _AberrationAmount/-35);
            float2 aberrationUV_G = grabUV;
            float2 aberrationUV_B = grabUV - float2(_AberrationAmount/35, _AberrationAmount/-35);
            float4 RC = float4(
                blur(_GrabTexture, aberrationUV_R, BA/360).r,
                blur(_GrabTexture, aberrationUV_G, BA/360).g,
                blur(_GrabTexture, aberrationUV_B, BA/360).b,
                0.0
            );
            return RC;
        }

        void Tint(Input i, SurfaceOutputStandard o, inout half4 C) {
            #ifndef UNITY_PASS_FORWARDADD
            if (_Transparency < 0.999)
            {
                float4 refractedColor = Refraction(i, o, _IOR, _BlurAMT);
                C.rgb = lerp(C.rgb, refractedColor.rgb, 1.0 - _Transparency);
            }
            float ita = 1.0 - saturate(2 - saturate(dot(normalize(UnityWorldSpaceViewDir(i.worldPos)), o.Normal)) / _InnerTintRadius/_InnerTintRadius);
            float ota = saturate(1.25 - saturate(dot(normalize(UnityWorldSpaceViewDir(i.worldPos)), o.Normal)) / _OutterTintRadius/_OutterTintRadius);
            C.rgb = lerp(C.rgb, _InnerTintColor.rgb, ita * _InnerTintColor.a);
            C.rgb = lerp(C.rgb, _OutterTintColor.rgb, ota * _OutterTintColor.a);
            #endif
        }

        void surf(Input i, inout SurfaceOutputStandard o) {
            fixed4 c = tex2D(_MainTex, i.uv_MainTex) * _Color;
            o.Albedo = lerp(_Light.rgb, c.rgb, _Transparency);
            o.Metallic = _Mat / 1.1;
            o.Smoothness = _Smooth;
            o.Normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv_NormalMap + float2(_Time.x * _NormalScroll.x, _Time.x * _NormalScroll.y)), _NormalIntensity);
            o.Emission = tex2D(_EmissTex, i.uv_MainTex).rgb * _EmissionIntensity + _EmissionColor.rgb * _EmissionIntensity;
        }

        ENDCG
    }
    Fallback "Diffuse"
}
