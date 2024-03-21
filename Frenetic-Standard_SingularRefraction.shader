Shader "Frenetic/Standard_SingularRefraction" {
    Properties {
        [Header(Standard)]
        _Color("Texture Color/Tint", Color) = (1, 1, 1, 1)
        _MainTex("Texture (RGBA)", 2D) = "white" {}
        _NormalMap("Normal Map", 2D) = "bump" {}
        _NormalIntensity("Normal Intensity", Range(-2, 2)) = 0
        _Smooth("Smoothness", Range(0, 1)) = 0.3
        _Mat("Metallic", Range(0, 1)) = 0.5
        [Header(Refraction)]
        _IOR("IOR", Range(0, 2)) = 1
        _IORT("IOR-Type", Range(-0.5, 0.5)) = 0
        _AberrationAmount("Aberration Amount", Range(0, 0.1)) = 0
        _BlurAMT("Blur", Range(0, 1)) = 0
        [Header(Tint Outline)]
        _TintColor("Tint Color", Color) = (0, 0, 0, 0)
        _TintRadius("Tint Radius", Range(0, 1)) = 1
    }

    SubShader {
        Tags { "RenderType" = "Opaque" "Queue" = "Transparent+0" "IsEmissive" = "true" }
        LOD 200
        Cull Off

        GrabPass { "_GrabbyHands" }

        CGINCLUDE
        #pragma target 5.0
        #pragma multi_compile _ALPHAPREMULTIPLY_ON

        struct Input {
            float2 uv_MainTex;
            float2 uv_NormalMap;
            INTERNAL_DATA
            float4 screenPos;
            float3 worldPos;
        };

        sampler2D _MainTex;
        sampler2D _NormalMap;
        sampler2D _GrabbyHands;
        uniform float4 _Color;
        uniform float _Mat;
        uniform float _Smooth;
        uniform float _IOR;
        uniform float _IORT;
        uniform float _BlurAMT;
        uniform fixed4 _TintColor;
        uniform float _TintRadius;
        uniform float _NormalIntensity;
        uniform float _AberrationAmount;

        float4 blur(sampler2D tex, float2 uv, float r) {
            float4 c = 0;
            float ws = 0;
        
            float wss[25] = { 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 
                                  0.075, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 
                                  0.075, 0.075, 0.075, 0.075, 0.075, 0.075, 0.075 };
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
            screenPos.y = (screenPos.y - screenPos.w * 0.5) * _ProjectionParams.x * -1 + screenPos.w * 0.5;
            screenPos.w += 0.00000000001;
            float3 RO = (IOR - 1.0) * mul(UNITY_MATRIX_V, float4(o.Normal, 0.0)) * (_IORT - dot(o.Normal, normalize(UnityWorldSpaceViewDir(i.worldPos))));
            float2 grabUV = (screenPos.xy / screenPos.w + float2(RO.x, RO.y));
            float2 aberrationUV_R = grabUV + float2(_AberrationAmount/35, _AberrationAmount/-35);
            float2 aberrationUV_G = grabUV;
            float2 aberrationUV_B = grabUV - float2(_AberrationAmount/35, _AberrationAmount/-35);
            float4 RC = float4(
                blur(_GrabbyHands, aberrationUV_R, BA/350).r,
                blur(_GrabbyHands, aberrationUV_G, BA/350).g,
                blur(_GrabbyHands, aberrationUV_B, BA/350).b,
                1.0
            );
            return RC;
        }
        
        void Tint(Input i, SurfaceOutputStandard o, inout half4 C) {
            C.rgb = C.rgb + Refraction(i, o, _IOR, _BlurAMT) * (1 - C.a);
            float ta = saturate(1.25 - saturate(dot(normalize(UnityWorldSpaceViewDir(i.worldPos)), o.Normal)) / _TintRadius);
            C.rgb = lerp(C.rgb, _TintColor.rgb, ta * _TintColor.a);
        }        

        void surf(Input i, inout SurfaceOutputStandard o) {
            fixed4 c = tex2D(_MainTex, i.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;
            o.Metallic = _Mat;
            o.Smoothness = _Smooth;
            o.Normal = UnpackScaleNormal(tex2D(_NormalMap, i.uv_NormalMap), _NormalIntensity);
            o.Normal = o.Normal + 0.00001 * i.screenPos * i.worldPos;
        }
        ENDCG

        CGPROGRAM
        #pragma surface surf Standard keepalpha finalcolor:Tint fullforwardshadows exclude_path:deferred
        ENDCG
    }
    Fallback "Diffuse"
}
