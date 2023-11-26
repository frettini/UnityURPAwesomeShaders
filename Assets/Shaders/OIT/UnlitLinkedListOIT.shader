Shader "Custom/OIT/UnlitLinkedListOIT"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "Queue"="Geometry" }

        Pass
        {
            ZTest LEqual
			ZWrite Off
			Cull Off
			ColorMask 0
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma require randomwrite
            #pragma multi_compile __ IS_UNITY_EDITOR

            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            #include "Assets/Shaders/OIT/OITCommon.hlsl"
            #include "Assets/Shaders/OIT/OITLinkedListCommon.hlsl"
            
            RWStructuredBuffer<FragmentAndLinkBuffer_STRUCT> fragmentLLBuffer : register(u1);
            RWByteAddressBuffer startOffsetBuffer : register(u2);
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 screenPos : TEXCOORD1;
                
            };

            half4 _Color;
            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            [earlydepthstencil]
            half4 frag (v2f i, uint uCoverage : SV_Coverage) : SV_Target
            {
                
                // get the color, need to pack it somehow
                float4 col = tex2D(_MainTex, i.uv) * _Color; 
                
                // vertex is already in window space, shift by 0.5 to make sure we are in bounds
                float2 screenPos = (i.vertex.xy-0.5);
                
                // get the address of the buffer from screen pos
                uint offsetAddress = SIZEOF_UINT * (screenPos.y * _ScreenParams.x + screenPos.x);
                uint oldOffsetAddress;
                
                // increment to the last address of the linked list
                uint counter = fragmentLLBuffer.IncrementCounter();
                // exchange the value with the current counter value
                startOffsetBuffer.InterlockedExchange(offsetAddress, counter, oldOffsetAddress);
                
                // now need to add the value to the linked list
                FragmentAndLinkBuffer_STRUCT frag;
                frag.color = PackRGBA(col);
                frag.depth = PackDepthSampleIdx( Linear01Depth( i.vertex.z, _ZBufferParams), uCoverage );
                frag.next = oldOffsetAddress;
                fragmentLLBuffer[counter] = frag;
                
                return col;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Unlit/Transparent"
}
