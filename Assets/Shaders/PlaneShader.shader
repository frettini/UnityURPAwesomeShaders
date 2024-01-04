Shader "Custom/GridPlane"
{
    Properties
    {
        _GridSize ("Grid Size", Range(0,100)) = 2
        _Color1 ("Color 1", Color) = (0.5,0.5,0.5,1)
        _Color2 ("Color 2", Color) = (0.25,0.25,0.25,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque"  "RenderPipeline" = "UniversalRenderPipeline" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target  3.0
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            
            CBUFFER_START(UnityPerMaterial)
                float _GridSize;
                half4 _Color1;
                half4 _Color2;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Vert2Frac
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
            };

            
            Vert2Frac vert (Attributes IN)
            {
                Vert2Frac OUT;
                OUT.positionWS = TransformObjectToWorld(IN.positionOS);
                OUT.positionHCS = TransformWorldToHClip(OUT.positionWS);
                OUT.uv = IN.uv;
                return OUT;
            }
            
            half4 frag (Vert2Frac IN) : SV_Target
            {
                // consider using the world pos instead
                float2 cellUV = IN.uv * _GridSize;
                int2 gridUV = int2(floor(cellUV)) ;
                return (gridUV.x % 2) == (gridUV.y % 2) ? _Color1 : _Color2;
            }
            ENDHLSL
        }
    }
}
