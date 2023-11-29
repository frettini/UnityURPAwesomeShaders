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
            
            
            
            #pragma vertex Vert
            #pragma fragment frag
            #pragma target 5.0
            #pragma require randomwrite

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"
            
            #include "Assets/Shaders/OIT/OITCommon.hlsl"
            #include "Assets/Shaders/OIT/OITLinkedListCommon.hlsl"
            
             // The Blit.hlsl file provides the vertex shader (Vert),
            // input structure (Attributes) and output strucutre (Varyings)
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"
            
            StructuredBuffer<FragmentAndLinkBuffer_STRUCT> fragmentLLBuffer : register(t0);
            ByteAddressBuffer startOffsetBuffer : register(t1);
            
            TEXTURE2D_X(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
            
            sampler2D _MainTex;
            float4 _MainTex_ST;

            half4 frag (Varyings input, uint uSampleIdx : SV_SampleIndex) : SV_Target
            {
                half3 col = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, input.texcoord).rgb;
                
                // for every pixel, sort the pixels and blend them
                float2 screenPos = input.positionCS.xy-0.5;
                
                // get the first index in the LL from the startOffsetBuffer
                uint address = SIZEOF_UINT * (screenPos.y * _ScreenParams.x + screenPos.x);
                uint offset = startOffsetBuffer.Load(address);
                
                if(offset > 0)
                {
                }
                
                FragmentAndLinkBuffer_STRUCT tempFrag[MAX_NUM_FRAGS];
                uint numFragments = 0;
                
                // go through all frags in linked list
                while(offset != 0)
                {
                    FragmentAndLinkBuffer_STRUCT Element = fragmentLLBuffer[offset];
                    uint uCoverage = UnpackSampleIdx(Element.depth);
                    if (uCoverage & (1 << uSampleIdx ))
                    {
                        tempFrag[numFragments] = Element;
                        numFragments++;
                    }
                    
                    offset = (numFragments >= MAX_NUM_FRAGS) ? 0 : fragmentLLBuffer[offset].next;
                }   
                
                // sort the array from biggest to smallest depth?
                for(uint i = 1; i < numFragments; i++)
                {
                    FragmentAndLinkBuffer_STRUCT frag = tempFrag[i];
                    
                    uint j = i;
                    while(j > 0 && UnpackDepth(frag.depth) > UnpackDepth(tempFrag[j-1].depth))
                    {
                        FragmentAndLinkBuffer_STRUCT temp = tempFrag[j - 1];
                        tempFrag[j - 1] = tempFrag[j];
                        tempFrag[j] = temp;
                        j--;
                    }
                }
                
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
