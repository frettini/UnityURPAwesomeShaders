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
			ColorMask 0
			Cull Off
            
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma require randomwrite
            
            //#include "UnityCG.cginc"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            #define SIZEOF_UINT 4
            
            struct FragmentAndLinkBuffer_STRUCT
            {
                uint color;
                uint depth;
                uint next;
            };
            
            RWStructuredBuffer<FragmentAndLinkBuffer_STRUCT> fragmentLLBuffer : register(u1);
            RWByteAddressBuffer startOffsetBuffer : register(u2);
            
            //https://github.com/GameTechDev/AOIT-Update/blob/master/OIT_DX11/AOIT%20Technique/AOIT.hlsl
            // UnpackRGBA takes a uint value and converts it to a float4
            float4 UnpackRGBA(uint packedInput)
            {
	            float4 unpackedOutput;
	            uint4 p = uint4((packedInput & 0xFFUL),
		            (packedInput >> 8UL) & 0xFFUL,
		            (packedInput >> 16UL) & 0xFFUL,
		            (packedInput >> 24UL));

	            unpackedOutput = ((float4)p) / 255;
	            return unpackedOutput;
            }

            // PackRGBA takes a float4 value and packs it into a UINT (8 bits / float)
            uint PackRGBA(float4 unpackedInput)
            {
	            uint4 u = (uint4)(saturate(unpackedInput) * 255 + 0.5);
	            uint packedOutput = (u.w << 24UL) | (u.z << 16UL) | (u.y << 8UL) | u.x;
	            return packedOutput;
            }

            float UnpackDepth(uint uDepthSampleIdx) {
	            return (float)(uDepthSampleIdx >> 8UL) / (pow(2, 24) - 1);
            }

            uint UnpackSampleIdx(uint uDepthSampleIdx) {
	            return uDepthSampleIdx & 0xFFUL;
            }

            uint PackDepthSampleIdx(float depth, uint uSampleIdx) {
	            uint d = (uint)(saturate(depth) * (pow(2, 24) - 1));
	            return d << 8UL | uSampleIdx;
            }


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
                //o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.screenPos = ComputeScreenPos(o.vertex);
                return o;
            }

            [earlydepthstencil]
            half4 frag (v2f i, uint uSampleIndex : SV_SampleIndex) : SV_Target
            {
                // increment to the last address of the linked list
                uint counter = fragmentLLBuffer.IncrementCounter();
                
                // get the color, need to pack it somehow
                float4 col = tex2D(_MainTex, i.uv) * _Color; 
                
                // we want to get the screenpos so we can access where we are in the start offset buffer
                //float2 screenPos = i.screenPos / i.screenPos.w;//
                float2 screenPos = i.vertex.xy - 0.5;
                
                //return half4(screenPos, 0.,1.);
                // get the address of the buffer from screen pos
                uint offsetAddress = SIZEOF_UINT * (screenPos.y * _ScreenParams.x + screenPos.x);
                uint oldOffsetAddress;
                // exchange the value with the current counter value
                startOffsetBuffer.InterlockedExchange(offsetAddress, counter, oldOffsetAddress);
                //return half4(half(counter)/(_ScreenParams.x * _ScreenParams.y*2.),1.,1.,1.);
                
                // now need to add the value to the linked list
                FragmentAndLinkBuffer_STRUCT frag;
                frag.color = PackRGBA(col);
                frag.depth = PackDepthSampleIdx( Linear01Depth( i.vertex.z, _ZBufferParams), uSampleIndex );
                //frag.depth = PackDepthSampleIdx( Linear01Depth( i.vertex.z) );
                frag.next = oldOffsetAddress;
                fragmentLLBuffer[counter] = frag;
                
                return col;
            }
            
            ENDHLSL
        }
    }
    
    FallBack "Unlit/Transparent"
}
