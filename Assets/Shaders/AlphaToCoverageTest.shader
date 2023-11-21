// https://forum.unity.com/threads/stochastic-transparency.831115/
Shader "Custom/AlphaToCoverageTest"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        [KeywordEnum(SV_Coverage, AlphaToMask)] _MSAA_ALPHA ("MSAA Transparency Mode", Float) = 0.0
    }
    SubShader
    {
        Tags { "Queue"="AlphaTest" "RenderType"="Opaque" }
        LOD 100
 
        Pass
        {
            AlphaToMask [_MSAA_ALPHA]
 
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
 
            #pragma target 5.0
 
            #pragma shader_feature _ _MSAA_ALPHA_ALPHATOMASK
 
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
 
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };
 
            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };
 
            half4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;
 
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }
 
            // adapted from https://www.shadertoy.com/view/4djSRW
            float hash13(float3 p3)
            {
                p3  = frac(p3 * .1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }
 
            half4 frag (v2f i
            #if !defined(_MSAA_ALPHA_ALPHATOMASK)
                , out uint coverage : SV_Coverage
            #endif
                ) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv) * _Color;
                col = col.xyzx;
                float noise = hash13(i.vertex.xyz - frac(_Time.y * float3(0.5, 1.0, 2.0)));
 
                int MSAA = 4;
                col.a = saturate(col.a * ((float)(MSAA + 1) / (float)(MSAA)) - (noise / (float)(MSAA)));
 
            #if !defined(_MSAA_ALPHA_ALPHATOMASK)
                int mask = (240 >> int(col.a * float(MSAA) + 0.5)) & 15;
                int shift = (int(noise * float(MSAA-1))) & (MSAA-1);
                coverage = (((mask<<MSAA)|mask)>>shift) & 15;
 
                col.a = 1.0;
            #endif
                return col;
            }
            ENDHLSL
        }
    }
}