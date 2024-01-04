// https://forum.unity.com/threads/stochastic-transparency.831115/
Shader "Custom/StochasticTransparency"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
        [KeywordEnum(SV_Coverage, AlphaToMask)] _MSAA_ALPHA ("MSAA Transparency Mode", Float) = 0.0
    }
    SubShader
    {
        //Tags { "Queue"="Geometry" "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        //LOD 100
        
        Pass
        {
            Tags{"LightMode" = "ST_Transmittance"}
            
            Blend Zero OneMinusSrcColor, One One
            ZWrite Off
            //ZTest Off
            ZClip Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
 
            #pragma target 5.0
 
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
 
            half4 frag (v2f i) : SV_Target
            {
                //return half4(1.0,1.0,0.,1.);
                return _Color.a;
            }
            ENDHLSL
        }
        Pass
        {
            Tags{"LightMode" = "ST_DepthPass"}
        
            // here we only care about storing z
            ZWrite On
            ZClip Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
 
            #pragma target 5.0
 
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
                , uint primitiveID : SV_PrimitiveID
                , out uint coverage : SV_Coverage
                ) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv) * _Color;
                float noise = hash13( float3( i.vertex.x, i.vertex.y, float(primitiveID)) - frac(_Time.y * float3(0.5, 1.0, 0.)));
                
                // TODO: this needs to become a parameter somehow
                int MSAA = 4;
 
                //Ri = bαiS + ξc
                uint sampleCount = clamp(col.a * MSAA + noise, 0 , MSAA);
                int mask = (240 >> int(sampleCount + 0.5)) & 15;
                int shift = (int(noise * float(MSAA)));
                int shiftedMask = (((mask << shift) & 240) >> MSAA) ;
                coverage = (((mask<<MSAA)|mask)>>shift) & 15;
                col.a = 1.0;
 
                return col;
            }
            ENDHLSL
        }
        Pass
        {
            Tags{"LightMode" = "ST_Accumulation"}
            
            // additive blend
            Blend One One
            ZTest LEqual
            ZWrite Off
            ZClip Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
 
            #pragma target 5.0
 
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
 
            half4 frag (v2f i) : SV_Target
            {
                half4 col = tex2D(_MainTex, i.uv) * _Color;
                return half4(col.rgb * col.a, col.a);
            }
            
            ENDHLSL
        }
        
        Pass
        {
            Tags{"LightMode" = "ResolveStochasticTransparency"}
            
            ZWrite Off 
            Cull Off
            
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // The Blit.hlsl file provides the vertex shader (Vert),
            // input structure (Attributes) and output strucutre (Varyings)
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            #pragma vertex Vert
            #pragma fragment frag
            
            TEXTURE2D_X(_Transmittance);
            SAMPLER(sampler_Transmittance);
            
            TEXTURE2D_X(_ST_ColorAccumulation);
            SAMPLER(sampler_ST_ColorAccumulation);

            TEXTURE2D_X(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);

            half4 frag (Varyings input) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                float4 background = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, input.texcoord);
                
                float4 accumCol = SAMPLE_TEXTURE2D_X(_ST_ColorAccumulation, sampler_ST_ColorAccumulation, input.texcoord);
                float transmittance = SAMPLE_TEXTURE2D_X(_Transmittance, sampler_Transmittance, input.texcoord).r;
                
                // dim the background by transmittance
                background *= (transmittance);
                // coorect to filtered alpha (misses a couple things rn)
                accumCol *= (1.-transmittance);
                //blend over the filtered dimmedzz 
                float3 col = background.rgb + accumCol.rgb;
                
                //return half4(transmittance,0.,0.,1.f);
                return half4(col,1.);
                //return half4(color.rgb,1.);
                
            }
            ENDHLSL
        }
    }
}