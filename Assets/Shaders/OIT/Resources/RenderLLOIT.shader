Shader "Hidden/RenderLLOIT"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalRenderPipeline" }
       
        Pass
        {
            ZTest Always
		    ZWrite Off
		    Cull Off
		    Blend Off
        
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma require randomwrite

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            #define SIZEOF_UINT 4
            #define MAXFRAGS 2
            
            struct FragmentAndLinkBuffer_STRUCT
            {
                uint color;
                uint depth;
                uint next;
            };
            
            StructuredBuffer<FragmentAndLinkBuffer_STRUCT> fragmentLLBuffer : register(t0);
            ByteAddressBuffer startOffsetBuffer : register(t1);
            
            // move that to a separate file in time
            
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

            half4 frag (v2f input, uint uSampleIndex : SV_SampleIndex) : SV_Target
            {
                half3 col = tex2D(_MainTex, input.uv).rgb;
                
                // for every pixel, sort the pixels and blend them
                //float2 screenPos = input.screenPos / input.screenPos.w; 
                float2 screenPos = (input.vertex.xy - 0.5);
                
                // get the first index in the LL from the startOffsetBuffer
                uint address = SIZEOF_UINT * (screenPos.y * _ScreenParams.x + screenPos.x);
                uint offset = startOffsetBuffer.Load(address);
                
                if(offset > 0)
                {
                    col = half3(screenPos.xy,0.);
                }
                
                FragmentAndLinkBuffer_STRUCT tempFrag[MAXFRAGS];
                uint numFragments = 0;
                
                // go through all frags in linked list
                while(offset != 0)
                {
                    FragmentAndLinkBuffer_STRUCT Element = fragmentLLBuffer[offset];
                    uint uSampleIdx = UnpackSampleIdx(Element.depth);
                    if (uSampleIdx == uSampleIndex)
                    {
                        tempFrag[numFragments] = Element;
                        numFragments += 1;
                    }
                    
                    numFragments++;
                    offset = (numFragments >= MAXFRAGS) ? 0 : fragmentLLBuffer[offset].next;
                }
                
                
                // sort the array from biggest to smallest depth?
                for(uint i = 1; i < numFragments; i++)
                {
                    FragmentAndLinkBuffer_STRUCT frag = tempFrag[i];
                    
                    uint j = i;
                    while(j > 0 && frag.depth > tempFrag[j-1].depth)
                    {
                        //tempFrag[j] = tempFrag[j-1];
                        FragmentAndLinkBuffer_STRUCT temp = tempFrag[j - 1];
                        tempFrag[j - 1] = tempFrag[j];
                        tempFrag[j] = temp;
                        j--;
                    }
                    // insert frag 
                    //tempFrag[j] = frag;
                }
                
                return half4(col,1.0);
                return half4(half(numFragments)/half(MAXFRAGS),0.,0.,0.0);
                /*
                // Sort pixels in depth
                for (int i = 0; i < numFragments - 1; i++)
                {
                    for (int j = i + 1; j > 0; j--)
                    {
                        float depth = UnpackDepth(tempFrag[j].depth);
                        float previousElementDepth = UnpackDepth(tempFrag[j - 1].depth);
                        if (previousElementDepth < depth)
                        {
                            FragmentAndLinkBuffer_STRUCT temp = tempFrag[j - 1];
                            tempFrag[j - 1] = tempFrag[j];
                            tempFrag[j] = temp;
                        }
                    }
                }*/
                
                // blend the pixels together
                for(uint k=0; k < numFragments; k++)
                {
                    half4 fragCol = UnpackRGBA(tempFrag[k].color);
                    col = lerp(col.rgb, fragCol.rgb, fragCol.a);
                }
                return half4(col,1.0);
                
            }
            ENDHLSL
        }
    }
}
