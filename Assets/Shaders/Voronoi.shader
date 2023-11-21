Shader "Custom/Voronoi"
{
    Properties
    {
        _CellSize ("Cell Size", Range(0,100)) = 2
        _Pow ("Power", Range(1,10)) = 1
        [MaterialToggle] _Invert("Invert", Float) = 1
        [ShowAsVector2] _Offset("Offset", Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target  3.0
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"            
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Random.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                half _CellSize;
                uint _Pow;
                float _Invert;
                float2 _Offset;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS   : POSITION;
                float2 uv           : TEXCOORD0;
            };

            struct Vert2Frac
            {
                float4 positionHCS  : SV_POSITION;
                float2 uv           : TEXCOORD0;
            };

            Vert2Frac vert (Attributes IN)
            {
                Vert2Frac OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS);
                OUT.uv = IN.uv;
                return OUT;
            }

            // Created by David Hoskins. May 2018
            #define UI0 1597334673U
            #define UI1 3812015801U
            #define UI2 uint2(UI0, UI1)
            #define UI3 uint3(UI0, UI1, 2798796415U)
            #define UI4 uint4(UI3, 1979697957U)
            #define UIF (1.0 / float(0xffffffffU))
            
            float2 hash22(float2 p)
            {
	            uint2 q = uint2(int2(p))*UI2;
	            q = (q.x ^ q.y) * UI2;
	            return float2(q) * UIF;
            }
            
            half4 frag (Vert2Frac IN) : SV_Target
            {
                // consider using the world pos instead
                float2 cellUV = IN.uv * _CellSize + _Offset;
                int2 gridUV = int2(floor(cellUV)) ;
                
                float dist = 100000000;
                
                for(int i = -1; i <= 1; i++ )
                {
                    for(int j = -1; j <= 1; j++)
                    {
                        int2 tempGridUV = gridUV + int2(i, j);
                        //float2 randUV = InitRandom(tempGridUV);
                        float2 randUV = hash22(tempGridUV);
                        float2 pointPos = randUV + float2(tempGridUV);
                        
                        dist = min(distance(pointPos, cellUV),dist);
                    }
                }
                
                dist = pow(dist,float(_Pow));
                dist = clamp(dist, 0.,1.);
                dist = _Invert > 0.5 ? 1.0 - dist : dist;
                half4 col = half4(dist, dist, dist,1.0);
                return col;
            }
            ENDHLSL
        }
    }
}
